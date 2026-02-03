import 'dart:io';

import 'package:yaml/yaml.dart';

/// Configuration for tom_analyzer CLI and builder.
class TomAnalyzerConfig {
  final List<String> barrels;
  final String outputFormat;
  final String? outputFile;
  final String? workspaceRoot;
  final Map<String, dynamic> raw;

  const TomAnalyzerConfig({
    this.barrels = const [],
    this.outputFormat = 'yaml',
    this.outputFile,
    this.workspaceRoot,
    this.raw = const {},
  });

  TomAnalyzerConfig applyOverrides({
    List<String>? barrels,
    String? outputFormat,
    String? outputFile,
    String? workspaceRoot,
  }) {
    return TomAnalyzerConfig(
      barrels: barrels ?? this.barrels,
      outputFormat: outputFormat ?? this.outputFormat,
      outputFile: outputFile ?? this.outputFile,
      workspaceRoot: workspaceRoot ?? this.workspaceRoot,
      raw: raw,
    );
  }

  static TomAnalyzerConfig empty() => const TomAnalyzerConfig();

  static TomAnalyzerConfig load({String? path}) {
    final configPath = path ?? _defaultConfigPath();
    if (configPath == null) {
      return empty();
    }
    final file = File(configPath);
    if (!file.existsSync()) {
      return empty();
    }
    final yaml = loadYaml(file.readAsStringSync());
    if (yaml is! YamlMap) {
      return empty();
    }
    return fromMap(Map<String, dynamic>.from(yaml));
  }

  static TomAnalyzerConfig fromMap(Map<String, dynamic> map) {
    final barrels = _readStringList(map['barrels']);
    final outputFormat = _readString(map['output_format']) ?? 'yaml';
    final outputFile = _readString(map['output_file']);
    final workspaceRoot = _readString(map['workspace_root']);
    return TomAnalyzerConfig(
      barrels: barrels,
      outputFormat: outputFormat,
      outputFile: outputFile,
      workspaceRoot: workspaceRoot,
      raw: map,
    );
  }

  static String? _defaultConfigPath() {
    final file = File('tom_analyzer.yaml');
    if (file.existsSync()) {
      return file.path;
    }
    return null;
  }

  static String? _readString(Object? value) {
    return value is String ? value : null;
  }

  static List<String> _readStringList(Object? value) {
    if (value == null) {
      return const [];
    }
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return const [];
  }
}
