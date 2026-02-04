import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_analyzer/tom_analyzer.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addCommand('analyze')
    ..addCommand('reflect')
    ..addOption('config', abbr: 'c')
    ..addOption('barrel', abbr: 'b')
    ..addOption('workspace-root', abbr: 'w')
    ..addOption('output', abbr: 'o')
    ..addOption('format', abbr: 'f', defaultsTo: 'yaml');

  final result = parser.parse(arguments);
  final command = result.command?.name ?? 'analyze';

  final configPath = result['config'] as String?;
  var config = TomAnalyzerConfig.load(path: configPath);

  final barrelOverride = result['barrel'] as String?;
  if (barrelOverride != null) {
    config = config.applyOverrides(barrels: [barrelOverride]);
  }

  final barrel = config.barrels.isNotEmpty ? config.barrels.first : null;
  if (barrel == null) {
    stderr.writeln('Missing barrel path. Use --barrel or config file.');
    exitCode = 1;
    return;
  }

  if (command == 'reflect') {
    config = config.applyOverrides(
      workspaceRoot: result['workspace-root'] as String?,
      reflectionOutputFile: result['output'] as String?,
    );

    final analyzer = TomAnalyzer();
    final analysis = await analyzer.analyzeBarrel(
      barrelPath: barrel,
      workspaceRoot: config.workspaceRoot,
      followReExports: config.followReExports,
      followReExportPackages: config.followReExportPackages,
      skipReExports: config.skipReExports,
    );

    final model = ReflectionModel.fromAnalysis(analysis);
    final generator = ReflectionGenerator();
    final content = generator.generate(model);

    final outputPath = _resolveReflectionOutput(
      barrelPath: barrel,
      outputFile: config.reflectionOutputFile,
    );

    await File(outputPath).writeAsString(content);
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
