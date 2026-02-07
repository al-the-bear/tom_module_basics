import 'dart:io';

import 'package:args/args.dart';
import 'package:tom_build_base/tom_build_base.dart';
import 'package:yaml/yaml.dart';

/// Base class for all integrated build tools.
///
/// Provides common infrastructure: argument parsing, project discovery,
/// config loading, verbose/dry-run support, and shared utility methods.
abstract class ToolBase {
  /// Tool key used in tom_build.yaml (e.g., 'cleanup', 'versioner').
  String get toolKey;

  /// Short description for help text.
  String get toolDescription;

  /// Whether verbose output is enabled.
  bool verbose = false;

  /// Whether dry-run mode is enabled.
  bool dryRun = false;

  /// Run the tool with the given arguments.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> run(List<String> args);

  /// Create the argument parser with common options.
  ///
  /// Subclasses override [addToolOptions] to add tool-specific options.
  ArgParser createParser() {
    final parser = ArgParser(allowTrailingOptions: false)
      ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help')
      ..addFlag('verbose',
          abbr: 'v', negatable: false, help: 'Verbose output')
      ..addOption('project',
          abbr: 'p', help: 'Project directory or glob pattern')
      ..addOption('scan',
          abbr: 's', help: 'Scan directory for projects')
      ..addFlag('recursive',
          abbr: 'R', negatable: false, help: 'Scan recursively')
      ..addMultiOption('exclude',
          abbr: 'x', help: 'Exclude patterns')
      ..addMultiOption('recursion-exclude',
          help: 'Exclude patterns during recursive scan')
      ..addFlag('list',
          abbr: 'l', negatable: false, help: 'List matching projects')
      ..addFlag('show',
          negatable: false, help: 'Show configuration for project');

    addToolOptions(parser);
    return parser;
  }

  /// Override to add tool-specific options to the parser.
  void addToolOptions(ArgParser parser) {}

  /// Find projects based on common config fields.
  Future<List<String>> findProjects({
    String? project,
    String? scan,
    bool recursive = false,
    List<String> exclude = const [],
    List<String> recursionExclude = const [],
    required String basePath,
  }) async {
    final discovery = ProjectDiscovery(verbose: verbose);

    if (project != null) {
      final paths = await discovery.resolveProjectPatterns(
        project,
        basePath: basePath,
      );
      return _filterProjects(paths, exclude);
    }

    if (scan != null) {
      final scanDir = _resolvePath(scan, basePath);
      final paths = await discovery.scanForProjects(
        scanDir,
        recursive: recursive,
        toolKey: toolKey,
      );
      return _filterProjects(paths, exclude);
    }

    return [basePath];
  }

  /// Check if a directory is a project this tool should process.
  bool isToolProject(String dirPath);

  /// Filter projects by exclusion patterns.
  List<String> _filterProjects(
      List<String> projects, List<String> exclude) {
    if (exclude.isEmpty) return projects;

    return projects.where((path) {
      for (final pattern in exclude) {
        if (path.contains(pattern)) return false;
      }
      return true;
    }).toList();
  }

  /// Resolve a path relative to a base.
  String _resolvePath(String path, String basePath) {
    if (path.startsWith('/')) return path;
    return '$basePath/$path';
  }

  // ---------------------------------------------------------------------------
  // Shared YAML utilities
  // ---------------------------------------------------------------------------

  /// Load tom_build.yaml from a directory, returning the parsed YAML map.
  YamlMap? loadTomBuildYaml(String dir) {
    final file = File('$dir/tom_build.yaml');
    if (!file.existsSync()) return null;
    try {
      final content = file.readAsStringSync();
      return loadYaml(content) as YamlMap?;
    } catch (_) {
      return null;
    }
  }

  /// Load build.yaml from a directory, returning the parsed YAML map.
  YamlMap? loadBuildYaml(String dir) {
    final file = File('$dir/build.yaml');
    if (!file.existsSync()) return null;
    try {
      final content = file.readAsStringSync();
      return loadYaml(content) as YamlMap?;
    } catch (_) {
      return null;
    }
  }

  /// Convert a dynamic YAML value to a `List<String>`.
  static List<String> toStringList(dynamic value) {
    if (value == null) return [];
    if (value is String) return [value];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  /// Print a YAML node with indentation (for --show).
  static void printYamlNode(dynamic node, {int indent = 0}) {
    final prefix = '  ' * indent;
    if (node is YamlMap) {
      for (final entry in node.entries) {
        if (entry.value is YamlMap || entry.value is YamlList) {
          print('$prefix${entry.key}:');
          printYamlNode(entry.value, indent: indent + 1);
        } else {
          print('$prefix${entry.key}: ${entry.value}');
        }
      }
    } else if (node is YamlList) {
      for (final item in node) {
        if (item is YamlMap || item is YamlList) {
          print('$prefix-');
          printYamlNode(item, indent: indent + 1);
        } else {
          print('$prefix- $item');
        }
      }
    } else {
      print('$prefix$node');
    }
  }

  /// Print the build.yaml section for a specific builder key (for --show).
  void printBuildYamlSection(String projectPath, String builderKey,
      {String? workspaceRoot}) {
    final buildYaml = loadBuildYaml(projectPath);
    if (buildYaml == null) {
      print('  No build.yaml found in $projectPath');
      return;
    }

    // Navigate to targets.$default.builders.<builderKey>.options
    final targets = buildYaml['targets'] as YamlMap?;
    if (targets == null) return;

    final defaultTarget = targets[r'$default'] as YamlMap?;
    if (defaultTarget == null) return;

    final builders = defaultTarget['builders'] as YamlMap?;
    if (builders == null) return;

    final builder = builders[builderKey] as YamlMap?;
    if (builder == null) {
      print('  No $builderKey configuration in build.yaml');
      return;
    }

    print('  build.yaml ($builderKey):');
    printYamlNode(builder, indent: 2);
  }
}
