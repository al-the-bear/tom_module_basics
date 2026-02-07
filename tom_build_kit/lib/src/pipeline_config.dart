import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'pipeline_step.dart';

/// Configuration for a single pipeline.
class Pipeline {
  /// Whether this pipeline can be triggered from the command line.
  final bool executable;

  /// Pipelines to run before this one.
  final List<String> runBefore;

  /// Pipelines to run after this one.
  final List<String> runAfter;

  /// Steps to run before the core (can be added at project level).
  final List<PipelineStep> precore;

  /// Core steps of this pipeline.
  final List<PipelineStep> core;

  /// Steps to run after the core (can be added at project level).
  final List<PipelineStep> postcore;

  Pipeline({
    this.executable = true,
    this.runBefore = const [],
    this.runAfter = const [],
    this.precore = const [],
    this.core = const [],
    this.postcore = const [],
  });

  /// Parse a pipeline from YAML.
  factory Pipeline.fromYaml(YamlMap yaml) {
    return Pipeline(
      executable: yaml['executable'] as bool? ?? true,
      runBefore: _parseStringList(yaml['runBefore']),
      runAfter: _parseStringList(yaml['runAfter']),
      precore: _parseSteps(yaml['precore']),
      core: _parseSteps(yaml['core']),
      postcore: _parseSteps(yaml['postcore']),
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is String) {
      return value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    if (value is YamlList) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  static List<PipelineStep> _parseSteps(dynamic value) {
    if (value == null) return [];
    if (value is! YamlList) return [];

    return value.map((e) {
      if (e is YamlMap) {
        return PipelineStep.fromYaml(e);
      }
      return PipelineStep(commands: []);
    }).where((step) => step.commands.isNotEmpty).toList();
  }

  /// Merge with project-level overrides.
  /// 
  /// Project-level pipelines replace workspace-level completely (no merging).
  Pipeline mergeWith(Pipeline? projectPipeline) {
    if (projectPipeline == null) return this;

    // Project pipeline completely replaces workspace pipeline
    return projectPipeline;
  }
}

/// Configuration for all pipelines.
class PipelineConfig {
  /// All configured pipelines.
  final Map<String, Pipeline> pipelines;

  /// Source of the configuration (for debugging).
  final String source;

  PipelineConfig({
    required this.pipelines,
    required this.source,
  });

  /// Load pipeline configuration from tom_build.yaml files.
  /// 
  /// Priority (project replaces workspace, no merging):
  /// 1. tom_build.yaml in project directory
  /// 2. tom_build.yaml in root directory
  factory PipelineConfig.load({
    required String projectPath,
    required String rootPath,
  }) {
    // First, load workspace-level config
    final workspaceConfig = _loadFromTomBuildYaml(rootPath);
    
    // Then, load project-level config
    final projectConfig = projectPath != rootPath
        ? _loadFromTomBuildYaml(projectPath)
        : null;

    // Merge: project replaces workspace for matching pipeline names
    final mergedPipelines = <String, Pipeline>{};
    
    // Start with workspace pipelines
    if (workspaceConfig != null) {
      mergedPipelines.addAll(workspaceConfig.pipelines);
    }

    // Project pipelines replace workspace ones
    if (projectConfig != null) {
      for (final entry in projectConfig.pipelines.entries) {
        mergedPipelines[entry.key] = entry.value;
      }
    }

    final source = projectConfig != null
        ? 'project tom_build.yaml (with workspace fallback)'
        : workspaceConfig != null
            ? 'workspace tom_build.yaml'
            : 'none';

    return PipelineConfig(
      pipelines: mergedPipelines,
      source: source,
    );
  }

  static PipelineConfig? _loadFromTomBuildYaml(String dir) {
    final yamlPath = p.join(dir, 'tom_build.yaml');
    final yamlFile = File(yamlPath);

    if (!yamlFile.existsSync()) return null;

    try {
      final content = yamlFile.readAsStringSync();
      final rootYaml = loadYaml(content) as YamlMap?;
      if (rootYaml == null) return null;

      final buildkitYaml = rootYaml['buildkit'] as YamlMap?;
      if (buildkitYaml == null) return null;

      final pipelinesYaml = buildkitYaml['pipelines'] as YamlMap?;
      if (pipelinesYaml == null) return null;

      final pipelines = <String, Pipeline>{};
      for (final entry in pipelinesYaml.entries) {
        final name = entry.key.toString();
        final value = entry.value;
        if (value is YamlMap) {
          pipelines[name] = Pipeline.fromYaml(value);
        }
      }

      return PipelineConfig(
        pipelines: pipelines,
        source: yamlPath,
      );
    } catch (e) {
      // Silently fail - configuration not found
      return null;
    }
  }

  /// Get a pipeline by name.
  Pipeline? getPipeline(String name) => pipelines[name];

  /// Check if a pipeline exists and is executable.
  bool isExecutable(String name) {
    final pipeline = pipelines[name];
    return pipeline != null && pipeline.executable;
  }
}
