import 'dart:io';

import 'package:args/args.dart';
import 'package:tom_analyzer/tom_analyzer.dart';
import 'package:yaml/yaml.dart';

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

  if (command == 'reflect') {
    stderr.writeln('Reflection generation is not yet implemented.');
    exitCode = 1;
    return;
  }

  final configPath = result['config'] as String?;
  final config = configPath != null ? _loadConfig(configPath) : <String, dynamic>{};

  final barrel = result['barrel'] as String? ?? config['barrels']?.first as String?;
  if (barrel == null) {
    stderr.writeln('Missing barrel path. Use --barrel or config file.');
    exitCode = 1;
    return;
  }

  final workspaceRoot = result['workspace-root'] as String? ?? config['workspace_root'] as String?;
  final outputPath = result['output'] as String? ?? config['output_file'] as String?;
  final format = result['format'] as String? ?? config['output_format'] as String? ?? 'yaml';

  final analyzer = TomAnalyzer();
  final analysis = await analyzer.analyzeBarrel(
    barrelPath: barrel,
    workspaceRoot: workspaceRoot,
  );

  final content = format == 'json'
      ? JsonSerializer.encode(analysis)
      : YamlSerializer.encode(analysis);

  if (outputPath != null) {
    await File(outputPath).writeAsString(content);
  } else {
    stdout.writeln(content);
  }
}

Map<String, dynamic> _loadConfig(String path) {
  final file = File(path);
  if (!file.existsSync()) return {};
  final yaml = loadYaml(file.readAsStringSync());
  if (yaml is YamlMap) {
    return Map<String, dynamic>.from(yaml);
  }
  return {};
}
