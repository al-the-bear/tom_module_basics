import 'dart:io';

import 'package:args/args.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';
import 'package:yaml/yaml.dart';

import 'tool_base.dart';

/// Configuration for a single cleanup section (patterns + excludes).
class CleanupSection {
  final List<String> globs;
  final List<String> excludes;

  CleanupSection({
    required this.globs,
    this.excludes = const [],
  });

  /// Parse from JSON/YAML structure.
  /// Accepts a string (single glob) or a map with globs/excludes keys.
  factory CleanupSection.fromJson(dynamic json) {
    if (json is String) {
      return CleanupSection(globs: [json]);
    }
    if (json is Map) {
      final globs = ToolBase.toStringList(json['globs'] ?? json['glob']);
      final excludes = ToolBase.toStringList(json['excludes'] ?? json['exclude']);
      if (globs.isEmpty) {
        throw ArgumentError('CleanupSection map must have "globs" key');
      }
      return CleanupSection(globs: globs, excludes: excludes);
    }
    throw ArgumentError('CleanupSection must be a string or map, got: '
        '${json.runtimeType}');
  }
}

/// Configuration for the cleanup tool.
class CleanupConfig {
  final String? project;
  final String? scan;
  final bool recursive;
  final List<String> exclude;
  final List<String> recursionExclude;
  final bool verbose;
  final bool dryRun;
  final List<CleanupSection> cleanupSections;
  final List<String> globalExcludes;
  final int maxFiles;
  final bool force;

  /// Additional folders to protect from deletion (additive to built-in list).
  final List<String> protectedFolders;

  CleanupConfig({
    this.project,
    this.scan,
    this.recursive = false,
    this.exclude = const [],
    this.recursionExclude = const [],
    this.verbose = false,
    this.dryRun = false,
    this.cleanupSections = const [],
    this.globalExcludes = const [],
    this.maxFiles = 100,
    this.force = false,
    this.protectedFolders = const [],
  });

  /// Load config from buildkit.yaml in the given directory.
  static CleanupConfig? loadFromYaml(String dir) {
    final file = File('$dir/buildkit.yaml');
    if (!file.existsSync()) return null;

    try {
      final content = file.readAsStringSync();
      final yaml = loadYaml(content) as YamlMap?;
      if (yaml == null) return null;

      final cleanupValue = yaml['cleanup'];
      // Support bare key `cleanup:` (null value) — activates tool with defaults
      if (!yaml.containsKey('cleanup')) return null;
      if (cleanupValue == null) return CleanupConfig();

      // Handle direct list format: cleanup: [...]
      if (cleanupValue is YamlList) {
        final sections = <CleanupSection>[];
        for (final item in cleanupValue) {
          sections.add(CleanupSection.fromJson(item));
        }
        return CleanupConfig(cleanupSections: sections);
      }

      // Handle map format: cleanup: { cleanup: [...], excludes: [...], ... }
      if (cleanupValue is! YamlMap) return null;
      final cleanupYaml = cleanupValue;

      // Parse cleanup sections
      final sections = <CleanupSection>[];
      final cleanupList = cleanupYaml['cleanup'];
      if (cleanupList is YamlList) {
        for (final item in cleanupList) {
          sections.add(CleanupSection.fromJson(item));
        }
      }

      // Parse global excludes
      final globalExcludes =
          ToolBase.toStringList(cleanupYaml['excludes'] ?? cleanupYaml['exclude']);

      // Parse additional protected folders (additive to built-in list)
      final protectedFolders = ToolBase.toStringList(
          cleanupYaml['protected-folders'] ?? cleanupYaml['protectedFolders']);

      return CleanupConfig(
        project: cleanupYaml['project'] as String?,
        scan: cleanupYaml['scan'] as String?,
        recursive: cleanupYaml['recursive'] as bool? ?? false,
        exclude: ToolBase.toStringList(cleanupYaml['exclude']),
        recursionExclude: ToolBase.toStringList(
            cleanupYaml['recursion-exclude'] ?? cleanupYaml['recursionExclude']),
        cleanupSections: sections,
        globalExcludes: globalExcludes,
        protectedFolders: protectedFolders,
      );
    } catch (_) {
      return null;
    }
  }

  /// Merge with another config (other takes precedence for non-null values).
  CleanupConfig merge(CleanupConfig other) {
    return CleanupConfig(
      project: other.project ?? project,
      scan: other.scan ?? scan,
      recursive: other.recursive || recursive,
      exclude: [...exclude, ...other.exclude],
      recursionExclude: [...recursionExclude, ...other.recursionExclude],
      verbose: other.verbose || verbose,
      dryRun: other.dryRun || dryRun,
      cleanupSections: other.cleanupSections.isNotEmpty
          ? other.cleanupSections
          : cleanupSections,
      globalExcludes: [...globalExcludes, ...other.globalExcludes],
      maxFiles: other.maxFiles != 100 ? other.maxFiles : maxFiles,
      force: other.force || force,
      protectedFolders: [...protectedFolders, ...other.protectedFolders],
    );
  }
}

/// Cleanup tool - removes generated and temporary files from Dart projects.
///
/// Supports glob patterns, exclusions, two-pass safety checks, and
/// configurable file count limits.
class CleanupTool extends ToolBase {
  @override
  String get toolKey => 'cleanup';

  @override
  String get toolDescription =>
      'Clean up generated and temporary files in Dart projects';

  @override
  void addToolOptions(ArgParser parser) {
    parser
      ..addFlag('force',
          abbr: 'f',
          negatable: false,
          help: 'Skip safety check on file count')
      ..addOption('max-files',
          abbr: 'm',
          defaultsTo: '100',
          help: 'Maximum files to delete without --force');
  }

  @override
  bool isToolProject(String dirPath) {
    final pubspec = File('$dirPath/pubspec.yaml');
    if (!pubspec.existsSync()) return false;
    return hasTomBuildConfig(dirPath, toolKey);
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

    final force = results['force'] as bool;
    final maxFiles = int.tryParse(results['max-files'] as String) ?? 100;
    final listMode = results['list'] as bool;
    final showMode = results['show'] as bool;

    // Load workspace-level config
    var config = CleanupConfig.loadFromYaml(executionRoot) ?? CleanupConfig();

    // Override with CLI options
    config = config.merge(CleanupConfig(
      project: navArgs.project,
      scan: navArgs.scan,
      recursive: navArgs.recursive,
      exclude: navArgs.exclude,
      recursionExclude: navArgs.recursionExclude,
      verbose: verbose,
      dryRun: dryRun,
      maxFiles: maxFiles,
      force: force,
    ));

    // Validate paths
    if (!validateAndEnforcePaths(
      scan: config.scan,
      project: config.project,
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
      print('Projects with cleanup configuration:');
      for (final project in projects) {
        if (isToolProject(project)) {
          print('  ${p.relative(project, from: executionRoot)}');
        }
      }
      return true;
    }

    if (showMode) {
      for (final project in projects) {
        print('Project: ${p.relative(project, from: executionRoot)}');
        printTomBuildYamlSection(project, 'cleanup');
      }
      return true;
    }

    // Process each project
    var success = true;
    var processed = 0;
    var failed = 0;

    for (final projectPath in projects) {
      final result = await processProject(
        projectPath,
        config,
        maxFiles: config.maxFiles,
        force: config.force,
      );
      if (result) {
        processed++;
      } else {
        failed++;
        success = false;
      }
    }

    if (projects.length > 1) {
      print('');
      print('Cleanup summary: $processed succeeded, $failed failed');
    }

    return success;
  }

  /// Process a single project: collect files to delete, safety check, delete.
  Future<bool> processProject(
    String projectPath,
    CleanupConfig config, {
    int maxFiles = 100,
    bool force = false,
  }) async {
    if (verbose) {
      print('Processing: ${p.basename(projectPath)}');
    }

    // Load project-level config and merge
    var projectConfig = config;
    final yamlConfig = CleanupConfig.loadFromYaml(projectPath);
    if (yamlConfig != null) {
      projectConfig = projectConfig.merge(yamlConfig);
    }

    // Build effective protected folder set (built-in + workspace + project)
    _effectiveProtectedFolders = {
      ...builtinProtectedFolders,
      ...projectConfig.protectedFolders,
    };
    if (verbose && projectConfig.protectedFolders.isNotEmpty) {
      print('  Additional protected folders: '
          '${projectConfig.protectedFolders.join(', ')}');
    }

    // Default cleanup targets if none configured
    var sections = projectConfig.cleanupSections;
    if (sections.isEmpty) {
      sections = [
        CleanupSection(globs: [
          'build',
          '.dart_tool/build',
          '**/*.g.dart',
          '**/*.r.dart',
          '**/*.b.dart',
          '**/*.reflection.dart',
          '**/*.reflectable.dart',
        ]),
      ];
    }

    // First pass: collect all files that would be deleted
    final filesToDelete = <String>[];
    for (final section in sections) {
      for (final pattern in section.globs) {
        _collectMatchingFiles(
          projectPath,
          pattern,
          section.excludes,
          projectConfig.globalExcludes,
          filesToDelete,
        );
      }
    }

    if (filesToDelete.isEmpty) {
      if (verbose) print('  No files to clean up');
      return true;
    }

    // Safety check
    if (filesToDelete.length > maxFiles && !force) {
      print('');
      print('WARNING: Cleanup would delete ${filesToDelete.length} files '
          'in ${p.basename(projectPath)} (limit: $maxFiles)');
      print('');
      print('Files to be deleted:');
      for (var i = 0; i < filesToDelete.length && i < 20; i++) {
        print('  - ${p.relative(filesToDelete[i], from: projectPath)}');
      }
      if (filesToDelete.length > 20) {
        print('  ... and ${filesToDelete.length - 20} more');
      }
      print('');
      print('To proceed, use one of these options:');
      print('  1. Use --force flag to skip safety check');
      print(
          '  2. Use --max-files=${filesToDelete.length} to allow this many files');
      print('');
      print('Cleanup aborted for ${p.basename(projectPath)}.');
      return false;
    }

    // Second pass: delete files
    if (dryRun) {
      print('  [DRY RUN] Would delete ${filesToDelete.length} file(s):');
      for (final file in filesToDelete) {
        print('    - ${p.relative(file, from: projectPath)}');
      }
      return true;
    }

    var deleted = 0;
    for (final filePath in filesToDelete) {
      // Final safety guard: never delete protected folders/files
      if (_isInProtectedFolder(filePath)) {
        if (verbose) {
          print('  Skipping protected: '
              '${p.relative(filePath, from: projectPath)}');
        }
        continue;
      }
      try {
        if (verbose) {
          print('  Removing: ${p.relative(filePath, from: projectPath)}');
        }
        final entity = FileSystemEntity.isDirectorySync(filePath)
            ? Directory(filePath)
            : File(filePath);
        entity.deleteSync(recursive: true);
        deleted++;
      } catch (e) {
        if (verbose) print('  Warning: Failed to remove $filePath: $e');
      }
    }

    print('  Cleanup: deleted $deleted file(s) in ${p.basename(projectPath)}');
    return true;
  }

  /// Built-in folders that must never be deleted or have their contents
  /// removed. This is a hard safety guard — cleanup will always skip these.
  /// Additional folders can be added via `protected-folders` in
  /// buildkit.yaml, but the built-in set can never be reduced.
  static const builtinProtectedFolders = {'.git', '.github', '.vscode', '.idea'};

  /// The effective set of protected folders for the current project.
  /// Built from [builtinProtectedFolders] + config `protected-folders`.
  Set<String> _effectiveProtectedFolders = builtinProtectedFolders;

  /// Returns true if [path] is inside a protected folder.
  ///
  /// Single-segment names (e.g., `.git`, `src`) are matched against
  /// individual path segments for fast lookup.
  /// Multi-segment entries containing `/` or glob characters (e.g.,
  /// `lib/src`, `**/generated`) are matched using Glob patterns.
  bool _isInProtectedFolder(String path) {
    final parts = p.split(path);
    for (final folder in _effectiveProtectedFolders) {
      if (folder.contains('/') || folder.contains('*')) {
        // Multi-segment or glob pattern — use Glob matching
        try {
          if (Glob('**/$folder/**').matches(path) ||
              Glob('$folder/**').matches(path)) {
            return true;
          }
        } catch (_) {
          // Fallback: check if the path contains the folder as a substring
          if (path.contains(folder)) return true;
        }
      } else {
        // Single-segment — fast path via set lookup
        if (parts.contains(folder)) return true;
      }
    }
    return false;
  }

  /// Collect files matching a glob pattern, excluding specified patterns.
  void _collectMatchingFiles(
    String projectPath,
    String pattern,
    List<String> sectionExcludes,
    List<String> globalExcludes,
    List<String> results,
  ) {
    final fullPath = '$projectPath/$pattern';

    // Handle direct path (no glob characters)
    if (!pattern.contains('*') &&
        !pattern.contains('?') &&
        !pattern.contains('[')) {
      if (_isInProtectedFolder(fullPath)) {
        if (verbose) {
          print('  Skipping protected path: $pattern');
        }
        return;
      }
      if (FileSystemEntity.isDirectorySync(fullPath)) {
        _collectFilesInDirectory(Directory(fullPath), results);
      } else if (File(fullPath).existsSync()) {
        if (!_isExcluded(fullPath, sectionExcludes, globalExcludes)) {
          results.add(fullPath);
        }
      }
      return;
    }

    // Handle glob pattern
    try {
      final glob = Glob(pattern);
      for (final entity in glob.listSync(root: projectPath)) {
        if (_isInProtectedFolder(entity.path)) continue;
        if (_isExcluded(entity.path, sectionExcludes, globalExcludes)) {
          continue;
        }
        if (entity is File) {
          results.add(entity.path);
        } else if (entity is Directory) {
          _collectFilesInDirectory(entity as Directory, results);
        }
      }
    } catch (e) {
      if (verbose) print('  Warning: Glob error for "$pattern": $e');
    }
  }

  /// Recursively collect all files in a directory.
  ///
  /// Skips files inside protected folders (.git, .github, .vscode, .idea).
  void _collectFilesInDirectory(Directory dir, List<String> files) {
    if (_isInProtectedFolder(dir.path)) return;
    try {
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File && !_isInProtectedFolder(entity.path)) {
          files.add(entity.path);
        }
      }
    } catch (e) {
      if (verbose) print('  Warning: Error scanning ${dir.path}: $e');
    }
  }

  /// Check if a path matches any exclusion pattern.
  bool _isExcluded(
      String path, List<String> sectionExcludes, List<String> globalExcludes) {
    for (final exclude in [...sectionExcludes, ...globalExcludes]) {
      try {
        if (Glob(exclude).matches(path)) return true;
      } catch (_) {
        if (path.contains(exclude)) return true;
      }
    }
    return false;
  }

  void _printUsage(ArgParser parser) {
    print('Cleanup Tool - $toolDescription');
    print('');
    print('Usage: cleanup [options]');
    print('       buildkit :cleanup [options]');
    print('       dart run tom_build_kit:cleanup [options]');
    print('       cleanup version');
    print('');
    print('Options:');
    print(parser.usage);
    print('');
    print('Default targets (when no config is provided):');
    print('  build, .dart_tool/build, **/*.g.dart, **/*.r.dart, **/*.b.dart,');
    print('  **/*.reflection.dart, **/*.reflectable.dart');
    print('');
    print('Configuration (buildkit.yaml):');
    print('  cleanup:');
    print('    - build');
    print('    - globs: ["**/*.g.dart", "**/*.r.dart"]');
    print('      excludes: ["**/version.g.dart"]');
    print('    protected-folders: [".secrets", ".env"]');
    print('');
    print('Safety: Aborts if file count exceeds --max-files (default 100).');
    print('  Use --force to skip the safety check.');
    print('');
    print('Protected folders (never deleted):');
    print('  Built-in: .git, .github, .vscode, .idea');
    print('  Additional folders can be configured via protected-folders');
    print('  in buildkit.yaml (additive only — cannot reduce built-in list).');
  }
}
