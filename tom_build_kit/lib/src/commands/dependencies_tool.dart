import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'tool_base.dart';

/// Represents a dependency type.
enum DependencyType { normal, dev }

/// A single dependency entry.
class Dependency {
  final String name;
  final DependencyType type;
  final String source;
  final String? override;

  Dependency({
    required this.name,
    required this.type,
    required this.source,
    this.override,
  });

  /// Display source with [override] annotation if present.
  String get displaySource =>
      override != null ? '$source [override: $override]' : source;

  /// Prefix character for display.
  String get prefix => type == DependencyType.dev ? '+>' : '->';
}

/// Parsed dependencies for a project.
class ProjectDependencies {
  final String projectPath;
  final String projectName;
  final List<Dependency> dependencies;

  ProjectDependencies({
    required this.projectPath,
    required this.projectName,
    required this.dependencies,
  });
}

/// Configuration for the dependencies tool.
class DependenciesConfig {
  final String? project;
  final String? scan;
  final bool recursive;
  final List<String> exclude;
  final List<String> recursionExclude;
  final bool verbose;
  final bool showDev;
  final bool showAll;
  final bool deep;

  DependenciesConfig({
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

/// Dependencies tool - dependency tree visualization for Dart projects.
///
/// Shows direct dependencies, dev dependencies, path/git sources,
/// and can recursively resolve the full dependency tree.
class DependenciesTool extends ToolBase {
  @override
  String get toolKey => 'dependencies';

  @override
  String get toolDescription =>
      'Dependency tree visualization for Dart projects';

  @override
  void addToolOptions(ArgParser parser) {
    parser
      ..addFlag('dev',
          abbr: 'd', negatable: false, help: 'Show only dev dependencies')
      ..addFlag('all',
          abbr: 'a', negatable: false, help: 'Show all dependency types')
      ..addFlag('deep',
          abbr: 'D',
          negatable: false,
          help: 'Show recursive dependency tree');
  }

  @override
  bool isToolProject(String dirPath) {
    return File('$dirPath/pubspec.yaml').existsSync();
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

    final config = DependenciesConfig(
      project: results['project'] as String?,
      scan: results['scan'] as String?,
      recursive: results['recursive'] as bool,
      exclude: results['exclude'] as List<String>,
      recursionExclude: results['recursion-exclude'] as List<String>,
      verbose: verbose,
      showDev: results['dev'] as bool,
      showAll: results['all'] as bool,
      deep: results['deep'] as bool,
    );

    final basePath = Directory.current.path;

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
      print('Dart projects:');
      for (final project in projects) {
        if (isToolProject(project)) {
          print('  ${p.relative(project, from: basePath)}');
        }
      }
      return true;
    }

    if (showMode) {
      for (final projectPath in projects) {
        print('Project: ${p.relative(projectPath, from: basePath)}');
        print('  Tool: $toolKey');
        print('  Has pubspec.yaml: ${File('$projectPath/pubspec.yaml').existsSync()}');
        print('  Has pubspec_overrides.yaml: ${File('$projectPath/pubspec_overrides.yaml').existsSync()}');
      }
      return true;
    }

    // Process each project
    var success = true;
    for (final projectPath in projects) {
      if (!processProject(projectPath, config)) {
        success = false;
      }
    }

    return success;
  }

  /// Process a single project: parse and display dependencies.
  bool processProject(String projectPath, DependenciesConfig config) {
    final deps = _parseDependencies(projectPath);
    if (deps == null) {
      print('  Error: Could not parse dependencies for $projectPath');
      return false;
    }

    // Filter dependencies
    List<Dependency> filteredDeps;
    if (config.showAll) {
      filteredDeps = deps.dependencies;
    } else if (config.showDev) {
      filteredDeps = deps.dependencies
          .where((d) => d.type == DependencyType.dev)
          .toList();
    } else {
      filteredDeps = deps.dependencies
          .where((d) => d.type == DependencyType.normal)
          .toList();
    }

    // Sort: type first (normal before dev), then alphabetically
    filteredDeps.sort((a, b) {
      final typeCompare = a.type.index.compareTo(b.type.index);
      if (typeCompare != 0) return typeCompare;
      return a.name.compareTo(b.name);
    });

    // Print header
    print('${deps.projectName} (${p.basename(projectPath)}):');

    if (filteredDeps.isEmpty) {
      print('  (no dependencies)');
      return true;
    }

    if (config.deep) {
      // Deep tree mode - start visited set with project name to prevent self-references
      final visited = <String>{deps.projectName};
      for (final dep in filteredDeps) {
        _printDependencyTree(dep, config, visited);
      }
    } else {
      // Flat list
      for (final dep in filteredDeps) {
        print('  ${dep.prefix} ${dep.name}: ${dep.displaySource}');
      }
    }

    print('');
    return true;
  }

  /// Print a dependency tree recursively.
  void _printDependencyTree(
    Dependency dep,
    DependenciesConfig config,
    Set<String> visited, {
    int indent = 1,
  }) {
    final prefix = '  ' * indent;
    final circular = visited.contains(dep.name);
    final marker = circular ? ' (circular)' : '';

    print('$prefix${dep.prefix} ${dep.name}: ${dep.displaySource}$marker');

    if (circular) return;
    visited.add(dep.name);

    // Try to resolve path dependency for sub-tree
    final depPath = _resolveDependencyPath(dep);
    if (depPath != null) {
      final subDeps = _parseDependencies(depPath);
      if (subDeps != null) {
        // Filter and sort sub-dependencies
        final filteredSubDeps = subDeps.dependencies.where((subDep) {
          return config.showAll ||
              (config.showDev && subDep.type == DependencyType.dev) ||
              (!config.showDev && subDep.type == DependencyType.normal);
        }).toList();
        filteredSubDeps.sort((a, b) {
          final typeCompare = a.type.index.compareTo(b.type.index);
          if (typeCompare != 0) return typeCompare;
          return a.name.compareTo(b.name);
        });
        for (final subDep in filteredSubDeps) {
          _printDependencyTree(subDep, config, visited,
              indent: indent + 1);
        }
      }
    }

    visited.remove(dep.name);
  }

  /// Resolve a path dependency to its absolute directory path.
  String? _resolveDependencyPath(Dependency dep) {
    // Check override first, then source
    final source = dep.override ?? dep.source;
    // Only path dependencies can be resolved
    if (!source.startsWith('path: ') && !source.startsWith('path:')) return null;
    final pathStr = source.startsWith('path: ')
        ? source.substring(6).trim()
        : source.substring(5).trim();
    if (p.isAbsolute(pathStr)) return pathStr;
    // Resolve relative paths against current working directory
    final resolved = p.normalize(p.join(Directory.current.path, pathStr));
    if (Directory(resolved).existsSync()) return resolved;
    return null;
  }

  /// Parse dependencies from a project's pubspec.yaml.
  ProjectDependencies? _parseDependencies(String projectPath) {
    final pubspecFile = File('$projectPath/pubspec.yaml');
    if (!pubspecFile.existsSync()) return null;

    try {
      final content = pubspecFile.readAsStringSync();
      final pubspec = loadYaml(content) as YamlMap;
      final name = pubspec['name'] as String? ?? p.basename(projectPath);

      final deps = <Dependency>[];

      // Parse overrides
      Map<String, dynamic>? overrides;
      final overridesFile = File('$projectPath/pubspec_overrides.yaml');
      if (overridesFile.existsSync()) {
        try {
          final overridesContent = overridesFile.readAsStringSync();
          final overridesYaml = loadYaml(overridesContent) as YamlMap?;
          final depOverrides =
              overridesYaml?['dependency_overrides'] as YamlMap?;
          if (depOverrides != null) {
            overrides = {};
            for (final entry in depOverrides.entries) {
              overrides[entry.key.toString()] = entry.value;
            }
          }
        } catch (_) {}
      }

      // Also check pubspec.yaml for dependency_overrides
      final pubspecOverrides =
          pubspec['dependency_overrides'] as YamlMap?;

      // Parse normal dependencies
      final depsMap = pubspec['dependencies'] as YamlMap?;
      if (depsMap != null) {
        for (final entry in depsMap.entries) {
          final depName = entry.key.toString();
          deps.add(Dependency(
            name: depName,
            type: DependencyType.normal,
            source: _formatDependencySource(entry.value),
            override: _getOverride(depName, overrides, pubspecOverrides),
          ));
        }
      }

      // Parse dev dependencies
      final devDepsMap = pubspec['dev_dependencies'] as YamlMap?;
      if (devDepsMap != null) {
        for (final entry in devDepsMap.entries) {
          final depName = entry.key.toString();
          deps.add(Dependency(
            name: depName,
            type: DependencyType.dev,
            source: _formatDependencySource(entry.value),
            override: _getOverride(depName, overrides, pubspecOverrides),
          ));
        }
      }

      return ProjectDependencies(
        projectPath: projectPath,
        projectName: name,
        dependencies: deps,
      );
    } catch (e) {
      if (verbose) print('  Warning: Error parsing pubspec.yaml: $e');
      return null;
    }
  }

  /// Format a dependency source value for display.
  String _formatDependencySource(dynamic value) {
    if (value == null) return 'any';
    if (value is String) return value;
    if (value is Map) {
      if (value.containsKey('path')) return 'path: ${value['path']}';
      if (value.containsKey('git')) {
        final git = value['git'];
        if (git is String) return 'git: $git';
        if (git is Map) {
          final url = git['url'] ?? '';
          final ref = git['ref'] ?? '';
          final path = git['path'] ?? '';
          var result = 'git: $url';
          if (ref.toString().isNotEmpty) result += ' @$ref';
          if (path.toString().isNotEmpty) result += ' ($path)';
          return result;
        }
      }
      if (value.containsKey('version')) {
        final ver = value['version'];
        if (value.containsKey('hosted')) return '$ver (hosted: ${value['hosted']})';
        return ver.toString();
      }
      if (value.containsKey('hosted')) return 'hosted: ${value['hosted']}';
      if (value.containsKey('sdk')) return 'sdk: ${value['sdk']}';
    }
    return value.toString();
  }

  /// Get override value for a dependency.
  String? _getOverride(
    String name,
    Map<String, dynamic>? fileOverrides,
    YamlMap? pubspecOverrides,
  ) {
    // Check pubspec_overrides.yaml first
    if (fileOverrides != null && fileOverrides.containsKey(name)) {
      return _formatDependencySource(fileOverrides[name]);
    }
    // Check pubspec.yaml dependency_overrides
    if (pubspecOverrides != null && pubspecOverrides.containsKey(name)) {
      return _formatDependencySource(pubspecOverrides[name]);
    }
    return null;
  }

  void _printUsage(ArgParser parser) {
    print('Dependencies Tool - $toolDescription');
    print('');
    print('Usage: dependencies [options]');
    print('       buildkit :dependencies [options]');
    print('       dart run tom_build_kit:dependencies [options]');
    print('       dependencies version');
    print('');
    print('Options:');
    print(parser.usage);
    print('');
    print('Legend:');
    print('  ->  normal dependency');
    print('  +>  dev dependency');
    print('  [override: ...]  dependency_overrides from pubspec or pubspec_overrides.yaml');
    print('  (circular)       circular dependency detected in --deep mode');
    print('');
    print('Source formats:');
    print('  ^1.0.0           version constraint');
    print('  any              no version constraint');
    print('  path: ../pkg     path dependency');
    print('  git: url @ref    git dependency with optional ref and path');
    print('  sdk: flutter     SDK dependency');
    print('');
    print('Examples:');
    print('  dependencies                      # Show normal deps in current project');
    print('  dependencies --all                # Show all deps (normal + dev)');
    print('  dependencies --deep               # Recursive dependency tree');
    print('  dependencies -s . -R              # All projects recursively');
  }
}
