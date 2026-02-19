import 'dart:io' show Directory, File;

import 'package:dcli/dcli.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'build_config.dart';

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

  /// Tool basename for skip file resolution (e.g., 'buildkit', 'testkit').
  /// If null, defaults to 'buildkit' for backwards compatibility.
  final String? toolBasename;

  ProjectDiscovery({
    this.verbose = false,
    void Function(String)? log,
    this.toolBasename,
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
    final fullPath = truepath(p.isAbsolute(resolvedPattern)
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

  /// Search for a project by name, project ID, or project name in the workspace.
  ///
  /// Resolution order (first match wins):
  /// 1. Folder basename exact match
  /// 2. Project ID match (from tom_project.yaml `project_id`/`short-id`, or buildkit.yaml `project-id`)
  /// 3. Project name match (from tom_project.yaml `name`, or buildkit.yaml `name`)
  ///
  /// ID and name matching is case-insensitive.
  Future<String?> _findProjectByName(
    String rootDir,
    String projectName,
    bool Function(String)? projectFilter,
  ) async {
    if (!exists(rootDir) || !isDirectory(rootDir)) return null;

    final lowerSearch = projectName.toLowerCase();
    String? idMatch;
    String? nameMatch;

    try {
      // Use DCli find to search recursively for directories
      for (final dirPath in find('*',
              workingDirectory: rootDir,
              recursive: true,
              types: [Find.directory])
          .toList()) {
        final dirName = p.basename(dirPath);

        // Skip hidden directories and known non-project directories
        if (dirName.startsWith('.') || alwaysSkipDirectories.contains(dirName)) {
          continue;
        }

        if (!_isProject(dirPath)) continue;
        if (projectFilter != null && !projectFilter(dirPath)) continue;

        // 1. Folder basename exact match (highest priority)
        if (dirName == projectName) {
          return truepath(dirPath);
        }

        // 2 & 3. Check project ID and name from YAML config files
        if (idMatch == null || nameMatch == null) {
          final match = _matchProjectConfig(dirPath, lowerSearch);
          if (match == _ConfigMatch.id && idMatch == null) {
            idMatch = truepath(dirPath);
          } else if (match == _ConfigMatch.name && nameMatch == null) {
            nameMatch = truepath(dirPath);
          }
        }
      }
    } catch (e) {
      _log('Warning: Error searching workspace: $e');
    }

    // Return first match by priority: folder name → ID → name
    return idMatch ?? nameMatch;
  }

  /// Check if a directory's project config files match the search term.
  /// Returns the type of match found, or null if no match.
  _ConfigMatch? _matchProjectConfig(String dirPath, String lowerSearch) {
    // Check tom_project.yaml
    final tomProjectFile = File(p.join(dirPath, 'tom_project.yaml'));
    if (tomProjectFile.existsSync()) {
      try {
        final content = tomProjectFile.readAsStringSync();
        final yaml = loadYaml(content);
        if (yaml is Map) {
          // Check project_id and short-id
          final projectId = yaml['project_id'] as String? ?? yaml['short-id'] as String?;
          if (projectId != null && projectId.toLowerCase() == lowerSearch) {
            return _ConfigMatch.id;
          }
          // Check name
          final name = yaml['name'] as String?;
          if (name != null && name.toLowerCase() == lowerSearch) {
            return _ConfigMatch.name;
          }
        }
      } catch (_) {}
    }

    // Check buildkit.yaml
    final buildkitFile = File(p.join(dirPath, 'buildkit.yaml'));
    if (buildkitFile.existsSync()) {
      try {
        final content = buildkitFile.readAsStringSync();
        final yaml = loadYaml(content);
        if (yaml is Map) {
          // Check project-id
          final projectId = yaml['project-id'] as String?;
          if (projectId != null && projectId.toLowerCase() == lowerSearch) {
            return _ConfigMatch.id;
          }
          // Check name
          final name = yaml['name'] as String?;
          if (name != null && name.toLowerCase() == lowerSearch) {
            return _ConfigMatch.name;
          }
        }
      } catch (_) {}
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
          final path = truepath(entity.path);
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
    return exists(p.join(dirPath, 'pubspec.yaml'));
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

    if (!exists(scanDir) || !isDirectory(scanDir)) {
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
      scanDir,
      projects,
      recursive: recursive,
      insideProject: false,
      toolKey: toolKey,
      recursionGlobs: recursionGlobs,
      scanRoot: scanDir,
    );
    return projects;
  }

  /// Global skip file that blocks all tools.
  static const globalSkipFileName = 'tom_skip.yaml';

  /// Legacy/default skip file name for backwards compatibility.
  static const skipFileName = 'buildkit_skip.yaml';

  /// Check if a directory contains a skip marker file.
  ///
  /// Checks in order:
  /// 1. tom_skip.yaml (global skip for all tools)
  /// 2. {basename}_skip.yaml (tool-specific skip)
  ///
  /// If [basename] is not provided, falls back to 'buildkit' for backwards compatibility.
  static bool hasSkipFile(String dirPath, {String? basename}) {
    // Check global skip first
    if (exists(p.join(dirPath, globalSkipFileName))) {
      return true;
    }
    // Check tool-specific skip
    final toolSkipFileName = '${basename ?? 'buildkit'}_skip.yaml';
    return exists(p.join(dirPath, toolSkipFileName));
  }

  /// Get the skip file name that was found, or null if none.
  static String? getSkipFileName(String dirPath, {String? basename}) {
    if (exists(p.join(dirPath, globalSkipFileName))) {
      return globalSkipFileName;
    }
    final toolSkipFileName = '${basename ?? 'buildkit'}_skip.yaml';
    if (exists(p.join(dirPath, toolSkipFileName))) {
      return toolSkipFileName;
    }
    return null;
  }

  Future<void> _scanDirectory(
    String dirPath,
    List<String> projects, {
    required bool recursive,
    required bool insideProject,
    String? toolKey,
    List<Glob> recursionGlobs = const [],
    String? scanRoot,
  }) async {
    final dirName = p.basename(dirPath);

    // Skip directories that contain a skip marker file
    if (hasSkipFile(dirPath, basename: toolBasename)) {
      if (verbose) {
        final skipFile = getSkipFileName(dirPath, basename: toolBasename);
        _log('  Skipping ($skipFile): $dirPath');
      }
      return;
    }

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
      final relativePath = p.relative(dirPath, from: scanRoot);
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
    final isProject = exists(p.join(dirPath, 'pubspec.yaml'));

    if (isProject) {
      projects.add(dirPath);

      // Check if we should recurse into this project
      bool shouldRecurseIntoProject = recursive;

      // Check for project-level override in tom_build.yaml
      final projectRecursive = getProjectRecursiveSetting(dirPath, toolKey);
      if (projectRecursive != null) {
        shouldRecurseIntoProject = projectRecursive;
        if (verbose) {
          _log('  Project override: recursive=$projectRecursive for $dirPath');
        }
      }

      if (!shouldRecurseIntoProject) {
        // Don't scan inside this project
        return;
      }

      // Recurse into project, but now we're "inside" a project
      await _scanSubdirectories(
        dirPath,
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
        dirPath,
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
    String dirPath,
    List<String> projects, {
    required bool recursive,
    required bool insideProject,
    String? toolKey,
    List<Glob> recursionGlobs = const [],
    String? scanRoot,
  }) async {
    try {
      // Use DCli find to get immediate subdirectories
      for (final subDirPath in find('*',
              workingDirectory: dirPath,
              recursive: false,
              types: [Find.directory])
          .toList()) {
        await _scanDirectory(
          subDirPath,
          projects,
          recursive: recursive,
          insideProject: insideProject,
          toolKey: toolKey,
          recursionGlobs: recursionGlobs,
          scanRoot: scanRoot,
        );
      }
    } catch (e) {
      _log('Warning: Cannot scan $dirPath: $e');
    }
  }

  /// Check if a project has recursive override in buildkit.yaml.
  /// 
  /// Looks for:
  /// - `buildkit.recursive: true/false` (global for all tools)
  /// - `{toolKey}.recursive: true/false` (tool-specific)
  /// 
  /// Returns null if not specified (use default), true/false if explicitly set.
  static bool? getProjectRecursiveSetting(String projectPath, String? toolKey) {
    final buildkitYamlFile = File(p.join(projectPath, TomBuildConfig.projectFilename));
    if (!buildkitYamlFile.existsSync()) return null;

    try {
      final content = buildkitYamlFile.readAsStringSync();
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
      final buildkitSection = yaml['buildkit'] as YamlMap?;
      if (buildkitSection != null && buildkitSection.containsKey('recursive')) {
        return buildkitSection['recursive'] as bool?;
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

  // ===========================================================================
  // Module Filtering
  // ===========================================================================

  /// Find all git repositories in the workspace.
  ///
  /// Returns a map from repository folder name to absolute path.
  /// The main repository uses 'root' and the actual repository name as keys.
  static Map<String, String> findGitRepositories(String workspaceRoot) {
    final repos = <String, String>{};
    final rootGit = p.join(workspaceRoot, '.git');

    // Check if workspace root is a git repo
    if (Directory(rootGit).existsSync() || File(rootGit).existsSync()) {
      // Add with 'root' key and repository folder name
      repos['root'] = workspaceRoot;
      final repoName = p.basename(workspaceRoot);
      repos[repoName] = workspaceRoot;
    }

    // Recursively find git repos in subdirectories
    _findGitReposRecursive(Directory(workspaceRoot), repos, workspaceRoot);

    return repos;
  }

  static void _findGitReposRecursive(
    Directory dir,
    Map<String, String> repos,
    String workspaceRoot,
  ) {
    try {
      for (final entity in dir.listSync()) {
        if (entity is Directory) {
          final dirName = p.basename(entity.path);

          // Skip hidden directories and known non-project directories
          if (dirName.startsWith('.') ||
              alwaysSkipDirectories.contains(dirName)) {
            continue;
          }

          // Check if this directory is a git repo
          final gitPath = p.join(entity.path, '.git');
          if (Directory(gitPath).existsSync() || File(gitPath).existsSync()) {
            repos[dirName] = entity.path;
            // Still recurse to find nested repos
          }

          // Recurse into subdirectory
          _findGitReposRecursive(entity, repos, workspaceRoot);
        }
      }
    } catch (_) {
      // Ignore permission errors
    }
  }

  /// Resolve module names to their absolute paths.
  ///
  /// [moduleNames] - List of module names (e.g., ['tom_module_d4rt', 'root'])
  /// [workspaceRoot] - The workspace root path
  ///
  /// Returns a list of absolute paths for the specified modules.
  /// Unknown module names are logged and skipped.
  static List<String> resolveModulePaths(
    List<String> moduleNames,
    String workspaceRoot, {
    bool verbose = false,
    void Function(String)? log,
  }) {
    if (moduleNames.isEmpty) return [];

    final repos = findGitRepositories(workspaceRoot);
    final paths = <String>[];
    final logFn = log ?? print;

    for (final name in moduleNames) {
      final modulePath = repos[name];
      if (modulePath != null) {
        paths.add(modulePath);
      } else {
        // Try case-insensitive match
        final lowerName = name.toLowerCase();
        final match = repos.entries.firstWhere(
          (e) => e.key.toLowerCase() == lowerName,
          orElse: () => const MapEntry('', ''),
        );
        if (match.value.isNotEmpty) {
          paths.add(match.value);
        } else {
          if (verbose) {
            logFn('Warning: Unknown module "$name". Available: ${repos.keys.join(', ')}');
          }
        }
      }
    }

    return paths;
  }

  /// Filter projects to only those within specified modules.
  ///
  /// [projectPaths] - List of project paths to filter
  /// [modulePaths] - List of module root paths (from resolveModulePaths)
  ///
  /// Returns only projects whose path starts with one of the module paths.
  static List<String> filterByModules(
    List<String> projectPaths,
    List<String> modulePaths,
  ) {
    if (modulePaths.isEmpty) return projectPaths;

    return projectPaths.where((projectPath) {
      final normalizedProject = p.normalize(p.absolute(projectPath));
      return modulePaths.any((modulePath) {
        final normalizedModule = p.normalize(p.absolute(modulePath));
        // Project path must start with module path (be inside the module)
        return normalizedProject.startsWith(normalizedModule + p.separator) ||
            normalizedProject == normalizedModule;
      });
    }).toList();
  }

  /// Filter projects using WorkspaceNavigationArgs.modules setting.
  ///
  /// Convenience method that combines resolveModulePaths and filterByModules.
  static List<String> applyModulesFilter(
    List<String> projectPaths,
    List<String> modules,
    String workspaceRoot, {
    bool verbose = false,
    void Function(String)? log,
  }) {
    if (modules.isEmpty) return projectPaths;

    final modulePaths = resolveModulePaths(
      modules,
      workspaceRoot,
      verbose: verbose,
      log: log,
    );

    if (modulePaths.isEmpty) {
      // No valid modules found - return empty (strict filtering)
      if (verbose) {
        (log ?? print)('Warning: No valid modules found, no projects will be processed');
      }
      return [];
    }

    return filterByModules(projectPaths, modulePaths);
  }
}

/// Type of config match found during project search.
enum _ConfigMatch { id, name }
