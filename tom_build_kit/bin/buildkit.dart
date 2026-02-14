#!/usr/bin/env dart
/// Tom Build Kit - Pipeline-based build orchestration tool (v2).
///
/// This is the v2 implementation using ToolRunner for command execution
/// and PipelineExecutor for pipeline orchestration.
///
/// ## Execution Modes
///
/// 1. **Direct commands**: `buildkit :versioner`, `buildkit :gitstatus`
/// 2. **Pipelines**: `buildkit build`, `buildkit deploy`
/// 3. **Macros**: `buildkit :define name=value`, `buildkit :defines`
///
/// ## Navigation Options
///
/// - `--scan <dir>` - Scan directory for projects
/// - `--recursive` - Scan recursively
/// - `--project <glob>` - Filter projects by name
/// - `--root` or `-R` - Execute from workspace root
/// - `--inner-first-git` - Process innermost git repos first
/// - `--outer-first-git` - Process outermost git repos first
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base_v2.dart';
import 'package:tom_build_kit/tom_build_kit.dart';

/// Version string.
String get _version => BuildkitVersionInfo.versionLong;

/// Global macro storage.
final Map<String, String> _macros = {};

/// Verbose flag.
bool _verbose = false;

/// Dry-run flag.
bool _dryRun = false;

Future<void> main(List<String> args) async {
  // Check for version command early
  if (args.isNotEmpty && 
      (args.first.toLowerCase() == 'version' || args.first == '--version' || args.first == '-V')) {
    print('Build Kit $_version');
    return;
  }

  // Check for help command early
  if (args.isEmpty || args.first == '--help' || args.first == '-h') {
    _printUsage();
    return;
  }

  // Pre-process args to handle -R without argument
  final (processedArgs, bareRootFlag) = _preprocessRootFlag(args);
  
  // Parse global options
  final globalParser = _createGlobalParser();
  ArgResults globalResults;
  
  try {
    globalResults = globalParser.parse(processedArgs);
  } catch (e) {
    print('Error parsing arguments: $e');
    print('');
    _printUsage();
    exit(1);
  }

  _verbose = globalResults['verbose'] as bool;
  _dryRun = globalResults['dry-run'] as bool;
  
  // Determine workspace/project mode
  final currentDir = Directory.current.path;
  final isWorkspaceMode = bareRootFlag || globalResults['root'] != null ||
      (globalResults['inner-first-git'] as bool) || 
      (globalResults['outer-first-git'] as bool);
  final rootPath = bareRootFlag
      ? _findWorkspaceRoot(currentDir)
      : (globalResults['root'] as String?) ?? 
        (isWorkspaceMode ? _findWorkspaceRoot(currentDir) : currentDir);
  
  // Get the command/pipeline and its args
  final rest = globalResults.rest;
  if (rest.isEmpty) {
    // Just global options - show list if --list
    if (globalResults['list'] as bool) {
      await _listPipelines(rootPath);
    } else {
      _printUsage();
    }
    return;
  }

  // Parse execution steps (commands with :, pipelines without)
  final steps = _parseExecutionSteps(rest, globalResults);
  
  // Load pipeline config
  final config = PipelineConfig.load(
    projectPath: rootPath,
    rootPath: rootPath,
  );
  
  // Create tool runner for direct commands
  final executors = createBuildkitExecutors(
    onDefine: (name, value) => _macros[name] = value,
    onUndefine: (name) => _macros.remove(name) != null,
    getMacros: () => Map.unmodifiable(_macros),
  );
  
  final runner = ToolRunner(
    tool: buildkitTool,
    executors: executors,
    verbose: _verbose,
  );
  
  // Execute each step
  for (final step in steps) {
    if (_verbose && steps.length > 1) {
      print('');
      print('─' * 40);
      print('▶ ${step.displayName}');
      print('─' * 40);
    }
    
    bool success;
    if (step.isCommand) {
      // Direct command via ToolRunner
      success = await _executeCommand(runner, step, globalResults, rootPath, isWorkspaceMode);
    } else {
      // Pipeline via PipelineExecutor
      success = await _executePipeline(config, step, globalResults, rootPath);
    }
    
    if (!success) {
      exit(1);
    }
  }

  // Print overall success summary
  if (steps.length > 1 || steps.any((s) => !s.isCommand)) {
    print('Pipeline completed: SUCCESS');
  }
}

/// Create the global argument parser.
ArgParser _createGlobalParser() {
  return ArgParser(allowTrailingOptions: false)
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help')
    ..addFlag('version', abbr: 'V', negatable: false, help: 'Show version')
    ..addFlag('verbose', abbr: 'v', negatable: false, help: 'Verbose output')
    ..addFlag('dry-run', abbr: 'n', negatable: false, help: 'Show what would be executed')
    ..addFlag('list', abbr: 'l', negatable: false, help: 'List available pipelines')
    ..addFlag('recursive', abbr: 'r', negatable: true, defaultsTo: false,
        help: 'Scan directories recursively')
    ..addFlag('inner-first-git', abbr: 'i', negatable: false,
        help: 'Process innermost git repos first (for commit/push)')
    ..addFlag('outer-first-git', abbr: 'o', negatable: false,
        help: 'Process outermost git repos first (for pull/fetch)')
    ..addFlag('workspace-recursion', abbr: 'w', negatable: false,
        help: 'Shell out to sub-workspaces')
    ..addOption('scan', abbr: 's', help: 'Scan directory for projects')
    ..addOption('root', abbr: 'R', help: 'Workspace root path')
    ..addOption('project', abbr: 'p', help: 'Project filter (glob patterns)')
    ..addMultiOption('exclude', abbr: 'x', help: 'Exclude patterns')
    ..addMultiOption('exclude-projects', help: 'Exclude projects by name')
    ..addOption('modules', abbr: 'm', help: 'Git modules filter')
    ..addFlag('build-order', abbr: 'b', negatable: true, defaultsTo: false,
        help: 'Sort projects in dependency build order');
}

/// Represents an execution step.
class _ExecutionStep {
  final bool isCommand;
  final String name;
  final List<String> args;
  final Set<String> suppressedOptions;

  _ExecutionStep({
    required this.isCommand,
    required this.name,
    this.args = const [],
    this.suppressedOptions = const {},
  });

  String get displayName {
    final prefix = isCommand ? ':' : '';
    final argsStr = args.isNotEmpty ? ' ${args.join(' ')}' : '';
    return '$prefix$name$argsStr';
  }
}

/// Parse execution steps from remaining args.
///
/// Handles commands (`:xxx`) and pipeline names. Options and their values
/// that follow a command are treated as command args, not pipeline names.
List<_ExecutionStep> _parseExecutionSteps(List<String> rest, ArgResults global) {
  final steps = <_ExecutionStep>[];
  var i = 0;

  while (i < rest.length) {
    final arg = rest[i];
    final suppressions = <String>{};
    
    // Check for command (starts with :)
    if (arg.startsWith(':')) {
      final name = arg.substring(1);
      final stepArgs = <String>[];
      i++;
      
      // Collect args until next command or standalone pipeline name.
      // If a token is preceded by an option (e.g., --scan <value>),
      // it is the option's value, not a pipeline name.
      var prevWasValueOption = false;
      while (i < rest.length && !rest[i].startsWith(':')) {
        final stepArg = rest[i];
        
        // If the previous token was a value-taking option, this is its value
        if (prevWasValueOption) {
          stepArgs.add(stepArg);
          prevWasValueOption = false;
          i++;
          continue;
        }
        
        // Check if this is an option that takes a value
        if (stepArg.startsWith('-')) {
          // Check for option suppression (-X-)
          if (stepArg.length == 3 && stepArg[0] == '-' && stepArg[2] == '-' &&
              !stepArg.startsWith('--')) {
            suppressions.add(stepArg[1]);
          } else if (stepArg.contains('=')) {
            // --key=value form, no next value expected
            stepArgs.add(stepArg);
          } else if (_isValueOption(stepArg)) {
            // Option that expects a value as next arg
            stepArgs.add(stepArg);
            prevWasValueOption = true;
          } else {
            // Flag (boolean option)
            stepArgs.add(stepArg);
          }
          i++;
          continue;
        }
        
        // Non-option, non-command token: could be positional arg or pipeline name
        // If we're collecting command args, treat as positional
        stepArgs.add(stepArg);
        i++;
      }
      
      steps.add(_ExecutionStep(
        isCommand: true,
        name: name,
        args: stepArgs,
        suppressedOptions: suppressions,
      ));
    } else if (!arg.startsWith('-')) {
      // Check if this is a macro keyword (handled as a command)
      const macroKeywords = {'define', 'defines', 'undefine'};
      final isCommand = macroKeywords.contains(arg);
      final name = arg;
      final stepArgs = <String>[];
      i++;
      
      // Collect args until next command/pipeline
      var prevWasValueOption = false;
      while (i < rest.length && !rest[i].startsWith(':')) {
        final stepArg = rest[i];
        
        if (prevWasValueOption) {
          stepArgs.add(stepArg);
          prevWasValueOption = false;
          i++;
          continue;
        }
        
        if (stepArg.startsWith('-')) {
          if (stepArg.contains('=')) {
            stepArgs.add(stepArg);
          } else if (_isValueOption(stepArg)) {
            stepArgs.add(stepArg);
            prevWasValueOption = true;
          } else {
            stepArgs.add(stepArg);
          }
          i++;
          continue;
        }
        
        // Non-option: treat as pipeline arg (positional)
        stepArgs.add(stepArg);
        i++;
      }
      
      steps.add(_ExecutionStep(
        isCommand: isCommand,
        name: name,
        args: stepArgs,
      ));
    } else {
      // Unexpected flag in rest - skip
      i++;
    }
  }

  return steps;
}

/// Check if an option takes a value (not a boolean flag).
bool _isValueOption(String opt) {
  // Known value-taking options
  const valueOptions = {
    '--scan', '-s',
    '--project', '-p',
    '--root', '-R',
    '--exclude', '-x',
    '--exclude-projects',
    '--modules',
    '--message',
    '--type', '--set',
    '--target', '--builder',
    '--prefix', '--branch',
    '--base', '--onto', '--create', '--delete',
    '--remote', '--index', '--count', '-n',
    '--to', '--depth',
    '--init-source',
    '--config',
  };
  return valueOptions.contains(opt);
}

/// Execute a direct command via ToolRunner.
Future<bool> _executeCommand(
  ToolRunner runner,
  _ExecutionStep step,
  ArgResults global,
  String rootPath,
  bool isWorkspaceMode,
) async {
  // Build args for the command.
  // Global options MUST come BEFORE the :command, because CliArgParser treats
  // all options after a :command as per-command options.
  final globalArgs = <String>[];
  final cmdArgs = <String>[];
  
  // Global navigation options first
  if (isWorkspaceMode) {
    globalArgs.addAll(['--root', rootPath]);
  }
  
  final scanPath = global['scan'] as String?;
  if (scanPath != null && !step.suppressedOptions.contains('s')) {
    globalArgs.addAll(['--scan', scanPath]);
  } else if (isWorkspaceMode) {
    // In workspace mode, default to scanning from workspace root recursively.
    globalArgs.addAll(['--scan', rootPath]);
  }
  
  if (global['recursive'] == true && !step.suppressedOptions.contains('r')) {
    globalArgs.add('--recursive');
  } else if (isWorkspaceMode && scanPath == null) {
    globalArgs.add('--recursive');
  }
  
  if (global['inner-first-git'] == true) {
    globalArgs.add('--inner-first-git');
  }
  
  if (global['outer-first-git'] == true) {
    globalArgs.add('--outer-first-git');
  }
  
  if (global['workspace-recursion'] == true) {
    globalArgs.add('--workspace-recursion');
  }
  
  if (global['build-order'] == true) {
    globalArgs.add('--build-order');
  }
  
  // Global common options
  if (_verbose && !step.suppressedOptions.contains('v')) {
    globalArgs.add('--verbose');
  }
  if (_dryRun && !step.suppressedOptions.contains('n')) {
    globalArgs.add('--dry-run');
  }
  
  final project = global['project'] as String?;
  if (project != null && !step.suppressedOptions.contains('p')) {
    globalArgs.addAll(['--project', project]);
    // When --project is specified without --scan, enable recursive scanning
    // so the project can be found by the traversal engine.
    if (scanPath == null && !isWorkspaceMode) {
      globalArgs.addAll(['--scan', '.', '--recursive']);
    }
  }
  
  final excludes = global['exclude'] as List<String>?;
  if (excludes != null) {
    for (final x in excludes) {
      globalArgs.addAll(['--exclude', x]);
    }
  }
  
  final excludeProjects = global['exclude-projects'] as List<String>?;
  if (excludeProjects != null) {
    for (final x in excludeProjects) {
      globalArgs.addAll(['--exclude-projects', x]);
    }
  }
  
  final modules = global['modules'] as String?;
  if (modules != null) {
    globalArgs.addAll(['--modules', modules]);
  }
  
  // Command comes after global args, followed by command-specific args
  cmdArgs.addAll(globalArgs);
  cmdArgs.add(':${step.name}');
  cmdArgs.addAll(step.args);
  
  // Apply macro substitution
  final processedArgs = _applyMacros(cmdArgs);
  
  // Run via ToolRunner
  final result = await runner.run(processedArgs);
  
  if (!result.success && result.errorMessage != null) {
    print('Error: ${result.errorMessage}');
  }
  
  return result.success;
}

/// Execute a pipeline via PipelineExecutor.
Future<bool> _executePipeline(
  PipelineConfig config,
  _ExecutionStep step,
  ArgResults global,
  String rootPath,
) async {
  final scanPath = global['scan'] as String?;
  final recursive = global['recursive'] as bool;
  
  if (scanPath != null) {
    // Execute pipeline across scanned projects
    return _executePipelineAcrossProjects(
      config: config,
      pipelineName: step.name,
      scanPath: scanPath,
      recursive: recursive,
      rootPath: rootPath,
    );
  } else {
    // Execute pipeline in current directory
    final executor = PipelineExecutor(
      config: config,
      projectPath: rootPath,
      rootPath: rootPath,
      verbose: _verbose,
      dryRun: _dryRun,
    );
    return executor.execute(step.name);
  }
}

/// Execute pipeline across multiple scanned projects.
Future<bool> _executePipelineAcrossProjects({
  required PipelineConfig config,
  required String pipelineName,
  required String scanPath,
  required bool recursive,
  required String rootPath,
}) async {
  final scanner = FolderScanner(toolBasename: 'buildkit', verbose: _verbose);
  final folders = await scanner.scan(scanPath, recursive: recursive);
  
  var allSuccess = true;
  for (final folder in folders) {
    if (_verbose) {
      print('');
      print('▶ ${folder.name}');
    }
    
    final executor = PipelineExecutor(
      config: config,
      projectPath: folder.path,
      rootPath: rootPath,
      verbose: _verbose,
      dryRun: _dryRun,
    );
    
    final success = await executor.execute(pipelineName);
    if (!success) {
      allSuccess = false;
      // Continue with other projects or stop?
      // For now, continue to see all failures
    }
  }
  
  return allSuccess;
}

/// Apply macro substitution to args.
List<String> _applyMacros(List<String> args) {
  return args.map((arg) {
    var result = arg;
    for (final entry in _macros.entries) {
      result = result.replaceAll('@${entry.key}', entry.value);
    }
    return result;
  }).toList();
}

/// List available pipelines.
Future<void> _listPipelines(String rootPath) async {
  final config = PipelineConfig.load(
    projectPath: rootPath,
    rootPath: rootPath,
  );
  
  print('Available pipelines:');
  for (final entry in config.pipelines.entries) {
    final pipeline = entry.value;
    final status = pipeline.executable ? '' : ' (internal)';
    print('  ${entry.key}$status');
  }
}

/// Pre-process args to handle bare -R flag.
(List<String>, bool) _preprocessRootFlag(List<String> args) {
  final processed = <String>[];
  var bareRootFlag = false;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];

    if (arg == '-R') {
      // Check if next arg looks like a path
      if (i + 1 < args.length) {
        final nextArg = args[i + 1];
        if (!nextArg.startsWith('-') && !nextArg.startsWith(':')) {
          // Has path argument
          processed.add(arg);
          continue;
        }
      }
      // Bare -R without path
      bareRootFlag = true;
      // Don't add to processed - we handle it separately
    } else {
      processed.add(arg);
    }
  }

  return (processed, bareRootFlag);
}

/// Find workspace root by looking for buildkit_master.yaml.
String _findWorkspaceRoot(String fromPath) {
  var current = fromPath;
  while (true) {
    final masterFile = File(p.join(current, 'buildkit_master.yaml'));
    if (masterFile.existsSync()) {
      return current;
    }
    
    final parent = p.dirname(current);
    if (parent == current) {
      // Reached root without finding workspace
      return fromPath;
    }
    current = parent;
  }
}

/// Print usage help.
void _printUsage() {
  print('Build Kit $_version - Pipeline-based build orchestration');
  print('');
  print('Usage: buildkit [options] <pipeline|:command> [args...]');
  print('');
  print('Commands (prefixed with :):');
  print('  :versioner      Update version files');
  print('  :bumpversion    Bump version numbers');
  print('  :compiler       Compile Dart executables');
  print('  :runner         Run build_runner');
  print('  :cleanup        Clean build artifacts');
  print('  :dependencies   Show dependency tree');
  print('  :publisher      Publish to pub.dev');
  print('  :buildsorter    Sort packages by build order');
  print('  :pubget         Run dart pub get');
  print('  :pubgetall      Run dart pub get in all projects');
  print('  :pubupdate      Run dart pub upgrade');
  print('  :pubupdateall   Run dart pub upgrade in all projects');
  print('');
  print('Git Commands:');
  print('  :gitstatus      Show git status');
  print('  :gitcommit      Commit changes');
  print('  :gitpull        Pull changes');
  print('  :gitpush        Push changes');
  print('  :gitbranch      Branch operations');
  print('  :gittag         Tag operations');
  print('  :gitcheckout    Checkout branch');
  print('  :gitreset       Reset to commit');
  print('  :gitsync        Sync with remote');
  print('  :gitprune       Prune remote branches');
  print('  :gitstash       Stash changes');
  print('  :gitunstash     Apply stashed changes');
  print('  :gitcompare     Compare branches');
  print('  :gitmerge       Merge branches');
  print('  :gitsquash      Squash commits');
  print('  :gitrebase      Rebase branch');
  print('');
  print('Macros:');
  print('  :define         Define a macro (name=value)');
  print('  :undefine       Remove a macro');
  print('  :defines        List defined macros');
  print('');
  print('Options:');
  print(_createGlobalParser().usage);
  print('');
  print('Examples:');
  print('  buildkit build                    Run build pipeline');
  print('  buildkit :versioner --scan .      Run versioner in current dir');
  print('  buildkit :gitstatus -R            Git status from workspace root');
  print('  buildkit :define proj=tom_core    Define macro');
  print('  buildkit :compiler --project @proj   Use macro');
}
