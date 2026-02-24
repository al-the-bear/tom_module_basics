import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base_v2.dart' show kBuildkitMasterYaml;
import 'package:yaml/yaml.dart';

import 'pipeline_step.dart';

/// Project-level buildkit config file name.
const kBuildkitYaml = 'buildkit.yaml';

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
      return value
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (value is YamlList) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  static List<PipelineStep> _parseSteps(dynamic value) {
    if (value == null) return [];
    if (value is! YamlList) return [];

    return value
        .map((e) {
          if (e is YamlMap) {
            return PipelineStep.fromYaml(e);
          }
          return PipelineStep(commands: []);
        })
        .where((step) => step.commands.isNotEmpty)
        .toList();
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
  /// Internal (hardcoded) list of allowed binaries.
  ///
  /// These are always allowed without any buildkit.yaml configuration.
  /// The `allowed-binaries` list in buildkit.yaml is additive on top
  /// of this internal list.
  static const internalAllowedBinaries = <String>{
    'astgen',
    'd4rtgen',
    'reflector',
    'reflectiongenerator',
    'ws_prepper',
    'ws_analyzer',
  };

  /// All configured pipelines.
  final Map<String, Pipeline> pipelines;

  /// Binaries allowed to be executed directly from the command line.
  ///
  /// This is the merged set of [internalAllowedBinaries] plus any
  /// additional entries from buildkit.yaml `buildkit.allowed-binaries`.
  /// Additive to the built-in commands (versioner, compiler, etc.).
  /// Binaries not in this list or the built-in list will cause an error
  /// when invoked via `:command` syntax or as pipeline step commands.
  /// Compile configuration `commandline:` entries are NOT restricted.
  /// The `shell ` prefix in pipeline step configuration also bypasses
  /// this restriction (any shell command is valid there).
  final Set<String> allowedBinaries;

  /// Source of the configuration (for debugging).
  final String source;

  PipelineConfig({
    required this.pipelines,
    this.allowedBinaries = const {},
    required this.source,
  });

  /// Load pipeline configuration.
  ///
  /// Priority (project replaces workspace, no merging):
  /// 1. buildkit.yaml in project directory
  /// 2. buildkit_master.yaml in root directory
  factory PipelineConfig.load({
    required String projectPath,
    required String rootPath,
  }) {
    // First, load workspace-level config from buildkit_master.yaml
    final workspaceConfig = _loadFromYaml(
      p.join(rootPath, kBuildkitMasterYaml),
    );

    // Then, load project-level config from buildkit.yaml
    final projectConfig = projectPath != rootPath
        ? _loadFromYaml(p.join(projectPath, kBuildkitYaml))
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

    // Merge allowed binaries: internal + workspace + project (all additive)
    final mergedAllowedBinaries = <String>{...internalAllowedBinaries};
    if (workspaceConfig != null) {
      mergedAllowedBinaries.addAll(workspaceConfig.allowedBinaries);
    }
    if (projectConfig != null) {
      mergedAllowedBinaries.addAll(projectConfig.allowedBinaries);
    }

    final source = projectConfig != null
        ? 'project buildkit.yaml (with workspace fallback)'
        : workspaceConfig != null
        ? 'workspace buildkit.yaml'
        : 'none';

    return PipelineConfig(
      pipelines: mergedPipelines,
      allowedBinaries: mergedAllowedBinaries,
      source: source,
    );
  }

  static PipelineConfig? _loadFromYaml(String yamlPath) {
    final yamlFile = File(yamlPath);

    if (!yamlFile.existsSync()) return null;

    try {
      final content = yamlFile.readAsStringSync();
      final rootYaml = loadYaml(content) as YamlMap?;
      if (rootYaml == null) return null;

      final buildkitYaml = rootYaml['buildkit'] as YamlMap?;
      if (buildkitYaml == null) return null;

      final pipelinesYaml = buildkitYaml['pipelines'] as YamlMap?;

      final pipelines = <String, Pipeline>{};
      if (pipelinesYaml != null) {
        for (final entry in pipelinesYaml.entries) {
          final name = entry.key.toString();
          final value = entry.value;
          if (value is YamlMap) {
            pipelines[name] = Pipeline.fromYaml(value);
          }
        }
      }

      // Parse allowed-binaries list
      final allowedBinaries = <String>{};
      final allowedBinariesYaml = buildkitYaml['allowed-binaries'];
      if (allowedBinariesYaml is YamlList) {
        allowedBinaries.addAll(
          allowedBinariesYaml.map((e) => e.toString().toLowerCase()),
        );
      } else if (allowedBinariesYaml is String) {
        allowedBinaries.addAll(
          allowedBinariesYaml.split(',').map((s) => s.trim().toLowerCase()),
        );
      }

      return PipelineConfig(
        pipelines: pipelines,
        allowedBinaries: allowedBinaries,
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
