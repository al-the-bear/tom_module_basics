import 'dart:io';

import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'project_discovery.dart';
import 'v2/traversal/folder_scanner.dart';
import 'workspace_mode.dart';
import 'yaml_utils.dart';

/// Configuration for which navigation options should be applied.
///
/// Tools can customize which navigation features they support by creating
/// a config with specific options enabled/disabled. This allows shared
/// navigation logic while supporting tool-specific behavior.
///
/// Example:
/// ```dart
/// // Full buildkit-style navigation
/// final config = NavigationConfig.all();
///
/// // Simpler testkit-style (no skip files, no master config)
/// final config = NavigationConfig(
///   usePathExclude: true,
///   useNameExclude: true,
///   useModulesFilter: true,
///   useSkipFiles: false,
///   useMasterConfigDefaults: false,
/// );
/// ```
class NavigationConfig {
  /// Apply path-based exclude patterns (`--exclude`, `-x`).
  final bool usePathExclude;

  /// Apply project name/path exclude patterns (`--exclude-projects`).
  final bool useNameExclude;

  /// Apply git module filtering (`--modules`, `-m`).
  final bool useModulesFilter;

  /// Apply recursion exclude patterns (`--recursion-exclude`).
  final bool useRecursionExclude;

  /// Skip projects with `buildkit_skip.yaml`.
  final bool useSkipFiles;

  /// Load navigation defaults from `buildkit_master.yaml`.
  final bool useMasterConfigDefaults;

  /// Support build-order sorting (`--build-order`, `-b`).
  final bool useBuildOrder;

  /// Support git-based traversal (`--inner-first-git`, `--outer-first-git`).
  final bool useGitTraversal;

  /// Custom project filter function.
  ///
  /// If provided, only projects where this returns true will be included.
  /// This is called after all other filters are applied.
  final bool Function(String)? projectFilter;

  const NavigationConfig({
    this.usePathExclude = true,
    this.useNameExclude = true,
    this.useModulesFilter = true,
    this.useRecursionExclude = true,
    this.useSkipFiles = true,
    this.useMasterConfigDefaults = true,
    this.useBuildOrder = true,
    this.useGitTraversal = true,
    this.projectFilter,
  });

  /// Configuration that enables all navigation features.
  ///
  /// This is the default for buildkit.
  const NavigationConfig.all({
    this.projectFilter,
  })  : usePathExclude = true,
        useNameExclude = true,
        useModulesFilter = true,
        useRecursionExclude = true,
        useSkipFiles = true,
        useMasterConfigDefaults = true,
        useBuildOrder = true,
        useGitTraversal = true;

  /// Configuration with minimal features.
  ///
  /// Useful for tools that only need basic project discovery.
  const NavigationConfig.minimal({
    this.projectFilter,
  })  : usePathExclude = false,
        useNameExclude = false,
        useModulesFilter = false,
        useRecursionExclude = false,
        useSkipFiles = false,
        useMasterConfigDefaults = false,
        useBuildOrder = false,
        useGitTraversal = false;

  /// Create a copy with some options changed.
  NavigationConfig copyWith({
    bool? usePathExclude,
    bool? useNameExclude,
    bool? useModulesFilter,
    bool? useRecursionExclude,
    bool? useSkipFiles,
    bool? useMasterConfigDefaults,
    bool? useBuildOrder,
    bool? useGitTraversal,
    bool Function(String)? projectFilter,
  }) {
    return NavigationConfig(
      usePathExclude: usePathExclude ?? this.usePathExclude,
      useNameExclude: useNameExclude ?? this.useNameExclude,
      useModulesFilter: useModulesFilter ?? this.useModulesFilter,
      useRecursionExclude: useRecursionExclude ?? this.useRecursionExclude,
      useSkipFiles: useSkipFiles ?? this.useSkipFiles,
      useMasterConfigDefaults:
          useMasterConfigDefaults ?? this.useMasterConfigDefaults,
      useBuildOrder: useBuildOrder ?? this.useBuildOrder,
      useGitTraversal: useGitTraversal ?? this.useGitTraversal,
      projectFilter: projectFilter ?? this.projectFilter,
    );
  }
}

/// Navigation defaults loaded from master config.
class NavigationDefaults {
  final String? scan;
  final bool recursive;
  final List<String> exclude;
  final List<String> recursionExclude;
  final List<String> excludeProjects;

  const NavigationDefaults({
    this.scan,
    this.recursive = false,
    this.exclude = const [],
    this.recursionExclude = const [],
    this.excludeProjects = const [],
  });
}

/// Result of navigation containing discovered paths and metadata.
class NavigationResult {
  /// The discovered paths (projects or git repos).
  final List<String> paths;

  /// Whether git-based traversal was used.
  final bool isGitMode;

  /// Whether an error occurred during discovery.
  final bool hasError;

  /// Error message if [hasError] is true.
  final String? errorMessage;

  const NavigationResult({
    required this.paths,
    this.isGitMode = false,
    this.hasError = false,
    this.errorMessage,
  });

  factory NavigationResult.error(String message) => NavigationResult(
        paths: const [],
        hasError: true,
        errorMessage: message,
      );
}

/// Unified project navigation and discovery.
///
/// This class provides project discovery with consistent filtering behavior
/// that can be shared across different tools (buildkit, testkit, etc.).
///
/// Example:
/// ```dart
/// final navigator = ProjectNavigator(
///   config: NavigationConfig.all(),
///   verbose: true,
/// );
///
/// final result = await navigator.navigate(
///   navArgs,
///   basePath: Directory.current.path,
/// );
///
/// if (result.hasError) {
///   print('Error: ${result.errorMessage}');
///   return;
/// }
///
/// for (final project in result.paths) {
///   // Process each project
/// }
/// ```
class ProjectNavigator {
  /// Configuration for which navigation features to use.
  final NavigationConfig config;

  /// Whether to print verbose output.
  final bool verbose;

  /// Output function for messages.
  final void Function(String) log;

  /// Tool basename for skip file resolution (e.g., 'buildkit', 'testkit').
  /// If null, defaults to 'buildkit' for backwards compatibility.
  final String? toolBasename;

  ProjectNavigator({
    this.config = const NavigationConfig.all(),
    this.verbose = false,
    void Function(String)? log,
    this.toolBasename,
  }) : log = log ?? print;

  void _log(String message) {
    if (verbose) log(message);
  }

  /// Navigate to find projects or git repositories based on navigation args.
  ///
  /// This is the main entry point that handles all navigation modes:
  /// - Top repo resolution (`topRepo`) - find topmost git repo and use as base
  /// - Git-based traversal (`innerFirstGit`, `outerFirstGit`)
  /// - Project pattern matching (`project`)
  /// - Directory scanning (`scan`, `recursive`)
  ///
  /// Note: `topRepo` requires either `innerFirstGit` or `outerFirstGit`.
  ///
  /// Returns a [NavigationResult] with the discovered paths.
  Future<NavigationResult> navigate(
    WorkspaceNavigationArgs navArgs, {
    required String basePath,
  }) async {
    var effectiveBasePath = basePath;

    // Validate: topRepo requires git traversal mode
    if (navArgs.topRepo && !navArgs.innerFirstGit && !navArgs.outerFirstGit) {
      return NavigationResult.error(
        '-T/--top-repo requires git traversal mode (-i/--inner-first-git or -o/--outer-first-git)',
      );
    }

    // If topRepo is set, find the topmost git repo and use that as base
    if (navArgs.topRepo) {
      final finder = GitRepoFinder();
      final topRepo = finder.findTopRepo(basePath);
      if (topRepo == null) {
        return NavigationResult.error(
          'No git repository found in directory tree above: $basePath',
        );
      }
      effectiveBasePath = topRepo;
      _log('Using top git repository: $effectiveBasePath');
    }

    // Check for git-based traversal mode
    if (config.useGitTraversal &&
        (navArgs.innerFirstGit || navArgs.outerFirstGit)) {
      return _navigateGitMode(navArgs, effectiveBasePath);
    }

    // Project-based navigation
    return _navigateProjectMode(navArgs, effectiveBasePath);
  }

  /// Navigate in git-based traversal mode.
  ///
  /// Returns git repository root folders ordered by depth. With `innerFirstGit`,
  /// deepest repos come first; with `outerFirstGit`, shallowest come first.
  /// Use `--exclude` patterns to filter repos by path.
  Future<NavigationResult> _navigateGitMode(
    WorkspaceNavigationArgs navArgs,
    String basePath,
  ) async {
    var repos = findGitRepositories(basePath);

    if (repos.isEmpty) {
      return NavigationResult.error('No git repositories found in: $basePath');
    }

    // Sort by depth based on traversal order
    final innerFirst = navArgs.innerFirstGit;
    repos.sort((a, b) {
      final depthA = p.split(a).length;
      final depthB = p.split(b).length;
      if (depthA != depthB) {
        return innerFirst
            ? depthB.compareTo(depthA) // deepest first
            : depthA.compareTo(depthB); // shallowest first
      }
      return p.basename(a).compareTo(p.basename(b)); // alphabetic tie-break
    });

    // Apply modules filter if specified
    if (config.useModulesFilter && navArgs.modules.isNotEmpty) {
      final wsRoot = findWorkspaceRoot(basePath);
      repos = ProjectDiscovery.applyModulesFilter(
        repos,
        navArgs.modules,
        wsRoot,
        verbose: verbose,
        log: log,
      );
    }

    // Apply path exclusion filter
    if (config.usePathExclude && navArgs.exclude.isNotEmpty) {
      repos = filterByPath(repos, navArgs.exclude);
    }

    // Apply skip files filter
    if (config.useSkipFiles) {
      repos = filterSkippedProjects(
        repos,
        verbose: verbose,
        log: log,
        basename: toolBasename,
      );
    }

    // Apply project filter to git repo roots (filter repos that are valid projects)
    if (config.projectFilter != null) {
      repos = repos.where(config.projectFilter!).toList();
    }

    _log('Found ${repos.length} git repository(ies) '
        '(${innerFirst ? 'inner-first' : 'outer-first'})');

    return NavigationResult(paths: repos, isGitMode: true);
  }

  /// Navigate in project-based mode.
  Future<NavigationResult> _navigateProjectMode(
    WorkspaceNavigationArgs navArgs,
    String basePath,
  ) async {
    final discovery = ProjectDiscovery(
      verbose: verbose,
      log: log,
      toolBasename: toolBasename,
    );

    // Effective values (may be overridden by master config defaults)
    var project = navArgs.project;
    var scan = navArgs.scan;
    var recursive = navArgs.recursive;
    var exclude = navArgs.exclude;
    var recursionExclude = navArgs.recursionExclude;
    var excludeProjects = navArgs.excludeProjects;

    // Load defaults from master config if enabled and no explicit options set
    if (config.useMasterConfigDefaults && project == null && scan == null) {
      final defaults = loadNavigationDefaults(basePath);
      if (defaults != null) {
        scan = defaults.scan;
        recursive = defaults.recursive || recursive;
        if (defaults.exclude.isNotEmpty && exclude.isEmpty) {
          exclude = defaults.exclude;
        }
        if (defaults.recursionExclude.isNotEmpty && recursionExclude.isEmpty) {
          recursionExclude = defaults.recursionExclude;
        }
        if (defaults.excludeProjects.isNotEmpty && excludeProjects.isEmpty) {
          excludeProjects = defaults.excludeProjects;
        }
      } else {
        // Hardcoded fallback when no master config: --scan . --recursive
        scan = '.';
        recursive = true;
      }
    }

    // Fallback when master config is disabled and no options specified
    if (!config.useMasterConfigDefaults && project == null && scan == null) {
      // Default to current directory only
      if (config.projectFilter == null || config.projectFilter!(basePath)) {
        return NavigationResult(paths: [basePath]);
      }
      return const NavigationResult(paths: []);
    }

    List<String> results;

    // Phase 1: Discover projects
    if (project != null) {
      String effectivePattern = project;

      // For non-glob patterns, try literal path first, then search by name
      if (!_isGlobPattern(project)) {
        final resolvedPath = p.isAbsolute(project)
            ? project
            : p.normalize(p.join(basePath, project));
        if (!Directory(resolvedPath).existsSync()) {
          // If it looks like a simple project name (no path separators),
          // convert to glob pattern and search
          if (!project.contains('/') && !project.contains(r'\')) {
            effectivePattern = '**/$project';
            if (verbose) {
              log('Project "$project" not found as literal path, searching '
                  'with pattern "$effectivePattern"');
            }
          } else {
            return NavigationResult.error(
                'Project path does not exist: $project');
          }
        }
      }

      final paths = await discovery.resolveProjectPatterns(
        effectivePattern,
        basePath: basePath,
        projectFilter: config.projectFilter,
      );
      
      if (paths.isEmpty && effectivePattern != project) {
        return NavigationResult.error(
            'No project found matching name: $project');
      }
      
      results = config.usePathExclude ? filterByPath(paths, exclude) : paths;
    } else if (scan != null) {
      final scanDir = _resolvePath(scan, basePath);
      final paths = await discovery.scanForProjects(
        scanDir,
        recursive: recursive,
        recursionExclude:
            config.useRecursionExclude ? recursionExclude : const [],
      );
      results = config.usePathExclude ? filterByPath(paths, exclude) : paths;
    } else {
      results = [basePath];
    }

    // Phase 2: Apply name-based exclusions
    if (config.useNameExclude) {
      final wsRoot = findWorkspaceRoot(basePath);

      // Merge CLI excludeProjects with master config if applicable
      final allExcludeProjects = [...excludeProjects];
      if (config.useMasterConfigDefaults) {
        allExcludeProjects.addAll(loadMasterExcludeProjects(basePath));
      }

      results = filterByName(results, allExcludeProjects, wsRoot);
    }

    // Phase 3: Remove skipped projects
    if (config.useSkipFiles) {
      results = filterSkippedProjects(
        results,
        verbose: verbose,
        log: log,
        basename: toolBasename,
      );
    }

    // Phase 4: Apply modules filter
    if (config.useModulesFilter && navArgs.modules.isNotEmpty) {
      final wsRoot = findWorkspaceRoot(basePath);
      results = ProjectDiscovery.applyModulesFilter(
        results,
        navArgs.modules,
        wsRoot,
        verbose: verbose,
        log: log,
      );
    }

    // Phase 5: Apply custom project filter
    if (config.projectFilter != null) {
      results = results.where(config.projectFilter!).toList();
    }

    // Phase 6: Apply build order sorting
    if (config.useBuildOrder && navArgs.buildOrder && results.length > 1) {
      final sorted = sortByBuildOrder(results);
      if (sorted != null) {
        results = sorted;
      }
      // If sorting fails (circular deps), keep original order
    }

    return NavigationResult(paths: results);
  }

  /// Check if a pattern contains glob characters.
  bool _isGlobPattern(String pattern) {
    return pattern.contains('*') ||
        pattern.contains('?') ||
        pattern.contains('[') ||
        pattern.contains(',');
  }

  /// Resolve a path relative to a base.
  String _resolvePath(String path, String basePath) {
    if (p.isAbsolute(path)) return path;
    return p.normalize(p.join(basePath, path));
  }

  // ===========================================================================
  // Git Repository Discovery
  // ===========================================================================

  /// Find all git repositories under the given root path.
  ///
  /// Recursively scans directories looking for `.git` folders.
  /// Skips hidden directories, common build artifacts, and directories
  /// with `buildkit_skip.yaml`.
  List<String> findGitRepositories(String rootPath) {
    final repos = <String>[];
    final rootDir = Directory(rootPath);

    void scanDirectory(Directory dir) {
      // Check if this directory is a git repo
      final gitPath = p.join(dir.path, '.git');
      if (Directory(gitPath).existsSync() || File(gitPath).existsSync()) {
        repos.add(dir.path);
      }

      // Scan subdirectories
      try {
        for (final entity in dir.listSync(followLinks: false)) {
          if (entity is Directory) {
            final name = p.basename(entity.path);
            // Skip hidden directories
            if (name.startsWith('.')) continue;
            // Skip excluded directories
            if (_isExcludedDirectory(name)) continue;
            // Check for skip file if enabled
            if (config.useSkipFiles &&
                hasSkipFile(entity.path, basename: toolBasename)) {
              continue;
            }

            scanDirectory(entity);
          }
        }
      } catch (e) {
        // Ignore permission errors etc.
      }
    }

    scanDirectory(rootDir);
    return repos;
  }

  /// Check if a directory name should be excluded from git scanning.
  bool _isExcludedDirectory(String name) {
    const excluded = {
      'node_modules',
      'build',
      '.dart_tool',
      '.pub-cache',
      '.gradle',
      '__pycache__',
    };
    return excluded.contains(name);
  }

  // ===========================================================================
  // Build Order Sorting
  // ===========================================================================

  /// Sort projects by dependency build order.
  ///
  /// Returns projects sorted so that dependencies come before dependents.
  /// Returns null if circular dependencies are detected.
  ///
  /// By default only regular dependencies are considered. Set [includeDev]
  /// to true to also consider dev_dependencies.
  List<String>? sortByBuildOrder(
    List<String> projects, {
    bool includeDev = false,
  }) {
    // Parse all project infos
    final infos = <String, _ProjectInfo>{};
    final nameToPath = <String, String>{};

    for (final projectPath in projects) {
      final info = _parseProjectInfo(projectPath);
      if (info == null) continue;
      infos[projectPath] = info;
      nameToPath[info.name] = projectPath;
    }

    // Build set of workspace package names for filtering
    final workspaceNames = nameToPath.keys.toSet();

    // Build adjacency: project → set of workspace projects it depends on
    final dependsOn = <String, Set<String>>{};
    for (final entry in infos.entries) {
      final path = entry.key;
      final info = entry.value;
      final deps = <String>{};

      for (final depName in info.dependencies) {
        if (workspaceNames.contains(depName)) {
          final depPath = nameToPath[depName]!;
          if (depPath != path) deps.add(depPath);
        }
      }

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

    // Compute in-degrees (number of workspace dependencies)
    final inDegree = <String, int>{};
    for (final entry in dependsOn.entries) {
      inDegree[entry.key] = entry.value.length;
    }

    // Initialize queue with all zero-degree nodes
    final queue = <String>[];
    for (final path in inDegree.keys) {
      if (inDegree[path] == 0) queue.add(path);
    }
    queue.sort((a, b) => p.basename(a).compareTo(p.basename(b)));

    final result = <String>[];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      result.add(current);

      // Remove this project from others' dependencies
      for (final entry in dependsOn.entries) {
        if (entry.value.contains(current)) {
          entry.value.remove(current);
          inDegree[entry.key] = inDegree[entry.key]! - 1;
          if (inDegree[entry.key] == 0) {
            queue.add(entry.key);
            queue.sort((a, b) => p.basename(a).compareTo(p.basename(b)));
          }
        }
      }
    }

    // Check for circular dependencies
    if (result.length != infos.length) {
      final remaining = infos.keys.where((k) => !result.contains(k)).toList();
      log('Error: Circular dependency detected among: '
          '${remaining.map((p2) => p.basename(p2)).join(', ')}');
      return null;
    }

    return result;
  }

  /// Parse project info from pubspec.yaml.
  _ProjectInfo? _parseProjectInfo(String projectPath) {
    final pubspec = File(p.join(projectPath, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return null;

    try {
      final content = pubspec.readAsStringSync();
      final yaml = loadYaml(content);
      if (yaml is! Map) return null;

      final name = yaml['name'] as String?;
      if (name == null) return null;

      final deps = <String>[];
      final devDeps = <String>[];

      final dependencies = yaml['dependencies'];
      if (dependencies is Map) {
        deps.addAll(dependencies.keys.cast<String>());
      }

      final devDependencies = yaml['dev_dependencies'];
      if (devDependencies is Map) {
        devDeps.addAll(devDependencies.keys.cast<String>());
      }

      return _ProjectInfo(
        name: name,
        dependencies: deps,
        devDependencies: devDeps,
      );
    } catch (e) {
      return null;
    }
  }

  // ===========================================================================
  // Filtering Methods (Static for reuse)
  // ===========================================================================

  /// Filter projects by exclusion patterns using glob matching on full path.
  static List<String> filterByPath(
    List<String> projects,
    List<String> exclude,
  ) {
    if (exclude.isEmpty) return projects;

    return projects.where((path) {
      for (final pattern in exclude) {
        try {
          if (Glob(pattern).matches(path)) return false;
        } catch (_) {
          if (path.contains(pattern)) return false;
        }
      }
      return true;
    }).toList();
  }

  /// Filter projects by exclude-projects patterns.
  ///
  /// Patterns containing `/` or `**` are matched against workspace-relative paths.
  /// Other patterns are matched against folder basename only.
  static List<String> filterByName(
    List<String> projects,
    List<String> excludePatterns,
    String wsRoot,
  ) {
    if (excludePatterns.isEmpty) return projects;

    return projects.where((projectPath) {
      final folderName = p.basename(projectPath);
      final relativePath = p.relative(projectPath, from: wsRoot);
      for (final pattern in excludePatterns) {
        final isPathPattern = pattern.contains('/') || pattern.contains('**');
        final matchTarget = isPathPattern ? relativePath : folderName;
        try {
          if (Glob(pattern).matches(matchTarget)) return false;
        } catch (_) {
          if (matchTarget.contains(pattern)) return false;
        }
      }
      return true;
    }).toList();
  }

  /// Remove projects that contain a skip file.
  ///
  /// Checks for `tom_skip.yaml` (global) and `{basename}_skip.yaml` (tool-specific).
  static List<String> filterSkippedProjects(
    List<String> projects, {
    bool verbose = false,
    void Function(String)? log,
    String? basename,
  }) {
    final logFn = log ?? print;
    return projects.where((projectPath) {
      final skipFileName = ProjectDiscovery.getSkipFileName(
        projectPath,
        basename: basename,
      );
      if (skipFileName != null) {
        if (verbose) {
          logFn('  Skipping ($skipFileName): $projectPath');
        }
        return false;
      }
      return true;
    }).toList();
  }

  /// Check if a directory contains a skip file.
  ///
  /// Checks for `tom_skip.yaml` (global) and `{basename}_skip.yaml` (tool-specific).
  static bool hasSkipFile(String dirPath, {String? basename}) {
    return ProjectDiscovery.hasSkipFile(dirPath, basename: basename);
  }

  // ===========================================================================
  // Master Config Loading
  // ===========================================================================

  /// Load navigation defaults from `buildkit_master.yaml`.
  static NavigationDefaults? loadNavigationDefaults(String basePath) {
    final masterYaml = _loadMasterConfig(basePath);
    if (masterYaml == null) return null;
    final nav = masterYaml['navigation'] as YamlMap?;
    if (nav == null) return null;
    return NavigationDefaults(
      scan: nav['scan'] as String?,
      recursive: nav['recursive'] as bool? ?? false,
      exclude: toStringList(nav['exclude']),
      recursionExclude:
          toStringList(nav['recursion-exclude'] ?? nav['recursionExclude']),
      excludeProjects:
          toStringList(nav['exclude-projects'] ?? nav['excludeProjects']),
    );
  }

  /// Load `exclude-projects` from the master YAML navigation section.
  static List<String> loadMasterExcludeProjects(String basePath) {
    final masterYaml = _loadMasterConfig(basePath);
    if (masterYaml == null) return [];
    final nav = masterYaml['navigation'] as YamlMap?;
    if (nav == null) return [];
    return toStringList(nav['exclude-projects'] ?? nav['excludeProjects']);
  }

  /// Load the master config YAML from the workspace root.
  static YamlMap? _loadMasterConfig(String basePath) {
    final wsRoot = findWorkspaceRoot(basePath);
    final masterFile = File(p.join(wsRoot, kBuildkitMasterYaml));
    if (!masterFile.existsSync()) return null;

    try {
      final content = masterFile.readAsStringSync();
      final yaml = loadYaml(content);
      if (yaml is YamlMap) return yaml;
      return null;
    } catch (e) {
      return null;
    }
  }
}

/// Internal class for project dependency info.
class _ProjectInfo {
  final String name;
  final List<String> dependencies;
  final List<String> devDependencies;

  _ProjectInfo({
    required this.name,
    required this.dependencies,
    required this.devDependencies,
  });
}
