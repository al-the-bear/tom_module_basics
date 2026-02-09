/// tom_analyzer CLI - Dart code analysis tool
///
/// Configuration is read from buildkit.yaml (tom_analyzer: section).
/// Run `analyzer help` or `--help` for full usage information.
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';

import 'package:tom_analyzer/tom_analyzer.dart';

const _toolKey = 'tom_analyzer';

void main(List<String> args) async {
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

  // Preprocess args for bare -R detection
  final (processedArgs, bareRoot) = preprocessRootFlag(args);

  final parser = ArgParser()
    // Tool-specific options
    ..addOption('config',
        abbr: 'c',
        defaultsTo: TomBuildConfig.projectFilename,
        help: 'Path to config file')
    ..addOption('barrel', help: 'Barrel file to analyze (overrides config)')
    ..addOption('output', help: 'Output file path')
    ..addOption('format',
        abbr: 'f', defaultsTo: 'yaml', help: 'Output format (yaml or json)')
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
  final barrelOverride = results['barrel'] as String?;
  final outputPath = results['output'] as String?;
  final outputFormat = results['format'] as String?;

  // Apply defaults (--scan . --recursive --build-order) if no explicit navigation
  final effectiveNavArgs = navArgs.withDefaults();

  // Find projects to process
  final projects = await _findProjects(effectiveNavArgs, executionRoot, verbose);

  if (projects.isEmpty) {
    stderr.writeln('No projects found to process.');
    if (verbose) {
      stderr.writeln(
          'Tip: Create a buildkit.yaml with a "tom_analyzer:" section');
    }
    exitCode = 1;
    return;
  }

  // Handle --list mode
  if (results['list'] as bool) {
    print('tom_analyzer projects (${projects.length}):');
    for (final project in projects) {
      final relativePath = p.relative(project, from: executionRoot);
      print('  $relativePath');
    }
    return;
  }

  // Process each project
  if (projects.length > 1) {
    print('tom_analyzer: Running on ${projects.length} project(s)');
    print('');
  }

  final processingResult = ProcessingResult();
  for (final projectPath in projects) {
    if (ProjectDiscovery.hasSkipFile(projectPath)) continue;

    final success = await _processProject(
      projectPath: projectPath,
      executionRoot: executionRoot,
      barrelOverride: barrelOverride,
      outputPath: outputPath,
      outputFormat: outputFormat,
      verbose: verbose,
    );

    if (success) {
      processingResult.addSuccess();
    } else {
      processingResult.addFailure();
    }
  }

  // Summary for multi-project runs
  if (projects.length > 1) {
    print('');
    print('tom_analyzer: Processed ${projects.length} project(s)');
    if (processingResult.hasFailures) {
      print('  Failed: ${processingResult.failureCount}');
      exitCode = 1;
    }
  }
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
      projectFilter: _isAnalyzerProject,
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
      toolKey: _toolKey,
    );

    return allProjects.where(_isAnalyzerProject).toList();
  }

  // Default: process current directory if it has config
  if (_isAnalyzerProject(basePath)) {
    return [basePath];
  }

  return [];
}

/// Check if a directory is a tom_analyzer project.
bool _isAnalyzerProject(String dirPath) {
  if (!File('$dirPath/pubspec.yaml').existsSync()) return false;
  return hasTomBuildConfig(dirPath, _toolKey);
}

/// Process a single project.
Future<bool> _processProject({
  required String projectPath,
  required String executionRoot,
  String? barrelOverride,
  String? outputPath,
  String? outputFormat,
  required bool verbose,
}) async {
  try {
    // Load config from buildkit.yaml tom_analyzer: section
    final buildConfig =
        TomBuildConfig.load(dir: projectPath, toolKey: _toolKey);
    var config = TomAnalyzerConfig.fromMap(buildConfig?.toolOptions ?? {});

    if (barrelOverride != null) {
      config = config.applyOverrides(barrels: [barrelOverride]);
    }

    final barrel = config.barrels.isNotEmpty ? config.barrels.first : null;
    if (barrel == null) {
      stderr.writeln('[$projectPath] Missing barrel in buildkit.yaml.');
      return false;
    }

    config = config.applyOverrides(
      outputFile: outputPath,
      outputFormat: outputFormat,
      workspaceRoot: config.workspaceRoot ?? projectPath,
    );

    final analyzer = TomAnalyzer();
    final analysis = await analyzer.analyzeBarrel(
      barrelPath: barrel,
      workspaceRoot: config.workspaceRoot,
      followReExports: config.followReExports,
      followReExportPackages: config.followReExportPackages,
      skipReExports: config.skipReExports,
    );

    final content = config.outputFormat == 'json'
        ? JsonSerializer.encode(analysis)
        : YamlSerializer.encode(analysis);

    if (config.outputFile != null) {
      await File(config.outputFile!).writeAsString(content);
      if (verbose) {
        final displayPath = p.relative(projectPath, from: executionRoot);
        print('  $displayPath -> ${config.outputFile}');
      }
    } else {
      stdout.writeln(content);
    }
    return true;
  } catch (e, stack) {
    stderr.writeln('Error processing $projectPath: $e');
    if (verbose) stderr.writeln(stack);
    return false;
  }
}

void _printUsage(ArgParser? parser) {
  // Standard header
  for (final line in getToolHelpHeader(
    toolName: 'Tom Analyzer',
    toolDescription: 'Dart code analysis tool',
    usagePatterns: [
      'analyzer [options]',
      'dart run tom_analyzer [options]',
      'buildkit :analyzer [options]',
      'analyzer help',
      'analyzer version',
    ],
  )) {
    print(line);
  }

  // Tool-specific options
  print('Tool Options:');
  print('  -c, --config=<path>  Path to config file (default: buildkit.yaml)');
  print('      --barrel=<path>  Barrel file to analyze (overrides config)');
  print('      --output=<path>  Output file path');
  print('  -f, --format=<fmt>   Output format: yaml or json (default: yaml)');
  print('  -v, --verbose        Enable verbose output');
  print('  -l, --list           List projects that would be processed (no action)');
  print('  -h, --help           Show this help message');
  print('');

  // Standard navigation options from tom_build_base
  printNavigationOptionsHelp();
  print('');

  // Tool-specific configuration info
  print('Configuration:');
  print('  Reads from buildkit.yaml file with the following structure:');
  print('');
  print('  tom_analyzer:');
  print('    barrels:');
  print('      - lib/my_package.dart');
  print('    output_format: yaml');
  print('');

  // Standard footer
  for (final line in getToolHelpFooter(toolName: 'analyzer')) {
    print(line);
  }
  print('');
  print('Related:');
  print('  For reflection generation, use tom_reflector:');
  print('    dart run tom_analyzer:tom_reflector --help');
}

void _printVersion() {
  const version = String.fromEnvironment('version', defaultValue: '1.0.0');
  const buildNumber =
      String.fromEnvironment('buildNumber', defaultValue: '0');
  const gitCommit =
      String.fromEnvironment('gitCommit', defaultValue: 'unknown');
  const buildTimestamp =
      String.fromEnvironment('buildTimestamp', defaultValue: '');

  print('Tom Analyzer $version+$buildNumber');
  if (gitCommit != 'unknown') print('Git: $gitCommit');
  if (buildTimestamp.isNotEmpty) print('Built: $buildTimestamp');
}
