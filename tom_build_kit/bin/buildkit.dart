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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:console_markdown/console_markdown.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';
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

/// List mode flag.
bool _listMode = false;

/// Force mode flag.
bool _forceMode = false;

/// Dump-config mode flag.
bool _dumpConfigMode = false;

/// Guide mode flag.
bool _guideMode = false;

/// Workspace root path (set during initialization).
String _rootPath = '';

/// Get the macros file path (.buildkit_macros in workspace root).
String get _macrosFilePath => p.join(_rootPath, '.buildkit_macros');

/// Load macros from disk.
void _loadMacros() {
  final file = File(_macrosFilePath);
  if (!file.existsSync()) return;
  try {
    final content = file.readAsStringSync();
    final data = json.decode(content);
    if (data is Map) {
      _macros.clear();
      for (final entry in data.entries) {
        _macros[entry.key.toString()] = entry.value.toString();
      }
    }
  } catch (_) {
    // Ignore corrupt macro files
  }
}

/// Save macros to disk.
void _saveMacros() {
  final file = File(_macrosFilePath);
  if (_macros.isEmpty) {
    if (file.existsSync()) file.deleteSync();
    return;
  }
  file.writeAsStringSync(json.encode(_macros));
}

Future<void> main(List<String> args) async {
  // Run inside a console_markdown zone so that print() output
  // automatically renders markdown syntax (bold, colors, etc.)
  // to ANSI escape codes.  The zone value guards against
  // double-rendering when called from contexts that already
  // have console_markdown active (e.g. tom_d4rt_dcli).
  if (Zone.current[#consoleMarkdownActive] != true) {
    return runZoned(
      () => main(args),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          parent.print(zone, line.toConsole());
        },
      ),
      zoneValues: {#consoleMarkdownActive: true},
    );
  }

  // Handle special commands (help, version) early
  final result = handleSpecialCommands(
    args,
    buildkitTool,
    toolHelpGenerator: (_) => _generateToolHelp(),
    commandHelpGenerator: (_, cmd) => _generateCommandHelp(cmd),
    versionGenerator: (_) => 'Build Kit $_version',
  );
  if (result == SpecialCommandResult.handled) {
    return;
  }

  // Pre-process args to handle -R without argument (uses tom_build_base)
  final (processedArgs, bareRootFlag) = preprocessRootFlag(args);

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
  _listMode = globalResults['list'] as bool;
  _forceMode = globalResults['force'] as bool;
  _dumpConfigMode = globalResults['dump-config'] as bool;
  _guideMode = globalResults['guide'] as bool;

  // Initialize central logging verbose flag
  ToolLogger.verbose = _verbose;

  // Parse navigation args using tom_build_base (single source of truth)
  final navArgs = parseNavigationArgs(globalResults, bareRoot: bareRootFlag);
  final isWorkspaceMode = navArgs.isWorkspaceMode;

  // Determine execution root
  final currentDir = Directory.current.path;
  final rootPath = navArgs.bareRoot
      ? _findWorkspaceRoot(currentDir)
      : navArgs.root ??
            (isWorkspaceMode ? _findWorkspaceRoot(currentDir) : currentDir);

  // Initialize macro persistence
  _rootPath = rootPath;
  _loadMacros();

  // Get the command/pipeline and its args
  final rest = globalResults.rest;
  if (rest.isEmpty) {
    // Just global options - show list if --list
    if (_listMode) {
      await _listPipelines(rootPath);
    } else {
      _printUsage();
    }
    return;
  }

  // Apply macro expansion with placeholder support
  List<String> expandedRest;
  try {
    expandedRest = expandMacros(rest, _macros);
  } on MacroExpansionException catch (e) {
    print('Error: ${e.message}');
    if (e.detail != null) print('  ${e.detail}');
    exit(1);
  }

  // Parse execution steps (commands with :, pipelines without)
  final steps = _parseExecutionSteps(expandedRest, globalResults);

  // Load pipeline config
  final config = PipelineConfig.load(projectPath: rootPath, rootPath: rootPath);

  // Create tool runner for direct commands
  final executors = createBuildkitExecutors(
    onDefine: (name, value) {
      _macros[name] = value;
      _saveMacros();
    },
    onUndefine: (name) {
      final removed = _macros.remove(name) != null;
      if (removed) _saveMacros();
      return removed;
    },
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
      success = await _executeCommand(
        runner,
        step,
        navArgs,
        rootPath,
        isWorkspaceMode,
      );
    } else {
      // Pipeline via PipelineExecutor
      success = await _executePipeline(config, step, navArgs, rootPath);
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
///
/// Uses `addNavigationOptions()` from tom_build_base for all navigation options,
/// ensuring buildkit stays in sync when new options are added.
ArgParser _createGlobalParser() {
  final parser = ArgParser(allowTrailingOptions: false)
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help')
    ..addFlag('version', abbr: 'V', negatable: false, help: 'Show version')
    ..addFlag('verbose', abbr: 'v', negatable: false, help: 'Verbose output')
    ..addFlag(
      'dry-run',
      abbr: 'n',
      negatable: false,
      help: 'Show what would be executed',
    )
    ..addFlag(
      'list',
      abbr: 'l',
      negatable: false,
      help: 'List available pipelines',
    )
    ..addFlag('force', abbr: 'f', negatable: false, help: 'Force operation')
    ..addFlag(
      'dump-config',
      negatable: false,
      help: 'Show configuration for the command',
    )
    ..addFlag(
      'guide',
      negatable: false,
      help: 'Show guided help for the command',
    );

  // Add all navigation options from tom_build_base (single source of truth)
  addNavigationOptions(parser);

  return parser;
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
List<_ExecutionStep> _parseExecutionSteps(
  List<String> rest,
  ArgResults global,
) {
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
          if (stepArg.length == 3 &&
              stepArg[0] == '-' &&
              stepArg[2] == '-' &&
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

      steps.add(
        _ExecutionStep(
          isCommand: true,
          name: name,
          args: stepArgs,
          suppressedOptions: suppressions,
        ),
      );
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

      steps.add(
        _ExecutionStep(isCommand: isCommand, name: name, args: stepArgs),
      );
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
    '--scan',
    '-s',
    '--project',
    '-p',
    '--root',
    '-R',
    '--exclude',
    '-x',
    '--exclude-projects',
    '--modules',
    '--message',
    '--type',
    '--set',
    '--target',
    '--builder',
    '--prefix',
    '--branch',
    '--base',
    '--onto',
    '--create',
    '--delete',
    '--remote',
    '--index',
    '--count',
    '-n',
    '--to',
    '--depth',
    '--init-source',
    '--config',
  };
  return valueOptions.contains(opt);
}

/// Execute a direct command via ToolRunner.
///
/// Uses `navArgs.toArgs()` from tom_build_base to build navigation arguments,
/// ensuring all options are passed consistently without manual duplication.
Future<bool> _executeCommand(
  ToolRunner runner,
  _ExecutionStep step,
  WorkspaceNavigationArgs navArgs,
  String rootPath,
  bool isWorkspaceMode,
) async {
  // Build args for the command.
  // Global options MUST come BEFORE the :command, because CliArgParser treats
  // all options after a :command as per-command options.
  final cmdArgs = <String>[];

  // Normalize --project when given as an absolute/relative path.
  // The v2 traversal filter matches by project name (folder basename), not
  // by full path.  Convert `/abs/path/to/_build` → `_build`.
  var effectiveNavArgs = navArgs;
  if (navArgs.project != null &&
      (navArgs.project!.contains('/') || navArgs.project!.contains(r'\'))) {
    // Security: reject absolute paths outside workspace root
    final projectPath = p.normalize(p.absolute(navArgs.project!));
    final normalizedRoot = p.normalize(rootPath);
    if (!projectPath.startsWith(normalizedRoot)) {
      print(
        'Error: --project path is outside the workspace root.\n'
        '  Project: ${navArgs.project}\n'
        '  Workspace: $rootPath',
      );
      return false;
    }
    // Check that the resolved path actually exists
    final projectDir = Directory(projectPath);
    if (!projectDir.existsSync()) {
      print(
        'Error: --project path does not exist: ${navArgs.project}\n'
        '  Resolved: $projectPath',
      );
      return false;
    }
    effectiveNavArgs = navArgs.copyWith(project: p.basename(navArgs.project!));
  }

  // Apply navigation defaults for workspace mode
  if (isWorkspaceMode) {
    if (navArgs.scan == null) {
      // In workspace mode without explicit scan, default to scanning from
      // workspace root recursively
      effectiveNavArgs = navArgs.copyWith(scan: rootPath, recursive: true);
    } else if (!navArgs.recursiveExplicitlySet) {
      // In workspace mode with scan but no explicit recursive flag,
      // default to recursive (workspace scans should recurse)
      effectiveNavArgs = navArgs.copyWith(recursive: true);
    }
  }

  // Get navigation args as command-line list (handles all options automatically)
  final navCmdArgs = effectiveNavArgs.toArgs(
    rootPath: isWorkspaceMode ? rootPath : null,
    suppress: step.suppressedOptions,
  );
  cmdArgs.addAll(navCmdArgs);

  // Global common options (verbose, dry-run)
  if (_verbose && !step.suppressedOptions.contains('v')) {
    cmdArgs.add('--verbose');
  }
  if (_dryRun && !step.suppressedOptions.contains('n')) {
    cmdArgs.add('--dry-run');
  }

  // Global action flags
  if (_listMode) cmdArgs.add('--list');
  if (_forceMode) cmdArgs.add('--force');
  if (_dumpConfigMode) cmdArgs.add('--dump-config');
  if (_guideMode) cmdArgs.add('--guide');

  // When --project is specified without --scan, enable recursive scanning
  // so the project can be found by the traversal engine.
  if (navArgs.project != null && navArgs.scan == null && !isWorkspaceMode) {
    if (!cmdArgs.contains('--scan')) {
      cmdArgs.addAll(['--scan', '.', '--recursive']);
    }
  }

  // Command comes after global args, followed by command-specific args
  cmdArgs.add(':${step.name}');
  cmdArgs.addAll(step.args);

  // Run via ToolRunner
  final result = await runner.run(cmdArgs);

  // Print item results summary
  for (final item in result.itemResults) {
    if (item.success) {
      if (item.message != null &&
          item.message!.isNotEmpty &&
          !item.message!.startsWith('skipped')) {
        // Capitalize first letter for display
        final msg = item.message![0].toUpperCase() + item.message!.substring(1);
        print(msg);
      }
    } else if (item.error != null) {
      print('Error [${item.name}]: ${item.error}');
    }
  }

  if (!result.success && result.errorMessage != null) {
    print('Error: ${result.errorMessage}');
  }

  return result.success;
}

/// Execute a pipeline via PipelineExecutor.
Future<bool> _executePipeline(
  PipelineConfig config,
  _ExecutionStep step,
  WorkspaceNavigationArgs navArgs,
  String rootPath,
) async {
  // Validate project directory when --project is used without --scan
  if (navArgs.project != null && navArgs.scan == null) {
    final projectDir = Directory(p.join(rootPath, navArgs.project!));
    if (!projectDir.existsSync()) {
      print('Error: project directory does not exist: ${projectDir.path}');
      return false;
    }
  }

  if (navArgs.scan != null) {
    // Execute pipeline across scanned projects
    return _executePipelineAcrossProjects(
      config: config,
      pipelineName: step.name,
      scanPath: navArgs.scan!,
      recursive: navArgs.recursive,
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

/// List available pipelines.
Future<void> _listPipelines(String rootPath) async {
  final config = PipelineConfig.load(projectPath: rootPath, rootPath: rootPath);

  print('Available pipelines:');
  for (final entry in config.pipelines.entries) {
    final pipeline = entry.value;
    final status = pipeline.executable ? '' : ' (internal)';
    print('  ${entry.key}$status');
  }
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

/// Generate tool help text.
String _generateToolHelp() {
  final buf = StringBuffer();
  buf.writeln('**Build Kit** $_version - Pipeline-based build orchestration');
  buf.writeln();
  buf.writeln(
    '<cyan>**Usage:**</cyan> buildkit [options] <pipeline|:command> [args...]',
  );
  buf.writeln();
  buf.writeln('<cyan>**Commands**</cyan> (prefixed with :):');
  buf.writeln('  :versioner      Update version files');
  buf.writeln('  :bumpversion    Bump version numbers');
  buf.writeln('  :compiler       Compile Dart executables');
  buf.writeln('  :runner         Run build_runner');
  buf.writeln('  :cleanup        Clean build artifacts');
  buf.writeln('  :dependencies   Show dependency tree');
  buf.writeln('  :publisher      Publish to pub.dev');
  buf.writeln('  :buildsorter    Sort packages by build order');
  buf.writeln('  :pubget         Run dart pub get');
  buf.writeln('  :pubgetall      Run dart pub get in all projects');
  buf.writeln('  :pubupdate      Run dart pub upgrade');
  buf.writeln('  :pubupdateall   Run dart pub upgrade in all projects');
  buf.writeln();
  buf.writeln('<cyan>**Git Commands:**</cyan>');
  buf.writeln('  :gitstatus      Show git status');
  buf.writeln('  :gitcommit      Commit changes');
  buf.writeln('  :gitpull        Pull changes');
  buf.writeln('  :gitpush        Push changes');
  buf.writeln('  :gitbranch      Branch operations');
  buf.writeln('  :gittag         Tag operations');
  buf.writeln('  :gitcheckout    Checkout branch');
  buf.writeln('  :gitreset       Reset to commit');
  buf.writeln('  :gitsync        Sync with remote');
  buf.writeln('  :gitprune       Prune remote branches');
  buf.writeln('  :gitstash       Stash changes');
  buf.writeln('  :gitunstash     Apply stashed changes');
  buf.writeln('  :gitcompare     Compare branches');
  buf.writeln('  :gitmerge       Merge branches');
  buf.writeln('  :gitsquash      Squash commits');
  buf.writeln('  :gitrebase      Rebase branch');
  buf.writeln();
  buf.writeln('<cyan>**Macros:**</cyan>');
  buf.writeln('  :define         Define a macro (name=value)');
  buf.writeln('  :undefine       Remove a macro');
  buf.writeln('  :defines        List defined macros');
  buf.writeln();
  buf.writeln('<yellow>**Options:**</yellow>');
  buf.writeln(_createGlobalParser().usage);
  buf.writeln();
  buf.writeln('<cyan>**Examples:**</cyan>');
  buf.writeln('  buildkit build                    Run build pipeline');
  buf.writeln(
    '  buildkit :versioner --scan .      Run versioner in current dir',
  );
  buf.writeln(
    '  buildkit :gitstatus -R            Git status from workspace root',
  );
  buf.writeln('  buildkit :define proj=tom_core    Define macro');
  buf.writeln('  buildkit :compiler --project @proj   Use macro');
  buf.writeln();
  buf.writeln(
    'Use "buildkit help :command" for detailed help on a specific command.',
  );
  return buf.toString();
}

/// Print usage help.
void _printUsage() {
  print(_generateToolHelp());
}

/// Generate help text for a specific command.
String _generateCommandHelp(CommandDefinition cmd) {
  final buf = StringBuffer();

  buf.writeln('**Build Kit** $_version');
  buf.writeln();
  buf.writeln('<cyan>**Command:**</cyan> :${cmd.name}');
  if (cmd.aliases.isNotEmpty) {
    buf.writeln(
      '<cyan>**Aliases:**</cyan> ${cmd.aliases.map((a) => ':$a').join(', ')}',
    );
  }
  buf.writeln();
  buf.writeln(cmd.description);
  buf.writeln();

  // Command-specific options
  if (cmd.options.isNotEmpty) {
    buf.writeln('<yellow>**Options:**</yellow>');
    for (final opt in cmd.options) {
      final abbr = opt.abbr != null ? '-${opt.abbr}, ' : '    ';
      final name = '--${opt.name}';
      final valuePart = opt.valueName != null ? '=<${opt.valueName}>' : '';
      buf.writeln('  $abbr$name$valuePart');
      buf.writeln('      ${opt.description}');
      if (opt.defaultValue != null) {
        buf.writeln('      (default: ${opt.defaultValue})');
      }
    }
    buf.writeln();
  }

  // Examples
  if (cmd.examples.isNotEmpty) {
    buf.writeln('<cyan>**Examples:**</cyan>');
    for (final ex in cmd.examples) {
      buf.writeln('  $ex');
    }
    buf.writeln();
  }

  // Traversal info
  if (cmd.supportsProjectTraversal || cmd.supportsGitTraversal) {
    buf.writeln('<cyan>**Traversal:**</cyan>');
    if (cmd.supportsProjectTraversal) {
      buf.writeln('  Supports --project, --exclude-project filters');
    }
    if (cmd.supportsGitTraversal) {
      buf.writeln(
        '  Supports --inner-first-git, --outer-first-git, --top-repo traversal',
      );
    }
    buf.writeln();
  }

  return buf.toString();
}
