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
    this.maxFiles = 10,
    this.force = false,
  });

  /// Load config from tom_build.yaml in the given directory.
  static CleanupConfig? loadFromYaml(String dir) {
    final file = File('$dir/tom_build.yaml');
    if (!file.existsSync()) return null;

    try {
      final content = file.readAsStringSync();
      final yaml = loadYaml(content) as YamlMap?;
      if (yaml == null) return null;

      final cleanupValue = yaml['cleanup'];
      if (cleanupValue == null) return null;

      // Handle direct list format: cleanup: [...]
      if (cleanupValue is YamlList) {
        final sections = <CleanupSection>[];
        for (final item in cleanupValue) {
          sections.add(CleanupSection.fromJson(item));
        }
        return CleanupConfig(cleanupSections: sections);
      }

      // Handle map format: cleanup: { cleanup: [...], excludes: [...], ... }
      final cleanupYaml = cleanupValue as YamlMap;

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

      return CleanupConfig(
        project: cleanupYaml['project'] as String?,
        scan: cleanupYaml['scan'] as String?,
        recursive: cleanupYaml['recursive'] as bool? ?? false,
        exclude: ToolBase.toStringList(cleanupYaml['exclude']),
        recursionExclude: ToolBase.toStringList(
            cleanupYaml['recursion-exclude'] ?? cleanupYaml['recursionExclude']),
        cleanupSections: sections,
        globalExcludes: globalExcludes,
      );
    } catch (_) {
      return null;
    }
  }

  /// Load config from build.yaml (tom_cleanup_builder:cleanup_builder options).
  static CleanupConfig? loadFromBuildYaml(String dir,
      {String builderKey = 'tom_build_kit:cleanup_builder'}) {
    final file = File('$dir/build.yaml');
    if (!file.existsSync()) return null;

    try {
      final content = file.readAsStringSync();
      final yaml = loadYaml(content) as YamlMap?;
      if (yaml == null) return null;

      final targets = yaml['targets'] as YamlMap?;
      final defaultTarget = targets?[r'$default'] as YamlMap?;
      final builders = defaultTarget?['builders'] as YamlMap?;
      final builder = builders?[builderKey] as YamlMap?;
      final options = builder?['options'] as YamlMap?;
      if (options == null) return null;

      final sections = <CleanupSection>[];
      final cleanupList = options['cleanup'];
      if (cleanupList is YamlList) {
        for (final item in cleanupList) {
          sections.add(CleanupSection.fromJson(item));
        }
      }

      final globalExcludes =
          ToolBase.toStringList(options['excludes'] ?? options['exclude']);

      return CleanupConfig(
        cleanupSections: sections,
        globalExcludes: globalExcludes,
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
      maxFiles: other.maxFiles != 10 ? other.maxFiles : maxFiles,
      force: other.force || force,
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
          defaultsTo: '10',
          help: 'Maximum files to delete without --force');
  }

  @override
  bool isToolProject(String dirPath) {
    final pubspec = File('$dirPath/pubspec.yaml');
    if (!pubspec.existsSync()) return false;
    return hasTomBuildConfig(dirPath, toolKey) ||
        _hasBuildYamlCleanupConfig(dirPath);
  }

  bool _hasBuildYamlCleanupConfig(String dirPath) {
    final file = File('$dirPath/build.yaml');
    if (!file.existsSync()) return false;
    try {
      final content = file.readAsStringSync();
      return content.contains('tom_build_kit:cleanup_builder');
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> run(List<String> args) async {
    if (checkVersionArg(args)) return true;

    final parser = createParser();
    ArgResults results;

    try {
      results = parser.parse(args);
    } catch (e) {
      print('Error: $e');
      _printUsage(parser);
      return false;
    }

    if (results['help'] as bool) {
      _printUsage(parser);
      return true;
    }

    verbose = results['verbose'] as bool;
    dryRun = results['dry-run'] as bool;

    final force = results['force'] as bool;
    final maxFiles = int.tryParse(results['max-files'] as String) ?? 10;
    final listMode = results['list'] as bool;
    final showMode = results['show'] as bool;

    // Load workspace-level config
    final basePath = Directory.current.path;
    var config = CleanupConfig.loadFromYaml(basePath) ?? CleanupConfig();

    // Override with CLI options
    config = config.merge(CleanupConfig(
      project: results['project'] as String?,
      scan: results['scan'] as String?,
      recursive: results['recursive'] as bool,
      exclude: results['exclude'] as List<String>,
      recursionExclude: results['recursion-exclude'] as List<String>,
      verbose: verbose,
      dryRun: dryRun,
      maxFiles: maxFiles,
      force: force,
    ));

    // Validate paths
    if (!validateAndEnforcePaths(
      scan: config.scan,
      project: config.project,
      basePath: basePath,
    )) {
      return false;
    }

    // Find projects
    final projects = await findProjects(
      project: config.project,
      scan: config.scan,
      recursive: config.recursive,
      exclude: config.exclude,
      recursionExclude: config.recursionExclude,
      basePath: basePath,
    );

    if (listMode) {
      print('Projects with cleanup configuration:');
      for (final project in projects) {
        if (isToolProject(project)) {
          print('  ${p.relative(project, from: basePath)}');
        }
      }
      return true;
    }

    if (showMode) {
      for (final project in projects) {
        print('Project: ${p.relative(project, from: basePath)}');
        printBuildYamlSection(project, 'tom_build_kit:cleanup_builder');
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
    int maxFiles = 10,
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
    final buildYamlConfig = CleanupConfig.loadFromBuildYaml(projectPath);
    if (buildYamlConfig != null) {
      projectConfig = projectConfig.merge(buildYamlConfig);
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
  void _collectFilesInDirectory(Directory dir, List<String> files) {
    try {
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File) {
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
    print('');
    print('Options:');
    print(parser.usage);
  }
}
