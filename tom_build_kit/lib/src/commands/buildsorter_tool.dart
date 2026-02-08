import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'tool_base.dart';

/// Information about a workspace project for build ordering.
class _ProjectInfo {
  final String path;
  final String name;
  final Set<String> dependencies;
  final Set<String> devDependencies;

  _ProjectInfo({
    required this.path,
    required this.name,
    required this.dependencies,
    required this.devDependencies,
  });
}

/// Build sorter tool — calculates the correct build order for workspace
/// projects based on inter-project dependencies.
///
/// Uses topological sorting. Projects with no dependencies on other workspace
/// projects come first. Projects with equal dependency depth are sorted
/// alphabetically.
///
/// The result can be used by buildkit's `--build-order` option to process
/// projects in the correct compilation order.
class BuildSorterTool extends ToolBase {
  @override
  String get toolKey => 'buildsorter';

  @override
  String get toolDescription =>
      'Calculate build order from inter-project dependencies';

  @override
  void addToolOptions(ArgParser parser) {
    parser
      ..addFlag('reverse',
          negatable: false,
          help: 'Reverse the build order (dependents first)')
      ..addFlag('names',
          negatable: false, help: 'Print package names instead of paths')
      ..addFlag('include-dev',
          negatable: false,
          help: 'Include dev_dependencies in build order calculation');
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
    final reverseOrder = results['reverse'] as bool;
    final showNames = results['names'] as bool;
    final includeDev = results['include-dev'] as bool;

    final basePath = Directory.current.path;

    // Validate paths
    if (!validateAndEnforcePaths(
      scan: results['scan'] as String?,
      project: results['project'] as String?,
      basePath: basePath,
    )) {
      return false;
    }

    // Find projects
    final projects = await findProjects(
      project: results['project'] as String?,
      scan: results['scan'] as String?,
      recursive: results['recursive'] as bool,
      exclude: results['exclude'] as List<String>,
      excludeProjects: results['exclude-projects'] as List<String>,
      recursionExclude: results['recursion-exclude'] as List<String>,
      basePath: basePath,
    );

    if (findProjectsError) return false;

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
        if (!isToolProject(projectPath)) continue;
        print('Project: ${p.relative(projectPath, from: basePath)}');
        final info = _parseProjectInfo(projectPath);
        if (info != null) {
          print('  Name: ${info.name}');
          print('  Dependencies: ${info.dependencies.join(', ')}');
        }
      }
      return true;
    }

    // Compute build order
    final sorted = computeBuildOrder(projects, includeDev: includeDev);
    if (sorted == null) return false;

    final ordered = reverseOrder ? sorted.reversed.toList() : sorted;

    for (final projectPath in ordered) {
      if (showNames) {
        final info = _parseProjectInfo(projectPath);
        print(info?.name ?? p.basename(projectPath));
      } else {
        print(p.relative(projectPath, from: basePath));
      }
    }

    return true;
  }

  /// Compute the build order for the given project paths.
  ///
  /// Returns a list of project paths sorted in dependency order
  /// (projects with no intra-workspace dependencies first).
  /// Returns null if a circular dependency is detected.
  ///
  /// By default only regular dependencies are considered. Set [includeDev]
  /// to true to also consider dev_dependencies.
  ///
  /// This method is public so buildkit can reuse it.
  List<String>? computeBuildOrder(
    List<String> projectPaths, {
    bool includeDev = false,
  }) {
    // Parse all project infos
    final infos = <String, _ProjectInfo>{};
    final nameToPath = <String, String>{};

    for (final projectPath in projectPaths) {
      final info = _parseProjectInfo(projectPath);
      if (info == null) continue;
      infos[projectPath] = info;
      nameToPath[info.name] = projectPath;
    }

    // Build set of workspace package names for filtering
    final workspaceNames = nameToPath.keys.toSet();

    // Build adjacency: project → set of workspace projects it depends on
    final dependsOn = <String, Set<String>>{}; // path → set of dep paths
    for (final entry in infos.entries) {
      final path = entry.key;
      final info = entry.value;
      final deps = <String>{};
      // Always include regular dependencies
      for (final depName in info.dependencies) {
        if (workspaceNames.contains(depName)) {
          final depPath = nameToPath[depName]!;
          if (depPath != path) deps.add(depPath);
        }
      }
      // Optionally include dev dependencies
      if (includeDev) {
        for (final depName in info.devDependencies) {
          if (workspaceNames.contains(depName)) {
            final depPath = nameToPath[depName]!;
            if (depPath != path) deps.add(depPath);
          }
        }
      }
      dependsOn[path] = deps;
    }

    // Kahn's algorithm for topological sort with alphabetic tie-breaking
    // Compute in-degrees
    final inDegree = <String, int>{};
    for (final path in dependsOn.keys) {
      inDegree.putIfAbsent(path, () => 0);
      for (final dep in dependsOn[path]!) {
        inDegree[dep] = (inDegree[dep] ?? 0);
        // dep is depended upon by path — but in-degree is for path's deps
      }
    }

    // In-degree: how many workspace projects depend on THIS project being
    // built first? Actually, for topological sort, in-degree = number of
    // dependencies this project has on other workspace projects.
    // We want: projects with 0 deps first.
    for (final entry in dependsOn.entries) {
      inDegree[entry.key] = entry.value.length;
    }

    // Also include projects that have no entry in dependsOn (no pubspec)
    // but were in the project list — skip them, they won't appear.

    // Initialize queue with all zero-degree nodes, sorted alphabetically
    final queue = <String>[];
    for (final path in inDegree.keys) {
      if (inDegree[path] == 0) queue.add(path);
    }
    queue.sort((a, b) => p.basename(a).compareTo(p.basename(b)));

    final result = <String>[];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      result.add(current);

      // For each project that depends on current, decrement in-degree
      for (final entry in dependsOn.entries) {
        if (entry.value.contains(current)) {
          inDegree[entry.key] = inDegree[entry.key]! - 1;
          if (inDegree[entry.key] == 0) {
            // Insert in sorted position
            final insertName = p.basename(entry.key);
            var inserted = false;
            for (var i = 0; i < queue.length; i++) {
              if (p.basename(queue[i]).compareTo(insertName) > 0) {
                queue.insert(i, entry.key);
                inserted = true;
                break;
              }
            }
            if (!inserted) queue.add(entry.key);
          }
        }
      }
    }

    // Check for circular dependencies
    if (result.length < dependsOn.length) {
      final remaining = dependsOn.keys
          .where((p) => !result.contains(p))
          .map((p2) => '  ${infos[p2]?.name ?? p.basename(p2)}')
          .toList()
        ..sort();
      print('Error: Circular dependency detected among:');
      for (final name in remaining) {
        print(name);
      }
      return null;
    }

    return result;
  }

  /// Parse a project's pubspec.yaml for name and dependencies.
  _ProjectInfo? _parseProjectInfo(String projectPath) {
    final pubspecFile = File('$projectPath/pubspec.yaml');
    if (!pubspecFile.existsSync()) return null;

    try {
      final content = pubspecFile.readAsStringSync();
      final pubspec = loadYaml(content) as YamlMap;
      final name = pubspec['name'] as String? ?? p.basename(projectPath);

      final deps = <String>{};
      final devDeps = <String>{};

      // Collect regular dependency names
      final depsMap = pubspec['dependencies'] as YamlMap?;
      if (depsMap != null) {
        for (final key in depsMap.keys) {
          deps.add(key.toString());
        }
      }
      // Collect dev dependency names separately
      final devDepsMap = pubspec['dev_dependencies'] as YamlMap?;
      if (devDepsMap != null) {
        for (final key in devDepsMap.keys) {
          devDeps.add(key.toString());
        }
      }

      return _ProjectInfo(
        path: projectPath,
        name: name,
        dependencies: deps,
        devDependencies: devDeps,
      );
    } catch (e) {
      if (verbose) print('  Warning: Error parsing pubspec.yaml in $projectPath: $e');
      return null;
    }
  }

  void _printUsage(ArgParser parser) {
    print('Build Sorter - $toolDescription');
    print('');
    print('Usage: buildsorter [options]');
    print('       buildkit :buildsorter [options]');
    print('       dart run tom_build_kit:buildsorter [options]');
    print('       buildsorter version');
    print('');
    print('Options:');
    print(parser.usage);
    print('');
    print('Output: Projects sorted in build order (dependencies first).');
    print('Projects at the same dependency level are sorted alphabetically.');
    print('');
    print('Examples:');
    print('  buildsorter                        # Build order for workspace');
    print('  buildsorter --reverse              # Reverse order (dependents first)');
    print('  buildsorter --names                # Print package names');
    print('  buildsorter -v                     # Verbose with dependency info');
  }
}
