import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Configuration loaded from tom_build.yaml for a specific tool.
/// 
/// This class provides shared CLI configuration options that are common
/// across Tom build tools. Tool-specific options are accessible via
/// [toolOptions].
class TomBuildConfig {
  /// Path to a single project directory.
  final String? project;
  
  /// Glob patterns for projects to process.
  final List<String> projects;
  
  /// Path to a specific config file.
  final String? config;
  
  /// Directory to scan for projects.
  final String? scan;
  
  /// Whether to process subprojects recursively.
  final bool recursive;
  
  /// Glob patterns for projects to exclude from processing.
  final List<String> exclude;
  
  /// Glob patterns to exclude from recursive traversal.
  final List<String> recursionExclude;
  
  /// Whether to show detailed output.
  final bool verbose;
  
  /// Tool-specific options as a raw map.
  /// Tools can extract additional options from this.
  final Map<String, dynamic> toolOptions;

  const TomBuildConfig({
    this.project,
    this.projects = const [],
    this.config,
    this.scan,
    this.recursive = false,
    this.exclude = const [],
    this.recursionExclude = const [],
    this.verbose = false,
    this.toolOptions = const {},
  });

  /// Load configuration from tom_build.yaml file for a specific tool.
  /// 
  /// [dir] - Directory containing tom_build.yaml
  /// [toolKey] - The tool's section key in the YAML (e.g., 'dartgen', 'versioner')
  /// 
  /// Returns null if:
  /// - tom_build.yaml doesn't exist
  /// - The file is invalid YAML
  /// - The tool's section doesn't exist
  static TomBuildConfig? load({
    required String dir,
    required String toolKey,
  }) {
    final yamlPath = p.join(dir, 'tom_build.yaml');
    final yamlFile = File(yamlPath);

    if (!yamlFile.existsSync()) return null;

    try {
      final content = yamlFile.readAsStringSync();
      final rootYaml = loadYaml(content) as YamlMap?;
      if (rootYaml == null) return null;

      // Look for tool's section
      final yaml = rootYaml[toolKey] as YamlMap?;
      if (yaml == null) return null;

      return TomBuildConfig.fromYamlMap(yaml);
    } catch (_) {
      return null;
    }
  }

  /// Create a config from a YAML map (tool's section).
  factory TomBuildConfig.fromYamlMap(YamlMap yaml) {
    // Convert YamlMap to regular Map for toolOptions
    final toolOptions = <String, dynamic>{};
    for (final key in yaml.keys) {
      final value = yaml[key];
      if (value is YamlMap) {
        toolOptions[key.toString()] = _convertYamlToMap(value);
      } else if (value is YamlList) {
        toolOptions[key.toString()] = value.toList();
      } else {
        toolOptions[key.toString()] = value;
      }
    }

    return TomBuildConfig(
      project: yaml['project'] as String?,
      projects: _toStringList(yaml['projects']),
      config: yaml['config'] as String?,
      scan: yaml['scan'] as String?,
      recursive: yaml['recursive'] as bool? ?? false,
      exclude: _toStringList(yaml['exclude']),
      recursionExclude: _toStringList(
        yaml['recursion-exclude'] ?? yaml['recursionExclude'],
      ),
      verbose: yaml['verbose'] as bool? ?? false,
      toolOptions: toolOptions,
    );
  }

  static Map<String, dynamic> _convertYamlToMap(YamlMap yaml) {
    final result = <String, dynamic>{};
    for (final key in yaml.keys) {
      final value = yaml[key];
      if (value is YamlMap) {
        result[key.toString()] = _convertYamlToMap(value);
      } else if (value is YamlList) {
        result[key.toString()] = value.toList();
      } else {
        result[key.toString()] = value;
      }
    }
    return result;
  }

  static List<String> _toStringList(dynamic value) {
    if (value == null) return [];
    if (value is String) return [value];
    if (value is YamlList) return value.map((e) => e.toString()).toList();
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  /// Check if any project/scan/config option is specified.
  bool get hasProjectOptions =>
      project != null || projects.isNotEmpty || config != null || scan != null;

  /// Merge with another config (other takes precedence for non-null values).
  TomBuildConfig merge(TomBuildConfig other) {
    return TomBuildConfig(
      project: other.project ?? project,
      projects: other.projects.isNotEmpty ? other.projects : projects,
      config: other.config ?? config,
      scan: other.scan ?? scan,
      recursive: other.recursive || recursive,
      exclude: other.exclude.isNotEmpty ? other.exclude : exclude,
      recursionExclude: other.recursionExclude.isNotEmpty
          ? other.recursionExclude
          : recursionExclude,
      verbose: other.verbose || verbose,
      toolOptions: {...toolOptions, ...other.toolOptions},
    );
  }

  /// Create a copy with updated values.
  TomBuildConfig copyWith({
    String? project,
    List<String>? projects,
    String? config,
    String? scan,
    bool? recursive,
    List<String>? exclude,
    List<String>? recursionExclude,
    bool? verbose,
    Map<String, dynamic>? toolOptions,
  }) {
    return TomBuildConfig(
      project: project ?? this.project,
      projects: projects ?? this.projects,
      config: config ?? this.config,
      scan: scan ?? this.scan,
      recursive: recursive ?? this.recursive,
      exclude: exclude ?? this.exclude,
      recursionExclude: recursionExclude ?? this.recursionExclude,
      verbose: verbose ?? this.verbose,
      toolOptions: toolOptions ?? this.toolOptions,
    );
  }
}

/// Check if a directory has tom_build.yaml with a specific tool section.
bool hasTomBuildConfig(String dirPath, String toolKey) {
  final yamlPath = p.join(dirPath, 'tom_build.yaml');
  final yamlFile = File(yamlPath);
  if (!yamlFile.existsSync()) return false;

  try {
    final content = yamlFile.readAsStringSync();
    final yaml = loadYaml(content) as YamlMap?;
    return yaml != null && yaml[toolKey] != null;
  } catch (_) {
    return false;
  }
}
