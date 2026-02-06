#!/usr/bin/env dart
/// Build Runner CLI wrapper (build_runner)
///
/// Command-line interface for running build_runner across multiple projects
/// in a workspace with project discovery and builder filtering.
///
/// ## Configuration Sources (in order of precedence)
///
/// 1. Command-line arguments
/// 2. `tom_build.yaml` (build_runner: section) in project directory
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
/// build_runner --include=tom_version_builder:version_builder
///
/// # Exclude specific builders
/// build_runner --exclude=some_package:some_builder
///
/// # Show help
/// build_runner --help
/// ```
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';
import 'package:yaml/yaml.dart';

/// The tool key for build_runner in tom_build.yaml
const _toolKey = 'build_runner';

/// Global verbose flag
bool _verbose = false;

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
  final List<String> includeBuilders;
  final List<String> excludeBuilders;
  final bool deleteConflicting;
  final String? configName;
  final bool release;

  const BuildRunnerConfig({
    this.project,
    this.scan,
    this.recursive = false,
    this.exclude = const [],
    this.recursionExclude = const [],
    this.verbose = false,
    this.dryRun = false,
    this.command = 'build',
    this.includeBuilders = const [],
    this.excludeBuilders = const [],
    this.deleteConflicting = true,
    this.configName,
    this.release = false,
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
        includeBuilders: _toStringList(buildRunnerYaml['include']),
        excludeBuilders: _toStringList(buildRunnerYaml['exclude-builders']),
        deleteConflicting:
            buildRunnerYaml['delete-conflicting'] as bool? ?? true,
        configName: buildRunnerYaml['config'] as String?,
        release: buildRunnerYaml['release'] as bool? ?? false,
      );
    } catch (e) {
      if (_verbose) {
        print('Error loading tom_build.yaml: $e');
      }
      return null;
    }
  }

  static List<String> _toStringList(dynamic value) {
    if (value == null) return [];
    if (value is String) return [value];
    if (value is YamlList) return value.map((e) => e.toString()).toList();
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
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
      includeBuilders: other.includeBuilders.isNotEmpty
          ? other.includeBuilders
          : includeBuilders,
      excludeBuilders: other.excludeBuilders.isNotEmpty
          ? other.excludeBuilders
          : excludeBuilders,
      deleteConflicting: other.deleteConflicting && deleteConflicting,
      configName: other.configName ?? configName,
      release: other.release || release,
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
    ..addMultiOption('include',
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
    includeBuilders: args['include'] as List<String>,
    excludeBuilders: args['exclude-builders'] as List<String>,
    deleteConflicting: args['delete-conflicting'] as bool,
    configName: args['config'] as String?,
    release: args['release'] as bool,
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
        includeBuilders: cliConfig.includeBuilders,
        excludeBuilders: cliConfig.excludeBuilders,
        deleteConflicting: cliConfig.deleteConflicting,
        configName: cliConfig.configName,
        release: cliConfig.release,
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

  // Print header
  print('=' * 60);
  print('Build Runner - ${config.command}');
  print('=' * 60);
  print('');

  // Process projects
  final result = ProcessingResult();
  for (final projectPath in projects) {
    final displayPath = p.relative(projectPath, from: Directory.current.path);
    print('Project: $displayPath');

    final success = await _processProject(projectPath, config);

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
  const version = String.fromEnvironment(
    'buildRunnerToolVersion',
    defaultValue: '1.0.0+0',
  );
  const buildDate = String.fromEnvironment(
    'buildRunnerToolBuildDate',
    defaultValue: 'unknown',
  );
  const gitCommit = String.fromEnvironment(
    'buildRunnerToolGitCommit',
    defaultValue: 'unknown',
  );

  print('Build Runner Tool $version');
  print('Build date: $buildDate');
  if (gitCommit != 'unknown') {
    print('Git commit: $gitCommit');
  }
}

void _printUsage(ArgParser parser) {
  print('Build Runner CLI - Workspace build_runner wrapper');
  print('');
  print('Usage: build_runner [options]');
  print('');
  print('Options:');
  print(parser.usage);
  print('');
  print('Commands:');
  print('  build   Run build_runner build (default)');
  print('  watch   Run build_runner watch');
  print('  clean   Run build_runner clean');
  print('');
  print('Configuration:');
  print('  tom_build.yaml - CLI options (build_runner: section)');
  print('');
  print('Examples:');
  print('  # Run on current project');
  print('  build_runner');
  print('');
  print('  # Scan and run on all projects');
  print('  build_runner --scan=. --recursive');
  print('');
  print('  # Run only specific builders');
  print('  build_runner --include=tom_version_builder:version_builder');
  print('');
  print('  # Dry run to see what would be executed');
  print('  build_runner --scan=. --dry-run');
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
    final scanner = ProjectScanner(
      toolKey: _toolKey,
      basePath: basePath,
      verbose: config.verbose,
      projectValidator: _isBuildRunnerProject,
    );

    return scanner.scanForProjects(
      config.scan!,
      config.exclude,
    );
  }

  // Default: process current directory if it has build.yaml
  if (_isBuildRunnerProject(basePath)) {
    return [basePath];
  }

  return [];
}

/// Check if a directory is a build_runner project.
bool _isBuildRunnerProject(String dirPath, [String? _]) {
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
    String projectPath, BuildRunnerConfig config) async {
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

  // Builder filtering via --define
  // Note: build_runner doesn't have direct include/exclude for builders,
  // but we can disable builders by setting enabled: false via --define
  for (final builder in config.excludeBuilders) {
    args.add('--define=$builder=enabled=false');
  }

  // For include, we need a different approach - log a warning if used
  if (config.includeBuilders.isNotEmpty) {
    print(
        '  Note: --include filters are applied by checking build.yaml content');
    // We'll check if the project uses any of the included builders
    final hasIncludedBuilder = _projectHasBuilder(projectPath, config.includeBuilders);
    if (!hasIncludedBuilder) {
      if (config.verbose) {
        print('  Skipping - no matching builders in include list');
      }
      return true; // Not a failure, just skipped
    }
  }

  final commandStr = 'dart ${args.join(' ')}';
  print('  Running: $commandStr');

  if (config.dryRun) {
    print('  [DRY RUN] Would execute in: $projectPath');
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

/// Check if a project's build.yaml contains any of the specified builders.
bool _projectHasBuilder(String projectPath, List<String> builders) {
  final buildYamlPath = p.join(projectPath, 'build.yaml');
  final buildYamlFile = File(buildYamlPath);

  if (!buildYamlFile.existsSync()) return false;

  try {
    final content = buildYamlFile.readAsStringSync();
    
    // Simple check: see if any builder name appears in the file
    for (final builder in builders) {
      if (content.contains(builder)) {
        return true;
      }
    }
    return false;
  } catch (_) {
    return false;
  }
}
