/// tom_reflector CLI - Dart code reflection generation tool
///
/// Configuration is read from buildkit.yaml (tom_reflector: section).
///
/// Usage:
///   dart run tom_analyzer:tom_reflector [options]
///   reflector [options]
///   buildkit :reflector [options]
///
/// Tool Options:
///   -c, --config=`<path>`    Path to config file (default: buildkit.yaml)
///   -e, --entry=`<file>`     Entry point file(s) (can repeat, comma-separated)
///   -b, --barrel=`<path>`    Barrel file (legacy mode)
///   -o, --output=`<path>`    Output file path
///   -v, --verbose          Enable verbose output
///   -l, --list             List projects that would be processed (no action)
///   -h, --help             Show this help message
///
/// Navigation Options (common to all Tom build tools):
///   -s, --scan=`<path>`      Scan directory for projects
///   -r, --recursive        Scan directories recursively
///   -b, --build-order      Sort projects in dependency build order
///   -p, --project=`<pattern>` Project(s) to run (comma-separated, globs supported)
///   -R, --root             Workspace root (bare: detected, path: specified)
///   -x, --exclude          Exclude patterns (path-based globs)
///   --exclude-projects     Exclude projects by name or path
///   --recursion-exclude    Exclude patterns during recursive scan
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';

import 'package:tom_analyzer/tom_analyzer.dart';
import 'package:tom_analyzer/src/reflection/generator/generator.dart' as gen;

const _toolKey = 'tom_reflector';

void main(List<String> args) async {
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
    if (ProjectDiscovery.hasSkipFile(projectPath)) continue;

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
      projectFilter: _isReflectorProject,
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

    return allProjects.where(_isReflectorProject).toList();
  }

  // Default: process current directory if it has config
  if (_isReflectorProject(basePath)) {
    return [basePath];
  }

  return [];
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

void _printUsage(ArgParser parser) {
  stdout.writeln('tom_reflector - Dart code reflection generation tool');
  stdout.writeln();
  stdout.writeln('Usage: dart run tom_analyzer:tom_reflector [options]');
  stdout.writeln('       reflector [options]');
  stdout.writeln('       buildkit :reflector [options]');
  stdout.writeln();
  stdout.writeln('Options:');
  stdout.writeln(parser.usage);
  stdout.writeln();
  stdout.writeln('Examples:');
  stdout.writeln('  # Generate reflection for current project (reads buildkit.yaml)');
  stdout.writeln('  dart run tom_analyzer:tom_reflector');
  stdout.writeln();
  stdout.writeln('  # Scan workspace for all reflector projects');
  stdout.writeln('  dart run tom_analyzer:tom_reflector -R');
  stdout.writeln();
  stdout.writeln('  # Specific project');
  stdout.writeln('  dart run tom_analyzer:tom_reflector -p reflect_dart_overview');
  stdout.writeln();
  stdout.writeln('  # Override barrel on command line');
  stdout.writeln('  dart run tom_analyzer:tom_reflector --barrel lib/my_lib.dart');
  stdout.writeln();
  stdout.writeln('  # Entry points for new-style generation');
  stdout.writeln('  dart run tom_analyzer:tom_reflector -e lib/my_app.dart');
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
