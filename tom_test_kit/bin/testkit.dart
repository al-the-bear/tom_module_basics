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
    stderr.writeln('Available subcommands: :baseline, :test');
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
        help: 'Output file path (overrides default)')
    ..addOption('file',
        help: 'Tracking file to update (:test only)')
    ..addOption('test-args',
        help: 'Additional arguments passed to dart test')
    ..addFlag('baseline',
        help: 'Create baseline if no tracking file exists (:test only)')
    ..addFlag('verbose', abbr: 'v', help: 'Enable verbose output')
    ..addFlag('list',
        abbr: 'l', help: 'List projects that would be processed (no action)')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help');

  // Add standard navigation options
  addNavigationOptions(parser);

  final ArgResults results;
  try {
    results = parser.parse(processedArgs);

    // Check for unexpected arguments
    if (results.rest.isNotEmpty) {
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
  final testArgsStr = results['test-args'] as String?;
  final testArgs = testArgsStr != null ? testArgsStr.split(' ') : <String>[];

  // Apply defaults (--scan . --recursive --build-order) if no explicit navigation
  final effectiveNavArgs = navArgs.withDefaults();

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
          outputPath: outputPath,
          testArgs: testArgs,
          verbose: verbose,
        );
      case 'test':
        success = await TestCommand.run(
          projectPath: projectPath,
          trackingFilePath: trackingFile,
          testArgs: testArgs,
          verbose: verbose,
          createBaseline: results['baseline'] as bool,
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
  if (first == 'baseline' || first == 'test') {
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
      'testkit :baseline [options]',
      'testkit :test [options]',
      'testkit --tui [--root <path>]',
      'buildkit :testkit :baseline [options]',
      'testkit help',
      'testkit version',
    ],
  )) {
    print(line);
  }

  // Subcommands
  print('Subcommands:');
  print('  :baseline            Run dart test, create new baseline tracking file');
  print('  :test                Run dart test, append results to existing tracking file');
  print('');

  // Tool-specific options
  print('Tool Options:');
  print('      --tui            Launch interactive TUI dashboard');
  print('      --output=<path>  Output file path (overrides default)');
  print('      --file=<path>    Tracking file to update (:test only)');
  print('      --baseline       Create baseline if none exists (:test only)');
  print('      --test-args=<args>  Additional arguments passed to dart test');
  print('  -v, --verbose        Enable verbose output');
  print('  -l, --list           List projects that would be processed (no action)');
  print('  -h, --help           Show this help message');
  print('');

  // Standard navigation options from tom_build_base
  printNavigationOptionsHelp();
  print('');

  // Tracking info
  print('Tracking File:');
  print('  Baseline creates doc/baseline_<MMDD_HHMM>.csv in each project.');
  print('  :test appends a result column to the most recent baseline file.');
  print('  Use :test --baseline to auto-create baseline when none exists.');
  print('');
  print('CSV Format:');
  print('  Pure data CSV — header row followed by data rows.');
  print('  Columns: ID, Groups, Description, then one column per run.');
  print('');
  print('Result Format:');
  print('  Each cell shows <result>/<expectation>:');
  print('    OK/OK    — Passed as expected');
  print('    X/OK     — Failed unexpectedly (regression)');
  print('    X/FAIL   — Failed as expected (known issue)');
  print('    OK/FAIL  — Passed unexpectedly (progress)');
  print('    SKIP/OK  — Skipped (needs attention)');
  print('    -/OK     — Not present in this run');
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
}
