/// Tom Test Kit CLI — test result tracking tool.
///
/// Run `testkit help` or `--help` for full usage information.
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';
import 'package:utopia_tui/utopia_tui.dart';

import 'package:tom_test_kit/src/version.g.dart';
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
    // "help <command>" → per-command help
    if (args.length >= 2) {
      final cmdArg = args[1].replaceFirst(':', '');
      final canonical = _commandAliases[cmdArg] ?? cmdArg;
      if (_commandHelp.containsKey(canonical)) {
        _printCommandHelp(canonical);
        return;
      }
    }
    _printOverview();
    return;
  }

  // Check for version command first (before parsing)
  if (isVersionCommand(args)) {
    _printVersion();
    return;
  }

  // Phase 1: Extract subcommand and split args into before/after
  final (subcommand, beforeSubcommand, afterSubcommand) = _extractSubcommandAndSplit(args);

  if (subcommand == null) {
    stderr.writeln('Error: No subcommand specified.');
    stderr.writeln('');
    _printOverview();
    exitCode = 1;
    return;
  }

  // Phase 2: Parse global navigation options (from args before subcommand)
  ArgResults? globalNavResults;
  bool globalBareRoot = false;
  if (beforeSubcommand.isNotEmpty) {
    // Preprocess args for bare -R detection
    final (processedGlobalArgs, bareRoot) = preprocessRootFlag(beforeSubcommand);
    globalBareRoot = bareRoot;
    
    final globalNavParser = ArgParser();
    addNavigationOptions(globalNavParser);
    
    try {
      globalNavResults = globalNavParser.parse(processedGlobalArgs);
      // Check for unknown options
      if (globalNavResults.rest.isNotEmpty) {
        stderr.writeln('Error: Unknown arguments before subcommand: ${globalNavResults.rest.join(' ')}');
        stderr.writeln('Only navigation options can appear before the subcommand.');
        exitCode = 1;
        return;
      }
    } catch (e) {
      stderr.writeln('Error parsing options before subcommand: $e');
      exitCode = 1;
      return;
    }
  }

  // Preprocess args for bare -R detection
  final (processedArgs, bareRoot) = preprocessRootFlag(afterSubcommand);

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
    ..addFlag('failed',
        help: 'Re-run only failed tests (X/OK, X/X) from most recent run')
    ..addFlag('mismatched',
        help: 'Re-run tests that don\'t match expectation (X/OK, OK/X)')
    ..addFlag('full',
        help: 'Include full details from last_testrun.json (diff commands)')
    ..addFlag('force',
        help: 'Skip confirmation prompts (:reset)')
    ..addFlag('verbose', abbr: 'v', help: 'Enable verbose output')
    ..addFlag('list',
        abbr: 'l', help: 'List projects that would be processed (no action)')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help');

  // Add standard navigation options (for command-level parsing)
  addNavigationOptions(parser);

  final ArgResults results;
  try {
    results = parser.parse(processedArgs);

    // :diff, :history, :trim accept positional args; others do not
    final positionalCommands = {'diff', 'history', 'trim'};
    if (results.rest.isNotEmpty && !positionalCommands.contains(subcommand)) {
      stderr.writeln('Error: Unknown arguments: ${results.rest.join(' ')}\n');
      _printCommandHelp(subcommand);
      exitCode = 1;
      return;
    }
  } catch (e) {
    stderr.writeln('Error: $e');
    _printCommandHelp(subcommand);
    exitCode = 1;
    return;
  }

  if (results['help'] as bool) {
    _printCommandHelp(subcommand);
    return;
  }

  // Parse command-level navigation options
  final cmdNavArgs = parseNavigationArgs(results, bareRoot: bareRoot);
  
  // Merge global and command-level navigation args (command overrides global)
  final navArgs = _mergeNavigationArgs(
    globalNavResults, 
    results, 
    cmdNavArgs,
    globalBareRoot: globalBareRoot,
    cmdBareRoot: bareRoot,
  );
  
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
          failedOnly: results['failed'] as bool,
          mismatchedOnly: results['mismatched'] as bool,
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
      case 'history':
        if (results.rest.isEmpty) {
          stderr.writeln('Error: :history requires a search term.');
          stderr.writeln('Usage: testkit :history <search>');
          stderr.writeln('');
          stderr.writeln('Search matches against test ID, description, or '
              'group path.');
          stderr.writeln('Run "testkit help history" for details.');
          exitCode = 1;
          return;
        }
        success = await HistoryCommand.run(
          projectPath: projectPath,
          searchTerm: results.rest.join(' '),
          baselineFile: baselineFile,
          output: outputSpec,
          verbose: verbose,
        );
      case 'flaky':
        success = await FlakyCommand.run(
          projectPath: projectPath,
          baselineFile: baselineFile,
          output: outputSpec,
          verbose: verbose,
        );
      case 'trim':
        if (results.rest.isEmpty) {
          stderr.writeln('Error: :trim requires a count.');
          stderr.writeln('Usage: testkit :trim <n>');
          exitCode = 1;
          return;
        }
        final keepCount = int.tryParse(results.rest.first);
        if (keepCount == null || keepCount < 1) {
          stderr.writeln('Error: :trim requires a positive integer.');
          exitCode = 1;
          return;
        }
        success = await TrimCommand.run(
          projectPath: projectPath,
          keepCount: keepCount,
          baselineFile: baselineFile,
          force: forceFlag,
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
/// Extract subcommand and split args into before/after subcommand.
///
/// Returns (subcommand, argsBefore, argsAfter).
/// argsBefore contains all args before the subcommand (e.g., navigation options).
/// argsAfter contains all args after the subcommand.
(String?, List<String>, List<String>) _extractSubcommandAndSplit(List<String> args) {
  if (args.isEmpty) return (null, [], []);

  const knownCommands = {
    'baseline', 'test', 'runs', 'status', 'basediff', 'lastdiff', 'diff',
    'history', 'flaky', 'crossreference', 'crossref', 'xref', 'trim', 'reset',
  };

  // Find the first argument that's a subcommand
  for (int i = 0; i < args.length; i++) {
    final arg = args[i];
    
    // Check for :command format
    if (arg.startsWith(':')) {
      final cmd = arg.substring(1);
      if (knownCommands.contains(cmd)) {
        return (cmd, args.sublist(0, i), args.sublist(i + 1));
      }
      // If it starts with : but isn't a known command, it's an error
      // Return it anyway so the error handling can deal with it
      return (cmd, args.sublist(0, i), args.sublist(i + 1));
    }
    
    // Check for command without colon
    if (knownCommands.contains(arg)) {
      return (arg, args.sublist(0, i), args.sublist(i + 1));
    }
  }

  return (null, [], args);
}

/// Find projects to process based on navigation args.
Future<List<String>> _findProjects(
  WorkspaceNavigationArgs navArgs,
  String basePath,
  bool verbose,
) async {
  final navigator = ProjectNavigator(
    config: NavigationConfig(
      usePathExclude: true,
      useNameExclude: true,
      useModulesFilter: true,
      useRecursionExclude: true,
      useSkipFiles: true,
      useMasterConfigDefaults: true,
      useBuildOrder: navArgs.buildOrder,
      useGitTraversal: true,
      projectFilter: _isTestableProject,
    ),
    verbose: verbose,
  );

  final result = await navigator.navigate(navArgs, basePath: basePath);

  if (result.hasError) {
    print('Error: ${result.errorMessage}');
    return [];
  }

  return result.paths;
}

/// Check if a directory is a testable project.
///
/// A project is testable if it has a pubspec.yaml and a test/ directory.
bool _isTestableProject(String dirPath) {
  if (!File('$dirPath/pubspec.yaml').existsSync()) return false;
  return Directory('$dirPath/test').existsSync();
}

// =============================================================================
// Help System
// =============================================================================

/// Common options printed in every command's help.
const _commonOptions = '''
Common Options:
  -v, --verbose            Enable verbose output
  -l, --list               List projects that would be processed (no action)
  -h, --help               Show help for this command
      --baseline-file=<path>  Use a specific baseline file (instead of most recent)''';

/// Navigation options summary (printed in overview and each command).
const _navOptionsSummary = '''
Project Traversal:
  By default, testkit operates on the current directory only (non-recursive).
  Use -r to recurse into subprojects, or -R for workspace mode.

  -s, --scan=<path>        Scan directory for projects (default: .)
  -r, --recursive          Recurse into subdirectories
  -R, --root[=<path>]      Workspace mode (detect or specify workspace root)
  -p, --project=<pattern>  Process projects matching glob pattern
  -b, --build-order        Process in dependency order (default: on)
  -i, --include=<pattern>  Include only matching projects
  -o, --exclude=<pattern>  Exclude matching projects''';

/// Per-command help definitions.
///
/// Each key is the canonical command name. The value is the full help text
/// that will be printed after the header when the user runs
/// `testkit help <command>`.
const _commandHelp = <String, String>{
  'baseline': '''
testkit :baseline — Create a new baseline tracking file.

Runs dart test, collects results, and writes a new baseline CSV file to doc/.
This becomes the reference point for comparing future test runs.

Usage:
  testkit :baseline [options]

Command Options:
  -c, --comment=<text>     Short label shown in the baseline column header
      --file=<path>        Output file path (overrides default doc/baseline_<ts>.csv)
      --test-args=<args>   Additional arguments passed to dart test

$_commonOptions

$_navOptionsSummary

Examples:
  testkit :baseline                          # Create baseline in current project
  testkit :baseline -c "v2.0 release"        # Baseline with comment
  testkit :baseline --test-args="--tags e2e"  # Only include e2e tests
  testkit :baseline -r                       # Baseline all subprojects''',

  'test': '''
testkit :test — Run tests and append results to the tracking file.

Runs dart test, collects results, and appends a new column to the most
recent baseline file. Each run is timestamped for later comparison.

Usage:
  testkit :test [options]

Command Options:
  -c, --comment=<text>     Short label shown in the run column header
      --file=<path>        Tracking file to update (instead of most recent)
      --baseline           Create baseline if no tracking file exists
      --failed             Re-run only failed tests (X/OK, X/X) from last run
      --mismatched         Re-run tests that don't match expectation (X/OK, OK/X)
      --test-args=<args>   Additional arguments passed to dart test

$_commonOptions

$_navOptionsSummary

Filtering Options:
  --failed and --mismatched filter tests based on the most recent run results.
  They can be combined to run both groups. Tests are matched using --name
  patterns passed to dart test.

  Result codes:
    X/OK  = Failed, expected pass (regression)
    X/X   = Failed, expected fail
    OK/X  = Passed, expected fail (unexpected pass)
    OK/OK = Passed, expected pass

Test Args (--test-args):
  Arguments are passed through to "dart test". testkit always adds
  --reporter json internally. Forbidden: --reporter, --file-reporter,
  --pause-after-load, --debug.

  Common dart test options:
    -n, --name=<regex>        Filter tests by name (regex)
    -N, --plain-name=<text>   Filter tests by plain-text name
    -t, --tags=<tags>         Run only tests with specified tags
    -x, --exclude-tags=<tags> Exclude tests with specified tags
    --[no-]fail-fast          Stop after first failure
    --timeout=<duration>      Test timeout (e.g. 15s, 2x, none)

Examples:
  testkit :test                              # Append run to latest baseline
  testkit :test -c "after refactor"          # Run with comment
  testkit :test --baseline                   # Create baseline if missing
  testkit :test --test-args="--name parser"  # Only run parser tests
  testkit :test --failed                     # Re-run only failed tests
  testkit :test --mismatched                 # Re-run regressions and fixes
  testkit :test --failed --mismatched        # Both groups combined''',

  'runs': '''
testkit :runs — List all run timestamps in the tracking file.

Displays a numbered table of all runs with their timestamp, type
(baseline or run), and comment. Use these timestamps with :diff.

Usage:
  testkit :runs [options]

Command Options:
      --output=<spec>      Output format: plain, csv, json, md
                           or <format>:<filename> to write to file

$_commonOptions

$_navOptionsSummary

Examples:
  testkit :runs                          # List runs in current project
  testkit :runs --output json            # Output as JSON
  testkit :runs --output csv:runs.csv    # Save to CSV file''',

  'status': '''
testkit :status — Quick summary of test results.

Shows total test counts (pass/fail/skip/absent) for the latest run,
plus regression and fix counts compared to the baseline and the
previous run.

Usage:
  testkit :status [options]

$_commonOptions

$_navOptionsSummary

Examples:
  testkit :status                    # Status for current project
  testkit :status -r                 # Status for all subprojects''',

  'basediff': '''
testkit :basediff — Compare baseline vs latest run.

Shows all tests that changed between the first (baseline) run and the
most recent run. Useful for seeing overall progress since tracking began.

Usage:
  testkit :basediff [options]

Command Options:
      --output=<spec>      Output format: plain, csv, json, md
                           or <format>:<filename> to write to file
      --full               Include error messages and stack traces from
                           last_testrun.json in the output
      --report=<file>      Generate a detailed Markdown report to file
                           (mutually exclusive with --output)

$_commonOptions

Change Labels:
  REGRESSION  — was passing, now failing
  FIX         — was failing, now passing
  NEW FAIL    — test appeared and is failing
  NEW PASS    — test appeared and is passing
  REMOVED     — test no longer present
  changed     — other status change

$_navOptionsSummary

Examples:
  testkit :basediff                          # Show changes since baseline
  testkit :basediff --full                   # Include error details
  testkit :basediff --report=progress.md     # Write Markdown report''',

  'lastdiff': '''
testkit :lastdiff — Compare previous run vs latest run.

Shows all tests that changed between the second-to-last run and the
most recent run. Useful for seeing what changed in the last test cycle.

Usage:
  testkit :lastdiff [options]

Command Options:
      --output=<spec>      Output format: plain, csv, json, md
                           or <format>:<filename> to write to file
      --full               Include error messages and stack traces from
                           last_testrun.json in the output
      --report=<file>      Generate a detailed Markdown report to file
                           (mutually exclusive with --output)

$_commonOptions

$_navOptionsSummary

Examples:
  testkit :lastdiff                      # Changes since previous run
  testkit :lastdiff --full               # Include error details
  testkit :lastdiff --output md          # Output as Markdown''',

  'diff': '''
testkit :diff — Compare two arbitrary runs by timestamp.

With one timestamp, compares that run against the latest run.
With two timestamps, compares those two runs directly.
Use :runs to see available timestamps.

Usage:
  testkit :diff <timestamp> [<timestamp2>] [options]

  Timestamp formats: MMDD_HHMM, MM-DD_HHMM, or "MM-DD HH:MM"
  Partial matches are supported (e.g., "0614" matches "06-14 ...").

Command Options:
      --output=<spec>      Output format: plain, csv, json, md
                           or <format>:<filename> to write to file
      --full               Include error messages and stack traces from
                           last_testrun.json in the output
      --report=<file>      Generate a detailed Markdown report to file
                           (mutually exclusive with --output)

$_commonOptions

$_navOptionsSummary

Examples:
  testkit :diff 0614_1430                # Compare 06-14 14:30 vs latest
  testkit :diff 0614_1430 0615_0900      # Compare two specific runs
  testkit :diff 0614_1430 --full         # With error details''',

  'history': '''
testkit :history — Show all results for a test across runs.

Displays a table with one row per matching test and one column per run,
showing how results evolved over time. Useful for tracking individual
test regressions and fixes.

Usage:
  testkit :history <search> [options]

  <search> is matched case-insensitively against:
    - Test ID (e.g., "TK-RUN-5")
    - Test description text
    - Full test path (group + description)

  If multiple tests match, all are shown. Use a more specific search
  string or the full test ID to narrow results.

Command Options:
      --output=<spec>      Output format: plain, csv, json, md
                           or <format>:<filename> to write to file

$_commonOptions

$_navOptionsSummary

Examples:
  testkit :history TK-RUN-5              # By test ID
  testkit :history "parse JSON"          # By description substring
  testkit :history parser                # All tests with "parser" in name
  testkit :history TK-RUN --output csv   # Export matching tests as CSV''',

  'flaky': '''
testkit :flaky — List tests with inconsistent results across runs.

Identifies tests that sometimes pass and sometimes fail — i.e., tests
with both OK and X results across different runs. Sorted by "flips"
(pass/fail transitions), most flaky first.

Usage:
  testkit :flaky [options]

  Columns: ID, Description, Pass count, Fail count, Flips, Fail Rate%

  A "flip" is a transition between OK and X in consecutive runs. More
  flips indicate higher flakiness. Skip and absent results are ignored.

Command Options:
      --output=<spec>      Output format: plain, csv, json, md
                           or <format>:<filename> to write to file

$_commonOptions

$_navOptionsSummary

Examples:
  testkit :flaky                         # Show flaky tests
  testkit :flaky --output json           # Export as JSON
  testkit :flaky -r                      # Check all subprojects''',

  'crossreference': '''
testkit :crossreference — Map tests to source files.

Searches source files (lib/) for test description strings to find where
each test is defined. Useful for navigating from tracking results to code.

Aliases: :crossref, :xref

Usage:
  testkit :crossreference [options]

Command Options:
      --output=<spec>      Output format: plain, csv, json, md
                           or <format>:<filename> to write to file

$_commonOptions

$_navOptionsSummary

Examples:
  testkit :crossreference                # Map tests to source
  testkit :xref --output csv:xref.csv    # Export as CSV''',

  'trim': '''
testkit :trim — Remove old run columns, keeping only the last N runs.

Reduces the size of the tracking CSV by removing intermediate runs.
The baseline (first) run is always preserved regardless of N.

Usage:
  testkit :trim <n> [options]

  <n> is the number of most recent runs to keep. The baseline run is
  always included, so the file will contain at most N + 1 columns
  (baseline + N most recent).

Command Options:
      --force              Skip the confirmation prompt

$_commonOptions

$_navOptionsSummary

Examples:
  testkit :trim 5                    # Keep baseline + last 5 runs
  testkit :trim 3 --force            # Trim without confirmation
  testkit :trim 10 -r                # Trim all subprojects''',

  'reset': '''
testkit :reset — Delete all tracking files.

Removes all baseline_*.csv files and last_testrun.json from the doc/
directory. Prompts for confirmation unless --force is specified.

Usage:
  testkit :reset [options]

Command Options:
      --force              Skip the confirmation prompt

$_commonOptions

$_navOptionsSummary

Examples:
  testkit :reset                     # Delete with confirmation
  testkit :reset --force             # Delete without prompt
  testkit :reset -r                  # Reset all subprojects''',
};

/// Canonical aliases for command names.
const _commandAliases = <String, String>{
  'crossref': 'crossreference',
  'xref': 'crossreference',
};

/// Prints the overview help (testkit help).
void _printOverview() {
  for (final line in getToolHelpHeader(
    toolName: 'Test Kit',
    toolDescription: 'Test result tracking for Dart projects',
    usagePatterns: [
      'testkit :<command> [options]',
      'testkit help <command>',
      'testkit --tui [--root <path>]',
      'testkit help | version',
    ],
  )) {
    print(line);
  }

  print('Commands:');
  print('');
  print('  Run commands (execute dart test):');
  print('    :baseline            Create new baseline tracking file');
  print('    :test                Append results to existing tracking file');
  print('');
  print('  Analysis commands (read-only):');
  print('    :runs                List run timestamps in the tracking file');
  print('    :status              Quick summary — pass/fail counts, regressions/fixes');
  print('    :basediff            Diff baseline vs latest run');
  print('    :lastdiff            Diff previous run vs latest run');
  print('    :diff <ts> [<ts2>]   Diff two arbitrary runs by timestamp');
  print('    :history <search>    Show all results for a test across runs');
  print('    :flaky               List tests with inconsistent results');
  print('    :crossreference      Map tests to source files (:crossref, :xref)');
  print('');
  print('  Maintenance commands:');
  print('    :trim <n>            Keep only the last N runs');
  print('    :reset               Delete all tracking files');
  print('');
  print('  Run "testkit help <command>" for detailed help on a specific command.');
  print('');
  print('Common Options:');
  print('  -v, --verbose            Enable verbose output');
  print('  -l, --list               List projects that would be processed');
  print('  -h, --help               Show help');
  print('      --baseline-file=<path>  Use a specific baseline file');
  print('');
  print('Project Traversal:');
  print('  By default, testkit operates on the current directory only.');
  print('  Use -r to recurse into subprojects, -R for workspace mode.');
  print('  Use -s <path> to scan a specific directory, -p <glob> for patterns.');
  print('');
  print('  Navigation options can appear before OR after the subcommand:');
  print('    testkit --project tom_d4rt :test');
  print('    testkit :test --project tom_d4rt');
  print('  Command-level options override global options when both are specified.');
  print('');
  print('Tracking File:');
  print('  Baseline: doc/baseline_<MMDD_HHMM>.csv');
  print('  :test appends a result column to the most recent baseline file.');
  print('  Raw JSON: doc/last_testrun.json');
  print('');
  print('Result Format:');
  print('  OK/OK (pass), X/OK (regression), X/X (known fail),');
  print('  OK/X (progress), -/OK (skip), --/OK (absent)');
  print('');

  for (final line in getToolHelpFooter(toolName: 'testkit')) {
    print(line);
  }
}

/// Prints detailed help for a specific command.
void _printCommandHelp(String command) {
  // Resolve aliases
  final canonical = _commandAliases[command] ?? command;
  final helpText = _commandHelp[canonical];
  if (helpText == null) {
    stderr.writeln('Unknown command: $command');
    stderr.writeln('Run "testkit help" for available commands.');
    return;
  }
  print(helpText);
}

/// Merge global and command-level navigation args.
///
/// Command-level options override global options when explicitly set.
/// If neither is set, uses the default from [cmdNavArgs].
WorkspaceNavigationArgs _mergeNavigationArgs(
  ArgResults? globalResults,
  ArgResults cmdResults,
  WorkspaceNavigationArgs cmdNavArgs, {
  required bool globalBareRoot,
  required bool cmdBareRoot,
}) {
  // If no global args were parsed, just use command args
  if (globalResults == null) return cmdNavArgs;

  // Helper to check if a value was explicitly set at command level
  bool wasSetInCmd(String name) => cmdResults.wasParsed(name);
  bool wasSetInGlobal(String name) => globalResults.wasParsed(name);

  // For each option, use command value if set, else global value if set, else default
  return WorkspaceNavigationArgs(
    scan: wasSetInCmd('scan')
        ? cmdNavArgs.scan
        : (wasSetInGlobal('scan')
            ? globalResults['scan'] as String?
            : cmdNavArgs.scan),
    
    recursive: wasSetInCmd('recursive')
        ? cmdNavArgs.recursive
        : (wasSetInGlobal('recursive')
            ? globalResults['recursive'] as bool? ?? false
            : cmdNavArgs.recursive),
    
    recursiveExplicitlySet: wasSetInCmd('recursive') || wasSetInGlobal('recursive'),
    
    buildOrder: wasSetInCmd('build-order')
        ? cmdNavArgs.buildOrder
        : (wasSetInGlobal('build-order')
            ? globalResults['build-order'] as bool? ?? false
            : cmdNavArgs.buildOrder),
    
    project: wasSetInCmd('project')
        ? cmdNavArgs.project
        : (wasSetInGlobal('project')
            ? globalResults['project'] as String?
            : cmdNavArgs.project),
    
    root: wasSetInCmd('root')
        ? cmdNavArgs.root
        : (wasSetInGlobal('root')
            ? _getRootValue(globalResults['root'] as String?)
            : cmdNavArgs.root),
    
    bareRoot: cmdBareRoot || globalBareRoot,
    
    workspaceRecursion: wasSetInCmd('workspace-recursion')
        ? cmdNavArgs.workspaceRecursion
        : (wasSetInGlobal('workspace-recursion')
            ? globalResults['workspace-recursion'] as bool? ?? false
            : cmdNavArgs.workspaceRecursion),
    
    innerFirstGit: wasSetInCmd('inner-first-git')
        ? cmdNavArgs.innerFirstGit
        : (wasSetInGlobal('inner-first-git')
            ? globalResults['inner-first-git'] as bool? ?? false
            : cmdNavArgs.innerFirstGit),
    
    outerFirstGit: wasSetInCmd('outer-first-git')
        ? cmdNavArgs.outerFirstGit
        : (wasSetInGlobal('outer-first-git')
            ? globalResults['outer-first-git'] as bool? ?? false
            : cmdNavArgs.outerFirstGit),
    
    exclude: wasSetInCmd('exclude')
        ? cmdNavArgs.exclude
        : (wasSetInGlobal('exclude')
            ? globalResults['exclude'] as List<String>? ?? []
            : cmdNavArgs.exclude),
    
    excludeProjects: wasSetInCmd('exclude-projects')
        ? cmdNavArgs.excludeProjects
        : (wasSetInGlobal('exclude-projects')
            ? globalResults['exclude-projects'] as List<String>? ?? []
            : cmdNavArgs.excludeProjects),
    
    recursionExclude: wasSetInCmd('recursion-exclude')
        ? cmdNavArgs.recursionExclude
        : (wasSetInGlobal('recursion-exclude')
            ? globalResults['recursion-exclude'] as List<String>? ?? []
            : cmdNavArgs.recursionExclude),
    
    modules: wasSetInCmd('modules')
        ? cmdNavArgs.modules
        : (wasSetInGlobal('modules')
            ? _parseModulesOption(globalResults['modules'] as String?)
            : cmdNavArgs.modules),
  );
}

/// Parse comma-separated modules option into a list.
List<String> _parseModulesOption(String? value) {
  if (value == null || value.isEmpty) return const [];
  return value
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Get root value, handling __BARE_ROOT__ marker.
String? _getRootValue(String? value) {
  if (value == '__BARE_ROOT__') return null;
  return value;
}

void _printVersion() {
  print('Test Kit ${TestKitVersionInfo.versionLong}');
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
