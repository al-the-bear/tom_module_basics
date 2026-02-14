/// Native v2 executor for the buildsorter command.
///
/// Calculates correct build order for workspace projects using
/// topological sort (Kahn's algorithm) based on inter-project dependencies.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base_v2.dart';
import 'package:yaml/yaml.dart';

/// Native v2 executor for the `:buildsorter` command.
///
/// Uses `requiresTraversal: false` because it needs all project info
/// collected before running the topological sort.
class BuildSorterExecutor extends CommandExecutor {
  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return ItemResult.failure(
      path: context.path,
      name: context.name,
      error: ':buildsorter uses executeWithoutTraversal',
    );
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    final cmdOpts = _getCmdOpts(args);
    final reverse = cmdOpts['reverse'] == true;
    final showNames = cmdOpts['names'] == true;
    final includeDev = cmdOpts['include-dev'] == true;

    final executionRoot = args.root ?? Directory.current.path;
    final traversalInfo =
        args.toProjectTraversalInfo(executionRoot: executionRoot);

    // Collect all project paths
    final projectPaths = <String>[];
    await BuildBase.traverse(
      info: traversalInfo,
      run: (context) async {
        if (File('${context.path}/pubspec.yaml').existsSync()) {
          projectPaths.add(context.path);
        }
        return true;
      },
    );

    if (projectPaths.isEmpty) {
      print('No projects found.');
      return const ToolResult.success();
    }

    // Compute build order
    final sorted = computeBuildOrder(
      projectPaths,
      includeDev: includeDev,
      basePath: executionRoot,
    );

    if (sorted == null) {
      return const ToolResult.failure('Circular dependency detected');
    }

    final ordered = reverse ? sorted.reversed.toList() : sorted;

    print('');
    print('Build order (${reverse ? "reverse" : "dependency-first"}):');
    for (var i = 0; i < ordered.length; i++) {
      final path = ordered[i];
      if (showNames) {
        final name = _getProjectName(path);
        print('  ${i + 1}. $name');
      } else {
        print('  ${i + 1}. ${p.relative(path, from: executionRoot)}');
      }
    }

    return const ToolResult.success();
  }

  Map<String, dynamic> _getCmdOpts(CliArgs args) {
    for (final cmd in args.commands) {
      if (cmd == 'buildsorter' || cmd == 'sort') {
        final cmdArgs = args.commandArgs[cmd];
        if (cmdArgs != null) return cmdArgs.options;
      }
    }
    return args.extraOptions;
  }

  /// Compute build order using Kahn's algorithm (topological sort).
  ///
  /// Returns sorted list of project paths (dependencies first), or null
  /// if a circular dependency is detected.
  ///
  /// This method is public and reused by other parts of buildkit.
  static List<String>? computeBuildOrder(
    List<String> allProjectPaths, {
    List<String>? targetProjectPaths,
    bool includeDev = false,
    String? basePath,
  }) {
    // Build name → path mapping
    final nameToPath = <String, String>{};
    final pathToName = <String, String>{};
    final pathToDeps = <String, Set<String>>{};

    for (final path in allProjectPaths) {
      final name = _getProjectName(path);
      nameToPath[name] = path;
      pathToName[path] = name;
      pathToDeps[path] = {};
    }

    // Build dependency graph (only intra-workspace deps)
    final workspaceNames = nameToPath.keys.toSet();
    for (final path in allProjectPaths) {
      final pubspecFile = File('$path/pubspec.yaml');
      if (!pubspecFile.existsSync()) continue;

      try {
        final yaml = loadYaml(pubspecFile.readAsStringSync()) as YamlMap?;
        if (yaml == null) continue;

        final deps = yaml['dependencies'] as YamlMap?;
        if (deps != null) {
          for (final depName in deps.keys.cast<String>()) {
            if (workspaceNames.contains(depName)) {
              pathToDeps[path]!.add(nameToPath[depName]!);
            }
          }
        }

        if (includeDev) {
          final devDeps = yaml['dev_dependencies'] as YamlMap?;
          if (devDeps != null) {
            for (final depName in devDeps.keys.cast<String>()) {
              if (workspaceNames.contains(depName)) {
                pathToDeps[path]!.add(nameToPath[depName]!);
              }
            }
          }
        }
      } catch (_) {}
    }

    // Kahn's algorithm
    final inDegree = <String, int>{};
    for (final path in allProjectPaths) {
      inDegree[path] = 0;
    }
    for (final entry in pathToDeps.entries) {
      for (final dep in entry.value) {
        inDegree[dep] = (inDegree[dep] ?? 0) + 0; // ensure key exists
        inDegree[entry.key] = (inDegree[entry.key] ?? 0) + 1;
      }
    }

    // Recalculate in-degrees properly
    for (final path in allProjectPaths) {
      inDegree[path] = 0;
    }
    for (final entry in pathToDeps.entries) {
      inDegree[entry.key] = entry.value.length;
    }

    // Queue with alphabetic tie-breaking
    final queue = <String>[];
    for (final path in allProjectPaths) {
      if (inDegree[path] == 0) queue.add(path);
    }
    queue.sort((a, b) =>
        (pathToName[a] ?? a).compareTo(pathToName[b] ?? b));

    final result = <String>[];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      result.add(current);

      // Reduce in-degree for dependents
      for (final entry in pathToDeps.entries) {
        if (entry.value.contains(current)) {
          inDegree[entry.key] = inDegree[entry.key]! - 1;
          if (inDegree[entry.key] == 0) {
            queue.add(entry.key);
            queue.sort((a, b) =>
                (pathToName[a] ?? a).compareTo(pathToName[b] ?? b));
          }
        }
      }
    }

    if (result.length != allProjectPaths.length) {
      // Circular dependency detected
      final remaining = allProjectPaths.where((p) => !result.contains(p));
      print('Circular dependency detected among:');
      for (final path in remaining) {
        print('  ${pathToName[path] ?? path}');
      }
      return null;
    }

    // Filter to targets if specified
    if (targetProjectPaths != null) {
      final targetSet = targetProjectPaths.toSet();
      return result.where((p) => targetSet.contains(p)).toList();
    }

    return result;
  }

  /// Get project name from pubspec.yaml.
  static String _getProjectName(String projectPath) {
    try {
      final pubspec = File('$projectPath/pubspec.yaml');
      if (pubspec.existsSync()) {
        final yaml = loadYaml(pubspec.readAsStringSync()) as YamlMap?;
        return yaml?['name']?.toString() ?? p.basename(projectPath);
      }
    } catch (_) {}
    return p.basename(projectPath);
  }
}
