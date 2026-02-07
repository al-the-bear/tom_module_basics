#!/usr/bin/env dart
/// Dependency Tree CLI (dependencies)
///
/// Command-line interface for visualizing Dart project dependency trees.
/// Shows dependencies from pubspec.yaml with overrides from pubspec_overrides.yaml.
///
/// ## Usage
///
/// ```bash
/// # Show dependencies for current project
/// dependencies
///
/// # Show only dev dependencies
/// dependencies --dev
///
/// # Show all dependencies (normal + dev)
/// dependencies --all
///
/// # Show full dependency tree (recursive)
/// dependencies --deep
///
/// # Process specific project
/// dependencies --project=my_app
///
/// # Show help
/// dependencies --help
/// ```
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';
import 'package:tom_dependencies_tool/src/version.g.dart';
import 'package:yaml/yaml.dart';

/// Dependency type
enum DependencyType {
  normal,
  dev,
}

/// Represents a single dependency with its source information
class Dependency {
  final String name;
  final DependencyType type;
  final String source; // version, path, git, etc.
  final String? override; // override source if present

  const Dependency({
    required this.name,
    required this.type,
    required this.source,
    this.override,
  });

  /// Format the dependency source for display
  String get displaySource {
    if (override != null) {
      return '$source [$override]';
    }
    return source;
  }

  /// Get the prefix based on dependency type
  String get prefix => type == DependencyType.dev ? '+>' : '->';
}

/// Parsed dependency information from pubspec files
class ProjectDependencies {
  final String projectPath;
  final String projectName;
  final List<Dependency> dependencies;

  const ProjectDependencies({
    required this.projectPath,
    required this.projectName,
    required this.dependencies,
  });
}

/// Configuration for the dependencies CLI
class DependenciesConfig {
  final String? project;
  final String? scan;
  final bool recursive;
  final List<String> exclude;
  final List<String> recursionExclude;
  final bool verbose;

  // Dependencies-specific options
  final bool showDev; // Show only dev dependencies
  final bool showAll; // Show both normal and dev dependencies
  final bool deep; // Recursively show dependency tree

  const DependenciesConfig({
    this.project,
    this.scan,
    this.recursive = false,
    this.exclude = const [],
    this.recursionExclude = const [],
    this.verbose = false,
    this.showDev = false,
    this.showAll = false,
    this.deep = false,
  });
}

/// Global verbose flag
bool _verbose = false;

void main(List<String> arguments) async {
  // Check for version command first
  if (arguments.isNotEmpty &&
      (arguments[0] == 'version' ||
          arguments[0] == '-version' ||
          arguments[0] == '--version')) {
    _printVersion();
    exit(0);
  }

  final parser = ArgParser()
    ..addOption('project',
        abbr: 'p',
        help:
            'Project(s) to analyze (comma-separated, globs: tom_*_builder, ./*)')
    ..addOption('scan', abbr: 's', help: 'Directory to scan for projects')
    ..addFlag('recursive',
        abbr: 'r',
        help: 'Process subprojects recursively',
        negatable: false)
    ..addMultiOption('exclude',
        abbr: 'e', help: 'Glob patterns for projects to exclude')
    ..addMultiOption('recursion-exclude',
        help: 'Glob patterns to exclude from recursive traversal')
    ..addFlag('dev',
        abbr: 'd',
        help: 'Show only dev dependencies',
        negatable: false)
    ..addFlag('all',
        abbr: 'a',
        help: 'Show both normal and dev dependencies',
        negatable: false)
    ..addFlag('deep',
        abbr: 'D', help: 'Show full dependency tree (recursive)', negatable: false)
    ..addFlag('verbose',
        abbr: 'v', help: 'Show detailed output', negatable: false)
    ..addFlag('list',
        abbr: 'l',
        help: 'List projects that would be processed (no action)',
        negatable: false)
    ..addFlag('help', abbr: 'h', help: 'Show this help message', negatable: false);

  final ArgResults args;
  try {
    args = parser.parse(arguments);

    // Check for unexpected arguments
    if (args.rest.isNotEmpty) {
      stderr.writeln('Error: Unknown arguments: ${args.rest.join(' ')}');
      stderr.writeln('');
      _printUsage(parser);
      exit(1);
    }
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

  final listOnly = args['list'] as bool;

  // Build config from CLI args
  final config = DependenciesConfig(
    project: args['project'] as String?,
    scan: args['scan'] as String?,
    recursive: args['recursive'] as bool,
    exclude: args['exclude'] as List<String>,
    recursionExclude: args['recursion-exclude'] as List<String>,
    verbose: args['verbose'] as bool,
    showDev: args['dev'] as bool,
    showAll: args['all'] as bool,
    deep: args['deep'] as bool,
  );

  _verbose = config.verbose;

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
    print('Nothing to do.');
    print('');
    _printUsage(parser);
    exit(0);
  }

  // Handle --list mode
  if (listOnly) {
    final workspaceRoot =
        ProjectDiscovery.findWorkspaceRoot(Directory.current.path);
    print('Dependencies projects (${projects.length}):');
    for (final project in projects) {
      final relativePath = p.relative(project, from: workspaceRoot);
      print('  $relativePath');
    }
    exit(0);
  }

  // Process projects
  for (final projectPath in projects) {
    await _processProject(projectPath, config);
  }
}

/// Find projects to process based on configuration.
Future<List<String>> _findProjects(
    DependenciesConfig config, String basePath) async {
  final discovery = ProjectDiscovery(verbose: config.verbose);

  // Project pattern(s) specified
  if (config.project != null) {
    return discovery.resolveProjectPatterns(
      config.project!,
      basePath: basePath,
      projectFilter: _isDartProject,
    );
  }

  // Scan directory for projects
  if (config.scan != null) {
    final scanPath = p.isAbsolute(config.scan!)
        ? config.scan!
        : p.join(basePath, config.scan!);

    return await discovery.scanForProjects(
      scanPath,
      recursive: config.recursive,
      // No toolKey needed - we just need pubspec.yaml
    );
  }

  // Default: process current directory if it's a Dart project
  if (_isDartProject(basePath)) {
    return [basePath];
  }

  return [];
}

/// Check if a directory is a Dart project (has pubspec.yaml)
bool _isDartProject(String dirPath) {
  return File(p.join(dirPath, 'pubspec.yaml')).existsSync();
}

/// Process a single project
Future<void> _processProject(String projectPath, DependenciesConfig config) async {
  final deps = _parseDependencies(projectPath);
  if (deps == null) {
    if (_verbose) {
      print('Warning: Could not parse pubspec.yaml in $projectPath');
    }
    return;
  }

  // Filter dependencies based on config
  var filteredDeps = deps.dependencies.where((d) {
    if (config.showAll) return true;
    if (config.showDev) return d.type == DependencyType.dev;
    return d.type == DependencyType.normal;
  }).toList();

  // Sort: first by type (normal before dev), then by name
  filteredDeps.sort((a, b) {
    final typeCompare = a.type.index.compareTo(b.type.index);
    if (typeCompare != 0) return typeCompare;
    return a.name.compareTo(b.name);
  });

  // Print project header
  print('${deps.projectName}:');

  if (filteredDeps.isEmpty) {
    print('   (no dependencies)');
    return;
  }

  if (config.deep) {
    // Deep mode: show full dependency tree
    final visited = <String>{deps.projectName};
    for (final dep in filteredDeps) {
      _printDependencyTree(dep, config, visited, indent: 1);
    }
  } else {
    // Shallow mode: show only direct dependencies
    for (final dep in filteredDeps) {
      print('   ${dep.prefix} ${dep.name}: ${dep.displaySource}');
    }
  }

  print('');
}

/// Print a dependency and its transitive dependencies (deep mode)
void _printDependencyTree(
  Dependency dep,
  DependenciesConfig config,
  Set<String> visited, {
  int indent = 1,
}) {
  final indentStr = '   ' * indent;
  final source = dep.displaySource;

  // Check for circular dependency
  if (visited.contains(dep.name)) {
    print('$indentStr${dep.prefix} ${dep.name}: ... (circular)');
    return;
  }

  print('$indentStr${dep.prefix} ${dep.name}: $source');

  // Try to resolve the dependency's own dependencies
  final depPath = _resolveDependencyPath(dep);
  if (depPath == null) {
    // Can't resolve - it's a pub package, show version only
    return;
  }

  final depDeps = _parseDependencies(depPath);
  if (depDeps == null) return;

  // Add to visited set for circular detection
  final newVisited = {...visited, dep.name};

  // Filter and sort sub-dependencies
  var subDeps = depDeps.dependencies.where((d) {
    if (config.showAll) return true;
    if (config.showDev) return d.type == DependencyType.dev;
    return d.type == DependencyType.normal;
  }).toList();

  subDeps.sort((a, b) {
    final typeCompare = a.type.index.compareTo(b.type.index);
    if (typeCompare != 0) return typeCompare;
    return a.name.compareTo(b.name);
  });

  // Recursively print sub-dependencies
  for (final subDep in subDeps) {
    _printDependencyTree(subDep, config, newVisited, indent: indent + 1);
  }
}

/// Try to resolve the path to a dependency's source
String? _resolveDependencyPath(Dependency dep) {
  // Check if it's a path dependency
  final source = dep.override ?? dep.source;
  if (source.startsWith('path: ')) {
    final pathValue = source.substring(6).trim();
    // Resolve relative to current directory
    final resolved = p.normalize(p.join(Directory.current.path, pathValue));
    if (Directory(resolved).existsSync()) {
      return resolved;
    }
  }

  // For other dependency types (version, git, etc.), we can't easily resolve
  // In a more complete implementation, we could look in .dart_tool/package_config.json
  return null;
}

/// Parse dependencies from pubspec.yaml and pubspec_overrides.yaml
ProjectDependencies? _parseDependencies(String projectPath) {
  final pubspecPath = p.join(projectPath, 'pubspec.yaml');
  final pubspecFile = File(pubspecPath);

  if (!pubspecFile.existsSync()) {
    return null;
  }

  try {
    final pubspecContent = pubspecFile.readAsStringSync();
    final pubspec = loadYaml(pubspecContent) as YamlMap?;
    if (pubspec == null) return null;

    final projectName = pubspec['name'] as String? ?? p.basename(projectPath);

    // Load overrides if they exist
    final overridesPath = p.join(projectPath, 'pubspec_overrides.yaml');
    final overridesFile = File(overridesPath);
    YamlMap? overrides;
    if (overridesFile.existsSync()) {
      try {
        final overridesContent = overridesFile.readAsStringSync();
        overrides = loadYaml(overridesContent) as YamlMap?;
      } catch (_) {
        // Ignore override parsing errors
      }
    }

    final dependencies = <Dependency>[];

    // Parse normal dependencies
    final deps = pubspec['dependencies'] as YamlMap?;
    if (deps != null) {
      for (final entry in deps.entries) {
        final name = entry.key as String;
        final value = entry.value;
        final source = _formatDependencySource(value);
        final override = _getOverride(name, overrides);
        dependencies.add(Dependency(
          name: name,
          type: DependencyType.normal,
          source: source,
          override: override,
        ));
      }
    }

    // Parse dev dependencies
    final devDeps = pubspec['dev_dependencies'] as YamlMap?;
    if (devDeps != null) {
      for (final entry in devDeps.entries) {
        final name = entry.key as String;
        final value = entry.value;
        final source = _formatDependencySource(value);
        final override = _getOverride(name, overrides);
        dependencies.add(Dependency(
          name: name,
          type: DependencyType.dev,
          source: source,
          override: override,
        ));
      }
    }

    return ProjectDependencies(
      projectPath: projectPath,
      projectName: projectName,
      dependencies: dependencies,
    );
  } catch (e) {
    if (_verbose) {
      print('Error parsing pubspec.yaml: $e');
    }
    return null;
  }
}

/// Format a dependency source for display
String _formatDependencySource(dynamic value) {
  if (value == null) {
    return 'any';
  }

  if (value is String) {
    return value; // Version constraint
  }

  if (value is YamlMap) {
    // Path dependency
    if (value.containsKey('path')) {
      return 'path: ${value['path']}';
    }

    // Git dependency
    if (value.containsKey('git')) {
      final git = value['git'];
      if (git is String) {
        return 'git: $git';
      }
      if (git is YamlMap) {
        final url = git['url'] ?? '';
        final ref = git['ref'];
        final path = git['path'];
        var result = 'git: $url';
        if (ref != null) result += ' @$ref';
        if (path != null) result += ' ($path)';
        return result;
      }
    }

    // Hosted dependency with version
    if (value.containsKey('version')) {
      final version = value['version'];
      final hosted = value['hosted'];
      if (hosted != null) {
        return '$version (hosted: $hosted)';
      }
      return version.toString();
    }

    // SDK dependency
    if (value.containsKey('sdk')) {
      return 'sdk: ${value['sdk']}';
    }
  }

  return value.toString();
}

/// Get override source for a dependency if it exists
String? _getOverride(String name, YamlMap? overrides) {
  if (overrides == null) return null;

  // Check dependency_overrides section
  final depOverrides = overrides['dependency_overrides'] as YamlMap?;
  if (depOverrides != null && depOverrides.containsKey(name)) {
    return _formatDependencySource(depOverrides[name]);
  }

  return null;
}

void _printVersion() {
  print('Dependencies Tool ${TomVersionInfo.versionLong}');
}

void _printUsage(ArgParser parser) {
  print('Dependency Tree CLI (dependencies)');
  print('');
  print('Usage: dependencies [options]');
  print('');
  print('Options:');
  print(parser.usage);
  print('');
  print('Output format:');
  print('  -> dependency: source      Normal dependency');
  print('  +> dependency: source      Dev dependency');
  print('  source [override]          Shows override in brackets');
  print('  ... (circular)             Circular dependency detected');
  print('');
  print('Examples:');
  print('  # Show dependencies for current project');
  print('  dependencies');
  print('');
  print('  # Show only dev dependencies');
  print('  dependencies --dev');
  print('');
  print('  # Show all dependencies (normal + dev)');
  print('  dependencies --all');
  print('');
  print('  # Show full dependency tree');
  print('  dependencies --deep');
  print('');
  print('  # Analyze multiple projects');
  print('  dependencies --project=\'tom_*\'');
  print('');
  print('  # Scan workspace recursively');
  print('  dependencies --scan=. --recursive');
}
