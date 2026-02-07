import 'dart:io';

import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
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

  /// Resolve project patterns to a list of project paths.
  ///
  /// [patterns] - Comma-separated list of project patterns. Supports:
  ///   - Single path: `my_project`
  ///   - Multiple paths: `project1,project2,project3`
  ///   - Glob patterns: `tom_*_builder`, `xternal/tom_module_*/*`
  ///   - Dot prefix for current directory: `./*` (direct children), `./**/*` (recursive)
  /// [basePath] - Base path for relative patterns
  /// [projectFilter] - Optional filter function to validate projects (e.g., check for build.yaml)
  ///
  /// Returns a list of absolute project paths.
  Future<List<String>> resolveProjectPatterns(
    String patterns, {
    required String basePath,
    bool Function(String)? projectFilter,
  }) async {
    final results = <String>[];
    final seen = <String>{};

    // Split by comma (but not inside braces for glob patterns like {a,b})
    final patternList = _splitPatterns(patterns);

    for (final pattern in patternList) {
      final trimmed = pattern.trim();
      if (trimmed.isEmpty) continue;

      final resolved = await _resolvePattern(trimmed, basePath, projectFilter);
      for (final path in resolved) {
        if (!seen.contains(path)) {
          seen.add(path);
          results.add(path);
        }
      }
    }

    return results;
  }

  /// Split patterns by comma, respecting brace groups.
  List<String> _splitPatterns(String patterns) {
    final result = <String>[];
    var current = StringBuffer();
    var braceDepth = 0;

    for (var i = 0; i < patterns.length; i++) {
      final char = patterns[i];
      if (char == '{') {
        braceDepth++;
        current.write(char);
      } else if (char == '}') {
        braceDepth--;
        current.write(char);
      } else if (char == ',' && braceDepth == 0) {
        result.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }

    if (current.isNotEmpty) {
      result.add(current.toString());
    }

    return result;
  }

  Future<List<String>> _resolvePattern(
    String pattern,
    String basePath,
    bool Function(String)? projectFilter,
  ) async {
    // Handle dot prefix: ./* means current directory children
    var resolvedPattern = pattern;
    if (pattern.startsWith('./')) {
      resolvedPattern = pattern.substring(2);
    } else if (pattern == '.') {
      // Single dot means current directory
      if (_isProject(basePath) && 
          (projectFilter == null || projectFilter(basePath))) {
        return [basePath];
      }
      return [];
    }

    // Check if pattern contains glob characters
    if (_isGlobPattern(resolvedPattern)) {
      return _resolveGlobPattern(resolvedPattern, basePath, projectFilter);
    }

    // Simple path - check if it's a valid project
    final fullPath = p.normalize(p.isAbsolute(resolvedPattern)
        ? resolvedPattern
        : p.join(basePath, resolvedPattern));

    if (_isProject(fullPath) &&
        (projectFilter == null || projectFilter(fullPath))) {
      return [fullPath];
    }

    // If pattern is a simple name (no path separators), search the workspace
    if (!resolvedPattern.contains('/') && !resolvedPattern.contains(p.separator)) {
      final workspaceRoot = findWorkspaceRoot(basePath);
      _log('Searching workspace for project: $resolvedPattern');
      
      // Search workspace recursively for a project with matching name
      final found = await _findProjectByName(workspaceRoot, resolvedPattern, projectFilter);
      if (found != null) {
        _log('Found project at: $found');
        return [found];
      }
    }

    _log('Warning: Not a valid project: $pattern');
    return [];
  }

  /// Search for a project by name in the workspace.
  Future<String?> _findProjectByName(
    String rootDir,
    String projectName,
    bool Function(String)? projectFilter,
  ) async {
    final dir = Directory(rootDir);
    if (!dir.existsSync()) return null;

    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is Directory) {
          final dirName = p.basename(entity.path);
          
          // Skip hidden directories and known non-project directories
          if (dirName.startsWith('.') || alwaysSkipDirectories.contains(dirName)) {
            continue;
          }
          
          // Check if this directory matches the project name and is a valid project
          if (dirName == projectName && _isProject(entity.path)) {
            if (projectFilter == null || projectFilter(entity.path)) {
              return p.normalize(entity.path);
            }
          }
        }
      }
    } catch (e) {
      _log('Warning: Error searching workspace: $e');
    }
    return null;
  }

  bool _isGlobPattern(String pattern) {
    return pattern.contains('*') ||
        pattern.contains('?') ||
        pattern.contains('[') ||
        pattern.contains('{');
  }

  Future<List<String>> _resolveGlobPattern(
    String pattern,
    String basePath,
    bool Function(String)? projectFilter,
  ) async {
    final results = <String>[];

    try {
      final glob = Glob(pattern);
      
      await for (final entity in glob.list(root: basePath)) {
        if (entity is Directory) {
          final path = p.normalize(entity.path);
          if (_isProject(path) &&
              (projectFilter == null || projectFilter(path))) {
            results.add(path);
          }
        }
      }
    } catch (e) {
      _log('Warning: Error resolving glob pattern "$pattern": $e');
    }

    return results;
  }

  /// Check if a directory is a Dart project (has pubspec.yaml).
  bool _isProject(String dirPath) {
    return File(p.join(dirPath, 'pubspec.yaml')).existsSync();
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
    List<String> recursionExclude = const [],
  }) async {
    final projects = <String>[];
    final dir = Directory(scanDir);

    if (!dir.existsSync()) {
      _log('Error: Directory does not exist: $scanDir');
      return projects;
    }

    // Pre-compile recursion exclusion globs
    final recursionGlobs = recursionExclude
        .map((pattern) {
          try {
            return Glob(pattern);
          } catch (_) {
            return null;
          }
        })
        .whereType<Glob>()
        .toList();

    await _scanDirectory(
      dir,
      projects,
      recursive: recursive,
      insideProject: false,
      toolKey: toolKey,
      recursionGlobs: recursionGlobs,
      scanRoot: scanDir,
    );
    return projects;
  }

  Future<void> _scanDirectory(
    Directory dir,
    List<String> projects, {
    required bool recursive,
    required bool insideProject,
    String? toolKey,
    List<Glob> recursionGlobs = const [],
    String? scanRoot,
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

    // Check recursion exclusions (relative path from scan root)
    if (recursionGlobs.isNotEmpty && scanRoot != null) {
      final relativePath = p.relative(dir.path, from: scanRoot);
      for (final glob in recursionGlobs) {
        if (glob.matches(relativePath) || glob.matches(dirName)) {
          if (verbose) {
            _log('  Skipping (recursion-exclude): $relativePath');
          }
          return;
        }
      }
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
        recursionGlobs: recursionGlobs,
        scanRoot: scanRoot,
      );
    } else {
      // Not a project - continue scanning subfolders
      await _scanSubdirectories(
        dir,
        projects,
        recursive: recursive,
        insideProject: insideProject,
        toolKey: toolKey,
        recursionGlobs: recursionGlobs,
        scanRoot: scanRoot,
      );
    }
  }

  Future<void> _scanSubdirectories(
    Directory dir,
    List<String> projects, {
    required bool recursive,
    required bool insideProject,
    String? toolKey,
    List<Glob> recursionGlobs = const [],
    String? scanRoot,
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
            recursionGlobs: recursionGlobs,
            scanRoot: scanRoot,
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

  /// Find the workspace root by looking for tom_workspace.yaml or tom.code-workspace.
  /// 
  /// Starts from [startPath] and traverses up the directory tree.
  /// Returns [startPath] if no workspace root is found.
  static String findWorkspaceRoot(String startPath) {
    var current = p.normalize(p.absolute(startPath));
    final root = p.rootPrefix(current);

    while (current != root) {
      if (File(p.join(current, 'tom_workspace.yaml')).existsSync() ||
          File(p.join(current, 'tom.code-workspace')).existsSync()) {
        return current;
      }
      current = p.dirname(current);
    }

    return startPath;
  }
}
