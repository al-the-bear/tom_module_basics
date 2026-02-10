/// Tom Test Kit CLI — test result tracking tool.
///
/// Run `testkit help` or `--help` for full usage information.
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';
import 'package:utopia_tui/utopia_tui.dart';

import 'package:tom_test_kit/tom_test_kit.dart';

const _toolName = 'testkit';

void main(List<String> args) async {
  // Check for --tui mode (before any other parsing)
  if (args.contains('--tui')) {
    await _runTuiMode(args.where((a) => a != '--tui').toList());
    return;
  }

  // Check for help command first (before parsing)
  if (isHelpCommand(args)) {
    _printUsage(null);
    return;
  }

  // Check for version command first (before parsing)
  if (isVersionCommand(args)) {
    _printVersion();
    return;
  }

  // Detect subcommand
  final (subcommand, remainingArgs) = _extractSubcommand(args);

  if (subcommand == null) {
    stderr.writeln('Error: No subcommand specified.');
    stderr.writeln('');
    stderr.writeln('Available subcommands: :baseline, :test, :runs, :status, '
        ':basediff, :lastdiff, :diff, :crossreference, :reset');
    stderr.writeln('Or use --tui for interactive mode.');
    stderr.writeln('Run "$_toolName help" for usage information.');
    exitCode = 1;
    return;
  }

  // Preprocess args for bare -R detection
  final (processedArgs, bareRoot) = preprocessRootFlag(remainingArgs);

  final parser = ArgParser()
    // Tool-specific options
    ..addOption('output',
        help: 'Output format/file: <format>[:<filename>] '
            '(plain, csv, json, md)')
    ..addOption('file',
        help: 'Tracking file to update (:test only)')
    ..addOption('baseline-file',
        help: 'Specific baseline file (instead of most recent)')
    ..addOption('test-args',
        help: 'Additional arguments passed to dart test')
    ..addOption('comment',
        abbr: 'c',
        help: 'Short description shown in the run column header')
    ..addOption('report',
        help: 'Generate detailed Markdown report (filename optional)')
    ..addFlag('baseline',
        help: 'Create baseline if no tracking file exists (:test only)')
    ..addFlag('full',
        help: 'Include full details from last_testrun.json (diff commands)')
    ..addFlag('force',
        help: 'Skip confirmation prompts (:reset)')
    ..addFlag('verbose', abbr: 'v', help: 'Enable verbose output')
    ..addFlag('list',
        abbr: 'l', help: 'List projects that would be processed (no action)')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help');

  // Add standard navigation options
  addNavigationOptions(parser);

  final ArgResults results;
  try {
    results = parser.parse(processedArgs);

    // :diff accepts positional timestamp args; others do not
    if (results.rest.isNotEmpty && subcommand != 'diff') {
      stderr.writeln('Error: Unknown arguments: ${results.rest.join(' ')}\n');
      _printUsage(parser);
      exitCode = 1;
      return;
    }
  } catch (e) {
    stderr.writeln('Error: $e');
    _printUsage(parser);
    exitCode = 1;
    return;
  }

  if (results['help'] as bool) {
    _printUsage(parser);
    return;
  }

  // Parse navigation options
  final navArgs = parseNavigationArgs(results, bareRoot: bareRoot);
  final currentDir = Directory.current.path;

  // Resolve execution root
  String executionRoot;
  try {
    executionRoot = resolveExecutionRoot(navArgs, currentDir: currentDir);
  } on ArgumentError catch (e) {
    stderr.writeln('Error: ${e.message}');
    exitCode = 1;
    return;
  }

  final verbose = results['verbose'] as bool;
  final outputPath = results['output'] as String?;
  final trackingFile = results['file'] as String?;
  final baselineFile = results['baseline-file'] as String?;
  final testArgsStr = results['test-args'] as String?;
  final testArgs = testArgsStr != null ? testArgsStr.split(' ') : <String>[];
  final comment = results['comment'] as String?;
  final fullFlag = results['full'] as bool;
  final forceFlag = results['force'] as bool;
  final reportPath = results['report'] as String?;

  // Validate --output and --report are not both specified
  if (outputPath != null && reportPath != null) {
    stderr.writeln('Error: --output and --report cannot be used together.');
    exitCode = 1;
    return;
  }

  // Parse --output spec
  OutputSpec? outputSpec;
  if (outputPath != null) {
    outputSpec = OutputSpec.tryParse(outputPath);
    if (outputSpec == null) {
      stderr.writeln(
          'Error: Invalid --output format. Use: plain, csv, json, md '
          'or <format>:<filename>');
      exitCode = 1;
      return;
    }
  }

  // Apply defaults (--scan . --build-order) if no explicit navigation.
  // Unlike other build tools, testkit does NOT default to --recursive.
  // Use -r explicitly to recurse into subprojects.
  final effectiveNavArgs = navArgs.withDefaults().copyWith(
        recursive: navArgs.recursive,
      );

  // Find projects to process
  final projects =
      await _findProjects(effectiveNavArgs, executionRoot, verbose);

  if (projects.isEmpty) {
    stderr.writeln('No projects found to process.');
    if (verbose) {
      stderr.writeln('Tip: Projects must have a pubspec.yaml file.');
    }
    exitCode = 1;
    return;
  }

  // Handle --list mode
  if (results['list'] as bool) {
    print('$_toolName projects (${projects.length}):');
    for (final project in projects) {
      final relativePath = p.relative(project, from: executionRoot);
      print('  $relativePath');
    }
    return;
  }

  // Process each project
  if (projects.length > 1) {
    print('$_toolName :$subcommand — Running on ${projects.length} project(s)');
    print('');
  }

  final processingResult = ProcessingResult();
  for (final projectPath in projects) {
    if (ProjectDiscovery.hasSkipFile(projectPath)) continue;

    final displayPath = p.relative(projectPath, from: executionRoot);
    print('$displayPath:');

    bool success;
    switch (subcommand) {
      case 'baseline':
        success = await BaselineCommand.run(
          projectPath: projectPath,
          outputPath: trackingFile,
          testArgs: testArgs,
          verbose: verbose,
          comment: comment,
        );
      case 'test':
        success = await TestCommand.run(
          projectPath: projectPath,
          trackingFilePath: trackingFile,
          testArgs: testArgs,
          verbose: verbose,
          createBaseline: results['baseline'] as bool,
          comment: comment,
        );
      case 'runs':
        success = await RunsCommand.run(
          projectPath: projectPath,
          baselineFile: baselineFile,
          output: outputSpec,
          verbose: verbose,
        );
      case 'status':
        success = await StatusCommand.run(
          projectPath: projectPath,
          baselineFile: baselineFile,
          verbose: verbose,
        );
      case 'basediff':
        success = await BaseDiffCommand.run(
          projectPath: projectPath,
          baselineFile: baselineFile,
          output: outputSpec,
          full: fullFlag,
          reportPath: reportPath,
          verbose: verbose,
        );
      case 'lastdiff':
        success = await LastDiffCommand.run(
          projectPath: projectPath,
          baselineFile: baselineFile,
          output: outputSpec,
          full: fullFlag,
          reportPath: reportPath,
          verbose: verbose,
        );
      case 'diff':
        success = await DiffCommand.run(
          projectPath: projectPath,
          timestamps: results.rest,
          baselineFile: baselineFile,
          output: outputSpec,
          full: fullFlag,
          reportPath: reportPath,
          verbose: verbose,
        );
      case 'crossreference' || 'crossref' || 'xref':
        success = await CrossReferenceCommand.run(
          projectPath: projectPath,
          baselineFile: baselineFile,
          output: outputSpec,
          verbose: verbose,
        );
      case 'reset':
        success = await ResetCommand.run(
          projectPath: projectPath,
          force: forceFlag,
          verbose: verbose,
        );
      default:
        stderr.writeln('Unknown subcommand: :$subcommand');
        exitCode = 1;
        return;
    }

    if (success) {
      processingResult.addSuccess();
    } else {
      processingResult.addFailure();
    }
  }

  // Summary for multi-project runs
  if (projects.length > 1) {
    print('');
    print('$_toolName: Processed ${projects.length} project(s)');
    if (processingResult.hasFailures) {
      print('  Failed: ${processingResult.failureCount}');
      exitCode = 1;
    }
  }
}

/// Extracts the subcommand from args.
///
/// Subcommands are prefixed with `:` (e.g., `:baseline`, `:test`).
/// Returns the subcommand name (without `:`) and the remaining args.
(String?, List<String>) _extractSubcommand(List<String> args) {
  if (args.isEmpty) return (null, args);

  final first = args.first;
  if (first.startsWith(':')) {
    return (first.substring(1), args.sublist(1));
  }

  // Also support without colon prefix
  const knownCommands = {
    'baseline', 'test', 'runs', 'status', 'basediff', 'lastdiff', 'diff',
    'crossreference', 'crossref', 'xref', 'reset',
  };
  if (knownCommands.contains(first)) {
    return (first, args.sublist(1));
  }

  return (null, args);
}

/// Find projects to process based on navigation args.
Future<List<String>> _findProjects(
  WorkspaceNavigationArgs navArgs,
  String basePath,
  bool verbose,
) async {
  final discovery = ProjectDiscovery(verbose: verbose);

  // Project pattern(s) specified
  if (navArgs.project != null) {
    return discovery.resolveProjectPatterns(
      navArgs.project!,
      basePath: basePath,
      projectFilter: _isTestableProject,
    );
  }

  // Scan directory for projects
  if (navArgs.scan != null) {
    final scanPath = p.isAbsolute(navArgs.scan!)
        ? navArgs.scan!
        : p.join(basePath, navArgs.scan!);

    final allProjects = await discovery.scanForProjects(
      scanPath,
      recursive: navArgs.recursive,
    );

    return allProjects.where(_isTestableProject).toList();
  }

  // Default: process current directory if it has tests
  if (_isTestableProject(basePath)) {
    return [basePath];
  }

  return [];
}

/// Check if a directory is a testable project.
///
/// A project is testable if it has a pubspec.yaml and a test/ directory.
bool _isTestableProject(String dirPath) {
  if (!File('$dirPath/pubspec.yaml').existsSync()) return false;
  return Directory('$dirPath/test').existsSync();
}

void _printUsage(ArgParser? parser) {
  // Standard header
  for (final line in getToolHelpHeader(
    toolName: 'Test Kit',
    toolDescription: 'Test result tracking for Dart projects',
    usagePatterns: [
      'testkit :<command> [options]',
      'testkit --tui [--root <path>]',
      'testkit help | version',
    ],
  )) {
    print(line);
  }

  // ── Subcommands ──────────────────────────────────────────
  print('Subcommands:');
  print('');
  print('  Run commands (execute dart test):');
  print('  :baseline            Run tests, create new baseline tracking file');
  print('  :test                Run tests, append results to existing tracking file');
  print('');
  print('  Analysis commands (read-only):');
  print('  :runs                List all run timestamps in the tracking file');
  print('  :status              Quick summary — pass/fail counts + regressions/fixes');
  print('  :basediff            Diff baseline vs latest run');
  print('  :lastdiff            Diff previous run vs latest run');
  print('  :diff <ts> [<ts2>]   Diff two arbitrary runs by timestamp');
  print('  :crossreference      Map tests to source files (aliases: :crossref, :xref)');
  print('');
  print('  Maintenance commands:');
  print('  :reset               Delete all tracking files (with confirmation)');
  print('');

  // ── Tool Options ─────────────────────────────────────────
  print('Tool Options:');
  print('      --tui                Launch interactive TUI dashboard');
  print('  -c, --comment=<text>     Short label for the run column header');
  print('      --baseline-file=<path>  Use a specific baseline file');
  print('      --file=<path>        Tracking file to update (:test only)');
  print('      --baseline           Create baseline if none exists (:test only)');
  print('      --test-args=<args>   Additional arguments passed to dart test');
  print('');
  print('  Diff / report options:');
  print('      --output=<spec>      Output format: plain, csv, json, md');
  print('                           or <format>:<filename> to write to file');
  print('      --full               Include error details from last_testrun.json');
  print('      --report=<file>      Generate detailed Markdown report to file');
  print('      --force              Skip confirmation prompts (:reset)');
  print('');
  print('  General options:');
  print('  -v, --verbose            Enable verbose output');
  print('  -l, --list               List projects that would be processed (no action)');
  print('  -h, --help               Show this help message');
  print('');

  // Standard navigation options from tom_build_base
  printNavigationOptionsHelp();
  print('');

  // ── Tracking File ────────────────────────────────────────
  print('Tracking File:');
  print('  :baseline creates doc/baseline_<MMDD_HHMM>.csv in each project.');
  print('  :test appends a result column to the most recent baseline file.');
  print('  Use :test --baseline to auto-create baseline when none exists.');
  print('  Raw JSON output is saved to doc/last_testrun.json.');
  print('');
  print('CSV Format:');
  print('  Pure data CSV — header row followed by data rows.');
  print('  Columns: ID, Groups, Description, then one column per run.');
  print('');
  print('Result Format:');
  print('  Each cell shows <result>/<expectation>:');
  print('    OK/OK    — Passed as expected');
  print('    X/OK     — Failed unexpectedly (regression)');
  print('    X/X      — Failed as expected (known issue)');
  print('    OK/X     — Passed unexpectedly (progress)');
  print('    -/OK     — Skipped (needs attention)');
  print('    --/OK    — Not present in this run');
  print('');

  // ── Diff Commands ────────────────────────────────────────
  print('Diff Commands:');
  print('  Compare two runs and show changes. Use timestamps from :runs output.');
  print('');
  print('  :basediff              Compare the baseline (first) run with the latest run');
  print('  :lastdiff              Compare the previous run with the latest run');
  print('  :diff 0614 1430        Compare run at 06-14 14:30 with the latest run');
  print('  :diff 0614_1430 0615_0900  Compare two specific runs');
  print('');
  print('  Timestamp formats: MMDD_HHMM, MM-DD_HHMM, or "MM-DD HH:MM"');
  print('');
  print('  Change labels in diff output:');
  print('    REGRESSION  — was passing, now failing');
  print('    FIX         — was failing, now passing');
  print('    NEW FAIL    — test appeared and is failing');
  print('    NEW PASS    — test appeared and is passing');
  print('    REMOVED     — test no longer present');
  print('    changed     — other status change');
  print('');

  // ── Test Args ────────────────────────────────────────────
  print('Test Args (--test-args):');
  print('  Additional arguments passed through to "dart test".');
  print('  testkit always adds --reporter json internally.');
  print('');
  print('  Commonly used dart test options:');
  print('    -n, --name=<regex>        Filter tests by name (regex)');
  print('    -N, --plain-name=<text>   Filter tests by plain-text name');
  print('    -t, --tags=<tags>         Run only tests with specified tags');
  print('    -x, --exclude-tags=<tags> Exclude tests with specified tags');
  print('    -j, --concurrency=<n>     Concurrent test suites (default: 5)');
  print('    --timeout=<duration>      Test timeout (e.g. 15s, 2x, none)');
  print('    --[no-]fail-fast          Stop after first failure');
  print('    --[no-]run-skipped        Run skipped tests');
  print('    --coverage=<dir>          Gather coverage to directory');
  print('');
  print('  Examples:');
  print('    testkit :test --test-args="--name parser"');
  print('    testkit :test --test-args="--fail-fast --timeout 60s"');
  print('    testkit :test --test-args="--tags integration"');
  print('');

  // Standard footer
  for (final line in getToolHelpFooter(toolName: 'testkit')) {
    print(line);
  }
}

void _printVersion() {
  // Version will come from version.g.dart once versioner runs
  const version = String.fromEnvironment('version', defaultValue: '0.1.0');
  const buildNumber =
      String.fromEnvironment('buildNumber', defaultValue: '0');
  const gitCommit =
      String.fromEnvironment('gitCommit', defaultValue: 'unknown');
  const buildTimestamp =
      String.fromEnvironment('buildTimestamp', defaultValue: '');

  print('Test Kit $version+$buildNumber');
  if (gitCommit != 'unknown') print('Git: $gitCommit');
  if (buildTimestamp.isNotEmpty) print('Built: $buildTimestamp');
}

/// Runs the TUI mode — full-screen interactive dashboard.
Future<void> _runTuiMode(List<String> args) async {
  // Parse minimal args for project path
  final tuiParser = ArgParser();
  addNavigationOptions(tuiParser);

  final (processedArgs, bareRoot) = preprocessRootFlag(args);
  final ArgResults results;
  try {
    results = tuiParser.parse(processedArgs);
  } catch (e) {
    stderr.writeln('Error: $e');
    exitCode = 1;
    return;
  }

  final navArgs = parseNavigationArgs(results, bareRoot: bareRoot);
  final currentDir = Directory.current.path;

  String projectPath;
  try {
    projectPath = resolveExecutionRoot(navArgs, currentDir: currentDir);
  } on ArgumentError catch (e) {
    stderr.writeln('Error: ${e.message}');
    exitCode = 1;
    return;
  }

  // Build command registry with built-in commands
  final registry = TuiCommandRegistry()
    ..registerCommand(BaselineTuiCommand())
    ..registerCommand(TestTuiCommand());

  // Launch TUI
  final app = TestKitTuiApp(
    registry: registry,
    projectPath: projectPath,
  );
  await TuiRunner(app).run();

  // Restore terminal line discipline after TUI exits.
  // The TUI's key reader puts the terminal in raw mode but doesn't restore it.
  // Without this, newlines lack carriage returns and output drifts right.
  await Process.run('stty', ['sane'], runInShell: true);
}
