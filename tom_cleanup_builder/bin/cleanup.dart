#!/usr/bin/env dart
/// File cleanup CLI tool
///
/// Command-line interface for cleaning up generated and temporary files.
/// Provides the same functionality as the build_runner builder but as a
/// standalone CLI that can be integrated into CI/CD pipelines.
///
/// ## Configuration Sources (in order of precedence)
///
/// 1. Command-line arguments
/// 2. `tom_build.yaml` (cleanup: section) in project directory
/// 3. `build.yaml` (tom_cleanup_builder:cleanup_builder options) in project directory
///
/// ## Usage
///
/// ```bash
/// # Clean up files in current project
/// cleanup
///
/// # Process project and all subprojects recursively
/// cleanup --project=my_app --recursive
///
/// # Scan directory for projects to clean
/// cleanup --scan=workspace
///
/// # Show help
/// cleanup --help
/// ```
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';
import 'package:yaml/yaml.dart';

/// The tool key for cleanup in tom_build.yaml
const _toolKey = 'cleanup';

/// Global verbose flag for error messages during config loading
bool _verbose = false;

/// Configuration for a cleanup section.
class CleanupSection {
  /// Glob patterns to match for cleanup.
  final List<String> globs;

  /// Glob patterns to exclude from cleanup.
  final List<String> excludes;

  CleanupSection({
    required this.globs,
    this.excludes = const [],
  });

  factory CleanupSection.fromJson(dynamic json) {
    if (json is String) {
      // Simple string pattern
      return CleanupSection(globs: [json]);
    } else if (json is Map) {
      // Complex pattern with globs and excludes
      final globsRaw = json['globs'];
      final excludesRaw = json['excludes'];

      final globs = <String>[];
      if (globsRaw is String) {
        globs.add(globsRaw);
      } else if (globsRaw is List) {
        globs.addAll(globsRaw.cast<String>());
      }

      final excludes = <String>[];
      if (excludesRaw is String) {
        excludes.add(excludesRaw);
      } else if (excludesRaw is List) {
        excludes.addAll(excludesRaw.cast<String>());
      }

      return CleanupSection(globs: globs, excludes: excludes);
    }

    throw ArgumentError('Invalid cleanup section format: $json');
  }
}

/// Configuration for the cleanup CLI.
class CleanupConfig {
  final String? project;
  final String? scan;
  final bool recursive;
  final List<String> exclude;
  final List<String> recursionExclude;
  final bool verbose;
  final bool dryRun;

  // Cleanup-specific options
  final List<CleanupSection> cleanupSections;
  final List<String> globalExcludes;

  const CleanupConfig({
    this.project,
    this.scan,
    this.recursive = false,
    this.exclude = const [],
    this.recursionExclude = const [],
    this.verbose = false,
    this.dryRun = false,
    this.cleanupSections = const [],
    this.globalExcludes = const [],
  });

  /// Load configuration from tom_build.yaml file (cleanup: section).
  static CleanupConfig? loadFromYaml(String dir) {
    final yamlPath = p.join(dir, 'tom_build.yaml');
    final yamlFile = File(yamlPath);

    if (!yamlFile.existsSync()) return null;

    try {
      final content = yamlFile.readAsStringSync();
      final rootYaml = loadYaml(content) as YamlMap?;
      if (rootYaml == null) return null;

      // Parse cleanup sections (can be a list directly)
      final sections = <CleanupSection>[];
      final cleanupRaw = rootYaml['cleanup'];
      if (cleanupRaw is YamlList) {
        for (final item in cleanupRaw) {
          sections.add(CleanupSection.fromJson(item));
        }
      } else if (cleanupRaw is YamlMap) {
        // If cleanup is a map (for TomBuildConfig compatibility)
        final innerCleanup = cleanupRaw['cleanup'];
        if (innerCleanup is List) {
          for (final item in innerCleanup) {
            sections.add(CleanupSection.fromJson(item));
          }
        }
      }

      if (sections.isEmpty) return null;

      // Parse global excludes
      final globalExcludes = <String>[];
      final excludesRaw = rootYaml['excludes'];
      if (excludesRaw is String) {
        globalExcludes.add(excludesRaw);
      } else if (excludesRaw is YamlList) {
        globalExcludes.addAll(excludesRaw.map((e) => e.toString()));
      }

      // Parse other options (if they exist at root level)
      return CleanupConfig(
        project: rootYaml['project'] as String?,
        scan: rootYaml['scan'] as String?,
        recursive: rootYaml['recursive'] as bool? ?? false,
        exclude: _toStringList(rootYaml['exclude']),
        recursionExclude: _toStringList(rootYaml['recursion-exclude'] ?? rootYaml['recursionExclude']),
        verbose: rootYaml['verbose'] as bool? ?? false,
        cleanupSections: sections,
        globalExcludes: globalExcludes,
      );
    } catch (e) {
      if (_verbose) {
        print('Error loading tom_build.yaml: $e');
      }
      return null;
    }
  }

  static List<String> _toStringList(dynamic value) {
    if (value == null) return [];
    if (value is String) return [value];
    if (value is YamlList) return value.map((e) => e.toString()).toList();
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  /// Load from build.yaml (build_runner format).
  static CleanupConfig? loadFromBuildYaml(String dir) {
    final buildYamlPath = p.join(dir, 'build.yaml');
    final buildYamlFile = File(buildYamlPath);
    if (!buildYamlFile.existsSync()) return null;

    try {
      final yaml = loadYaml(buildYamlFile.readAsStringSync()) as YamlMap;

      // Look for tom_cleanup_builder:cleanup_builder options
      final targets = yaml['targets'] as YamlMap?;
      if (targets == null) return null;

      final defaultTarget = targets[r'$default'] as YamlMap?;
      if (defaultTarget == null) return null;

      final builders = defaultTarget['builders'] as YamlMap?;
      if (builders == null) return null;

      final cleanupBuilder = builders['tom_cleanup_builder:cleanup_builder'] as YamlMap?;
      if (cleanupBuilder == null) return null;

      final options = cleanupBuilder['options'] as YamlMap?;
      if (options == null) return null;

      // Parse cleanup sections
      final sections = <CleanupSection>[];
      final cleanupRaw = options['cleanup'];
      if (cleanupRaw is YamlList) {
        for (final item in cleanupRaw) {
          sections.add(CleanupSection.fromJson(item));
        }
      }

      // Parse global excludes
      final globalExcludes = <String>[];
      final excludesRaw = options['excludes'];
      if (excludesRaw is String) {
        globalExcludes.add(excludesRaw);
      } else if (excludesRaw is YamlList) {
        globalExcludes.addAll(excludesRaw.cast<String>());
      }

      return CleanupConfig(
        cleanupSections: sections,
        globalExcludes: globalExcludes,
      );
    } catch (e) {
      return null;
    }
  }

  CleanupConfig merge(CleanupConfig other) {
    return CleanupConfig(
      project: other.project ?? project,
      scan: other.scan ?? scan,
      recursive: other.recursive,
      exclude: other.exclude.isNotEmpty ? other.exclude : exclude,
      recursionExclude: other.recursionExclude.isNotEmpty ? other.recursionExclude : recursionExclude,
      verbose: other.verbose || verbose,
      dryRun: other.dryRun || dryRun,
      cleanupSections: other.cleanupSections.isNotEmpty ? other.cleanupSections : cleanupSections,
      globalExcludes: other.globalExcludes.isNotEmpty ? other.globalExcludes : globalExcludes,
    );
  }
}

Future<void> main(List<String> arguments) async {
  // Check for version command first (before parsing)
  if (arguments.isNotEmpty && 
      (arguments[0] == 'version' || 
       arguments[0] == '-version' || 
       arguments[0] == '--version')) {
    _printVersion();
    exit(0);
  }

  final parser = ArgParser()
    ..addOption('project',
        abbr: 'p',
        help: 'Project(s) to clean (comma-separated, globs: tom_*_builder, ./*)')
    ..addOption('scan',
        abbr: 's', help: 'Scan directory for all projects with cleanup config')
    ..addFlag('recursive',
        abbr: 'r',
        defaultsTo: false,
        help: 'Recursively process subprojects within each project')
    ..addMultiOption('exclude',
        abbr: 'x', help: 'Glob patterns for projects to exclude')
    ..addMultiOption('recursion-exclude',
        abbr: 'R', help: 'Glob patterns to exclude from recursion')
    ..addFlag('dry-run',
        abbr: 'n',
        negatable: false,
        help: 'Show what would be deleted without actually deleting')
    ..addFlag('verbose',
        abbr: 'v', negatable: false, help: 'Show detailed output')
    ..addFlag('list',
        abbr: 'l',
        negatable: false,
        help: 'List projects that would be processed (no action)')
    ..addFlag('show',
        help: 'With --list, show build.yaml configuration for each project',
        negatable: false)
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show usage help');

  final args = parser.parse(arguments);

  if (args['help'] as bool) {
    _printUsage(parser);
    exit(0);
  }

  final listOnly = args['list'] as bool;
  final showConfig = args['show'] as bool;

  // Build config from CLI args
  final cliConfig = CleanupConfig(
    project: args['project'] as String?,
    scan: args['scan'] as String?,
    recursive: args['recursive'] as bool,
    exclude: args['exclude'] as List<String>,
    recursionExclude: args['recursion-exclude'] as List<String>,
    verbose: args['verbose'] as bool,
    dryRun: args['dry-run'] as bool,
  );

  // Check if any meaningful option was provided
  final hasAnyOption =
      cliConfig.project != null || cliConfig.scan != null;

  CleanupConfig config;
  if (!hasAnyOption) {
    // Try loading from tom_build.yaml in current directory
    final yamlConfig = CleanupConfig.loadFromYaml(Directory.current.path);
    if (yamlConfig != null) {
      if (cliConfig.verbose) {
        print('Using configuration from tom_build.yaml (cleanup: section)');
      }
      config = yamlConfig.merge(cliConfig);
    } else {
      // Try loading from build.yaml
      final buildYamlConfig =
          CleanupConfig.loadFromBuildYaml(Directory.current.path);
      if (buildYamlConfig != null) {
        if (cliConfig.verbose) {
          print('Using configuration from build.yaml');
        }
        config = buildYamlConfig.merge(cliConfig);
      } else {
        // Default: process current directory
        config = CleanupConfig(
          project: Directory.current.path,
          recursive: cliConfig.recursive,
          exclude: cliConfig.exclude,
          recursionExclude: cliConfig.recursionExclude,
          verbose: cliConfig.verbose,
          dryRun: cliConfig.dryRun,
        );
      }
    }
  } else {
    config = cliConfig;
  }

  // Validate path containment
  final validationError = validatePathContainment(
    project: config.project,
    scan: config.scan,
    basePath: Directory.current.path,
  );
  if (validationError != null) {
    stderr.writeln('Error: $validationError');
    stderr.writeln('All paths must be within the current working directory.');
    exit(1);
  }

  // Determine projects to process
  final projects = await _findProjects(config, Directory.current.path);

  if (projects.isEmpty) {
    print('No projects found to process.');
    if (config.verbose) {
      print('Tip: Create a tom_build.yaml with a "cleanup:" section');
    }
    exit(0);
  }

  // Handle --list mode: just list projects without processing
  if (listOnly) {
    final workspaceRoot = ProjectDiscovery.findWorkspaceRoot(Directory.current.path);
    print('Cleanup projects (${projects.length}):');
    for (final project in projects) {
      final relativePath = p.relative(project, from: workspaceRoot);
      print('  $relativePath');
      
      if (showConfig) {
        _printBuildYamlSection(project, workspaceRoot);
      }
    }
    exit(0);
  }

  // Print header
  print('=' * 60);
  print('Cleanup running');
  print('=' * 60);
  print('');

  // Process projects
  final result = ProcessingResult();
  for (final projectPath in projects) {
    final displayPath =
        p.relative(projectPath, from: Directory.current.path);
    print('Project: $displayPath');

    final success =
        await _processProject(projectPath, config);

    if (success) {
      result.addSuccess();
    } else {
      result.addFailure();
    }
    print('');
  }

  // Summary
  print('Cleanup: Processed ${projects.length} project(s)');
  if (result.hasFailures) {
    print('  Failed: ${result.failureCount}');
    exit(1);
  }
}

/// Find projects to process based on configuration.
Future<List<String>> _findProjects(
    CleanupConfig config, String basePath) async {
  final discovery = ProjectDiscovery(verbose: config.verbose);

  // Project pattern(s) specified (supports comma-separated, globs, ./* etc.)
  if (config.project != null) {
    return discovery.resolveProjectPatterns(
      config.project!,
      basePath: basePath,
      projectFilter: _isCleanupProject,
    );
  }

  // Scan directory for projects
  if (config.scan != null) {
    final scanPath = p.isAbsolute(config.scan!)
        ? config.scan!
        : p.join(basePath, config.scan!);

    final allProjects = await discovery.scanForProjects(
      scanPath,
      recursive: config.recursive,
      toolKey: _toolKey,
    );

    // Filter to only cleanup projects
    return allProjects.where((path) => _isCleanupProject(path)).toList();
  }

  // Default: process current directory if it has config
  if (_isCleanupProject(basePath)) {
    return [basePath];
  }

  return [];
}

/// Check if a directory is a cleanup project.
bool _isCleanupProject(String dirPath) {
  // Must have pubspec.yaml
  if (!File('$dirPath/pubspec.yaml').existsSync()) {
    return false;
  }

  // Check for tom_build.yaml with cleanup section
  if (hasTomBuildConfig(dirPath, _toolKey)) {
    return true;
  }

  // Check for build.yaml with cleanup configuration
  final buildYaml = File('$dirPath/build.yaml');
  if (buildYaml.existsSync()) {
    try {
      final yaml = loadYaml(buildYaml.readAsStringSync()) as YamlMap;
      final targets = yaml['targets'] as YamlMap?;
      if (targets != null) {
        final defaultTarget = targets[r'$default'] as YamlMap?;
        if (defaultTarget != null) {
          final builders = defaultTarget['builders'] as YamlMap?;
          if (builders != null) {
            return builders.containsKey('tom_cleanup_builder:cleanup_builder');
          }
        }
      }
    } catch (_) {
      return false;
    }
  }

  return false;
}

/// Process a single project.
Future<bool> _processProject(
    String projectPath, CleanupConfig config) async {
  // Load cleanup configuration for this project
  var projectConfig = CleanupConfig.loadFromYaml(projectPath) ??
      CleanupConfig.loadFromBuildYaml(projectPath);

  if (projectConfig == null) {
    if (config.verbose) {
      print('Warning: No cleanup configuration found in project');
    }
    return false;
  }

  // Merge with CLI config
  projectConfig = projectConfig.merge(config);

  if (projectConfig.cleanupSections.isEmpty) {
    if (config.verbose) {
      print('Warning: No cleanup patterns configured');
    }
    return true; // Not an error, just nothing to do
  }

  // Change to project directory
  final originalDir = Directory.current;
  Directory.current = projectPath;

  try {
    // Process each cleanup section
    for (final section in projectConfig.cleanupSections) {
      // Determine which excludes to use
      final effectiveExcludes = section.excludes.isEmpty
          ? projectConfig.globalExcludes
          : section.excludes;

      final excludeGlobs = effectiveExcludes.map((p) => Glob(p)).toList();

      // Process each glob pattern
      for (final pattern in section.globs) {
        var found = 0;
        var excluded = 0;
        var deleted = 0;
        
        try {
          final glob = Glob(pattern);

          for (final entity in glob.listSync()) {
            if (entity is! File) continue;
            found++;

            final filePath = entity.path;
            final relativePath = p.relative(filePath, from: projectPath);

            // Check if file matches any exclude pattern
            var isExcluded = false;
            for (final excludeGlob in excludeGlobs) {
              if (excludeGlob.matches(relativePath)) {
                isExcluded = true;
                excluded++;
                if (config.verbose) {
                  print('  Excluding: $relativePath');
                }
                break;
              }
            }

            if (isExcluded) continue;

            // Delete the file
            if (config.dryRun) {
              if (config.verbose) {
                print('  [DRY RUN] Would delete: $relativePath');
              }
              deleted++;
            } else {
              try {
                entity.deleteSync();
                deleted++;
                if (config.verbose) {
                  print('  Deleted: $relativePath');
                }
              } catch (e) {
                if (config.verbose) {
                  print('  Warning: Failed to delete $relativePath: $e');
                }
              }
            }
          }
        } catch (e) {
          if (config.verbose) {
            print('  Error processing pattern "$pattern": $e');
          }
        }
        
        // Print summary for this pattern
        print('Processing: $pattern - Found $found, excluded $excluded, deleted $deleted');
      }
    }

    return true;
  } finally {
    Directory.current = originalDir;
  }
}

void _printVersion() {
  try {
    const version = String.fromEnvironment('version', defaultValue: '1.0.0');
    const buildNumber = String.fromEnvironment('buildNumber', defaultValue: '0');
    const gitCommit = String.fromEnvironment('gitCommit', defaultValue: 'unknown');
    const buildTimestamp = String.fromEnvironment('buildTimestamp', defaultValue: '');
    
    print('Cleanup Tool $version+$buildNumber');
    if (gitCommit != 'unknown') {
      print('Git: $gitCommit');
    }
    if (buildTimestamp.isNotEmpty) {
      print('Built: $buildTimestamp');
    }
  } catch (e) {
    print('Cleanup Tool 1.0.0 (version info unavailable)');
  }
}

/// Print the build.yaml section for a project (--show option).
void _printBuildYamlSection(String projectPath, String workspaceRoot) {
  final buildYamlPath = p.join(projectPath, 'build.yaml');
  final buildYamlFile = File(buildYamlPath);
  
  if (!buildYamlFile.existsSync()) {
    print('    (no build.yaml)');
    return;
  }
  
  try {
    final content = buildYamlFile.readAsStringSync();
    final rootYaml = loadYaml(content) as YamlMap?;
    if (rootYaml == null) {
      print('    (empty build.yaml)');
      return;
    }
    
    // Navigate to tom_cleanup_builder:cleanup_builder section
    final targets = rootYaml['targets'] as YamlMap?;
    if (targets == null) {
      print('    (no targets section in build.yaml)');
      return;
    }
    
    final defaultTarget = targets[r'$default'] as YamlMap?;
    if (defaultTarget == null) {
      print('    (no \$default target in build.yaml)');
      return;
    }
    
    final builders = defaultTarget['builders'] as YamlMap?;
    if (builders == null) {
      print('    (no builders in build.yaml)');
      return;
    }
    
    final cleanupBuilder = builders['tom_cleanup_builder:cleanup_builder'] as YamlMap?;
    if (cleanupBuilder == null) {
      print('    (no tom_cleanup_builder:cleanup_builder section)');
      return;
    }
    
    // Print the cleanup_builder section as YAML
    print('    build.yaml:');
    _printYamlNode(cleanupBuilder, indent: 6);
  } catch (e) {
    print('    (error reading build.yaml: $e)');
  }
}

/// Print a YAML node with proper indentation.
void _printYamlNode(dynamic node, {int indent = 0}) {
  final prefix = ' ' * indent;
  
  if (node is YamlMap) {
    for (final entry in node.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (value is YamlMap || value is YamlList) {
        print('$prefix$key:');
        _printYamlNode(value, indent: indent + 2);
      } else {
        print('$prefix$key: $value');
      }
    }
  } else if (node is YamlList) {
    for (final item in node) {
      if (item is YamlMap) {
        // Print first key on same line as dash
        final entries = item.entries.toList();
        if (entries.isNotEmpty) {
          final first = entries.first;
          if (first.value is YamlMap || first.value is YamlList) {
            print('$prefix- ${first.key}:');
            _printYamlNode(first.value, indent: indent + 4);
          } else {
            print('$prefix- ${first.key}: ${first.value}');
          }
          // Print remaining keys indented
          for (var i = 1; i < entries.length; i++) {
            final entry = entries[i];
            if (entry.value is YamlMap || entry.value is YamlList) {
              print('$prefix  ${entry.key}:');
              _printYamlNode(entry.value, indent: indent + 4);
            } else {
              print('$prefix  ${entry.key}: ${entry.value}');
            }
          }
        }
      } else if (item is YamlList) {
        print('$prefix-');
        _printYamlNode(item, indent: indent + 2);
      } else {
        print('$prefix- $item');
      }
    }
  } else {
    print('$prefix$node');
  }
}

void _printUsage(ArgParser parser) {
  print('Cleanup CLI - File cleanup tool');
  print('');
  print('Usage: cleanup [options]');
  print('');
  print('Options:');
  print(parser.usage);
  print('');
  print('Configuration:');
  print('  Reads from tom_build.yaml (cleanup:) or build.yaml');
  print('');
  print('Examples:');
  print('  cleanup                    # Clean current project');
  print('  cleanup --scan .           # Scan workspace for projects');
  print('  cleanup --dry-run          # Preview what would be deleted');
  print('  cleanup --verbose          # Show detailed output');
}
