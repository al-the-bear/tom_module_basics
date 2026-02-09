/// Tom Build Kit - Pipeline-based build orchestration tool.
///
/// This tool orchestrates build pipelines that can call other Tom build tools
/// (versioner, compiler, runner, cleanup, dependencies) directly without
/// spawning new processes.
///
/// ## Configuration
///
/// Pipelines are defined in `buildkit.yaml`:
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
/// - `cleanup` - Clean build artifacts
/// - `dependencies` - Show dependency tree
/// - `<allowed-binary>` - Run an allowed binary (configured in buildkit.yaml)
/// - `shell <command>` - Run shell command (pipeline config only)
/// - Pipeline names - Call other pipelines
///
/// ## Command Security
///
/// Only built-in commands, configured pipelines, and explicitly allowed
/// binaries can be executed. Arbitrary shell commands are NOT permitted
/// via `:command` syntax or as pipeline step commands. To run arbitrary
/// shell commands, use the `shell ` prefix in pipeline configuration.
///
/// Allowed binaries are configured in buildkit.yaml:
///
/// ```yaml
/// buildkit:
///   allowed-binaries:
///     - astgen
///     - d4rtgen
///     - ws_prepper
/// ```
///
/// ## Per-Tool Option Override
///
/// When running multiple commands, each command inherits global options
/// (like --scan). Use `-s-` to suppress the global --scan for a command:
///
///   buildkit -s . :cleanup -s- --project tom_* :compiler
///
/// This scans with cleanup but NOT with compiler. The `-s-` syntax works
/// for any single-letter option flag: `-v-` suppresses verbose, etc.
///
/// ## Scanning Projects
///
/// Use --scan to run pipelines across multiple projects:
///   buildkit build --scan . --recursive
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';
import 'package:tom_build_kit/tom_build_kit.dart';
import 'package:yaml/yaml.dart';
/// Version info - will be replaced by generated version
String get _version {
  try {
    // ignore: avoid_relative_lib_imports
    return BuildkitVersionInfo.versionLong;
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

  /// Option suppressions using `-X-` syntax.
  /// Keys are the short flag letter (e.g. 's', 'v', 'n').
  final Set<String> suppressedOptions;

  _ExecutionStep({
    required this.isCommand,
    required this.name,
    this.args = const [],
    this.suppressedOptions = const {},
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
        abbr: 'r', negatable: false, help: 'Scan directories recursively')
    ..addFlag('inner-first-git',
        abbr: 'i',
        negatable: false,
        help: 'Scan git repos, process innermost (deepest) first (for commit/push)')
    ..addFlag('outer-first-git',
        abbr: 'o',
        negatable: false,
        help: 'Scan git repos, process outermost (shallowest) first (for pull/fetch)')
    ..addOption('scan',
        abbr: 's', help: 'Scan directory for projects to run pipeline in')
    ..addOption('root',
        abbr: 'R', help: 'Root directory for configuration lookup')
    ..addOption('project',
        abbr: 'p',
        help: 'Project(s) to run (comma-separated, globs: tom_*_builder, ./*)')
    ..addMultiOption('exclude',
        abbr: 'x', help: 'Exclude patterns (path-based globs)')
    ..addMultiOption('exclude-projects',
        help:
            'Exclude projects by name or path (e.g. zom_*, xternal/tom_module_basics/*)')
    ..addFlag('build-order',
        abbr: 'b',
        negatable: false,
        help: 'Sort projects in dependency build order');

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
  final innerFirstGit = results['inner-first-git'] as bool;
  final outerFirstGit = results['outer-first-git'] as bool;
  final scanPath = results['scan'] as String?;

  // Validate mutual exclusivity of git scan flags
  if (innerFirstGit && outerFirstGit) {
    print('Error: --inner-first-git and --outer-first-git are mutually exclusive.');
    exit(1);
  }

  // Warn if known global flags appear after the pipeline/command name.
  // ArgParser(allowTrailingOptions: false) stops parsing at the first
  // non-option argument, so flags after the pipeline name end up in
  // results.rest and are silently ignored. (Issue #15)
  _warnOnMisplacedFlags(results.rest);

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

  // Handle: buildkit help :<command> or buildkit help <command>
  if (results.rest.isNotEmpty && results.rest.first == 'help') {
    if (results.rest.length >= 2) {
      final target = results.rest[1];
      // Handle :command syntax (strip the colon)
      final cmdName =
          target.startsWith(':') ? target.substring(1) : target;
      final helpResult = await _runCommandHelp(cmdName);
      exit(helpResult ? 0 : 1);
    }
    // Plain 'buildkit help' → show main usage
    _printUsage(parser);
    return;
  }

  // Handle define, undefine, and defines commands (modify YAML and exit)
  var restArgs = results.rest.toList();
  if (_handleDefineCommand(restArgs, rootPath)) {
    return;
  }
  if (_handleUndefineCommand(restArgs, rootPath)) {
    return;
  }
  if (_handleDefinesCommand(restArgs, rootPath)) {
    return;
  }

  // Load and expand macros
  final macros = _loadMacros(rootPath);
  if (macros.isNotEmpty) {
    final expandedArgs = _expandMacros(restArgs, macros);
    if (expandedArgs != restArgs && _verbose) {
      print('[macro] Expanded: ${expandedArgs.join(' ')}');
    }
    restArgs = expandedArgs;
  }

  // Parse execution steps from remaining args
  final steps = _parseExecutionSteps(restArgs, pipelineConfig);
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
  } else if (innerFirstGit || outerFirstGit) {
    // Scan for git repositories in the workspace, sorted by depth
    projectPaths = _findGitRepositories(rootPath, recursive: recursive);
    if (projectPaths.isEmpty) {
      print('No git repositories found in: $rootPath');
      exit(1);
    }
    // Sort by path depth: inner-first = deepest first, outer-first = shallowest first
    projectPaths.sort((a, b) {
      final depthA = p.split(a).length;
      final depthB = p.split(b).length;
      if (depthA != depthB) {
        return innerFirstGit
            ? depthB.compareTo(depthA) // deepest first
            : depthA.compareTo(depthB); // shallowest first
      }
      return p.basename(a).compareTo(p.basename(b)); // alphabetic tie-break
    });
    print('Found ${projectPaths.length} git repository(ies) to process'
        ' (${innerFirstGit ? 'inner-first' : 'outer-first'})');
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
    // No explicit --scan, --project, or git flags: load navigation defaults
    // from buildkit_master.yaml
    final masterFile = File(p.join(rootPath, 'buildkit_master.yaml'));
    String? navScan;
    var navRecursive = false;
    if (masterFile.existsSync()) {
      try {
        final content = masterFile.readAsStringSync();
        final yaml = loadYaml(content);
        if (yaml is Map) {
          final nav = yaml['navigation'];
          if (nav is Map) {
            navScan = nav['scan'] as String?;
            navRecursive = nav['recursive'] as bool? ?? false;
          }
        }
      } catch (_) {
        // Ignore YAML parse errors
      }
    }

    if (navScan != null) {
      // Use navigation defaults from master YAML
      final scanDir =
          p.isAbsolute(navScan) ? navScan : p.join(currentDir, navScan);
      projectPaths = await discovery.scanForProjects(
        scanDir,
        recursive: navRecursive || recursive,
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
    } else {
      // Hardcoded fallback: --scan . --recursive
      final fallbackDir = p.join(currentDir, '.');
      projectPaths = await discovery.scanForProjects(
        fallbackDir,
        recursive: true,
        toolKey: 'buildkit',
      );
      if (projectPaths.isEmpty) {
        // No projects found scanning, just use current directory
        projectPaths = [currentDir];
      } else {
        print('Found ${projectPaths.length} project(s) to process');
        if (_verbose) {
          for (final path in projectPaths) {
            print('  - ${p.relative(path, from: currentDir)}');
          }
        }
      }
    }
  }

  // Apply exclusion filters
  projectPaths = _filterProjectPaths(
    projectPaths,
    exclude: results['exclude'] as List<String>,
    excludeProjects: results['exclude-projects'] as List<String>,
    rootPath: rootPath,
  );

  if (projectPaths.isEmpty) {
    print('No projects remaining after exclusion filters.');
    exit(1);
  }

  // Apply build-order sorting if requested
  final buildOrder = results['build-order'] as bool;
  if (buildOrder) {
    // Build-order requires workspace root context for a complete dependency graph
    if (currentDir != rootPath) {
      print('Error: --build-order must be used from the workspace root.');
      print('  Current directory: $currentDir');
      print('  Workspace root:    $rootPath');
      print('');
      print('Change to the workspace root directory and try again.');
      exit(1);
    }

    // Scan ALL workspace projects for the dependency graph — exclusions must
    // not affect graph construction, otherwise the order could be incorrect
    // or unresolvable.
    final allProjects = await discovery.scanForProjects(
      rootPath,
      recursive: true,
      toolKey: 'buildkit',
    );

    final sorter = BuildSorterTool();
    final sorted = sorter.computeBuildOrder(
      allProjects,
      targetProjectPaths: projectPaths,
    );
    if (sorted == null) {
      // Circularity was already printed by computeBuildOrder
      exit(1);
    }
    projectPaths = sorted;
    if (_verbose) {
      print('Build order:');
      for (var i = 0; i < projectPaths.length; i++) {
        print('  ${i + 1}. ${p.relative(projectPaths[i], from: currentDir)}');
      }
    }
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

    for (final step in steps) {
      // Print separator before each step
      _printStepSeparator(step);

      // Apply per-step option suppressions (-X- syntax)
      final stepVerbose =
          step.suppressedOptions.contains('v') ? false : _verbose;
      final stepDryRun =
          step.suppressedOptions.contains('n') ? false : dryRun;

      // If -s- is set and we were scanning, skip this project unless it's
      // the current directory (i.e., suppress scan = run only in cwd)
      if (step.suppressedOptions.contains('s') && scanPath != null) {
        if (projectPath != currentDir) continue;
      }

      // Create executor with per-step overrides
      final stepExecutor = PipelineExecutor(
        config: projectConfig,
        projectPath: projectPath,
        rootPath: rootPath,
        verbose: stepVerbose,
        dryRun: stepDryRun,
      );

      bool result;
      if (step.isCommand && step.name == 'git') {
        // Special :git command — execute git directly in project directory
        result = await _executeGitCommand(
          args: step.args,
          workingDirectory: projectPath,
          dryRun: stepDryRun,
          verbose: stepVerbose,
        );
      } else if (step.isCommand) {
        // Execute command directly via BuiltinCommands
        final commandStr = [step.name, ...step.args].join(' ');
        result = await stepExecutor.executeCommand(commandStr);
      } else {
        // Execute pipeline (pass step.args if we support pipeline args later)
        result = await stepExecutor.execute(step.name);
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
  print('       buildkit help :<command>      Show help for a built-in command');
  print('       buildkit --version            Show version information');
  print('');
  print('Steps can be:');
  print('  <pipeline>        Run a pipeline defined in buildkit.yaml');
  print('  :<command> [args] Run a tool command directly');
  print('');
  print('Built-in commands:');
  print('  :versioner      Generate version.g.dart files with build metadata');
  print('  :bumpversion    Bump pubspec.yaml versions across projects');
  print('  :compiler       Cross-platform Dart compilation with pre/post-compile commands');
  print('  :runner         Build_runner wrapper with builder filtering');
  print('  :cleanup        Clean generated and temporary files');
  print('  :dependencies   Dependency tree visualization');
  print('  :pubget         Run dart pub get on projects');
  print('  :pubgetall      Shortcut for :pubget --scan . --recursive');
  print('  :pubupdate      Run dart pub upgrade on projects');
  print('  :pubupdateall   Shortcut for :pubupdate --scan . --recursive');
  print('  :git            Run git commands in each project directory');
  print('  :dcli           Execute Dart scripts/expressions via dcli');
  print('');
  print('Allowed binaries (configured in buildkit.yaml buildkit.allowed-binaries):');
  print('  Additional binaries can be executed via :name syntax.');
  print('  Unknown commands that are not built-in, not a pipeline, and not');
  print('  in the allowed-binaries list will cause an error.');
  print('');
  print('Command shorthands:');
  print('  Commands can be abbreviated if unique. E.g., :v → :versioner, :cl → :cleanup.');
  print('  Ambiguous shorthands (e.g., :c matches compiler, cleanup) are rejected.');
  print('');
  print('Macros:');
  print('  define <name>=<commands>    Define a reusable macro (saved to buildkit_master.yaml)');
  print('  undefine <name>             Remove a macro');
  print('  defines                     List all defined macros');
  print(r'  $name [args]                Expand macro, replacing $1-$9 with args, $$ with all');
  print('');
  print('Per-tool option override:');
  print('  -s-   Suppress global --scan for this command');
  print('  -v-   Suppress global --verbose for this command');
  print('  -n-   Suppress global --dry-run for this command');
  print('');
  print('Options:');
  print(parser.usage);
  print('');
  print('Configuration:');
  print('  Pipelines are defined in buildkit_master.yaml (workspace) or');
  print('  buildkit.yaml (project) under the buildkit: key.');
  print('  Allowed binaries are defined in buildkit.allowed-binaries.');
  print('  See the project documentation for the full pipeline YAML format.');
  print('');
  print('Examples:');
  print('  buildkit build                      # Run build pipeline');
  print('  buildkit clean build                # Run clean then build');
  print('  buildkit :versioner :compiler       # Run versioner then compiler');
  print('  buildkit build :cleanup --force     # Run build, then cleanup with --force');
  print('  buildkit :pubgetall                 # Run pub get on all projects');
  print('  buildkit :pubgetall --errors        # Show only projects with errors');
  print('  buildkit help :compiler             # Show compiler help');
  print('  buildkit --list                     # List available pipelines');
  print('  buildkit -v build                   # Run build with verbose output');
  print('  buildkit -n deploy                  # Dry-run deploy pipeline');
  print('  buildkit build --scan .             # Run build in projects under current dir');
  print('  buildkit build -s . -r              # Run build recursively in all projects');
  print('  buildkit -i :git add -A :git commit -m "msg"  # Commit all repos (inner first)');
  print('  buildkit -o :git pull --rebase       # Pull all repos (outer first)');
  print('  buildkit :dcli ~s/build_hook.dart     # Run workspace script (if it exists)');
  print('  buildkit :dcli "print(DateTime.now())" # Run expression in every project');
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

/// Find workspace root by looking for buildkit_master.yaml or tom_workspace.yaml.
String _findWorkspaceRoot(String startPath) {
  var current = p.normalize(p.absolute(startPath));
  final root = p.rootPrefix(current);

  while (current != root) {
    if (File(p.join(current, 'buildkit_master.yaml')).existsSync() ||
        File(p.join(current, 'tom_workspace.yaml')).existsSync() ||
        File(p.join(current, 'tom.code-workspace')).existsSync()) {
      return current;
    }
    current = p.dirname(current);
  }

  return startPath;
}

// ============================================================================
// Macro System
// ============================================================================

/// Load macros from `defines:` section of `buildkit_master.yaml`.
Map<String, String> _loadMacros(String rootPath) {
  final masterFile = File(p.join(rootPath, 'buildkit_master.yaml'));
  if (!masterFile.existsSync()) return {};

  try {
    final content = masterFile.readAsStringSync();
    final yaml = loadYaml(content);
    if (yaml is! Map) return {};

    final defines = yaml['defines'];
    if (defines is! Map) return {};

    final macros = <String, String>{};
    for (final entry in defines.entries) {
      if (entry.key is String && entry.value is String) {
        macros[entry.key as String] = entry.value as String;
      }
    }
    return macros;
  } catch (e) {
    if (_verbose) print('Warning: Failed to load macros: $e');
    return {};
  }
}

/// Save a macro to `defines:` section of `buildkit_master.yaml`.
///
/// Uses text-based editing to preserve the file's original formatting.
bool _saveMacro(String rootPath, String name, String value) {
  final masterFile = File(p.join(rootPath, 'buildkit_master.yaml'));

  try {
    String content = '';
    Map<String, String> defines = {};

    if (masterFile.existsSync()) {
      content = masterFile.readAsStringSync();
      final parsed = loadYaml(content);
      if (parsed is Map && parsed['defines'] is Map) {
        defines = Map<String, String>.from(parsed['defines'] as Map);
      }
    }

    // Add/update the macro
    defines[name] = value;

    // Build the new defines section text
    final definesBuffer = StringBuffer();
    definesBuffer.writeln('defines:');
    for (final entry in defines.entries) {
      definesBuffer.writeln('  ${entry.key}: "${_escapeYamlString(entry.value)}"');
    }
    final newDefinesSection = definesBuffer.toString().trimRight();

    // Find and replace the existing defines section, or append
    final definesRegex = RegExp(
      r'^defines:\s*\n(  [^\n]+\n)*',
      multiLine: true,
    );

    String newContent;
    if (definesRegex.hasMatch(content)) {
      // Replace existing defines section
      newContent = content.replaceFirst(definesRegex, '$newDefinesSection\n');
    } else if (content.isNotEmpty) {
      // Append defines section to end
      newContent = '${content.trimRight()}\n\n$newDefinesSection\n';
    } else {
      // New file
      newContent = '$newDefinesSection\n';
    }

    masterFile.writeAsStringSync(newContent);
    return true;
  } catch (e) {
    print('Error saving macro: $e');
    return false;
  }
}

/// Remove a macro from `defines:` section of `buildkit_master.yaml`.
///
/// Uses text-based editing to preserve the file's original formatting.
bool _removeMacro(String rootPath, String name) {
  final masterFile = File(p.join(rootPath, 'buildkit_master.yaml'));
  if (!masterFile.existsSync()) {
    print('No macros defined (buildkit_master.yaml not found)');
    return false;
  }

  try {
    final content = masterFile.readAsStringSync();
    final parsed = loadYaml(content);
    if (parsed is! Map) {
      print('No macros defined');
      return false;
    }

    final definesRaw = parsed['defines'];
    if (definesRaw is! Map || !definesRaw.containsKey(name)) {
      print('Macro not found: $name');
      return false;
    }

    final defines = Map<String, String>.from(definesRaw);
    defines.remove(name);

    // Find the defines section in text
    final definesRegex = RegExp(
      r'^defines:\s*\n(  [^\n]+\n)*',
      multiLine: true,
    );

    String newContent;
    if (defines.isEmpty) {
      // Remove the entire defines section
      newContent = content.replaceFirst(definesRegex, '');
      // Clean up extra blank lines
      newContent = newContent.replaceAll(RegExp(r'\n{3,}'), '\n\n').trimRight();
      if (newContent.isNotEmpty) newContent += '\n';
    } else {
      // Build new defines section
      final definesBuffer = StringBuffer();
      definesBuffer.writeln('defines:');
      for (final entry in defines.entries) {
        definesBuffer.writeln('  ${entry.key}: "${_escapeYamlString(entry.value)}"');
      }
      final newDefinesSection = definesBuffer.toString().trimRight();
      newContent = content.replaceFirst(definesRegex, '$newDefinesSection\n');
    }

    masterFile.writeAsStringSync(newContent);
    return true;
  } catch (e) {
    print('Error removing macro: $e');
    return false;
  }
}

/// Escape a string for YAML double-quoted format.
String _escapeYamlString(String s) {
  return s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
}

/// Expand macros in command line arguments.
///
/// Replaces `$macroname` with the macro definition, substituting:
/// - `$1`, `$2`, etc. with positional arguments
/// - `$$` with all remaining arguments joined
///
/// Returns the expanded argument list.
List<String> _expandMacros(List<String> args, Map<String, String> macros) {
  final result = <String>[];
  var i = 0;

  while (i < args.length) {
    final arg = args[i];

    // Check for macro invocation: $name or $name(args)
    if (arg.startsWith(r'$') && arg.length > 1) {
      final macroName = arg.substring(1);

      // Check if this is a positional placeholder (not a macro)
      if (RegExp(r'^\d+$').hasMatch(macroName) || macroName == r'$') {
        result.add(arg);
        i++;
        continue;
      }

      final definition = macros[macroName];
      if (definition != null) {
        // Collect macro arguments until next command/pipeline/macro
        final macroArgs = <String>[];
        i++;
        while (i < args.length) {
          final next = args[i];
          // Stop at next command, pipeline, define/undefine, or macro
          if (next.startsWith(':') ||
              next.startsWith(r'$') ||
              next == 'define' ||
              next == 'undefine') {
            break;
          }
          macroArgs.add(next);
          i++;
        }

        // Expand the macro definition
        var expanded = definition;

        // Replace $$ with all args
        expanded = expanded.replaceAll(r'$$', macroArgs.join(' '));

        // Replace $1, $2, etc. with positional args
        for (var j = 0; j < macroArgs.length; j++) {
          expanded = expanded.replaceAll('\$${j + 1}', macroArgs[j]);
        }

        // Remove unused positional placeholders
        expanded = expanded.replaceAll(RegExp(r'\$\d+'), '');

        // Split the expanded definition and add to result
        final expandedParts = expanded.trim().split(RegExp(r'\s+'));
        result.addAll(expandedParts.where((p) => p.isNotEmpty));
        continue;
      }
    }

    result.add(arg);
    i++;
  }

  return result;
}

/// Handle `define` command: save macro and return true if handled.
bool _handleDefineCommand(List<String> args, String rootPath) {
  // Format: define name=value value value...
  // Or: define name=:cmd1 :cmd2 ...
  for (var i = 0; i < args.length; i++) {
    if (args[i] == 'define') {
      if (i + 1 >= args.length) {
        print('Error: define requires name=value format');
        print('Usage: define <name>=<command sequence>');
        return true;
      }

      // Parse name=value from next arg
      final def = args[i + 1];
      final eqIndex = def.indexOf('=');
      if (eqIndex <= 0) {
        print('Error: define requires name=value format');
        print('Usage: define <name>=<command sequence>');
        return true;
      }

      final name = def.substring(0, eqIndex);
      var value = def.substring(eqIndex + 1);

      // Collect remaining args until end or another define/undefine
      final valueArgs = <String>[value];
      for (var j = i + 2; j < args.length; j++) {
        if (args[j] == 'define' || args[j] == 'undefine') break;
        valueArgs.add(args[j]);
      }
      value = valueArgs.join(' ').trim();

      if (_saveMacro(rootPath, name, value)) {
        print('Defined macro: $name = $value');
      }
      return true;
    }
  }
  return false;
}

/// Handle `undefine` command: remove macro and return true if handled.
bool _handleUndefineCommand(List<String> args, String rootPath) {
  for (var i = 0; i < args.length; i++) {
    if (args[i] == 'undefine') {
      if (i + 1 >= args.length) {
        print('Error: undefine requires a macro name');
        print('Usage: undefine <name>');
        return true;
      }

      final name = args[i + 1];
      if (_removeMacro(rootPath, name)) {
        print('Removed macro: $name');
      }
      return true;
    }
  }
  return false;
}

/// Handle `defines` command: list all macros and return true if handled.
bool _handleDefinesCommand(List<String> args, String rootPath) {
  for (final arg in args) {
    if (arg == 'defines') {
      final macros = _loadMacros(rootPath);
      if (macros.isEmpty) {
        print('No macros defined.');
      } else {
        print('Defined macros:');
        final maxLen = macros.keys.map((k) => k.length).reduce((a, b) => a > b ? a : b);
        for (final entry in macros.entries) {
          print('  \${${entry.key.padRight(maxLen)}} = ${entry.value}');
        }
      }
      return true;
    }
  }
  return false;
}

// ============================================================================
// Git Repository Discovery
// ============================================================================

/// Find all git repository roots under [rootPath].
///
/// Scans for directories containing a `.git` folder or file (submodules
/// use a `.git` file pointing to the parent repo's modules directory).
/// The root path itself is included if it is a git repository. Submodules
/// and nested repos under known directories (`xternal/`, `xternal_apps/`)
/// are discovered by scanning one level deep by default, or recursively
/// if [recursive] is true.
List<String> _findGitRepositories(String rootPath, {bool recursive = false}) {
  final repos = <String>[];
  final rootDir = Directory(rootPath);

  if (!rootDir.existsSync()) return repos;

  // Helper: check if a directory is a git repo (directory .git or file .git for submodules)
  bool isGitRepo(String dirPath) {
    final gitPath = p.join(dirPath, '.git');
    return Directory(gitPath).existsSync() || File(gitPath).existsSync();
  }

  // Check if root itself is a git repo
  if (isGitRepo(rootPath)) {
    repos.add(rootPath);
  }

  // Scan immediate subdirectories for .git folders/files
  // Also scan xternal/*/ and xternal_apps/*/ for submodules
  final searchDirs = <String>[rootPath];
  final xternalDir = Directory(p.join(rootPath, 'xternal'));
  if (xternalDir.existsSync()) {
    searchDirs.add(xternalDir.path);
  }
  final xternalAppsDir = Directory(p.join(rootPath, 'xternal_apps'));
  if (xternalAppsDir.existsSync()) {
    searchDirs.add(xternalAppsDir.path);
  }

  for (final searchDir in searchDirs) {
    try {
      for (final entity in Directory(searchDir).listSync()) {
        if (entity is Directory && entity.path != rootPath) {
          if (isGitRepo(entity.path)) {
            repos.add(entity.path);
          }
        }
      }
    } catch (_) {
      // Permission errors, etc.
    }
  }

  // Sort for consistent ordering
  repos.sort((a, b) => p.relative(a, from: rootPath)
      .compareTo(p.relative(b, from: rootPath)));

  return repos;
}

/// Execute a git command in the specified working directory.
///
/// Used by the `:git` command to spawn git with the provided [args].
Future<bool> _executeGitCommand({
  required List<String> args,
  required String workingDirectory,
  required bool dryRun,
  required bool verbose,
}) async {
  final displayDir = p.basename(workingDirectory);
  final argsStr = args.join(' ');

  if (dryRun) {
    print('  [DRY RUN] ($displayDir) git $argsStr');
    return true;
  }

  if (verbose) {
    print('  ($displayDir) git $argsStr');
  }

  try {
    final result = await Process.run(
      'git',
      args,
      workingDirectory: workingDirectory,
    );

    final stdoutStr = result.stdout.toString();
    final stderrStr = result.stderr.toString();

    // Prefix output with directory name for clarity
    if (stdoutStr.trim().isNotEmpty) {
      for (final line in stdoutStr.trimRight().split('\n')) {
        print('  ($displayDir) $line');
      }
    }
    if (stderrStr.trim().isNotEmpty) {
      for (final line in stderrStr.trimRight().split('\n')) {
        stderr.writeln('  ($displayDir) $line');
      }
    }

    if (result.exitCode != 0) {
      print('  ($displayDir) git exited with code ${result.exitCode}');
      return false;
    }

    return true;
  } catch (e) {
    print('  Error executing git in $displayDir: $e');
    return false;
  }
}

/// Parse execution steps from remaining command line arguments.
///
/// Steps can be:
/// - Pipeline names (e.g., `build`, `clean`)
/// - Commands prefixed with `:` (e.g., `:versioner`, `:compiler`)
///
/// Each step collects all following arguments until the next step begins.
///
/// Per-tool option suppressions use `-X-` syntax (e.g., `-s-` suppresses
/// the global `--scan` option for that command only).
List<_ExecutionStep> _parseExecutionSteps(
  List<String> args,
  PipelineConfig config,
) {
  final steps = <_ExecutionStep>[];
  if (args.isEmpty) return steps;

  String? currentName;
  bool currentIsCommand = false;
  final currentArgs = <String>[];
  final currentSuppressed = <String>{};

  /// Regex for `-X-` style suppression flags.
  final suppressionPattern = RegExp(r'^-([a-zA-Z])-$');

  void flushStep() {
    if (currentName != null) {
      steps.add(_ExecutionStep(
        isCommand: currentIsCommand,
        name: currentName,
        args: List.from(currentArgs),
        suppressedOptions: Set.from(currentSuppressed),
      ));
      currentArgs.clear();
      currentSuppressed.clear();
    }
  }

  for (final arg in args) {
    // Check for suppression flag (e.g., -s-, -v-, -n-)
    final suppressMatch = suppressionPattern.firstMatch(arg);
    if (suppressMatch != null) {
      currentSuppressed.add(suppressMatch.group(1)!);
      continue;
    }

    if (arg.startsWith(':')) {
      // Start of a command step
      flushStep();
      final rawName = arg.substring(1); // Remove : prefix
      // Resolve shorthand if not an exact match
      if (_builtinCommandNames.contains(rawName.toLowerCase())) {
        currentName = rawName.toLowerCase();
      } else {
        final resolved = _resolveCommandShorthand(rawName);
        if (resolved != null) {
          currentName = resolved;
        } else {
          // Keep raw name for error handling downstream (allowed-binaries, etc.)
          currentName = rawName;
        }
      }
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
        // Bare command name without : prefix treated as argument
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
  'buildsorter',
  'versioner',
  'bumpversion',
  'compiler',
  'runner',
  'cleanup',
  'dependencies',
  'pubget',
  'pubgetall',
  'pubupdate',
  'pubupdateall',
  'git',
  'dcli',
  'define',
  'undefine',
  'defines',
};

/// Resolve a command shorthand to full command name.
///
/// Returns the full command name if [shorthand] uniquely matches a single
/// built-in command via `startsWith()`. Returns null if no match or multiple
/// matches (ambiguous).
String? _resolveCommandShorthand(String shorthand) {
  final lower = shorthand.toLowerCase();
  final matches =
      _builtinCommandNames.where((cmd) => cmd.startsWith(lower)).toList();
  if (matches.length == 1) {
    return matches.first;
  }
  return null; // No match or ambiguous
}

/// Print separator before a step.
void _printStepSeparator(_ExecutionStep step) {
  print('');
  print('________ Running ${step.displayName}');
  print('');
}

/// Run --help for a built-in command by name (supports shorthands).
Future<bool> _runCommandHelp(String commandName) async {
  // Resolve shorthand to full command name
  final resolved = _resolveCommandShorthand(commandName) ??
      ((_builtinCommandNames.contains(commandName.toLowerCase()))
          ? commandName.toLowerCase()
          : null);
  if (resolved == null) {
    // Check if it's ambiguous
    final matches = _builtinCommandNames
        .where((cmd) => cmd.startsWith(commandName.toLowerCase()))
        .toList();
    if (matches.length > 1) {
      print('Ambiguous command shorthand: $commandName');
      print('Matches: ${matches.join(', ')}');
      return false;
    }
    print('Unknown command: $commandName');
    print('');
    print('Available commands:');
    print('  Tools: buildsorter, versioner, bumpversion, compiler, runner,');
    print('         cleanup, dependencies, pubget, pubupdate');
    print('  Other: git, dcli');
    print('  Macros: define, undefine, defines');
    return false;
  }

  switch (resolved) {
    case 'versioner':
      return VersionerTool().run(['--help']);
    case 'bumpversion':
      return BumpVersionTool().run(['--help']);
    case 'compiler':
      return CompilerTool().run(['--help']);
    case 'runner':
      return RunnerTool().run(['--help']);
    case 'cleanup':
      return CleanupTool().run(['--help']);
    case 'dependencies':
      return DependenciesTool().run(['--help']);
    case 'buildsorter':
      return BuildSorterTool().run(['--help']);
    case 'pubget' || 'pubgetall':
      PubGetCommand.printUsage();
      return true;
    case 'pubupdate' || 'pubupdateall':
      PubUpdateCommand.printUsage();
      return true;
    case 'git':
      print('Git Command — run git in each project directory');
      print('');
      print('Usage: buildkit --inner-first-git :git <args...>');
      print('       buildkit -i :git <args...>');
      print('       buildkit --outer-first-git :git <args...>');
      print('       buildkit -o :git <args...>');
      print('');
      print('Executes git with the given arguments in each discovered');
      print('git repository root, ordered by nesting depth.');
      print('');
      print('  --inner-first-git / -i  Deepest repos first (for commit, push, tag, stash)');
      print('  --outer-first-git / -o  Shallowest repos first (for pull, fetch, checkout)');
      print('');
      print('Examples:');
      print('  buildkit -i :git add -A :git commit -m "msg"  # Commit all (inner first)');
      print('  buildkit -i :git push                         # Push all (inner first)');
      print('  buildkit -o :git pull --rebase                # Pull all (outer first)');
      print('  buildkit -i :git status                       # Status of all repos');
      return true;
    case 'dcli':
      print('DCli Command — execute Dart scripts via dcli');
      print('');
      print('Usage: buildkit :dcli <file|expression> [-init-source <file>] [-no-init-source]');
      print('       bk :dcli <file|expression> [-init-source <file>] [-no-init-source]');
      print('');
      print('Runs dcli with the given script, file, or expression in each');
      print('discovered project directory. For file targets, the command is');
      print('only executed if the file exists — this enables optional');
      print('per-project build scripts.');
      print('');
      print('Path notations:');
      print('  ~w/path   Workspace root (e.g., ~w/tool/setup.dart)');
      print('  ~s/path   Workspace _scripts/ folder (e.g., ~s/build_hook.dart)');
      print('  ::name    Workspace _scripts/bin/ folder (e.g., ::poll_binaries)');
      print('');
      print('If the filename has no extension, .dart is appended automatically.');
      print('If the argument is wrapped in double quotes, it is treated as a');
      print('Dart expression and always executed (no file check).');
      print('');
      print('Options (only these are allowed in buildkit context):');
      print('  -init-source <file>   Use custom init source file for dcli');
      print('  -no-init-source       Do not load custom init source');
      print('');
      print('Examples:');
      print('  bk :dcli ~s/build_hook.dart             # Run workspace script (if exists)');
      print('  bk :dcli ::poll_binaries                 # Run _scripts/bin/poll_binaries.dart');
      print('  bk :dcli build_step.dart                 # Run per-project script (optional)');
      print('  bk :dcli "print(DateTime.now())"         # Run expression in every project');
      print('  bk :dcli ~s/init.dart -no-init-source    # Skip init source');
      return true;
    case 'define':
      print('Define Command — create a reusable macro');
      print('');
      print('Usage: buildkit define <name>=<commands>');
      print('       bk define <name>=<commands>');
      print('');
      print('Creates a named macro that expands to the given commands.');
      print('Macros are saved to buildkit_master.yaml in the workspace root.');
      print('');
      print('Macro expansion:');
      print(r'  $1-$9    Replaced with positional arguments');
      print(r'  $$       Replaced with all arguments');
      print('');
      print('Examples:');
      print('  bk define cv=:versioner :compiler     # Create macro');
      print(r'  bk $cv                                # Expands to: :versioner :compiler');
      print(r'  bk define test=:runner --command $$   # With all-args placeholder');
      print(r'  bk $test build                        # Expands to: :runner --command build');
      print('');
      print('See also: undefine, defines');
      return true;
    case 'undefine':
      print('Undefine Command — remove a macro');
      print('');
      print('Usage: buildkit undefine <name>');
      print('       bk undefine <name>');
      print('');
      print('Removes a named macro from buildkit_master.yaml.');
      print('');
      print('Examples:');
      print('  bk undefine cv    # Remove the cv macro');
      print('');
      print('See also: define, defines');
      return true;
    case 'defines':
      print('Defines Command — list all defined macros');
      print('');
      print('Usage: buildkit defines');
      print('       bk defines');
      print('');
      print('Lists all macros defined in buildkit_master.yaml.');
      print('');
      print('Output format:');
      print('  <name>=<commands>');
      print('');
      print('See also: define, undefine');
      return true;
  }
  // Unreachable — all cases covered after early validation
  return false;
}

/// Filter project paths by exclude patterns, exclude-projects patterns,
/// master YAML exclude-projects, and buildkit_skip.yaml marker files.
List<String> _filterProjectPaths(
  List<String> projects, {
  required List<String> exclude,
  required List<String> excludeProjects,
  required String rootPath,
}) {
  var result = projects;

  // Apply --exclude (path-based globs)
  if (exclude.isNotEmpty) {
    result = result.where((path) {
      for (final pattern in exclude) {
        try {
          if (Glob(pattern).matches(path)) return false;
        } catch (_) {
          if (path.contains(pattern)) return false;
        }
      }
      return true;
    }).toList();
  }

  // Merge CLI --exclude-projects with master YAML navigation section
  final allExcludeProjects = [...excludeProjects];
  final masterFile = File(p.join(rootPath, 'buildkit_master.yaml'));
  if (masterFile.existsSync()) {
    try {
      final content = masterFile.readAsStringSync();
      final yaml = loadYaml(content);
      if (yaml is Map) {
        final nav = yaml['navigation'];
        if (nav is Map) {
          final ep = nav['exclude-projects'] ?? nav['excludeProjects'];
          if (ep is String) {
            allExcludeProjects.add(ep);
          } else if (ep is List) {
            allExcludeProjects.addAll(ep.map((e) => e.toString()));
          }
        }
      }
    } catch (_) {
      // Ignore YAML parse errors
    }
  }

  // Apply exclude-projects filtering
  // Patterns with '/' or '**' match against the workspace-relative path;
  // simple patterns match against the folder basename only.
  if (allExcludeProjects.isNotEmpty) {
    result = result.where((projectPath) {
      final folderName = p.basename(projectPath);
      final relativePath = p.relative(projectPath, from: rootPath);
      for (final pattern in allExcludeProjects) {
        final isPathPattern = pattern.contains('/') || pattern.contains('**');
        final matchTarget = isPathPattern ? relativePath : folderName;
        try {
          if (Glob(pattern).matches(matchTarget)) return false;
        } catch (_) {
          if (matchTarget.contains(pattern)) return false;
        }
      }
      return true;
    }).toList();
  }

  // Remove projects that contain buildkit_skip.yaml
  result = result.where((projectPath) {
    if (ProjectDiscovery.hasSkipFile(projectPath)) {
      if (_verbose) {
        print('  Skipping (${ProjectDiscovery.skipFileName}): $projectPath');
      }
      return false;
    }
    return true;
  }).toList();

  return result;
}

/// Known global flags that users might accidentally place after the
/// pipeline/command name. These are silently consumed by `results.rest`
/// when `allowTrailingOptions: false` is set.
const _knownGlobalFlags = {
  '--verbose', '-v',
  '--dry-run', '-n',
  '--recursive', '-r',
  '--inner-first-git', '-i',
  '--outer-first-git', '-o',
  '--scan', '-s',
  '--project', '-p',
  '--root', '-R',
  '--exclude', '-x',
  '--exclude-projects',
  '--list', '-l',
  '--help', '-h',
};

/// Warn if known global flags appear in the rest args (i.e., after the
/// pipeline/command name). These flags are silently ignored by ArgParser
/// due to `allowTrailingOptions: false`.
void _warnOnMisplacedFlags(List<String> rest) {
  final misplaced = rest.where((arg) => _knownGlobalFlags.contains(arg)).toList();
  if (misplaced.isEmpty) return;

  print('⚠️  Warning: The following global flag(s) appear AFTER the '
      'pipeline/command name and will be ignored:');
  print('   ${misplaced.join(', ')}');
  print('   Move them BEFORE the pipeline name. Example:');
  print('     buildkit ${misplaced.join(' ')} <pipeline>');
  print('');
}