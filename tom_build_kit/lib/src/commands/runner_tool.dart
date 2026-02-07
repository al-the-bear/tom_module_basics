import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'tool_base.dart';

/// Configuration for builder include/exclude filtering.
class BuilderFilterConfig {
  final List<String> includeBuilders;
  final List<String> excludeBuilders;

  BuilderFilterConfig({
    this.includeBuilders = const [],
    this.excludeBuilders = const [],
  });

  bool get isEmpty => includeBuilders.isEmpty && excludeBuilders.isEmpty;
  bool get isNotEmpty => !isEmpty;

  @override
  String toString() {
    final parts = <String>[];
    if (includeBuilders.isNotEmpty) {
      parts.add('include: ${includeBuilders.join(', ')}');
    }
    if (excludeBuilders.isNotEmpty) {
      parts.add('exclude: ${excludeBuilders.join(', ')}');
    }
    return parts.isEmpty ? 'BuilderFilterConfig(none)' : 'BuilderFilterConfig(${parts.join('; ')})';
  }

  /// Load from build.yaml (tom_build_runner.build_runner section).
  static BuilderFilterConfig? loadFromBuildYaml(String projectPath) {
    final file = File('$projectPath/build.yaml');
    if (!file.existsSync()) return null;

    try {
      final content = file.readAsStringSync();
      final yaml = loadYaml(content) as YamlMap?;
      if (yaml == null) return null;

      final kitSection = yaml['tom_build_kit'] as YamlMap?;
      if (kitSection == null) return null;

      final buildRunner = kitSection['build_runner'] as YamlMap?;
      if (buildRunner == null) return null;

      return BuilderFilterConfig(
        includeBuilders: ToolBase.toStringList(
            buildRunner['include-builders'] ?? buildRunner['include_builders']),
        excludeBuilders: ToolBase.toStringList(
            buildRunner['exclude-builders'] ?? buildRunner['exclude_builders']),
      );
    } catch (_) {
      return null;
    }
  }

  /// Load from tom_build.yaml (build_runner section).
  static BuilderFilterConfig? loadFromTomBuildYaml(String dir) {
    final file = File('$dir/tom_build.yaml');
    if (!file.existsSync()) return null;

    try {
      final content = file.readAsStringSync();
      final yaml = loadYaml(content) as YamlMap?;
      if (yaml == null) return null;

      final buildRunner = yaml['build_runner'] as YamlMap?;
      if (buildRunner == null) return null;

      return BuilderFilterConfig(
        includeBuilders: ToolBase.toStringList(
            buildRunner['include-builders'] ?? buildRunner['include_builders']),
        excludeBuilders: ToolBase.toStringList(
            buildRunner['exclude-builders'] ?? buildRunner['exclude_builders']),
      );
    } catch (_) {
      return null;
    }
  }

  /// Get effective filter config with 4-level precedence:
  /// 1. CLI args, 2. build.yaml, 3. project tom_build.yaml, 4. root tom_build.yaml
  static BuilderFilterConfig getEffective({
    required String projectPath,
    String? rootPath,
    List<String> cliInclude = const [],
    List<String> cliExclude = const [],
  }) {
    // Level 1: CLI args
    if (cliInclude.isNotEmpty || cliExclude.isNotEmpty) {
      return BuilderFilterConfig(
        includeBuilders: cliInclude,
        excludeBuilders: cliExclude,
      );
    }

    // Level 2: build.yaml
    final buildYamlConfig = loadFromBuildYaml(projectPath);
    if (buildYamlConfig != null && buildYamlConfig.isNotEmpty) {
      return buildYamlConfig;
    }

    // Level 3: project tom_build.yaml
    final projectConfig = loadFromTomBuildYaml(projectPath);
    if (projectConfig != null && projectConfig.isNotEmpty) {
      return projectConfig;
    }

    // Level 4: root tom_build.yaml
    if (rootPath != null && rootPath != projectPath) {
      final rootConfig = loadFromTomBuildYaml(rootPath);
      if (rootConfig != null && rootConfig.isNotEmpty) {
        return rootConfig;
      }
    }

    return BuilderFilterConfig();
  }
}

/// Configuration for the build runner tool.
class BuildRunnerConfig {
  final String? project;
  final String? scan;
  final bool recursive;
  final List<String> exclude;
  final List<String> recursionExclude;
  final bool verbose;
  final bool dryRun;
  final String command;
  final bool deleteConflicting;
  final String? configName;
  final bool release;
  final List<String> cliIncludeBuilders;
  final List<String> cliExcludeBuilders;

  BuildRunnerConfig({
    this.project,
    this.scan,
    this.recursive = false,
    this.exclude = const [],
    this.recursionExclude = const [],
    this.verbose = false,
    this.dryRun = false,
    this.command = 'build',
    this.deleteConflicting = true,
    this.configName,
    this.release = false,
    this.cliIncludeBuilders = const [],
    this.cliExcludeBuilders = const [],
  });

  /// Load config from tom_build.yaml.
  static BuildRunnerConfig? loadFromYaml(String dir) {
    final file = File('$dir/tom_build.yaml');
    if (!file.existsSync()) return null;

    try {
      final content = file.readAsStringSync();
      final yaml = loadYaml(content) as YamlMap?;
      if (yaml == null) return null;

      final runnerYaml = yaml['build_runner'] as YamlMap?;
      if (runnerYaml == null) return null;

      return BuildRunnerConfig(
        project: runnerYaml['project'] as String?,
        scan: runnerYaml['scan'] as String?,
        recursive: runnerYaml['recursive'] as bool? ?? false,
        exclude: ToolBase.toStringList(runnerYaml['exclude']),
        recursionExclude: ToolBase.toStringList(
            runnerYaml['recursion-exclude'] ?? runnerYaml['recursionExclude']),
        verbose: runnerYaml['verbose'] as bool? ?? false,
        dryRun: runnerYaml['dry-run'] as bool? ?? false,
        command: runnerYaml['command'] as String? ?? 'build',
        deleteConflicting:
            runnerYaml['delete-conflicting'] as bool? ?? true,
        configName: runnerYaml['config'] as String?,
        release: runnerYaml['release'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  /// Merge with another config (other takes precedence).
  BuildRunnerConfig merge(BuildRunnerConfig other) {
    return BuildRunnerConfig(
      project: other.project ?? project,
      scan: other.scan ?? scan,
      recursive: other.recursive || recursive,
      exclude: [...exclude, ...other.exclude],
      recursionExclude: [...recursionExclude, ...other.recursionExclude],
      verbose: other.verbose || verbose,
      dryRun: other.dryRun || dryRun,
      command: other.command != 'build' ? other.command : command,
      deleteConflicting: other.deleteConflicting && deleteConflicting,
      configName: other.configName ?? configName,
      release: other.release || release,
      cliIncludeBuilders: other.cliIncludeBuilders.isNotEmpty
          ? other.cliIncludeBuilders
          : cliIncludeBuilders,
      cliExcludeBuilders: other.cliExcludeBuilders.isNotEmpty
          ? other.cliExcludeBuilders
          : cliExcludeBuilders,
    );
  }
}

/// Runner tool - build_runner wrapper with project scanning and builder filtering.
///
/// Wraps `dart run build_runner` with:
/// - Multi-project scanning and discovery
/// - 4-level builder include/exclude filtering
/// - Configuration from tom_build.yaml and build.yaml
class RunnerTool extends ToolBase {
  @override
  String get toolKey => 'runner';

  @override
  String get toolDescription =>
      'Build_runner wrapper with project scanning and builder filtering';

  @override
  void addToolOptions(ArgParser parser) {
    parser
      ..addOption('command',
          abbr: 'c',
          defaultsTo: 'build',
          allowed: ['build', 'watch', 'clean'],
          help: 'Build runner command')
      ..addMultiOption('include-builders',
          abbr: 'i', help: 'Include specific builders')
      ..addMultiOption('exclude-builders',
          help: 'Exclude specific builders')
      ..addOption('config',
          help: 'Build runner config name')
      ..addFlag('release',
          negatable: false, help: 'Build in release mode')
      ..addFlag('delete-conflicting',
          defaultsTo: true,
          help: 'Delete conflicting outputs');
  }

  @override
  bool isToolProject(String dirPath) {
    return File('$dirPath/pubspec.yaml').existsSync() &&
        File('$dirPath/build.yaml').existsSync();
  }

  @override
  Future<bool> run(List<String> args) async {
    if (checkVersionArg(args)) return true;

    final parser = createParser();
    ArgResults results;

    try {
      results = parser.parse(args);
    } catch (e) {
      print('Error: $e');
      _printUsage(parser);
      return false;
    }

    if (results['help'] as bool) {
      _printUsage(parser);
      return true;
    }

    verbose = results['verbose'] as bool;
    dryRun = results['dry-run'] as bool;

    final listMode = results['list'] as bool;
    final showMode = results['show'] as bool;

    // Load workspace-level config
    final basePath = Directory.current.path;
    final rootPath = _findWorkspaceRoot(basePath);
    var config = BuildRunnerConfig.loadFromYaml(basePath) ?? BuildRunnerConfig();

    // Override with CLI options
    config = config.merge(BuildRunnerConfig(
      project: results['project'] as String?,
      scan: results['scan'] as String?,
      recursive: results['recursive'] as bool,
      exclude: results['exclude'] as List<String>,
      recursionExclude: results['recursion-exclude'] as List<String>,
      verbose: verbose,
      dryRun: dryRun,
      command: results['command'] as String,
      deleteConflicting: results['delete-conflicting'] as bool,
      configName: results['config'] as String?,
      release: results['release'] as bool,
      cliIncludeBuilders: results['include-builders'] as List<String>,
      cliExcludeBuilders: results['exclude-builders'] as List<String>,
    ));

    // Validate paths
    if (!validateAndEnforcePaths(
      scan: config.scan,
      project: config.project,
      basePath: basePath,
    )) {
      return false;
    }

    // Find projects
    final projects = await findProjects(
      project: config.project,
      scan: config.scan,
      recursive: config.recursive,
      exclude: config.exclude,
      recursionExclude: config.recursionExclude,
      basePath: basePath,
    );

    if (listMode) {
      print('Projects with build.yaml:');
      for (final project in projects) {
        if (isToolProject(project)) {
          print('  ${p.relative(project, from: basePath)}');
        }
      }
      return true;
    }

    if (showMode) {
      for (final project in projects) {
        print('Project: ${p.relative(project, from: basePath)}');
        _showProjectConfig(project, rootPath);
      }
      return true;
    }

    // Process each project
    var success = true;
    for (final projectPath in projects) {
      if (!await processProject(projectPath, config, rootPath)) {
        success = false;
      }
    }

    return success;
  }

  /// Process a single project: run build_runner with filtering.
  Future<bool> processProject(
    String projectPath,
    BuildRunnerConfig config,
    String rootPath,
  ) async {
    if (verbose) print('Processing: ${p.basename(projectPath)}');

    // Load project-level BuildRunnerConfig from tom_build.yaml
    var projectConfig = config;
    final yamlConfig = BuildRunnerConfig.loadFromYaml(projectPath);
    if (yamlConfig != null) {
      projectConfig = projectConfig.merge(yamlConfig);
    }

    // Get effective builder filter (4-level precedence)
    final filterConfig = BuilderFilterConfig.getEffective(
      projectPath: projectPath,
      rootPath: rootPath,
      cliInclude: projectConfig.cliIncludeBuilders,
      cliExclude: projectConfig.cliExcludeBuilders,
    );

    // Extract configured builders from build.yaml
    final configuredBuilders = _extractConfiguredBuilders(projectPath);

    // Determine which builders to run and which to disable
    List<String> buildersToRun;
    List<String> buildersToDisable;

    // Start with all configured builders
    buildersToRun = List.of(configuredBuilders);
    buildersToDisable = <String>[];

    // Apply include filter first (if set, only keep matching builders)
    if (filterConfig.includeBuilders.isNotEmpty) {
      buildersToRun = buildersToRun
          .where((b) => filterConfig.includeBuilders.any(
              (include) => b.contains(include) || include.contains(b)))
          .toList();
    }

    // Apply exclude filter on top (remove matching builders)
    if (filterConfig.excludeBuilders.isNotEmpty) {
      final excluded = buildersToRun
          .where((b) => filterConfig.excludeBuilders.any(
              (exclude) => b.contains(exclude) || exclude.contains(b)))
          .toList();
      buildersToRun = buildersToRun
          .where((b) => !excluded.contains(b))
          .toList();
    }

    // Anything not in buildersToRun should be disabled
    buildersToDisable = configuredBuilders
        .where((b) => !buildersToRun.contains(b))
        .toList();

    if (verbose && filterConfig.isNotEmpty) {
      print('  Builders to run: ${buildersToRun.join(', ')}');
      if (buildersToDisable.isNotEmpty) {
        print('  Builders disabled: ${buildersToDisable.join(', ')}');
      }
    }

    // Build dart run build_runner command
    final dartArgs = [
      'run',
      'build_runner',
      projectConfig.command,
    ];

    if (projectConfig.deleteConflicting &&
        (projectConfig.command == 'build' ||
         projectConfig.command == 'watch')) {
      dartArgs.add('--delete-conflicting-outputs');
    }
    if (projectConfig.configName != null) {
      dartArgs.add('--config=${projectConfig.configName}');
    }
    if (projectConfig.release) {
      dartArgs.add('--release');
    }
    if (verbose) {
      dartArgs.add('--verbose');
    }

    // Disable excluded builders via --define
    for (final builder in buildersToDisable) {
      dartArgs.add('--define=$builder=enabled=false');
    }

    if (dryRun) {
      print('  [DRY RUN] Would run: dart ${dartArgs.join(' ')}');
      return true;
    }

    print('  Running: dart ${dartArgs.join(' ')}');
    print('  Working directory: ${p.basename(projectPath)}');

    final result = await Process.run(
      'dart',
      dartArgs,
      workingDirectory: projectPath,
    );

    if (result.stdout.toString().isNotEmpty) {
      stdout.write(result.stdout);
    }
    if (result.stderr.toString().isNotEmpty) {
      stderr.write(result.stderr);
    }

    if (result.exitCode != 0) {
      print('  Error: build_runner ${projectConfig.command} failed '
          '(exit ${result.exitCode})');
      return false;
    }

    return true;
  }

  /// Extract all builder keys from a project's build.yaml.
  List<String> _extractConfiguredBuilders(String projectPath) {
    final file = File('$projectPath/build.yaml');
    if (!file.existsSync()) return [];

    try {
      final content = file.readAsStringSync();
      final yaml = loadYaml(content) as YamlMap?;
      if (yaml == null) return [];

      final builders = <String>{};

      // From targets section
      final targets = yaml['targets'] as YamlMap?;
      if (targets != null) {
        for (final target in targets.values) {
          if (target is! YamlMap) continue;
          final targetBuilders = target['builders'] as YamlMap?;
          if (targetBuilders == null) continue;
          for (final entry in targetBuilders.entries) {
            final builderConfig = entry.value as YamlMap?;
            final enabled = builderConfig?['enabled'] as bool? ?? true;
            if (enabled) {
              builders.add(entry.key.toString());
            }
          }
        }
      }

      // From global_options section
      final globalOptions = yaml['global_options'] as YamlMap?;
      if (globalOptions != null) {
        builders.addAll(globalOptions.keys.map((k) => k.toString()));
      }

      return builders.toList();
    } catch (_) {
      return [];
    }
  }

  /// Show project configuration (for --show).
  void _showProjectConfig(String projectPath, String rootPath) {
    final filterConfig = BuilderFilterConfig.getEffective(
      projectPath: projectPath,
      rootPath: rootPath,
    );

    final builders = _extractConfiguredBuilders(projectPath);

    print('  Configured builders:');
    for (final builder in builders) {
      print('    - $builder');
    }

    if (filterConfig.isNotEmpty) {
      if (filterConfig.includeBuilders.isNotEmpty) {
        print('  Include filter: ${filterConfig.includeBuilders.join(', ')}');
      }
      if (filterConfig.excludeBuilders.isNotEmpty) {
        print('  Exclude filter: ${filterConfig.excludeBuilders.join(', ')}');
      }
    }
  }

  /// Find workspace root by traversing up.
  String _findWorkspaceRoot(String startPath) {
    var current = p.normalize(p.absolute(startPath));
    final root = p.rootPrefix(current);

    while (current != root) {
      if (File('$current/tom_workspace.yaml').existsSync() ||
          File('$current/tom.code-workspace').existsSync()) {
        return current;
      }
      current = p.dirname(current);
    }

    return startPath;
  }

  void _printUsage(ArgParser parser) {
    print('Runner Tool - $toolDescription');
    print('');
    print('Usage: runner [options]');
    print('       buildkit :runner [options]');
    print('       dart run tom_build_kit:runner [options]');
    print('       runner version');
    print('');
    print('Options:');
    print(parser.usage);
    print('');
    print('Builder filter precedence:');
    print('  1. CLI --include-builders / --exclude-builders');
    print('  2. build.yaml (tom_build_kit section)');
    print('  3. Project tom_build.yaml (build_runner section)');
    print('  4. Root tom_build.yaml (build_runner section)');
    print('');
    print('Configuration (tom_build.yaml):');
    print('  build_runner:');
    print('    command: build          # build, watch, or clean');
    print('    exclude-builders:');
    print('      - <package>:<builder_name>');
    print('');
    print('Examples:');
    print('  runner                            # Build in current project');
    print('  runner -c watch                   # Watch mode');
    print('  runner -c clean                   # Clean build outputs');
    print('  runner -i tom_build_kit:version_builder  # Only run versioner');
    print('  runner -s . -R                    # All projects recursively');
  }
}
