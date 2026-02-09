import 'dart:io';

import 'package:args/args.dart';
import 'package:tom_analyzer/tom_analyzer.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('config', abbr: 'c', help: 'Path to tom_analyzer.yaml config')
    ..addOption('barrel', abbr: 'b', help: 'Barrel file to analyze')
    ..addOption('workspace-root', abbr: 'w', help: 'Workspace root directory')
    ..addOption('output', abbr: 'o', help: 'Output file path')
    ..addOption('format', abbr: 'f', defaultsTo: 'yaml',
        help: 'Output format (yaml or json)')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help');

  final result = parser.parse(arguments);

  if (result['help'] as bool) {
    _printUsage(parser);
    return;
  }

  final configPath = result['config'] as String?;
  final barrelOverride = result['barrel'] as String?;

  var config = TomAnalyzerConfig.load(path: configPath, section: 'tom_analyzer');

  if (barrelOverride != null) {
    config = config.applyOverrides(barrels: [barrelOverride]);
  }

  final barrel = config.barrels.isNotEmpty ? config.barrels.first : null;
  if (barrel == null) {
    stderr.writeln('Missing barrel path. Use --barrel or config file.');
    exitCode = 1;
    return;
  }

  config = config.applyOverrides(
    workspaceRoot: result['workspace-root'] as String?,
    outputFile: result['output'] as String?,
    outputFormat: result['format'] as String?,
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
  } else {
    stdout.writeln(content);
  }
}

void _printUsage(ArgParser parser) {
  stdout.writeln('tom_analyzer - Dart code analysis tool');
  stdout.writeln();
  stdout.writeln('Usage: dart run tom_analyzer [options]');
  stdout.writeln();
  stdout.writeln('Analyzes Dart barrel files and outputs structured');
  stdout.writeln('code information in YAML or JSON format.');
  stdout.writeln();
  stdout.writeln('Options:');
  stdout.writeln(parser.usage);
  stdout.writeln();
  stdout.writeln('Examples:');
  stdout.writeln('  # Analyze with config file');
  stdout.writeln('  dart run tom_analyzer --config tom_analyzer.yaml');
  stdout.writeln();
  stdout.writeln('  # Analyze a barrel file');
  stdout.writeln('  dart run tom_analyzer --barrel lib/my_lib.dart');
  stdout.writeln();
  stdout.writeln('  # Output as JSON');
  stdout.writeln('  dart run tom_analyzer --barrel lib/my_lib.dart --format json');
  stdout.writeln();
  stdout.writeln('For reflection generation, use tom_reflector:');
  stdout.writeln('  dart run tom_analyzer:tom_reflector --help');
}
