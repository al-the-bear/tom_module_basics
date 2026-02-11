/// tom_reflector CLI - Dart code reflection generation tool
///
/// Configuration is read from buildkit.yaml (tom_reflector: section).
/// Run `reflector help` or `--help` for full usage information.
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';

import 'package:tom_analyzer/tom_analyzer.dart';
import 'package:tom_analyzer/src/reflection/generator/generator.dart' as gen;

const _toolKey = 'tom_reflector';

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
    ..addMultiOption('entry',
        abbr: 'e',
        help: 'Entry point file(s) to analyze',
        splitCommas: true)
    ..addOption('barrel', help: 'Barrel file (legacy mode)')
    ..addOption('output', help: 'Output file path')
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
  final entryPoints = results['entry'] as List<String>;
  final barrelOverride = results['barrel'] as String?;
  final outputPath = results['output'] as String?;

  // Apply defaults (--scan . --recursive --build-order) if no explicit navigation
  final effectiveNavArgs = navArgs.withDefaults();

  // Find projects to process
  final projects =
      await _findProjects(effectiveNavArgs, executionRoot, verbose);

  if (projects.isEmpty) {
    stderr.writeln('No projects found to process.');
    if (verbose) {
      stderr.writeln(
          'Tip: Create a buildkit.yaml with a "tom_reflector:" section');
    }
    exitCode = 1;
    return;
  }

  // Handle --list mode
  if (results['list'] as bool) {
    print('tom_reflector projects (${projects.length}):');
    for (final project in projects) {
      final relativePath = p.relative(project, from: executionRoot);
      print('  $relativePath');
    }
    return;
  }

  // Process each project
  if (projects.length > 1) {
    print('tom_reflector: Running on ${projects.length} project(s)');
    print('');
  }

  final processingResult = ProcessingResult();
  for (final projectPath in projects) {
    final success = await _processProject(
      projectPath: projectPath,
      executionRoot: executionRoot,
      entryPoints: entryPoints,
      barrelOverride: barrelOverride,
      outputPath: outputPath,
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
    print('tom_reflector: Processed ${projects.length} project(s)');
    if (processingResult.hasFailures) {
      print('  Failed: ${processingResult.failureCount}');
      exitCode = 1;
    }
  }
}

/// Find projects to process based on navigation args using ProjectNavigator.
Future<List<String>> _findProjects(
  WorkspaceNavigationArgs navArgs,
  String basePath,
  bool verbose,
) async {
  final navigator = ProjectNavigator(
    verbose: verbose,
    config: NavigationConfig(
      usePathExclude: true,
      useNameExclude: true,
      useSkipFiles: true,
      useMasterConfigDefaults: false, // Uses withDefaults() instead
      projectFilter: _isReflectorProject,
    ),
  );

  final result = await navigator.navigate(navArgs, basePath: basePath);
  return result.paths;
}

/// Check if a directory is a tom_reflector project.
bool _isReflectorProject(String dirPath) {
  if (!File('$dirPath/pubspec.yaml').existsSync()) return false;
  return hasTomBuildConfig(dirPath, _toolKey);
}

/// Process a single project.
Future<bool> _processProject({
  required String projectPath,
  required String executionRoot,
  List<String> entryPoints = const [],
  String? barrelOverride,
  String? outputPath,
  required bool verbose,
}) async {
  try {
    // Load config from buildkit.yaml tom_reflector: section
    final buildConfig =
        TomBuildConfig.load(dir: projectPath, toolKey: _toolKey);
    final toolOptions = buildConfig?.toolOptions ?? {};

    // New config-based mode (entry points)
    if (entryPoints.isNotEmpty) {
      return _runNewReflect(
        projectPath: projectPath,
        entryPoints: entryPoints,
        outputPath: outputPath,
        verbose: verbose,
      );
    }

    // Barrel-based mode (from CLI or config)
    final config = TomAnalyzerConfig.fromMap(toolOptions);
    final barrel = barrelOverride ??
        (config.barrels.isNotEmpty ? config.barrels.first : null);

    if (barrel == null) {
      stderr.writeln('[$projectPath] Missing barrel in buildkit.yaml.');
      return false;
    }

    return _runLegacyReflect(
      projectPath: projectPath,
      barrelPath: barrel,
      config: config,
      outputPath: outputPath,
      verbose: verbose,
      executionRoot: executionRoot,
    );
  } catch (e, stack) {
    stderr.writeln('Error processing $projectPath: $e');
    if (verbose) stderr.writeln(stack);
    return false;
  }
}

/// New reflection generation using ReflectionConfig and MultiEntryGenerator.
Future<bool> _runNewReflect({
  required String projectPath,
  required List<String> entryPoints,
  String? outputPath,
  required bool verbose,
}) async {
  try {
    final config = gen.ReflectionConfig(
      entryPoints: entryPoints,
      output: outputPath,
      defaults: gen.ReflectionDefaults(),
      filters: const [],
      dependencyConfig: gen.DependencyConfig(),
      coverageConfig: gen.CoverageConfig(),
    );

    final generator = gen.MultiEntryGenerator(config);
    final result = await generator.generate();

    if (!result.isSuccess) {
      stderr.writeln('Reflection generation failed:');
      for (final error in result.errors) {
        stderr.writeln('  $error');
      }
      return false;
    }

    for (final entry in result.generatedFiles.entries) {
      final file = File(entry.key);
      await file.parent.create(recursive: true);
      await file.writeAsString(entry.value);
      if (verbose) print('  Generated: ${entry.key}');
    }
    return true;
  } catch (e, stack) {
    stderr.writeln('Error: $e');
    if (verbose) stderr.writeln(stack);
    return false;
  }
}

/// Legacy reflection generation using ReflectionModel.
Future<bool> _runLegacyReflect({
  required String projectPath,
  required String barrelPath,
  required TomAnalyzerConfig config,
  String? outputPath,
  required bool verbose,
  required String executionRoot,
}) async {
  final analyzer = TomAnalyzer();
  final analysis = await analyzer.analyzeBarrel(
    barrelPath: barrelPath,
    workspaceRoot: config.workspaceRoot ?? projectPath,
    followReExports: config.followReExports,
    followReExportPackages: config.followReExportPackages,
    skipReExports: config.skipReExports,
  );

  final model = ReflectionModel.fromAnalysis(analysis);
  final generator = ReflectionGenerator();
  final content = generator.generate(model);

  final resolvedOutput = _resolveReflectionOutput(
    barrelPath: barrelPath,
    outputFile: outputPath,
  );

  await File(resolvedOutput).writeAsString(content);
  final displayPath = p.relative(projectPath, from: executionRoot);
  if (verbose) {
    print('  $displayPath -> $resolvedOutput');
  } else {
    print('Generated: $resolvedOutput');
  }
  return true;
}

void _printUsage(ArgParser? parser) {
  // Standard header
  for (final line in getToolHelpHeader(
    toolName: 'Tom Reflector',
    toolDescription: 'Dart code reflection generation tool',
    usagePatterns: [
      'reflector [options]',
      'dart run tom_analyzer:tom_reflector [options]',
      'buildkit :reflector [options]',
      'reflector help',
      'reflector version',
    ],
  )) {
    print(line);
  }

  // Tool-specific options
  print('Tool Options:');
  print('  -c, --config=<path>  Path to config file (default: buildkit.yaml)');
  print('  -e, --entry=<file>   Entry point file(s) (can repeat, comma-separated)');
  print('      --barrel=<path>  Barrel file (legacy mode)');
  print('      --output=<path>  Output file path');
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
  print('  tom_reflector:');
  print('    barrels:');
  print('      - lib/my_package.dart');
  print('');

  // Standard footer
  for (final line in getToolHelpFooter(toolName: 'reflector')) {
    print(line);
  }
  print('');
  print('Related:');
  print('  For code analysis, use tom_analyzer:');
  print('    dart run tom_analyzer --help');
}

void _printVersion() {
  const version = String.fromEnvironment('version', defaultValue: '1.0.0');
  const buildNumber =
      String.fromEnvironment('buildNumber', defaultValue: '0');
  const gitCommit =
      String.fromEnvironment('gitCommit', defaultValue: 'unknown');
  const buildTimestamp =
      String.fromEnvironment('buildTimestamp', defaultValue: '');

  print('Tom Reflector $version+$buildNumber');
  if (gitCommit != 'unknown') print('Git: $gitCommit');
  if (buildTimestamp.isNotEmpty) print('Built: $buildTimestamp');
}

String _resolveReflectionOutput({
  required String barrelPath,
  String? outputFile,
}) {
  if (outputFile != null && outputFile.isNotEmpty) {
    return _ensureRdartExtension(outputFile);
  }
  final defaultPath = p.setExtension(barrelPath, '.r.dart');
  return _ensureRdartExtension(defaultPath);
}

String _ensureRdartExtension(String path) {
  return path.endsWith('.r.dart') ? path : '$path.r.dart';
}
