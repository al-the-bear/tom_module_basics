import 'dart:io';

import 'package:args/args.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';
import 'package:yaml/yaml.dart';

import '../version.g.dart';

/// Filename for the workspace-level build configuration.
const kBuildkitMasterYaml = 'buildkit_master.yaml';

/// Filename for the project-level build configuration.
const kBuildkitYaml = 'buildkit.yaml';

/// Filename that marks a directory (and all subdirectories) as excluded
/// from buildkit processing.
///
/// When present in a directory, no tool will process that directory or
/// any of its children. If the directory is a git repository root,
/// tests will also skip git commit/checkout operations for it.
const kBuildkitSkipYaml = 'buildkit_skip.yaml';

/// Base class for all integrated build tools.
///
/// Provides common infrastructure: argument parsing, project discovery,
/// config loading, verbose/dry-run support, and shared utility methods.
abstract class ToolBase {
  /// Tool key used in buildkit.yaml (e.g., 'cleanup', 'versioner').
  String get toolKey;

  /// Short description for help text.
  String get toolDescription;

  /// Whether verbose output is enabled.
  bool verbose = false;

  /// Whether dry-run mode is enabled.
  bool dryRun = false;

  /// Set to true when [findProjects] encounters a validation error
  /// (e.g., non-existent `--project` path). Tools should check this
  /// after calling [findProjects] and return false if set.
  bool findProjectsError = false;

  /// Run the tool with the given arguments.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> run(List<String> args);

  /// Check if the first argument is a version request.
  ///
  /// Supports `version`, `--version`, `-version`, and `-V` as first argument.
  /// Returns true if version was printed (caller should return).
  bool checkVersionArg(List<String> args) {
    if (isVersionCommand(args)) {
      print('$toolKey ${BuildkitVersionInfo.versionLong}');
      return true;
    }
    return false;
  }

  /// Check if the first argument is a help request.
  ///
  /// Supports `help`, `--help`, `-help`, and `-h` as first argument.
  /// Returns true if help was requested (caller should print usage and return).
  bool checkHelpArg(List<String> args) {
    return isHelpCommand(args);
  }

  /// Print the tool usage header in standardized format.
  ///
  /// Prints: tool name, description, usage patterns, help/version commands.
  /// Call before printing tool-specific options.
  void printUsageHeader() {
    final header = getToolHelpHeader(
      toolName: toolKey,
      toolDescription: toolDescription,
      usagePatterns: [
        '$toolKey [options]',
        'buildkit :$toolKey [options]',
        'dart run tom_build_kit:$toolKey [options]',
      ],
    );
    for (final line in header) {
      print(line);
    }
  }

  /// Print the standardized navigation options help.
  void printNavigationHelp() {
    printNavigationOptionsHelp();
  }

  /// Print just the execution modes explanation.
  ///
  /// Use this when the navigation options are already printed via parser.usage
  /// and you only need to add the execution modes explanation.
  void printExecutionModesExplanation() {
    printExecutionModesHelp();
  }

  /// Print the tool usage footer with examples.
  ///
  /// Prints common examples using the tool's name.
  void printUsageFooter() {
    final footer = getToolHelpFooter(toolName: toolKey);
    for (final line in footer) {
      print(line);
    }
  }

  /// Create the argument parser with common options.
  ///
  /// Subclasses override [addToolOptions] to add tool-specific options.
  ArgParser createParser() {
    final parser = ArgParser(allowTrailingOptions: false)
      ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help')
      ..addFlag('verbose',
          abbr: 'v', negatable: false, help: 'Verbose output');
    addNavigationOptions(parser);
    parser
      ..addFlag('list',
          abbr: 'l', negatable: false, help: 'List matching projects')
      ..addFlag('show',
          negatable: false, help: 'Show configuration for project')
      ..addFlag('dry-run',
          abbr: 'n', negatable: false, help: 'Show what would be done');

    addToolOptions(parser);
    return parser;
  }

  /// Override to add tool-specific options to the parser.
  void addToolOptions(ArgParser parser) {}

  /// Parse arguments with execution mode handling.
  ///
  /// Returns a tuple containing:
  /// - [ArgResults] from parsing the processed args
  /// - [WorkspaceNavigationArgs] with appropriate defaults applied
  /// - [String] executionRoot - the directory to execute from
  ///
  /// Handles:
  /// - Preprocessing for bare -R detection
  /// - Parsing navigation options
  /// - Applying project mode defaults (--scan . --recursive --build-order)
  /// - Resolving execution root based on -R
  ///
  /// Throws [FormatException] if argument parsing fails.
  /// Throws [ArgumentError] if specified workspace path is invalid.
  (ArgResults, WorkspaceNavigationArgs, String) parseArgsWithExecutionMode(
    ArgParser parser,
    List<String> args,
  ) {
    // Step 1: Preprocess args to detect bare -R
    final (processedArgs, bareRoot) = preprocessRootFlag(args);

    // Step 2: Parse args
    final results = parser.parse(processedArgs);

    // Step 3: Parse navigation options
    var navArgs = parseNavigationArgs(results, bareRoot: bareRoot);

    // Step 4: Apply defaults (scan, recursive, build-order)
    navArgs = navArgs.withDefaults();

    // Step 5: Resolve execution root
    final currentDir = Directory.current.path;
    final executionRoot = resolveExecutionRoot(navArgs, currentDir: currentDir);

    // Step 6: If bare -R, change to workspace root directory
    if (navArgs.bareRoot && executionRoot != currentDir) {
      if (verbose) {
        print('[workspace-mode] Bare -R: executing from $executionRoot');
      }
    } else if (navArgs.root != null && executionRoot != currentDir) {
      if (verbose) {
        print('[workspace-mode] -R ${navArgs.root}: executing from $executionRoot');
      }
    } else if (navArgs.isProjectMode) {
      if (verbose) {
        print('[project-mode] Executing from $currentDir');
      }
    }

    return (results, navArgs, executionRoot);
  }

  /// Find projects using [WorkspaceNavigationArgs].
  ///
  /// This is the preferred method for finding projects as it uses
  /// the standardized navigation options.
  Future<List<String>> findProjectsFromNavArgs(
    WorkspaceNavigationArgs navArgs, {
    required String basePath,
  }) async {
    return findProjects(
      project: navArgs.project,
      scan: navArgs.scan,
      recursive: navArgs.recursive,
      exclude: navArgs.exclude,
      excludeProjects: navArgs.excludeProjects,
      recursionExclude: navArgs.recursionExclude,
      modules: navArgs.modules,
      basePath: basePath,
    );
  }

  /// Find projects based on common config fields.
  ///
  /// The [excludeProjects] patterns are merged with any `exclude-projects`
  /// defined in the `navigation:` section of `buildkit_master.yaml`.
  ///
  /// When [project] is specified and is not a glob pattern, validates
  /// that the path exists. Returns an empty list and prints an error
  /// if the path does not exist.
  ///
  /// When neither [project] nor [scan] is provided, loads navigation
  /// defaults from `buildkit_master.yaml` (`navigation:` section).
  /// If the master config defines `scan:`, that is used as the default;
  /// otherwise falls back to processing only the current directory.
  ///
  /// When [modules] is provided, filters results to only include projects
  /// within the specified git modules (repositories).
  Future<List<String>> findProjects({
    String? project,
    String? scan,
    bool recursive = false,
    List<String> exclude = const [],
    List<String> excludeProjects = const [],
    List<String> recursionExclude = const [],
    List<String> modules = const [],
    required String basePath,
  }) async {
    final discovery = ProjectDiscovery(verbose: verbose);
    findProjectsError = false;

    // When no explicit --project or --scan, load defaults from master YAML.
    // If no master config exists, fall back to --scan . --recursive.
    if (project == null && scan == null) {
      final navDefaults = _loadNavigationDefaults(basePath);
      if (navDefaults != null) {
        scan = navDefaults.scan;
        recursive = navDefaults.recursive || recursive;
        if (navDefaults.exclude.isNotEmpty && exclude.isEmpty) {
          exclude = navDefaults.exclude;
        }
        if (navDefaults.recursionExclude.isNotEmpty &&
            recursionExclude.isEmpty) {
          recursionExclude = navDefaults.recursionExclude;
        }
      } else {
        // Hardcoded fallback: --scan . --recursive
        scan = '.';
        recursive = true;
      }
    }

    List<String> results;
    if (project != null) {
      // Validate --project path existence for non-glob patterns
      if (!project.contains('*') &&
          !project.contains('?') &&
          !project.contains('[') &&
          !project.contains(',')) {
        final resolvedPath = p.isAbsolute(project)
            ? project
            : p.normalize(p.join(basePath, project));
        if (!Directory(resolvedPath).existsSync()) {
          print('Error: Project path does not exist: $project');
          findProjectsError = true;
          return [];
        }
      }

      final paths = await discovery.resolveProjectPatterns(
        project,
        basePath: basePath,
      );
      results = _filterProjects(paths, exclude);
    } else if (scan != null) {
      final scanDir = _resolvePath(scan, basePath);
      final paths = await discovery.scanForProjects(
        scanDir,
        recursive: recursive,
        toolKey: toolKey,
        recursionExclude: recursionExclude,
      );
      results = _filterProjects(paths, exclude);
    } else {
      results = [basePath];
    }

    // Merge CLI --exclude-projects with master YAML navigation section
    final allExcludeProjects = [
      ...excludeProjects,
      ..._loadMasterExcludeProjects(basePath),
    ];

    // Apply --exclude-projects filtering
    final wsRoot = findWorkspaceRoot(basePath);
    results = _filterProjectsByName(results, allExcludeProjects, wsRoot);

    // Remove projects that contain buildkit_skip.yaml
    results = _filterSkippedProjects(results);

    // Apply --modules filtering (include only projects within specified modules)
    if (modules.isNotEmpty) {
      results = ProjectDiscovery.applyModulesFilter(
        results,
        modules,
        wsRoot,
        verbose: verbose,
        log: (msg) => print(msg),
      );
    }

    return results;
  }

  /// Load `exclude-projects` from the master YAML navigation section.
  List<String> _loadMasterExcludeProjects(String basePath) {
    final masterYaml = loadMasterConfig(basePath);
    if (masterYaml == null) return [];
    final nav = masterYaml['navigation'] as YamlMap?;
    if (nav == null) return [];
    return toStringList(nav['exclude-projects'] ?? nav['excludeProjects']);
  }

  /// Load navigation defaults (scan, recursive, exclude, recursion-exclude)
  /// from `buildkit_master.yaml`'s `navigation:` section.
  ///
  /// Returns null if no master config or no navigation section is found.
  _NavigationDefaults? _loadNavigationDefaults(String basePath) {
    final masterYaml = loadMasterConfig(basePath);
    if (masterYaml == null) return null;
    final nav = masterYaml['navigation'] as YamlMap?;
    if (nav == null) return null;
    return _NavigationDefaults(
      scan: nav['scan'] as String?,
      recursive: nav['recursive'] as bool? ?? false,
      exclude: toStringList(nav['exclude']),
      recursionExclude: toStringList(
          nav['recursion-exclude'] ?? nav['recursionExclude']),
    );
  }

  /// Check if a directory is a project this tool should process.
  bool isToolProject(String dirPath);

  /// Filter projects by exclusion patterns using glob matching on full path.
  List<String> _filterProjects(
      List<String> projects, List<String> exclude) {
    if (exclude.isEmpty) return projects;

    return projects.where((path) {
      for (final pattern in exclude) {
        try {
          if (Glob(pattern).matches(path)) return false;
        } catch (_) {
          // Fallback to substring match for non-glob patterns
          if (path.contains(pattern)) return false;
        }
      }
      return true;
    }).toList();
  }

  /// Filter projects by exclude-projects patterns.
  ///
  /// Patterns that contain `/` or `**` are treated as **path patterns** and
  /// matched against the workspace-relative path (e.g. `xternal/tom_module_basics/*`,
  /// `**/tom_module_basics/*`).
  ///
  /// All other patterns are treated as **folder name patterns** and matched
  /// against the directory basename only (e.g. `zom_*`, `tom_test_*`).
  List<String> _filterProjectsByName(
      List<String> projects, List<String> excludePatterns, String wsRoot) {
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

  /// Remove projects that contain a [kBuildkitSkipYaml] file.
  ///
  /// Also checks all parent directories up to (but not above) the workspace
  /// root — if any ancestor has the skip file, the project is excluded.
  List<String> _filterSkippedProjects(List<String> projects) {
    return projects.where((projectPath) {
      if (hasSkipFile(projectPath)) {
        if (verbose) {
          print('  Skipping ($kBuildkitSkipYaml): $projectPath');
        }
        return false;
      }
      return true;
    }).toList();
  }

  /// Check if a directory contains a [kBuildkitSkipYaml] file.
  static bool hasSkipFile(String dirPath) {
    return File(p.join(dirPath, kBuildkitSkipYaml)).existsSync();
  }

  /// Validate path containment and print error if invalid.
  ///
  /// Returns true if paths are valid, false if validation fails.
  bool validateAndEnforcePaths({
    String? scan,
    String? project,
    required String basePath,
  }) {
    final error = validatePathContainment(
      scan: scan,
      project: project,
      basePath: basePath,
    );
    if (error != null) {
      print('Error: $error');
      return false;
    }
    return true;
  }

  /// Resolve a path relative to a base.
  String _resolvePath(String path, String basePath) {
    if (path.startsWith('/')) return path;
    return '$basePath/$path';
  }

  // ---------------------------------------------------------------------------
  // Workspace root discovery
  // ---------------------------------------------------------------------------

  /// Find the workspace root by traversing upwards looking for
  /// `buildkit_master.yaml` or `tom_workspace.yaml`.
  ///
  /// Returns the directory containing the workspace config, or [startPath]
  /// if none is found.
  static String findWorkspaceRoot(String startPath) {
    var current = p.normalize(p.absolute(startPath));
    final root = p.rootPrefix(current);

    while (current != root) {
      if (File(p.join(current, kBuildkitMasterYaml)).existsSync() ||
          File(p.join(current, 'tom_workspace.yaml')).existsSync() ||
          File(p.join(current, 'tom.code-workspace')).existsSync()) {
        return current;
      }
      current = p.dirname(current);
    }

    return startPath;
  }

  /// Load the workspace-level master config ([kBuildkitMasterYaml]).
  ///
  /// Traverses up from [startDir] to find the workspace root,
  /// then loads `buildkit_master.yaml` from there.
  /// Returns null if not found.
  static YamlMap? loadMasterConfig(String startDir) {
    final wsRoot = findWorkspaceRoot(startDir);
    final file = File(p.join(wsRoot, kBuildkitMasterYaml));
    if (!file.existsSync()) return null;
    try {
      final content = file.readAsStringSync();
      return loadYaml(content) as YamlMap?;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Shared YAML utilities
  // ---------------------------------------------------------------------------

  /// Load buildkit.yaml from a directory, returning the parsed YAML map.
  YamlMap? loadTomBuildYaml(String dir) {
    final file = File('$dir/buildkit.yaml');
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

  /// Print a buildkit.yaml section for a specific key (for --show).
  void printTomBuildYamlSection(String projectPath, String sectionKey) {
    final file = File('$projectPath/buildkit.yaml');
    if (!file.existsSync()) {
      print('  No buildkit.yaml found');
      return;
    }
    try {
      final content = file.readAsStringSync();
      final yaml = loadYaml(content) as YamlMap?;
      final section = yaml?[sectionKey];
      if (section == null) {
        print('  No $sectionKey section in buildkit.yaml');
        return;
      }
      print('  buildkit.yaml ($sectionKey):');
      printYamlNode(section, indent: 2);
    } catch (e) {
      print('  Error reading buildkit.yaml: $e');
    }
  }
}

/// Navigation defaults loaded from `buildkit_master.yaml`.
class _NavigationDefaults {
  final String? scan;
  final bool recursive;
  final List<String> exclude;
  final List<String> recursionExclude;

  const _NavigationDefaults({
    this.scan,
    this.recursive = false,
    this.exclude = const [],
    this.recursionExclude = const [],
  });
}
