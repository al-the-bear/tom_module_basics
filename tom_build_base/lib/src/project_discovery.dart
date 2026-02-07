import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Enhanced project discovery with proper scan vs recursive behavior.
/// 
/// Behavior:
/// - `scan`: Scans subfolders until it finds a project, then stops at that boundary
/// - `recursive`: Also scans inside found projects for nested projects (e.g., test projects)
/// 
/// When inside a project, skips directories like bin/, lib/, build/, etc.
class ProjectDiscovery {
  /// Whether to print verbose output.
  final bool verbose;
  
  /// Output function for verbose messages.
  final void Function(String) log;

  ProjectDiscovery({
    this.verbose = false,
    void Function(String)? log,
  }) : log = log ?? print;

  void _log(String message) {
    if (verbose) log(message);
  }

  /// Scan for projects in a directory.
  /// 
  /// [scanDir] - The directory to start scanning from
  /// [recursive] - If true, also scan inside found projects for nested projects
  /// [toolKey] - Optional tool key for project-level recursive override lookup
  /// 
  /// Returns a list of project directory paths.
  Future<List<String>> scanForProjects(
    String scanDir, {
    bool recursive = false,
    String? toolKey,
  }) async {
    final projects = <String>[];
    final dir = Directory(scanDir);

    if (!dir.existsSync()) {
      _log('Error: Directory does not exist: $scanDir');
      return projects;
    }

    await _scanDirectory(
      dir,
      projects,
      recursive: recursive,
      insideProject: false,
      toolKey: toolKey,
    );
    return projects;
  }

  Future<void> _scanDirectory(
    Directory dir,
    List<String> projects, {
    required bool recursive,
    required bool insideProject,
    String? toolKey,
  }) async {
    final dirName = p.basename(dir.path);

    // Always skip these directories (but not the initial scan directory)
    if (alwaysSkipDirectories.contains(dirName)) {
      return;
    }
    // Hidden directories start with "." but we allow "." as the scan root
    if (dirName.startsWith('.') && dirName != '.') {
      return;
    }

    // If inside a project, skip source/build directories
    if (insideProject && skipInsideProjectDirectories.contains(dirName)) {
      return;
    }

    // Check if this directory is a project
    final pubspecFile = File(p.join(dir.path, 'pubspec.yaml'));
    final isProject = pubspecFile.existsSync();

    if (isProject) {
      projects.add(dir.path);

      // Check if we should recurse into this project
      bool shouldRecurseIntoProject = recursive;

      // Check for project-level override in tom_build.yaml
      final projectRecursive = getProjectRecursiveSetting(dir.path, toolKey);
      if (projectRecursive != null) {
        shouldRecurseIntoProject = projectRecursive;
        if (verbose) {
          _log('  Project override: recursive=$projectRecursive for ${dir.path}');
        }
      }

      if (!shouldRecurseIntoProject) {
        // Don't scan inside this project
        return;
      }

      // Recurse into project, but now we're "inside" a project
      await _scanSubdirectories(
        dir,
        projects,
        recursive: recursive,
        insideProject: true,
        toolKey: toolKey,
      );
    } else {
      // Not a project - continue scanning subfolders
      await _scanSubdirectories(
        dir,
        projects,
        recursive: recursive,
        insideProject: insideProject,
        toolKey: toolKey,
      );
    }
  }

  Future<void> _scanSubdirectories(
    Directory dir,
    List<String> projects, {
    required bool recursive,
    required bool insideProject,
    String? toolKey,
  }) async {
    try {
      await for (final entity in dir.list()) {
        if (entity is Directory) {
          await _scanDirectory(
            entity,
            projects,
            recursive: recursive,
            insideProject: insideProject,
            toolKey: toolKey,
          );
        }
      }
    } catch (e) {
      _log('Warning: Cannot scan ${dir.path}: $e');
    }
  }

  /// Check if a project has recursive override in tom_build.yaml.
  /// 
  /// Looks for:
  /// - `buildkit.recursive: true/false` (global for all tools)
  /// - `{toolKey}.recursive: true/false` (tool-specific)
  /// 
  /// Returns null if not specified (use default), true/false if explicitly set.
  static bool? getProjectRecursiveSetting(String projectPath, String? toolKey) {
    final tomBuildYaml = File(p.join(projectPath, 'tom_build.yaml'));
    if (!tomBuildYaml.existsSync()) return null;

    try {
      final content = tomBuildYaml.readAsStringSync();
      final yaml = loadYaml(content) as YamlMap?;
      if (yaml == null) return null;

      // Check tool-specific setting first
      if (toolKey != null) {
        final toolYaml = yaml[toolKey] as YamlMap?;
        if (toolYaml != null && toolYaml.containsKey('recursive')) {
          return toolYaml['recursive'] as bool?;
        }
      }

      // Check global buildkit setting
      final buildkitYaml = yaml['buildkit'] as YamlMap?;
      if (buildkitYaml != null && buildkitYaml.containsKey('recursive')) {
        return buildkitYaml['recursive'] as bool?;
      }
    } catch (_) {
      // Ignore errors
    }
    return null;
  }

  /// Directories to always skip when scanning (not projects, tooling dirs).
  static const alwaysSkipDirectories = {
    '.dart_tool',
    '.git',
    '.idea',
    '.vscode',
    'build',
    'node_modules',
    'coverage',
    '.pub-cache',
    '.pub',
    '__pycache__',
  };

  /// Directories to skip when scanning INSIDE a project.
  /// These are source/platform directories that won't contain nested Dart projects.
  static const skipInsideProjectDirectories = {
    // Source directories
    'bin',
    'lib',
    'src',

    // Build/output directories
    'build',
    'out',
    'dist',

    // Asset directories
    'assets',
    'fonts',
    'images',
    'res',
    'resources',

    // Documentation
    'doc',
    'docs',

    // Flutter platform directories
    'android',
    'ios',
    'macos',
    'windows',
    'linux',
    'web',

    // Generated/tooling
    'generated',
    '.dart_tool',
  };
}
