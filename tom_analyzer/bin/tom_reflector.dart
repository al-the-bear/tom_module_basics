import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_analyzer/tom_analyzer.dart';
import 'package:tom_analyzer/src/reflection/generator/generator.dart' as gen;

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('config', abbr: 'c', help: 'Path to tom_analyzer.yaml config')
    ..addMultiOption('entry',
        abbr: 'e',
        help: 'Entry point file(s) to analyze',
        splitCommas: true)
    ..addOption('barrel', abbr: 'b', help: 'Barrel file (legacy mode)')
    ..addOption('workspace-root', abbr: 'w', help: 'Workspace root directory')
    ..addOption('output', abbr: 'o', help: 'Output file path')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help');

  final result = parser.parse(arguments);

  if (result['help'] as bool) {
    _printUsage(parser);
    return;
  }

  final configPath = result['config'] as String?;
  final entryPoints = result['entry'] as List<String>;
  final barrelOverride = result['barrel'] as String?;
  final outputPath = result['output'] as String?;

  await _runReflect(
    configPath: configPath,
    entryPoints: entryPoints,
    barrelPath: barrelOverride,
    outputPath: outputPath,
  );
}

/// Run the reflection generation command.
Future<void> _runReflect({
  String? configPath,
  List<String> entryPoints = const [],
  String? barrelPath,
  String? outputPath,
}) async {
  // New config-based mode
  if (configPath != null || entryPoints.isNotEmpty) {
    await _runNewReflect(
      configPath: configPath,
      entryPoints: entryPoints,
      outputPath: outputPath,
    );
    return;
  }

  // Legacy barrel-based mode
  if (barrelPath != null) {
    await _runLegacyReflect(
      barrelPath: barrelPath,
      outputPath: outputPath,
    );
    return;
  }

  // Try to find buildkit.yaml or tom_analyzer.yaml in current directory
  final defaultBuildkit = File('buildkit.yaml');
  final defaultConfig = File('tom_analyzer.yaml');
  if (await defaultBuildkit.exists()) {
    await _runNewReflect(
      configPath: 'buildkit.yaml',
      entryPoints: [],
      outputPath: outputPath,
    );
    return;
  }
  if (await defaultConfig.exists()) {
    await _runNewReflect(
      configPath: 'tom_analyzer.yaml',
      entryPoints: [],
      outputPath: outputPath,
    );
    return;
  }

  stderr.writeln('Error: No configuration found.');
  stderr.writeln('  Use --config to specify tom_analyzer.yaml');
  stderr.writeln('  Use --entry to specify entry point(s)');
  stderr.writeln('  Use --barrel for legacy barrel-based generation');
  exitCode = 1;
}

/// New reflection generation using ReflectionConfig and MultiEntryGenerator.
Future<void> _runNewReflect({
  String? configPath,
  List<String> entryPoints = const [],
  String? outputPath,
}) async {
  try {
    // Load or create configuration
    gen.ReflectionConfig config;
    if (configPath != null) {
      config = gen.ReflectionConfig.load(path: configPath);
    } else {
      // Create minimal config from CLI arguments
      config = gen.ReflectionConfig(
        entryPoints: entryPoints,
        output: outputPath,
        defaults: gen.ReflectionDefaults(),
        filters: const [],
        dependencyConfig: gen.DependencyConfig(),
        coverageConfig: gen.CoverageConfig(),
      );
    }

    // Override entry points and output if specified on command line
    if (entryPoints.isNotEmpty) {
      config = gen.ReflectionConfig(
        entryPoints: entryPoints,
        output: outputPath ?? config.output,
        defaults: config.defaults,
        filters: config.filters,
        dependencyConfig: config.dependencyConfig,
        coverageConfig: config.coverageConfig,
      );
    } else if (outputPath != null && config.output != outputPath) {
      config = gen.ReflectionConfig(
        entryPoints: config.entryPoints,
        output: outputPath,
        defaults: config.defaults,
        filters: config.filters,
        dependencyConfig: config.dependencyConfig,
        coverageConfig: config.coverageConfig,
      );
    }

    if (config.entryPoints.isEmpty) {
      stderr.writeln('Error: No entry points specified.');
      stderr.writeln('  Add entry_points to tom_analyzer.yaml');
      stderr.writeln('  Or use --entry to specify entry point(s)');
      exitCode = 1;
      return;
    }

    // Generate reflection
    final generator = gen.MultiEntryGenerator(config);
    final result = await generator.generate();

    if (!result.isSuccess) {
      stderr.writeln('Reflection generation failed:');
      for (final error in result.errors) {
        stderr.writeln('  $error');
      }
      exitCode = 1;
      return;
    }

    // Write generated files
    for (final entry in result.generatedFiles.entries) {
      final file = File(entry.key);
      await file.parent.create(recursive: true);
      await file.writeAsString(entry.value);
      stdout.writeln('Generated: ${entry.key}');
    }
  } catch (e, stack) {
    stderr.writeln('Error: $e');
    stderr.writeln(stack);
    exitCode = 1;
  }
}

/// Legacy reflection generation using ReflectionModel.
Future<void> _runLegacyReflect({
  required String barrelPath,
  String? outputPath,
}) async {
  final config = TomAnalyzerConfig.load(section: 'tom_reflector');

  final analyzer = TomAnalyzer();
  final analysis = await analyzer.analyzeBarrel(
    barrelPath: barrelPath,
    workspaceRoot: config.workspaceRoot,
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
  stdout.writeln('Generated: $resolvedOutput');
}

void _printUsage(ArgParser parser) {
  stdout.writeln('tom_reflector - Dart code reflection generation');
  stdout.writeln();
  stdout.writeln('Usage: dart run tom_analyzer:tom_reflector [options]');
  stdout.writeln();
  stdout.writeln('Options:');
  stdout.writeln('  -c, --config <path>   Path to tom_analyzer.yaml configuration');
  stdout.writeln('  -e, --entry <file>    Entry point file(s) to analyze (can repeat)');
  stdout.writeln('  -o, --output <path>   Output file path (base name, .r.dart added)');
  stdout.writeln('  -b, --barrel <path>   Barrel file for legacy mode');
  stdout.writeln('  -w, --workspace-root  Workspace root directory');
  stdout.writeln();
  stdout.writeln('Examples:');
  stdout.writeln('  # Using configuration file');
  stdout.writeln('  dart run tom_analyzer:tom_reflector --config tom_analyzer.yaml');
  stdout.writeln();
  stdout.writeln('  # Specify entry point directly');
  stdout.writeln('  dart run tom_analyzer:tom_reflector --entry lib/my_app.dart');
  stdout.writeln();
  stdout.writeln('  # Multiple entry points');
  stdout.writeln('  dart run tom_analyzer:tom_reflector -e bin/cli.dart -e bin/server.dart');
  stdout.writeln();
  stdout.writeln('  # Legacy barrel-based mode');
  stdout.writeln('  dart run tom_analyzer:tom_reflector --barrel lib/my_lib.dart');
  stdout.writeln();
  stdout.writeln(parser.usage);
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
