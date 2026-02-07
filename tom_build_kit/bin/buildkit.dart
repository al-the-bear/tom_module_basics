/// Tom Build Kit - Pipeline-based build orchestration tool.
///
/// This tool orchestrates build pipelines that can call other Tom build tools
/// (versioner, compiler, runner, astgen, d4rtgen) directly without spawning
/// new processes.
///
/// ## Configuration
///
/// Pipelines are defined in `tom_build.yaml`:
///
/// ```yaml
/// buildkit:
///   pipelines:
///     clean:
///       executable: true
///       core:
///         - commands:
///             - shell rm -rf build/
///     build:
///       executable: true
///       runBefore: clean
///       core:
///         - commands:
///             - versioner
///             - compiler
///     deploy:
///       executable: true
///       runAfter: build
///       precore:
///         - commands:
///             - shell echo "Preparing deployment..."
///       core:
///         - commands:
///             - shell rsync -av build/ server:/app/
/// ```
///
/// ## Command Types
///
/// - `versioner` - Run version builder
/// - `compiler` - Run compiler builder
/// - `runner` - Run build_runner wrapper
/// - `astgen` - Run AST generator
/// - `d4rtgen` - Run D4rt generator
/// - `shell <command>` - Run shell command
/// - Pipeline names - Call other pipelines
///
/// ## Scanning Projects
///
/// Use --scan to run pipelines across multiple projects:
///   buildkit build --scan . --recursive
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';
import 'package:tom_build_kit/tom_build_kit.dart';

/// Version info - will be replaced by generated version
String get _version {
  try {
    // ignore: avoid_relative_lib_imports
    return TomVersionInfo.versionLong;
  } catch (_) {
    return '1.0.0-dev';
  }
}

bool _verbose = false;

/// Represents a step to execute: either a pipeline or a direct command.
class _ExecutionStep {
  /// True if this is a direct command (prefixed with :), false for pipeline.
  final bool isCommand;

  /// The name of the pipeline or command (without : prefix for commands).
  final String name;

  /// Arguments to pass to the pipeline or command.
  final List<String> args;

  _ExecutionStep({
    required this.isCommand,
    required this.name,
    this.args = const [],
  });

  /// Display string for separators and logging.
  String get displayName {
    final prefix = isCommand ? ':' : '';
    final argsStr = args.isNotEmpty ? ' ${args.join(' ')}' : '';
    return '$prefix$name$argsStr';
  }
}

Future<void> main(List<String> args) async {
  final parser = ArgParser(allowTrailingOptions: false)
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help')
    ..addFlag('version', abbr: 'V', negatable: false, help: 'Show version')
    ..addFlag('verbose', abbr: 'v', negatable: false, help: 'Verbose output')
    ..addFlag('dry-run',
        abbr: 'n', negatable: false, help: 'Show what would be executed')
    ..addFlag('list',
        abbr: 'l', negatable: false, help: 'List available pipelines')
    ..addFlag('recursive',
        abbr: 'R', negatable: false, help: 'Scan directories recursively')
    ..addOption('scan',
        abbr: 's', help: 'Scan directory for projects to run pipeline in')
    ..addOption('root',
        abbr: 'r', help: 'Root directory for configuration lookup')
    ..addOption('project',
        abbr: 'p',
        help: 'Project(s) to run (comma-separated, globs: tom_*_builder, ./*)');

  ArgResults results;
  try {
    results = parser.parse(args);
  } catch (e) {
    print('Error: $e');
    print('');
    _printUsage(parser);
    exit(1);
  }

  if (results['help'] as bool) {
    _printUsage(parser);
    return;
  }

  if (results['version'] as bool) {
    print('Build Kit $_version');
    return;
  }

  _verbose = results['verbose'] as bool;
  final dryRun = results['dry-run'] as bool;
  final listPipelines = results['list'] as bool;
  final recursive = results['recursive'] as bool;
  final scanPath = results['scan'] as String?;

  // Determine root directory
  final currentDir = Directory.current.path;
  final rootPath = results['root'] as String? ?? _findWorkspaceRoot(currentDir);

  // Load pipeline configuration from root
  final pipelineConfig = PipelineConfig.load(
    projectPath: currentDir,
    rootPath: rootPath,
  );

  if (listPipelines) {
    _listPipelines(pipelineConfig);
    return;
  }

  // Parse execution steps from remaining args
  final steps = _parseExecutionSteps(results.rest, pipelineConfig);
  if (steps.isEmpty) {
    print('Error: No pipeline or command specified.');
    print('');
    print('Use --list to see available pipelines.');
    print('');
    _printUsage(parser);
    exit(1);
  }

  // Determine projects to run on
  List<String> projectPaths;
  final discovery = ProjectDiscovery(verbose: _verbose);
  final projectArg = results['project'] as String?;

  if (scanPath != null) {
    // Scan for projects using shared ProjectDiscovery
    final scanDir = p.isAbsolute(scanPath) ? scanPath : p.join(currentDir, scanPath);
    projectPaths = await discovery.scanForProjects(
      scanDir,
      recursive: recursive,
      toolKey: 'buildkit',
    );
    if (projectPaths.isEmpty) {
      print('No projects found in: $scanDir');
      exit(1);
    }
    print('Found ${projectPaths.length} project(s) to process');
    if (_verbose) {
      for (final path in projectPaths) {
        print('  - ${p.relative(path, from: currentDir)}');
      }
    }
  } else if (projectArg != null) {
    // Project pattern(s) specified (supports comma-separated, globs, ./* etc.)
    projectPaths = await discovery.resolveProjectPatterns(
      projectArg,
      basePath: currentDir,
    );
    if (projectPaths.isEmpty) {
      print('No projects found matching: $projectArg');
      exit(1);
    }
    if (projectPaths.length > 1 || _verbose) {
      print('Found ${projectPaths.length} project(s) to process');
      if (_verbose) {
        for (final path in projectPaths) {
          print('  - ${p.relative(path, from: currentDir)}');
        }
      }
    }
  } else {
    // Default: current directory
    projectPaths = [currentDir];
  }

  // Execute steps in each project
  var success = true;
  var processedCount = 0;
  var failedCount = 0;

  for (final projectPath in projectPaths) {
    // Reload config for each project (may have project-level overrides)
    final projectConfig = PipelineConfig.load(
      projectPath: projectPath,
      rootPath: rootPath,
    );

    final executor = PipelineExecutor(
      config: projectConfig,
      projectPath: projectPath,
      rootPath: rootPath,
      verbose: _verbose,
      dryRun: dryRun,
    );

    for (final step in steps) {
      // Print separator before each step
      _printStepSeparator(step);

      bool result;
      if (step.isCommand) {
        // Execute command directly via BuiltinCommands
        final commandStr = [step.name, ...step.args].join(' ');
        result = await executor.executeCommand(commandStr);
      } else {
        // Execute pipeline (pass step.args if we support pipeline args later)
        result = await executor.execute(step.name);
      }

      if (!result) {
        success = false;
        failedCount++;
        // Continue to next project instead of stopping
        break;
      }
    }
    processedCount++;
  }

  print('');
  print('=' * 60);
  print('Build Kit Summary');
  print('=' * 60);
  print('Projects processed: $processedCount');
  if (failedCount > 0) {
    print('Projects failed: $failedCount');
  }
  print('Status: ${success ? 'SUCCESS' : 'FAILED'}');

  exit(success ? 0 : 1);
}

void _printUsage(ArgParser parser) {
  print('Build Kit - Pipeline-based build orchestration');
  print('');
  print('Usage: buildkit [options] <pipeline|:command> [args...] [<pipeline|:command> [args...]]...');
  print('');
  print('Steps can be:');
  print('  <pipeline>        Run a pipeline defined in tom_build.yaml');
  print('  :<command> [args] Run a tool command directly (versioner, compiler, etc.)');
  print('');
  print('Built-in commands:');
  print('  :versioner    Generate version files');
  print('  :compiler     Compile executables');
  print('  :runner       Run build_runner');
  print('  :astgen       Generate AST code');
  print('  :d4rtgen      Generate D4rt bridges');
  print('  :cleanup      Clean build artifacts');
  print('  :pubget       Run dart pub get on projects');
  print('  :pubgetall    Shortcut for :pubget --scan . --recursive');
  print('');
  print('Options:');
  print(parser.usage);
  print('');
  print('Examples:');
  print('  buildkit build                      # Run build pipeline');
  print('  buildkit clean build                # Run clean then build');
  print('  buildkit :versioner :compiler       # Run versioner then compiler');
  print('  buildkit build :cleanup --all       # Run build, then cleanup with --all');
  print('  buildkit :pubgetall                 # Run pub get on all projects');
  print('  buildkit :pubgetall --errors        # Show only projects with errors');
  print('  buildkit --list                     # List available pipelines');
  print('  buildkit -v build                   # Run build with verbose output');
  print('  buildkit -n deploy                  # Dry-run deploy pipeline');
  print('  buildkit build --scan .             # Run build in projects under current dir');
  print('  buildkit build -s . -R              # Run build recursively in all projects');
}

void _listPipelines(PipelineConfig config) {
  print('Available pipelines:');
  print('');

  final pipelines = config.pipelines;
  if (pipelines.isEmpty) {
    print('  (none configured)');
    return;
  }

  for (final entry in pipelines.entries) {
    final name = entry.key;
    final pipeline = entry.value;

    final executableStr = pipeline.executable ? '' : ' (internal)';
    print('  $name$executableStr');

    if (pipeline.runBefore.isNotEmpty) {
      print('    runs before: ${pipeline.runBefore.join(', ')}');
    }
    if (pipeline.runAfter.isNotEmpty) {
      print('    runs after: ${pipeline.runAfter.join(', ')}');
    }

    if (_verbose) {
      if (pipeline.precore.isNotEmpty) {
        print('    precore: ${pipeline.precore.length} step(s)');
      }
      if (pipeline.core.isNotEmpty) {
        print('    core: ${pipeline.core.length} step(s)');
      }
      if (pipeline.postcore.isNotEmpty) {
        print('    postcore: ${pipeline.postcore.length} step(s)');
      }
    }
  }
}

/// Find workspace root by looking for tom_build.yaml or tom_workspace.yaml.
String _findWorkspaceRoot(String startPath) {
  var current = p.normalize(p.absolute(startPath));
  final root = p.rootPrefix(current);

  while (current != root) {
    if (File(p.join(current, 'tom_workspace.yaml')).existsSync() ||
        File(p.join(current, 'tom.code-workspace')).existsSync()) {
      return current;
    }
    current = p.dirname(current);
  }

  return startPath;
}

/// Parse execution steps from remaining command line arguments.
///
/// Steps can be:
/// - Pipeline names (e.g., `build`, `clean`)
/// - Commands prefixed with `:` (e.g., `:versioner`, `:compiler`)
///
/// Each step collects all following arguments until the next step begins.
List<_ExecutionStep> _parseExecutionSteps(
  List<String> args,
  PipelineConfig config,
) {
  final steps = <_ExecutionStep>[];
  if (args.isEmpty) return steps;

  String? currentName;
  bool currentIsCommand = false;
  final currentArgs = <String>[];

  void flushStep() {
    if (currentName != null) {
      steps.add(_ExecutionStep(
        isCommand: currentIsCommand,
        name: currentName,
        args: List.from(currentArgs),
      ));
      currentArgs.clear();
    }
  }

  for (final arg in args) {
    if (arg.startsWith(':')) {
      // Start of a command step
      flushStep();
      currentName = arg.substring(1); // Remove : prefix
      currentIsCommand = true;
    } else if (currentName == null ||
        config.pipelines.containsKey(arg) ||
        _builtinCommandNames.contains(arg)) {
      // Start of a pipeline step (or first arg is a pipeline/command name)
      // Also check if this arg is a known pipeline name even mid-stream
      if (currentName == null) {
        // First step - determine if it's a pipeline or treat unknown as pipeline
        currentName = arg;
        currentIsCommand = false;
      } else if (config.pipelines.containsKey(arg)) {
        // This is a known pipeline name, start new step
        flushStep();
        currentName = arg;
        currentIsCommand = false;
      } else if (_builtinCommandNames.contains(arg) && !currentIsCommand) {
        // Could be a bare command without : prefix (backward compatibility)
        // But only if current step is also not a command
        currentArgs.add(arg);
      } else {
        // It's an argument for the current step
        currentArgs.add(arg);
      }
    } else {
      // Argument for current step
      currentArgs.add(arg);
    }
  }

  flushStep();
  return steps;
}

/// Names of built-in commands (without : prefix).
const _builtinCommandNames = {
  'versioner',
  'compiler',
  'runner',
  'astgen',
  'd4rtgen',
  'cleanup',
  'pubget',
  'pubgetall',
};

/// Print separator before a step.
void _printStepSeparator(_ExecutionStep step) {
  print('');
  print('________ Running ${step.displayName}');
  print('');
}
