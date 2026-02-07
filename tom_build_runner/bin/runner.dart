#!/usr/bin/env dart
/// Build Runner CLI wrapper (build_runner)
///
/// Command-line interface for running build_runner across multiple projects
/// in a workspace with project discovery and builder filtering.
///
/// ## Configuration Sources (in order of precedence, no merging)
///
/// 1. Command-line arguments (highest priority)
/// 2. `build.yaml` (tom_build_runner:build_runner section) in project
/// 3. `tom_build.yaml` (build_runner: section) in project directory
/// 4. `tom_build.yaml` (build_runner: section) in root/current directory
///
/// ## Usage
///
/// ```bash
/// # Run build_runner on current project
/// build_runner
///
/// # Scan workspace and run on all projects
/// build_runner --scan=.
///
/// # Run specific builders only
/// build_runner --include-builders=tom_version_builder:version_builder
///
/// # Exclude specific builders
/// build_runner --exclude-builders=some_package:some_builder
///
/// # Show help
/// build_runner --help
/// ```
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';
import 'package:tom_build_runner/src/version.g.dart';
import 'package:yaml/yaml.dart';

/// The tool key for runner in tom_build.yaml
const _toolKey = 'runner';

/// Global verbose flag
bool _verbose = false;

/// Convert a dynamic value to a list of strings.
List<String> _toStringList(dynamic value) {
  if (value == null) return [];
  if (value is String) return [value];
  if (value is YamlList) return value.map((e) => e.toString()).toList();
  if (value is List) return value.map((e) => e.toString()).toList();
  return [];
}

/// Builder filter configuration for a project.
/// 
/// Loaded from (in order of precedence, no merging):
/// 1. CLI arguments
/// 2. build.yaml (tom_build_runner:build_runner section)
/// 3. tom_build.yaml in project directory
/// 4. tom_build.yaml in root directory
class BuilderFilterConfig {
  final List<String> includeBuilders;
  final List<String> excludeBuilders;

  const BuilderFilterConfig({
    this.includeBuilders = const [],
    this.excludeBuilders = const [],
  });

  bool get isEmpty => includeBuilders.isEmpty && excludeBuilders.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// Load from build.yaml (tom_build_runner:build_runner section).
  static BuilderFilterConfig? loadFromBuildYaml(String projectPath) {
    final buildYamlPath = p.join(projectPath, 'build.yaml');
    final buildYamlFile = File(buildYamlPath);

    if (!buildYamlFile.existsSync()) return null;

    try {
      final content = buildYamlFile.readAsStringSync();
      final rootYaml = loadYaml(content) as YamlMap?;
      if (rootYaml == null) return null;

      // Look for tom_build_runner:build_runner section
      final tomBuildRunner = rootYaml['tom_build_runner'] as YamlMap?;
      if (tomBuildRunner == null) return null;

      final buildRunnerSection = tomBuildRunner['build_runner'] as YamlMap?;
      if (buildRunnerSection == null) return null;

      final include = _toStringList(buildRunnerSection['include-builders']);
      final exclude = _toStringList(buildRunnerSection['exclude-builders']);

      if (include.isEmpty && exclude.isEmpty) return null;

      return BuilderFilterConfig(
        includeBuilders: include,
        excludeBuilders: exclude,
      );
    } catch (e) {
      if (_verbose) {
        print('Error loading build.yaml: $e');
      }
      return null;
    }
  }

  /// Load from tom_build.yaml (build_runner: section).
  static BuilderFilterConfig? loadFromTomBuildYaml(String dir) {
    final yamlPath = p.join(dir, 'tom_build.yaml');
    final yamlFile = File(yamlPath);

    if (!yamlFile.existsSync()) return null;

    try {
      final content = yamlFile.readAsStringSync();
      final rootYaml = loadYaml(content) as YamlMap?;
      if (rootYaml == null) return null;

      final buildRunnerYaml = rootYaml['build_runner'] as YamlMap?;
      if (buildRunnerYaml == null) return null;

      final include = _toStringList(buildRunnerYaml['include-builders']);
      final exclude = _toStringList(buildRunnerYaml['exclude-builders']);

      if (include.isEmpty && exclude.isEmpty) return null;

      return BuilderFilterConfig(
        includeBuilders: include,
        excludeBuilders: exclude,
      );
    } catch (e) {
      if (_verbose) {
        print('Error loading tom_build.yaml: $e');
      }
      return null;
    }
  }

  /// Get the effective builder filter for a project.
  /// 
  /// Priority (no merging, first non-empty wins):
  /// 1. CLI arguments
  /// 2. build.yaml (tom_build_runner:build_runner section)
  /// 3. tom_build.yaml in project directory
  /// 4. tom_build.yaml in root directory
  static BuilderFilterConfig getEffective({
    required String projectPath,
    required String rootPath,
    required List<String> cliInclude,
    required List<String> cliExclude,
  }) {
    // 1. CLI arguments (highest priority)
    if (cliInclude.isNotEmpty || cliExclude.isNotEmpty) {
      if (_verbose) {
        print('  Using builder filter from CLI arguments');
      }
      return BuilderFilterConfig(
        includeBuilders: cliInclude,
        excludeBuilders: cliExclude,
      );
    }

    // 2. build.yaml in project
    final fromBuildYaml = loadFromBuildYaml(projectPath);
    if (fromBuildYaml != null) {
      if (_verbose) {
        print('  Using builder filter from build.yaml');
      }
      return fromBuildYaml;
    }

    // 3. tom_build.yaml in project directory
    final fromProjectTomBuild = loadFromTomBuildYaml(projectPath);
    if (fromProjectTomBuild != null) {
      if (_verbose) {
        print('  Using builder filter from project tom_build.yaml');
      }
      return fromProjectTomBuild;
    }

    // 4. tom_build.yaml in root directory (only if different from project)
    if (rootPath != projectPath) {
      final fromRootTomBuild = loadFromTomBuildYaml(rootPath);
      if (fromRootTomBuild != null) {
        if (_verbose) {
          print('  Using builder filter from root tom_build.yaml');
        }
        return fromRootTomBuild;
      }
    }

    // Default: no filtering
    return const BuilderFilterConfig();
  }

  @override
  String toString() {
    final parts = <String>[];
    if (includeBuilders.isNotEmpty) {
      parts.add('include: ${includeBuilders.join(', ')}');
    }
    if (excludeBuilders.isNotEmpty) {
      parts.add('exclude: ${excludeBuilders.join(', ')}');
    }
    return parts.isEmpty ? '(none)' : parts.join('; ');
  }
}

/// Extract configured builders from a project's build.yaml.
List<String> extractConfiguredBuilders(String projectPath) {
  final buildYamlPath = p.join(projectPath, 'build.yaml');
  final buildYamlFile = File(buildYamlPath);

  if (!buildYamlFile.existsSync()) return [];

  try {
    final content = buildYamlFile.readAsStringSync();
    final rootYaml = loadYaml(content) as YamlMap?;
    if (rootYaml == null) return [];

    final builders = <String>[];

    // Look in targets section
    final targets = rootYaml['targets'] as YamlMap?;
    if (targets != null) {
      for (final target in targets.values) {
        if (target is! YamlMap) continue;
        final targetBuilders = target['builders'] as YamlMap?;
        if (targetBuilders != null) {
          for (final builderKey in targetBuilders.keys) {
            final key = builderKey.toString();
            // Only add if enabled (default is enabled)
            final builderConfig = targetBuilders[builderKey];
            if (builderConfig is YamlMap) {
              final enabled = builderConfig['enabled'];
              if (enabled == false) continue;
            }
            if (!builders.contains(key)) {
              builders.add(key);
            }
          }
        }
      }
    }

    // Look in global_options section
    final globalOptions = rootYaml['global_options'] as YamlMap?;
    if (globalOptions != null) {
      for (final builderKey in globalOptions.keys) {
        final key = builderKey.toString();
        if (!builders.contains(key)) {
          builders.add(key);
        }
      }
    }

    return builders;
  } catch (e) {
    if (_verbose) {
      print('Error extracting builders from build.yaml: $e');
    }
    return [];
  }
}

/// Configuration for the build_runner CLI.
class BuildRunnerConfig {
  final String? project;
  final String? scan;
  final bool recursive;
  final List<String> exclude;
  final List<String> recursionExclude;
  final bool verbose;
  final bool dryRun;

  // Build runner specific options
  final String command;
  final bool deleteConflicting;
  final String? configName;
  final bool release;

  // CLI-level builder filters (used as highest priority in per-project resolution)
  final List<String> cliIncludeBuilders;
  final List<String> cliExcludeBuilders;

  const BuildRunnerConfig({
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

  /// Load configuration from tom_build.yaml file (build_runner: section).
  static BuildRunnerConfig? loadFromYaml(String dir) {
    final yamlPath = p.join(dir, 'tom_build.yaml');
    final yamlFile = File(yamlPath);

    if (!yamlFile.existsSync()) return null;

    try {
      final content = yamlFile.readAsStringSync();
      final rootYaml = loadYaml(content) as YamlMap?;
      if (rootYaml == null) return null;

      final buildRunnerYaml = rootYaml['build_runner'] as YamlMap?;
      if (buildRunnerYaml == null) return null;

      return BuildRunnerConfig(
        project: buildRunnerYaml['project'] as String?,
        scan: buildRunnerYaml['scan'] as String?,
        recursive: buildRunnerYaml['recursive'] as bool? ?? false,
        exclude: _toStringList(buildRunnerYaml['exclude']),
        recursionExclude: _toStringList(
          buildRunnerYaml['recursion-exclude'] ??
              buildRunnerYaml['recursionExclude'],
        ),
        verbose: buildRunnerYaml['verbose'] as bool? ?? false,
        dryRun: buildRunnerYaml['dry-run'] as bool? ?? false,
        command: buildRunnerYaml['command'] as String? ?? 'build',
        deleteConflicting:
            buildRunnerYaml['delete-conflicting'] as bool? ?? true,
        configName: buildRunnerYaml['config'] as String?,
        release: buildRunnerYaml['release'] as bool? ?? false,
        // Note: include/exclude builders are loaded per-project, not from root tom_build.yaml
      );
    } catch (e) {
      if (_verbose) {
        print('Error loading tom_build.yaml: $e');
      }
      return null;
    }
  }

  /// Merge this config with another, with the other taking precedence.
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

void main(List<String> arguments) async {
  // Check for version command first (before parsing)
  if (arguments.isNotEmpty &&
      (arguments[0] == 'version' ||
          arguments[0] == '-version' ||
          arguments[0] == '--version')) {
    _printVersion();
    exit(0);
  }

  final parser = ArgParser()
    ..addOption('project',
        abbr: 'p', help: 'Path to specific project to process')
    ..addOption('scan',
        abbr: 's', help: 'Directory to scan for projects with build.yaml')
    ..addFlag('recursive',
        abbr: 'r',
        defaultsTo: false,
        help: 'Process subprojects recursively')
    ..addMultiOption('exclude',
        abbr: 'e', help: 'Glob patterns for projects to exclude')
    ..addMultiOption('recursion-exclude',
        help: 'Glob patterns to exclude from recursive traversal')
    ..addOption('command',
        abbr: 'c',
        defaultsTo: 'build',
        help: 'Build runner command: build, watch, clean')
    ..addMultiOption('include-builders',
        abbr: 'i',
        help:
            'Builder patterns to include (e.g., tom_version_builder:version_builder)')
    ..addMultiOption('exclude-builders',
        abbr: 'x', help: 'Builder patterns to exclude')
    ..addOption('config',
        help: 'Use build.<name>.yaml instead of build.yaml')
    ..addFlag('release',
        defaultsTo: false, help: 'Build with release mode defaults')
    ..addFlag('delete-conflicting',
        defaultsTo: true, help: 'Delete conflicting outputs before build')
    ..addFlag('verbose',
        abbr: 'v', negatable: false, help: 'Show detailed output')
    ..addFlag('dry-run',
        abbr: 'd',
        negatable: false,
        help: 'Show what would be run without executing')
    ..addFlag('list',
        abbr: 'l',
        negatable: false,
        help: 'List projects that would be processed (no action)')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help');

  ArgResults args;
  try {
    args = parser.parse(arguments);
  } catch (e) {
    stderr.writeln('Error: $e');
    stderr.writeln('');
    _printUsage(parser);
    exit(1);
  }

  if (args['help'] as bool) {
    _printUsage(parser);
    exit(0);
  }

  // Check for unexpected arguments
  if (args.rest.isNotEmpty) {
    stderr.writeln('Error: Unknown arguments: ${args.rest.join(' ')}');
    stderr.writeln('');
    _printUsage(parser);
    exit(1);
  }

  final listOnly = args['list'] as bool;

  // Build config from CLI args
  final cliConfig = BuildRunnerConfig(
    project: args['project'] as String?,
    scan: args['scan'] as String?,
    recursive: args['recursive'] as bool,
    exclude: args['exclude'] as List<String>,
    recursionExclude: args['recursion-exclude'] as List<String>,
    verbose: args['verbose'] as bool,
    dryRun: args['dry-run'] as bool,
    command: args['command'] as String,
    deleteConflicting: args['delete-conflicting'] as bool,
    configName: args['config'] as String?,
    release: args['release'] as bool,
    cliIncludeBuilders: args['include-builders'] as List<String>,
    cliExcludeBuilders: args['exclude-builders'] as List<String>,
  );

  _verbose = cliConfig.verbose;

  // Check if any meaningful option was provided
  final hasAnyOption = cliConfig.project != null || cliConfig.scan != null;

  BuildRunnerConfig config;
  if (!hasAnyOption) {
    // Try loading from tom_build.yaml in current directory
    final yamlConfig = BuildRunnerConfig.loadFromYaml(Directory.current.path);
    if (yamlConfig != null) {
      if (cliConfig.verbose) {
        print('Using configuration from tom_build.yaml (build_runner: section)');
      }
      config = yamlConfig.merge(cliConfig);
    } else {
      // Default: process current directory
      config = BuildRunnerConfig(
        project: Directory.current.path,
        recursive: cliConfig.recursive,
        exclude: cliConfig.exclude,
        recursionExclude: cliConfig.recursionExclude,
        verbose: cliConfig.verbose,
        dryRun: cliConfig.dryRun,
        command: cliConfig.command,
        deleteConflicting: cliConfig.deleteConflicting,
        configName: cliConfig.configName,
        release: cliConfig.release,
        cliIncludeBuilders: cliConfig.cliIncludeBuilders,
        cliExcludeBuilders: cliConfig.cliExcludeBuilders,
      );
    }
  } else {
    config = cliConfig;
  }

  // Validate path containment
  final validationError = validatePathContainment(
    project: config.project,
    scan: config.scan,
    basePath: Directory.current.path,
  );
  if (validationError != null) {
    stderr.writeln('Error: $validationError');
    stderr.writeln('All paths must be within the current working directory.');
    exit(1);
  }

  // Determine projects to process
  final projects = await _findProjects(config, Directory.current.path);

  if (projects.isEmpty) {
    print('No projects found to process.');
    if (config.verbose) {
      print('Tip: Projects need a build.yaml file to be processed');
    }
    exit(0);
  }

  // Handle --list mode: just list projects without processing
  if (listOnly) {
    final workspaceRoot = ProjectDiscovery.findWorkspaceRoot(Directory.current.path);
    print('Runner projects (${projects.length}):');
    for (final project in projects) {
      final relativePath = p.relative(project, from: workspaceRoot);
      print('  $relativePath');
    }
    exit(0);
  }

  // Print header
  print('=' * 60);
  print('Build Runner - ${config.command}');
  print('=' * 60);
  print('');

  // Process projects
  final result = ProcessingResult();
  final rootPath = Directory.current.path;
  for (final projectPath in projects) {
    final displayPath = p.relative(projectPath, from: rootPath);
    print('Project: $displayPath');

    final success = await _processProject(projectPath, config, rootPath);

    if (success) {
      result.addSuccess();
    } else {
      result.addFailure();
    }
    print('');
  }

  // Summary
  print('Build Runner: Processed ${projects.length} project(s)');
  if (result.hasFailures) {
    print('  Failed: ${result.failureCount}');
    exit(1);
  }
}

void _printVersion() {
  print('Runner Tool ${TomVersionInfo.versionLong}');
}

void _printUsage(ArgParser parser) {
  print('Runner CLI - Workspace build_runner wrapper');
  print('');
  print('Usage: runner [options]');
  print('');
  print('Options:');
  print(parser.usage);
  print('');
  print('Commands:');
  print('  build   Run build_runner build (default)');
  print('  watch   Run build_runner watch');
  print('  clean   Run build_runner clean');
  print('');
  print('Configuration (in order of precedence, no merging):');
  print('  1. Command-line arguments');
  print('  2. build.yaml (tom_build_runner:build_runner section)');
  print('  3. tom_build.yaml in project directory');
  print('  4. tom_build.yaml in root directory');
  print('');
  print('Examples:');
  print('  # Run on current project');
  print('  runner');
  print('');
  print('  # Scan and run on all projects');
  print('  runner --scan=. --recursive');
  print('');
  print('  # Run only specific builders');
  print('  runner --include-builders=tom_version_builder:version_builder');
  print('');
  print('  # Exclude specific builders');
  print('  runner --exclude-builders=json_serializable:json_serializable');
  print('');
  print('  # Dry run to see what would be executed');
  print('  runner --scan=. --dry-run');
}

/// Find projects to process based on configuration.
Future<List<String>> _findProjects(
    BuildRunnerConfig config, String basePath) async {
  // Single project specified
  if (config.project != null) {
    final projectPath = p.normalize(p.join(basePath, config.project!));
    if (_isBuildRunnerProject(projectPath)) {
      return [projectPath];
    } else {
      print(
          'Warning: Specified project does not have build.yaml: ${config.project}');
      return [];
    }
  }

  // Scan directory for projects
  if (config.scan != null) {
    final scanPath = p.isAbsolute(config.scan!)
        ? config.scan!
        : p.join(basePath, config.scan!);

    final discovery = ProjectDiscovery(
      verbose: config.verbose,
    );

    final allProjects = await discovery.scanForProjects(
      scanPath,
      recursive: config.recursive,
      toolKey: _toolKey,
    );

    // Filter to only build_runner projects
    return allProjects.where((path) => _isBuildRunnerProject(path)).toList();
  }

  // Default: process current directory if it has build.yaml
  if (_isBuildRunnerProject(basePath)) {
    return [basePath];
  }

  return [];
}

/// Check if a directory is a build_runner project.
bool _isBuildRunnerProject(String dirPath) {
  // Must have pubspec.yaml
  if (!File('$dirPath/pubspec.yaml').existsSync()) {
    return false;
  }

  // Must have build.yaml
  if (!File('$dirPath/build.yaml').existsSync()) {
    return false;
  }

  return true;
}

/// Process a single project.
Future<bool> _processProject(
    String projectPath, BuildRunnerConfig config, String rootPath) async {
  // Get effective builder filter for this project
  final builderFilter = BuilderFilterConfig.getEffective(
    projectPath: projectPath,
    rootPath: rootPath,
    cliInclude: config.cliIncludeBuilders,
    cliExclude: config.cliExcludeBuilders,
  );

  // Get configured builders from the project's build.yaml
  final configuredBuilders = extractConfiguredBuilders(projectPath);
  
  if (config.verbose && configuredBuilders.isNotEmpty) {
    print('  Configured builders: ${configuredBuilders.join(', ')}');
  }
  if (config.verbose && builderFilter.isNotEmpty) {
    print('  Builder filter: $builderFilter');
  }

  // Determine which builders to actually run
  List<String> buildersToRun = configuredBuilders;
  List<String> buildersToDisable = [];

  if (builderFilter.includeBuilders.isNotEmpty) {
    // Only run builders that are in the include list AND configured
    buildersToRun = configuredBuilders
        .where((b) => builderFilter.includeBuilders.any(
            (include) => b.contains(include) || include.contains(b)))
        .toList();
    
    // Disable builders that are configured but not in the include list
    buildersToDisable = configuredBuilders
        .where((b) => !buildersToRun.contains(b))
        .toList();
    
    if (buildersToRun.isEmpty) {
      if (config.verbose) {
        print('  Skipping - no matching builders in include list');
      }
      return true; // Not a failure, just skipped
    }
  }

  if (builderFilter.excludeBuilders.isNotEmpty) {
    // Add excluded builders to disable list
    for (final exclude in builderFilter.excludeBuilders) {
      for (final builder in configuredBuilders) {
        if (builder.contains(exclude) || exclude.contains(builder)) {
          if (!buildersToDisable.contains(builder)) {
            buildersToDisable.add(builder);
          }
        }
      }
    }
    buildersToRun = buildersToRun
        .where((b) => !buildersToDisable.contains(b))
        .toList();
  }

  if (buildersToRun.isEmpty && configuredBuilders.isNotEmpty) {
    if (config.verbose) {
      print('  Skipping - all builders filtered out');
    }
    return true; // Not a failure, just skipped
  }

  // Build the command
  final args = <String>['run', 'build_runner', config.command];

  // Add delete-conflicting-outputs for build/watch
  if (config.deleteConflicting &&
      (config.command == 'build' || config.command == 'watch')) {
    args.add('--delete-conflicting-outputs');
  }

  // Add config if specified
  if (config.configName != null) {
    args.add('--config=${config.configName}');
  }

  // Add release flag
  if (config.release) {
    args.add('--release');
  }

  // Add verbose flag
  if (config.verbose) {
    args.add('--verbose');
  }

  // Disable excluded builders via --define
  for (final builder in buildersToDisable) {
    args.add('--define=$builder=enabled=false');
  }

  final commandStr = 'dart ${args.join(' ')}';
  print('  Running: $commandStr');

  if (config.dryRun) {
    print('  [DRY RUN] Would execute in: $projectPath');
    if (buildersToRun.isNotEmpty) {
      print('  Builders to run: ${buildersToRun.join(', ')}');
    }
    if (buildersToDisable.isNotEmpty) {
      print('  Builders disabled: ${buildersToDisable.join(', ')}');
    }
    return true;
  }

  // Execute build_runner
  final result = await Process.run(
    'dart',
    args,
    workingDirectory: projectPath,
    environment: Platform.environment,
  );

  if (result.exitCode != 0) {
    print('  Failed (exit code ${result.exitCode})');
    if (result.stderr.toString().isNotEmpty) {
      print('  Error: ${result.stderr}');
    }
    return false;
  }

  // Print output if verbose
  if (config.verbose && result.stdout.toString().isNotEmpty) {
    for (final line in result.stdout.toString().split('\n')) {
      if (line.trim().isNotEmpty) {
        print('  $line');
      }
    }
  }

  print('  Success');
  return true;
}
