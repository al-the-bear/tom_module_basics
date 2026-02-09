import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';
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
    WorkspaceNavigationArgs navArgs;
    String executionRoot;

    try {
      (results, navArgs, executionRoot) = parseArgsWithExecutionMode(parser, args);
    } on FormatException catch (e) {
      print('Error: $e');
      _printUsage(parser);
      return false;
    } on ArgumentError catch (e) {
      print('Error: $e');
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

    // Validate paths
    if (!validateAndEnforcePaths(
      scan: navArgs.scan,
      project: navArgs.project,
      basePath: executionRoot,
    )) {
      return false;
    }

    // Find projects using navigation args
    final projects = await findProjectsFromNavArgs(
      navArgs,
      basePath: executionRoot,
    );

    if (findProjectsError) return false;

    if (listMode) {
      print('Dart projects:');
      for (final project in projects) {
        if (isToolProject(project)) {
          print('  ${p.relative(project, from: executionRoot)}');
        }
      }
      return true;
    }

    if (showMode) {
      for (final projectPath in projects) {
        if (!isToolProject(projectPath)) continue;
        print('Project: ${p.relative(projectPath, from: executionRoot)}');
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
        print(p.relative(projectPath, from: executionRoot));
      }
    }

    return true;
  }

  /// Compute the build order for the given project paths.
  ///
  /// [allProjectPaths] is the full set of projects used to build the
  /// dependency graph. This must include all workspace projects so that
  /// the graph is complete and accurate.
  ///
  /// [targetProjectPaths] is an optional subset of projects to include
  /// in the returned result, in correct build order. If null, all projects
  /// from [allProjectPaths] are returned. This allows using `--project`
  /// with `--build-order` to only execute certain projects but in the
  /// correct dependency order.
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
    List<String> allProjectPaths, {
    List<String>? targetProjectPaths,
    bool includeDev = false,
  }) {
    // Parse all project infos
    final infos = <String, _ProjectInfo>{};
    final nameToPath = <String, String>{};

    for (final projectPath in allProjectPaths) {
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
      final remainingPaths = dependsOn.keys
          .where((path) => !result.contains(path))
          .toList();
      final remainingNames = remainingPaths
          .map((path) => infos[path]?.name ?? p.basename(path))
          .toList()
        ..sort();

      print('Error: Circular dependency detected!');
      print('');
      print('The following ${remainingNames.length} projects form a dependency '
          'cycle and cannot be ordered:');
      for (final name in remainingNames) {
        print('  - $name');
      }
      print('');
      print('Dependency chains in the cycle:');
      for (final path in remainingPaths) {
        final info = infos[path];
        if (info == null) continue;
        final cycleDeps = dependsOn[path]!
            .where((dep) => !result.contains(dep))
            .map((dep) => infos[dep]?.name ?? p.basename(dep))
            .toList()
          ..sort();
        if (cycleDeps.isNotEmpty) {
          print('  ${info.name} -> ${cycleDeps.join(', ')}');
        }
      }
      return null;
    }

    // Filter to target projects if specified
    if (targetProjectPaths != null) {
      final targetSet = targetProjectPaths.toSet();
      result.retainWhere(targetSet.contains);
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
