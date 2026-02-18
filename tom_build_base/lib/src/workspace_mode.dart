import 'package:args/args.dart';
import 'package:dcli/dcli.dart';
import 'package:path/path.dart' as p;

/// Constants for workspace configuration files.
const kBuildkitMasterYaml = 'buildkit_master.yaml';
const kTomWorkspaceYaml = 'tom_workspace.yaml';
const kTomCodeWorkspace = 'tom.code-workspace';
const kBuildkitSkipYaml = 'buildkit_skip.yaml';

/// Represents the execution mode for a tool.
enum ExecutionMode {
  /// Default mode: operates on current directory with auto-applied defaults.
  project,

  /// Workspace mode: triggered by navigation options like `-R`, `-s <path>`, `-i`, `-o`.
  workspace,
}

/// Parsed navigation options for workspace traversal.
///
/// Used to configure project discovery behavior across all Tom build tools.
class WorkspaceNavigationArgs {
  /// Scan directory for projects.
  final String? scan;

  /// Scan directories recursively.
  final bool recursive;

  /// True if recursive flag was explicitly set by user (--recursive or --no-recursive).
  ///
  /// Used to determine if defaults should be applied or user's explicit choice honored.
  final bool recursiveExplicitlySet;

  /// Sort projects in dependency build order.
  final bool buildOrder;

  /// Specific project(s) to run on.
  final String? project;

  /// Workspace root path (from `-R <path>`).
  ///
  /// If [bareRoot] is true and this is null, use detected workspace root.
  final String? root;

  /// True if bare -R was used (without path argument).
  final bool bareRoot;

  /// Shell out to sub-workspaces instead of skipping.
  final bool workspaceRecursion;

  /// Scan git repos, process innermost (deepest) first.
  final bool innerFirstGit;

  /// Scan git repos, process outermost (shallowest) first.
  final bool outerFirstGit;

  /// Find topmost git repo by traversing up from current directory.
  ///
  /// When set, traverses up the directory tree to find the outermost
  /// git repository and uses that as the root for subsequent traversal.
  /// Can be combined with [innerFirstGit] or [outerFirstGit].
  final bool topRepo;

  /// Exclude patterns (path-based globs).
  final List<String> exclude;

  /// Exclude projects by name or path.
  final List<String> excludeProjects;

  /// Exclude patterns during recursive scan.
  final List<String> recursionExclude;

  /// Include only projects within specified git modules (comma-separated).
  ///
  /// Module names are git repository folder names (e.g., "tom_module_d4rt").
  /// Use "root" or "tom" to reference the main repository.
  final List<String> modules;

  /// Active modes for configuration processing.
  ///
  /// Modes are workspace-wide configuration dimensions (e.g., DEV, CI, PROD).
  /// They affect how MODE-prefixed keys in config files are processed.
  final List<String> modes;

  WorkspaceNavigationArgs({
    this.scan,
    this.recursive = false,
    this.recursiveExplicitlySet = false,
    this.buildOrder = false,
    this.project,
    this.root,
    this.bareRoot = false,
    this.workspaceRecursion = false,
    this.innerFirstGit = false,
    this.outerFirstGit = false,
    this.topRepo = false,
    this.exclude = const [],
    this.excludeProjects = const [],
    this.recursionExclude = const [],
    this.modules = const [],
    this.modes = const [],
  });

  /// Determines the execution mode based on parsed arguments.
  ///
  /// Returns [ExecutionMode.workspace] if any workspace traversal option is used:
  /// - Bare `-R` or `-R <path>`
  /// - `-s <path>` where path is not "."
  /// - `-i` (inner-first-git)
  /// - `-o` (outer-first-git)
  /// - `-T` (top-repo)
  ExecutionMode get executionMode {
    if (bareRoot) return ExecutionMode.workspace;
    if (root != null) return ExecutionMode.workspace;
    if (scan != null && scan != '.') return ExecutionMode.workspace;
    if (innerFirstGit) return ExecutionMode.workspace;
    if (outerFirstGit) return ExecutionMode.workspace;
    if (topRepo) return ExecutionMode.workspace;
    return ExecutionMode.project;
  }

  /// Returns true if in workspace mode.
  bool get isWorkspaceMode => executionMode == ExecutionMode.workspace;

  /// Returns true if in project mode.
  bool get isProjectMode => executionMode == ExecutionMode.project;

  /// Apply default scanning behavior.
  ///
  /// Returns a new [WorkspaceNavigationArgs] with defaults applied:
  /// - `--scan .` (if no scan was specified)
  /// - `--recursive` (enabled unless explicitly disabled with --no-recursive)
  /// - `--build-order` (enabled unless explicitly disabled with --no-build-order)
  ///
  /// This applies in both project and workspace modes when no explicit
  /// scanning options are provided. The difference is which directory
  /// the scan runs from (current dir vs workspace root).
  WorkspaceNavigationArgs withDefaults() {
    // Only apply scan default if no explicit project/scan was given
    final needsScanDefault = scan == null && project == null;
    
    // Only apply recursive default if user didn't explicitly set it
    final effectiveRecursive = recursiveExplicitlySet 
        ? recursive 
        : (needsScanDefault || recursive);
    
    return WorkspaceNavigationArgs(
      scan: needsScanDefault ? '.' : scan,
      recursive: effectiveRecursive,
      recursiveExplicitlySet: recursiveExplicitlySet,
      buildOrder: needsScanDefault || buildOrder,
      project: project,
      root: root,
      bareRoot: bareRoot,
      workspaceRecursion: workspaceRecursion,
      innerFirstGit: innerFirstGit,
      outerFirstGit: outerFirstGit,
      topRepo: topRepo,
      exclude: exclude,
      excludeProjects: excludeProjects,
      recursionExclude: recursionExclude,
      modules: modules,
      modes: modes,
    );
  }

  /// Apply project mode defaults if in project mode.
  ///
  /// @deprecated Use [withDefaults] instead for consistent behavior.
  ///
  /// Returns a new [WorkspaceNavigationArgs] with defaults applied:
  /// - `--scan .`
  /// - `--recursive` (unless explicitly disabled)
  /// - `--build-order`
  ///
  /// In workspace mode, no defaults are applied - use explicit options.
  WorkspaceNavigationArgs withProjectModeDefaults() {
    if (isWorkspaceMode) return this;

    // Respect explicit --no-recursive
    final effectiveRecursive = recursiveExplicitlySet ? recursive : true;

    return WorkspaceNavigationArgs(
      scan: scan ?? '.',
      recursive: effectiveRecursive,
      recursiveExplicitlySet: recursiveExplicitlySet,
      buildOrder: true,
      project: project,
      root: root,
      bareRoot: bareRoot,
      workspaceRecursion: workspaceRecursion,
      innerFirstGit: innerFirstGit,
      outerFirstGit: outerFirstGit,
      topRepo: topRepo,
      exclude: exclude,
      excludeProjects: excludeProjects,
      recursionExclude: recursionExclude,
      modules: modules,
      modes: modes,
    );
  }

  /// Create a copy with modified values.
  WorkspaceNavigationArgs copyWith({
    String? scan,
    bool? recursive,
    bool? recursiveExplicitlySet,
    bool? buildOrder,
    String? project,
    String? root,
    bool? bareRoot,
    bool? workspaceRecursion,
    bool? innerFirstGit,
    bool? outerFirstGit,
    bool? topRepo,
    List<String>? exclude,
    List<String>? excludeProjects,
    List<String>? recursionExclude,
    List<String>? modules,
    List<String>? modes,
  }) {
    return WorkspaceNavigationArgs(
      scan: scan ?? this.scan,
      recursive: recursive ?? this.recursive,
      recursiveExplicitlySet: recursiveExplicitlySet ?? this.recursiveExplicitlySet,
      buildOrder: buildOrder ?? this.buildOrder,
      project: project ?? this.project,
      root: root ?? this.root,
      bareRoot: bareRoot ?? this.bareRoot,
      workspaceRecursion: workspaceRecursion ?? this.workspaceRecursion,
      innerFirstGit: innerFirstGit ?? this.innerFirstGit,
      outerFirstGit: outerFirstGit ?? this.outerFirstGit,
      topRepo: topRepo ?? this.topRepo,
      exclude: exclude ?? this.exclude,
      excludeProjects: excludeProjects ?? this.excludeProjects,
      recursionExclude: recursionExclude ?? this.recursionExclude,
      modules: modules ?? this.modules,
      modes: modes ?? this.modes,
    );
  }

  @override
  String toString() =>
      'WorkspaceNavigationArgs(mode=${executionMode.name}, scan=$scan, '
      'recursive=$recursive${recursiveExplicitlySet ? '(explicit)' : ''}, '
      'buildOrder=$buildOrder, project=$project, '
      'root=$root, bareRoot=$bareRoot, workspaceRecursion=$workspaceRecursion, '
      'innerFirstGit=$innerFirstGit, outerFirstGit=$outerFirstGit, topRepo=$topRepo)';
}

/// Add common workspace navigation options to an ArgParser.
///
/// Adds the following options:
/// - `-s, --scan` - Scan directory for projects
/// - `-r, --recursive` - Scan directories recursively (supports --no-recursive)
/// - `-b, --build-order` - Sort projects in dependency build order (supports --no-build-order)
/// - `-p, --project` - Project(s) to run on
/// - `-R, --root` - Workspace root (bare: detected, path: specified workspace)
/// - `-w, --workspace-recursion` - Shell out to sub-workspaces instead of skipping
/// - `-i, --inner-first-git` - Scan git repos, process innermost first
/// - `-o, --outer-first-git` - Scan git repos, process outermost first
/// - `-T, --top-repo` - Find topmost git repo by traversing up
/// - `-x, --exclude` - Exclude patterns (path-based globs)
/// - `--exclude-projects` - Exclude projects by name or path
/// - `--recursion-exclude` - Exclude patterns during recursive scan
/// - `-m, --modules` - Include only projects within specified git modules
void addNavigationOptions(ArgParser parser) {
  parser.addOption('scan',
      abbr: 's', help: 'Scan directory for projects');
  parser.addFlag('recursive',
      abbr: 'r',
      negatable: true,
      defaultsTo: false,
      help: 'Scan directories recursively (use --no-recursive to disable)');
  parser.addFlag('build-order',
      abbr: 'b',
      negatable: true,
      defaultsTo: false,
      help: 'Sort projects in dependency build order (use --no-build-order to disable)');
  parser.addOption('project',
      abbr: 'p', help: 'Project(s) to run (comma-separated, globs supported)');
  parser.addOption('root',
      abbr: 'R',
      help: 'Workspace root (bare: detected, path: specified workspace)');
  parser.addFlag('workspace-recursion',
      abbr: 'w',
      negatable: false,
      help: 'Shell out to sub-workspaces instead of skipping');
  parser.addFlag('inner-first-git',
      abbr: 'i',
      negatable: false,
      help: 'Scan git repos, process innermost (deepest) first');
  parser.addFlag('outer-first-git',
      abbr: 'o',
      negatable: false,
      help: 'Scan git repos, process outermost (shallowest) first');
  parser.addFlag('top-repo',
      abbr: 'T',
      negatable: false,
      help: 'Find topmost git repo by traversing up from current directory');
  parser.addMultiOption('exclude',
      abbr: 'x', help: 'Exclude patterns (path-based globs)');
  parser.addMultiOption('exclude-projects',
      help:
          'Exclude projects by name or path (e.g. zom_*, xternal/tom_module_basics/*)');
  parser.addMultiOption('recursion-exclude',
      help: 'Exclude patterns during recursive scan');
  parser.addOption('modules',
      abbr: 'm',
      help:
          'Include only projects within specified git modules (comma-separated, e.g. tom_module_d4rt,tom_module_basics)');
  parser.addOption('modes',
      help:
          'Active modes for config processing (comma-separated, e.g. DEV,CI). Overrides tom_workspace.yaml default.');
}

/// Preprocess command-line arguments to handle special -R behavior.
///
/// The -R/--root flag can be used in two ways:
/// 1. Bare `-R` - Use detected workspace root
/// 2. `-R <path>` - Use specified path as workspace root
///
/// Since ArgParser can't distinguish between these, this function
/// preprocesses args to detect the bare -R case.
///
/// Returns a record with:
/// - `processedArgs`: The args with bare -R converted to `--root=BARE_ROOT_MARKER`
/// - `bareRoot`: Whether bare -R was detected
(List<String> processedArgs, bool bareRoot) preprocessRootFlag(
    List<String> args) {
  final processedArgs = <String>[];
  var bareRoot = false;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];

    // Check for bare -R (not followed by a path)
    if (arg == '-R' || arg == '--root') {
      // Check if next argument is a path or another flag/command
      final hasNextArg = i + 1 < args.length;
      final nextArg = hasNextArg ? args[i + 1] : null;

      // If no next arg, or next arg starts with - (flag), or next arg
      // is a pipeline/command (starts with : or is a known command),
      // treat as bare -R
      if (!hasNextArg ||
          (nextArg != null &&
              (nextArg.startsWith('-') ||
                  nextArg.startsWith(':') ||
                  _isPipelineOrCommandName(nextArg)))) {
        bareRoot = true;
        // Add marker so parser knows -R was used
        processedArgs.add('--root=__BARE_ROOT__');
      } else {
        // -R with path - keep as is
        processedArgs.add(arg);
      }
    } else if (arg.startsWith('-R=') || arg.startsWith('--root=')) {
      // Explicit value form - keep as is
      processedArgs.add(arg);
    } else {
      processedArgs.add(arg);
    }
  }

  return (processedArgs, bareRoot);
}

/// Check if a string looks like a pipeline or command name rather than a path.
bool _isPipelineOrCommandName(String s) {
  // Pipeline names: simple identifiers like "build", "clean", etc.
  // Commands: start with ":" like ":versioner"
  if (s.startsWith(':')) return true;

  // Common pipeline names (heuristic)
  const commonPipelines = {
    'build',
    'clean',
    'release',
    'test',
    'deploy',
    'publish',
    'run',
    'help',
    'version',
    'defines',
    'define',
    'undefine',
  };
  if (commonPipelines.contains(s.toLowerCase())) return true;

  // If it looks like a simple identifier (no slashes, dots), it's likely a pipeline
  if (!s.contains('/') && !s.contains('.') && !s.contains(p.separator)) {
    return true;
  }

  return false;
}

/// Parse navigation options from ArgResults.
///
/// Call this after parsing with an ArgParser that has had
/// [addNavigationOptions] called on it.
///
/// The [bareRoot] parameter should come from [preprocessRootFlag].
WorkspaceNavigationArgs parseNavigationArgs(
  ArgResults results, {
  bool bareRoot = false,
}) {
  // Handle root value - check for bare root marker
  String? root = results['root'] as String?;
  if (root == '__BARE_ROOT__') {
    root = null;
    bareRoot = true;
  }

  // Check if recursive was explicitly set (--recursive or --no-recursive)
  final recursiveExplicitlySet = results.wasParsed('recursive');

  return WorkspaceNavigationArgs(
    scan: results['scan'] as String?,
    recursive: results['recursive'] as bool? ?? false,
    recursiveExplicitlySet: recursiveExplicitlySet,
    buildOrder: results['build-order'] as bool? ?? false,
    project: results['project'] as String?,
    root: root,
    bareRoot: bareRoot,
    workspaceRecursion: results['workspace-recursion'] as bool? ?? false,
    innerFirstGit: results['inner-first-git'] as bool? ?? false,
    outerFirstGit: results['outer-first-git'] as bool? ?? false,
    topRepo: results['top-repo'] as bool? ?? false,
    exclude: results['exclude'] as List<String>? ?? [],
    excludeProjects: results['exclude-projects'] as List<String>? ?? [],
    recursionExclude: results['recursion-exclude'] as List<String>? ?? [],
    modules: _parseModulesOption(results['modules'] as String?),
    modes: _parseModesOption(results['modes'] as String?),
  );
}

/// Parse comma-separated modes option into a list.
///
/// Modes are UPPERCASE identifiers (e.g., DEV, CI, PROD).
List<String> _parseModesOption(String? value) {
  if (value == null || value.isEmpty) return const [];
  return value
      .split(',')
      .map((s) => s.trim().toUpperCase())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Parse comma-separated modules option into a list.
///
/// Handles trimming whitespace around each module name.
List<String> _parseModulesOption(String? value) {
  if (value == null || value.isEmpty) return const [];
  return value
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Find the workspace root by traversing upwards looking for workspace markers.
///
/// Returns the directory containing `buildkit_master.yaml`, `tom_workspace.yaml`,
/// or `tom.code-workspace`, or [startPath] if none is found.
String findWorkspaceRoot(String startPath) {
  var current = truepath(startPath);
  final root = p.rootPrefix(current);

  while (current != root) {
    if (exists(p.join(current, kBuildkitMasterYaml)) ||
        exists(p.join(current, kTomWorkspaceYaml)) ||
        exists(p.join(current, kTomCodeWorkspace))) {
      return current;
    }
    current = p.dirname(current);
  }

  return startPath;
}

/// Check if a directory is a workspace boundary (contains buildkit_master.yaml).
///
/// Workspace boundaries are treated similarly to buildkit_skip.yaml - they
/// mark directories that should be processed separately unless -w is used.
bool isWorkspaceBoundary(String dirPath) {
  return exists(p.join(dirPath, kBuildkitMasterYaml));
}

/// Determine the execution root based on navigation args.
///
/// In workspace mode with bare `-R`, returns the detected workspace root.
/// In workspace mode with `-R <path>`, validates and returns that path.
/// In project mode, returns the current directory.
///
/// Throws [ArgumentError] if the specified root path is invalid.
String resolveExecutionRoot(
  WorkspaceNavigationArgs navArgs, {
  required String currentDir,
}) {
  if (navArgs.bareRoot) {
    // Bare -R: find workspace root
    return findWorkspaceRoot(currentDir);
  } else if (navArgs.root != null) {
    // -R <path>: validate specified workspace
    final specifiedPath =
        p.isAbsolute(navArgs.root!) ? navArgs.root! : p.join(currentDir, navArgs.root!);
    final resolved = truepath(specifiedPath);

    if (!exists(resolved) || !isDirectory(resolved)) {
      throw ArgumentError('Specified workspace does not exist: ${navArgs.root}');
    }
    if (!isWorkspaceBoundary(resolved)) {
      throw ArgumentError(
          'Specified path is not a workspace (no $kBuildkitMasterYaml): ${navArgs.root}');
    }
    return resolved;
  }

  // Project mode or no -R: use current directory
  return currentDir;
}

// =============================================================================
// CLI Commands (help, version)
// =============================================================================

/// Check if the first argument is a help command.
///
/// Returns true if `args[0]` is 'help', '-help', '-h', or '--help'.
/// Note: ArgParser also handles '-h' and '--help' flags, but this allows
/// `<tool> help` as a standalone command.
bool isHelpCommand(List<String> args) {
  if (args.isEmpty) return false;
  final first = args.first.toLowerCase();
  return first == 'help' || first == '-help' || first == '-h' || first == '--help';
}

/// Check if the first argument is a version command.
///
/// Returns true if `args[0]` is 'version', '-version', '-V', or '--version'.
bool isVersionCommand(List<String> args) {
  if (args.isEmpty) return false;
  final first = args.first.toLowerCase();
  return first == 'version' || first == '-version' || first == '-v' || first == '--version';
}

// =============================================================================
// Navigation Options Usage Text
// =============================================================================

/// Returns just the execution modes explanation.
///
/// Use this when the navigation options are already printed via ArgParser.usage
/// and you only need to add the execution modes explanation.
List<String> getExecutionModesHelpLines() {
  return [
    'Execution Modes:',
    '  Project Mode (default):   Runs from current directory with -s . -r -b defaults',
    '  Workspace Mode:           Runs from workspace root (triggered by -R, -s <path>, -i, -o)',
    '',
    '  -R alone triggers workspace mode from detected workspace root.',
    '  -R <path> runs in specified workspace (must have buildkit_master.yaml).',
    '  Sub-workspaces (containing buildkit_master.yaml) are skipped by default.',
    '  Use -w to shell out and process sub-workspaces recursively.',
  ];
}

/// Prints just the execution modes explanation to stdout.
void printExecutionModesHelp() {
  for (final line in getExecutionModesHelpLines()) {
    print(line);
  }
}

/// Returns the standard navigation options help text.
///
/// This is used to generate consistent help output across all Tom build tools.
/// The text describes the execution modes and all navigation options.
///
/// [toolName] is the name of the tool (e.g., 'astgen', 'd4rtgen', 'versioner').
/// [toolDescription] is a brief description of what the tool does.
/// [additionalUsageLines] are extra usage patterns specific to the tool.
List<String> getNavigationOptionsHelpLines() {
  return [
    'Execution Modes:',
    '  Project Mode (default):   Runs from current directory with -s . -r -b defaults',
    '  Workspace Mode:           Runs from workspace root (triggered by -R, -s <path>, -i, -o)',
    '',
    '  -R alone triggers workspace mode from detected workspace root.',
    '  -R <path> runs in specified workspace (must have buildkit_master.yaml).',
    '  Sub-workspaces (containing buildkit_master.yaml) are skipped by default.',
    '  Use -w to shell out and process sub-workspaces recursively.',
    '',
    'Navigation Options:',
    '  -s, --scan=<path>         Scan directory for projects',
    '  -r, --recursive           Scan directories recursively',
    '  -b, --build-order         Sort projects in dependency build order',
    '  -p, --project=<pattern>   Project(s) to run (comma-separated, globs supported)',
    '  -R, --root[=<path>]       Workspace root (bare: detected, path: specified)',
    '  -w, --workspace-recursion Shell out to sub-workspaces instead of skipping',
    '  -i, --inner-first-git     Scan git repos, process innermost (deepest) first',
    '  -o, --outer-first-git     Scan git repos, process outermost (shallowest) first',
    '  -x, --exclude=<glob>      Exclude patterns (path-based globs)',
    '      --exclude-projects=<pattern>  Exclude projects by name or path',
    '      --recursion-exclude=<glob>    Exclude patterns during recursive scan',
    '  -m, --modules=<names>     Include only projects within specified git modules',
    '                            (comma-separated, use "root" or "tom" for main repo)',
  ];
}

/// Prints the navigation options help text to stdout.
void printNavigationOptionsHelp() {
  for (final line in getNavigationOptionsHelpLines()) {
    print(line);
  }
}

/// Generates a complete help header for a Tom build tool.
///
/// Returns a list of lines that form the standard help output header.
///
/// [toolName] is the name of the tool (e.g., 'Astgen', 'D4rtgen').
/// [toolDescription] is a brief description of what the tool does.
/// [usagePatterns] are the usage patterns specific to the tool.
List<String> getToolHelpHeader({
  required String toolName,
  required String toolDescription,
  required List<String> usagePatterns,
}) {
  final lines = <String>[
    '$toolName - $toolDescription',
    '',
    'Usage:',
  ];
  
  for (final pattern in usagePatterns) {
    lines.add('  $pattern');
  }
  
  lines.add('');
  return lines;
}

/// Generates the standard footer for help output.
///
/// Includes examples and notes common to all Tom build tools.
List<String> getToolHelpFooter({String? toolName}) {
  final name = toolName?.toLowerCase() ?? 'tool';
  return [
    '',
    'Default Behavior:',
    '  When no explicit navigation options are provided, applies:',
    '    --scan . --recursive --build-order',
    '',
    'Examples:',
    '  $name                        # Process current project tree',
    '  $name -R                     # Process from workspace root',
    '  $name -R -l                  # List all projects in workspace',
    '  $name -p "tom_*" -r          # Process projects matching pattern',
    '  $name -s packages/ -r        # Scan packages/ recursively',
    '  $name help                   # Show this help',
    '  $name version                # Show version information',
  ];
}

