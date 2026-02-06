import 'dart:io';

import 'package:yaml/yaml.dart';

/// Configuration for tom_analyzer CLI and builder.
class TomAnalyzerConfig {
  final List<String> barrels;
  final String outputFormat;
  final String? outputFile;
  final String? reflectionOutputFile;
  final String? workspaceRoot;
  final bool followReExports;
  final List<String>? followReExportPackages;
  final List<String> skipReExports;
  final bool includeDeprecatedMembers;
  final Map<String, dynamic> raw;

  const TomAnalyzerConfig({
    this.barrels = const [],
    this.outputFormat = 'yaml',
    this.outputFile,
    this.reflectionOutputFile,
    this.workspaceRoot,
    this.followReExports = true,
    this.followReExportPackages,
    this.skipReExports = const [],
    this.includeDeprecatedMembers = false,
    this.raw = const {},
  });

  TomAnalyzerConfig applyOverrides({
    List<String>? barrels,
    String? outputFormat,
    String? outputFile,
    String? reflectionOutputFile,
    String? workspaceRoot,
    bool? includeDeprecatedMembers,
  }) {
    return TomAnalyzerConfig(
      barrels: barrels ?? this.barrels,
      outputFormat: outputFormat ?? this.outputFormat,
      outputFile: outputFile ?? this.outputFile,
      reflectionOutputFile: reflectionOutputFile ?? this.reflectionOutputFile,
      workspaceRoot: workspaceRoot ?? this.workspaceRoot,
      followReExports: followReExports,
      followReExportPackages: followReExportPackages,
      skipReExports: skipReExports,
      includeDeprecatedMembers:
          includeDeprecatedMembers ?? this.includeDeprecatedMembers,
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
    final reflectionOutputFile = _readString(
      map['reflection_output_file'] ?? map['reflectionOutputFile'],
    );
    final workspaceRoot = _readString(map['workspace_root']);
    final followValue = map['followReExports'] ?? map['follow_re_exports'];
    final followParsed = _readFollowReExports(followValue);
    final skipReExports = _readStringList(map['skipReExports'] ?? map['skip_re_exports']);
    final includeDeprecatedMembers =
      _readBool(map['include_deprecated_members'] ?? map['includeDeprecatedMembers']) ??
        false;
    return TomAnalyzerConfig(
      barrels: barrels,
      outputFormat: outputFormat,
      outputFile: outputFile,
      reflectionOutputFile: reflectionOutputFile,
      workspaceRoot: workspaceRoot,
      followReExports: followParsed.followReExports,
      followReExportPackages: followParsed.followReExportPackages,
      skipReExports: skipReExports,
      includeDeprecatedMembers: includeDeprecatedMembers,
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

  static bool? _readBool(Object? value) {
    return value is bool ? value : null;
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

  static _FollowReExportsConfig _readFollowReExports(Object? value) {
    if (value == null) {
      return const _FollowReExportsConfig(true, null);
    }
    if (value is bool) {
      return _FollowReExportsConfig(value, null);
    }
    if (value is String) {
      return _FollowReExportsConfig(true, [value]);
    }
    if (value is List) {
      return _FollowReExportsConfig(true, value.whereType<String>().toList());
    }
    return const _FollowReExportsConfig(true, null);
  }
}

class _FollowReExportsConfig {
  final bool followReExports;
  final List<String>? followReExportPackages;

  const _FollowReExportsConfig(this.followReExports, this.followReExportPackages);
}
