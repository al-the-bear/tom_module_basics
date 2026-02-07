#!/usr/bin/env dart
/// Version file generator CLI (versioner)
///
/// Command-line interface for generating version files from pubspec.yaml.
/// Provides the same functionality as the build_runner builder but as a
/// standalone CLI that can be integrated into CI/CD pipelines.
///
/// ## Configuration Sources (in order of precedence)
///
/// 1. Command-line arguments
/// 2. `tom_build.yaml` (versioner: section) in project directory
/// 3. `build.yaml` (tom_version_builder:version_builder options) in project directory
///
/// ## Usage
///
/// ```bash
/// # Generate version file for current project
/// versioner
///
/// # Process project and all subprojects recursively
/// versioner --project=my_app --recursive
///
/// # Custom output path
/// versioner --output=lib/src/app_version.g.dart
///
/// # Show help
/// versioner --help
/// ```
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';
import 'package:yaml/yaml.dart';

/// The tool key for versioner in tom_build.yaml
const _toolKey = 'versioner';

/// Configuration for the versioner CLI.
class VersionerConfig {
  final String? project;
  final List<String> projects;
  final String? scan;
  final bool recursive;
  final List<String> exclude;
  final List<String> recursionExclude;
  final bool verbose;
  
  // Version-specific options
  final String output;
  final bool includeGitCommit;
  final String? versionOverride;

  const VersionerConfig({
    this.project,
    this.projects = const [],
    this.scan,
    this.recursive = false,
    this.exclude = const [],
    this.recursionExclude = const [],
    this.verbose = false,
    this.output = 'lib/src/version.g.dart',
    this.includeGitCommit = true,
    this.versionOverride,
  });

  /// Load configuration from tom_build.yaml file (versioner: section).
  static VersionerConfig? loadFromYaml(String dir) {
    final buildConfig = TomBuildConfig.load(dir: dir, toolKey: _toolKey);
    if (buildConfig == null) return null;

    // Extract versioner-specific options from toolOptions
    final toolOpts = buildConfig.toolOptions;

    return VersionerConfig(
      project: buildConfig.project,
      projects: buildConfig.projects,
      scan: buildConfig.scan,
      recursive: buildConfig.recursive,
      exclude: buildConfig.exclude,
      recursionExclude: buildConfig.recursionExclude,
      verbose: buildConfig.verbose,
      output: toolOpts['output'] as String? ?? 'lib/src/version.g.dart',
      includeGitCommit: toolOpts['includeGitCommit'] as bool? ?? true,
      versionOverride: toolOpts['version'] as String?,
    );
  }

  /// Load from build.yaml (build_runner format).
  static VersionerConfig? loadFromBuildYaml(String dir) {
    final buildYamlPath = p.join(dir, 'build.yaml');
    final buildYamlFile = File(buildYamlPath);
    if (!buildYamlFile.existsSync()) return null;

    try {
      final content = buildYamlFile.readAsStringSync();
      final yaml = loadYaml(content) as YamlMap?;
      if (yaml == null) return null;

      // Look for targets.$default.builders.tom_version_builder:version_builder.options
      final targets = yaml['targets'] as YamlMap?;
      if (targets == null) return null;
      
      final defaultTarget = targets[r'$default'] as YamlMap?;
      if (defaultTarget == null) return null;
      
      final builders = defaultTarget['builders'] as YamlMap?;
      if (builders == null) return null;
      
      final versionBuilder = builders['tom_version_builder:version_builder'] as YamlMap?;
      if (versionBuilder == null) return null;
      
      final options = versionBuilder['options'] as YamlMap?;
      if (options == null) return VersionerConfig();

      return VersionerConfig(
        output: options['output'] as String? ?? 'lib/src/version.g.dart',
        includeGitCommit: options['includeGitCommit'] as bool? ?? true,
        versionOverride: options['version'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Merge with another config (other takes precedence for non-null values).
  VersionerConfig merge(VersionerConfig other) {
    return VersionerConfig(
      project: other.project ?? project,
      projects: other.projects.isNotEmpty ? other.projects : projects,
      scan: other.scan ?? scan,
      recursive: other.recursive || recursive,
      exclude: other.exclude.isNotEmpty ? other.exclude : exclude,
      recursionExclude: other.recursionExclude.isNotEmpty ? other.recursionExclude : recursionExclude,
      verbose: other.verbose || verbose,
      output: other.output != 'lib/src/version.g.dart' ? other.output : output,
      includeGitCommit: other.includeGitCommit,
      versionOverride: other.versionOverride ?? versionOverride,
    );
  }
}

/// Validates path containment using tom_build_base's validatePathContainment.
String? _validateConfigPaths(VersionerConfig config, String basePath) {
  return validatePathContainment(
    project: config.project,
    projects: config.projects,
    scan: config.scan,
    basePath: basePath,
  );
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
        help: 'Project(s) to version (comma-separated, globs: tom_*_builder, ./*)')
    ..addOption('scan',
        abbr: 's',
        help: 'Scan directory for all projects with version config')
    ..addFlag('recursive',
        abbr: 'r',
        defaultsTo: false,
        help: 'Recursively process subprojects within each project')
    ..addMultiOption('exclude',
        abbr: 'x',
        help: 'Glob patterns for projects to exclude')
    ..addMultiOption('recursion-exclude',
        abbr: 'R',
        help: 'Glob patterns to exclude from recursion')
    ..addOption('output',
        abbr: 'o',
        help: 'Output path for version file (default: lib/src/version.g.dart)')
    ..addFlag('no-git',
        negatable: false,
        help: 'Exclude git commit hash from version file')
    ..addOption('version',
        help: 'Override version (defaults to pubspec.yaml version)')
    ..addFlag('verbose',
        abbr: 'v',
        negatable: false,
        help: 'Show detailed output')
    ..addFlag('list',
        abbr: 'l',
        negatable: false,
        help: 'List projects that would be processed (no action)')
    ..addFlag('help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage help');

  final args = parser.parse(arguments);

  if (args['help'] as bool) {
    _printUsage(parser);
    exit(0);
  }
  
  // Check for unexpected arguments
  if (args.rest.isNotEmpty) {
    stderr.writeln('Error: Unknown arguments: ${args.rest.join(' ')}');
    stderr.writeln('');
    _printUsage(parser);
    exit(1);
  }

  final listOnly = args['list'] as bool;

  // Build config from CLI args
  final cliConfig = VersionerConfig(
    project: args['project'] as String?,
    projects: args['projects'] as List<String>,
    scan: args['scan'] as String?,
    recursive: args['recursive'] as bool,
    exclude: args['exclude'] as List<String>,
    recursionExclude: args['recursion-exclude'] as List<String>,
    verbose: args['verbose'] as bool,
    output: args['output'] as String? ?? 'lib/src/version.g.dart',
    includeGitCommit: !(args['no-git'] as bool),
    versionOverride: args['version'] as String?,
  );

  // Check if any meaningful option was provided
  final hasAnyOption = cliConfig.project != null ||
      cliConfig.projects.isNotEmpty ||
      cliConfig.scan != null;

  VersionerConfig config;
  if (!hasAnyOption) {
    // Try loading from tom_build.yaml in current directory
    final yamlConfig = VersionerConfig.loadFromYaml(Directory.current.path);
    if (yamlConfig != null) {
      print('Using configuration from tom_build.yaml (versioner: section)');
      config = yamlConfig.merge(cliConfig);
    } else {
      // Default: process current directory
      config = VersionerConfig(
        project: Directory.current.path,
        recursive: cliConfig.recursive,
        exclude: cliConfig.exclude,
        recursionExclude: cliConfig.recursionExclude,
        verbose: cliConfig.verbose,
        output: cliConfig.output,
        includeGitCommit: cliConfig.includeGitCommit,
        versionOverride: cliConfig.versionOverride,
      );
    }
  } else {
    config = cliConfig;
  }

  // Validate path containment
  final validationError = _validateConfigPaths(config, Directory.current.path);
  if (validationError != null) {
    stderr.writeln('Error: $validationError');
    stderr.writeln('All paths must be within the current working directory.');
    exit(1);
  }

  // Handle --list mode: just list projects without processing
  if (listOnly) {
    final projects = await _collectProjects(config);
    final workspaceRoot = ProjectDiscovery.findWorkspaceRoot(Directory.current.path);
    
    if (projects.isEmpty) {
      print('No versioner projects found.');
    } else {
      print('Versioner projects (${projects.length}):');
      for (final project in projects) {
        final relativePath = p.relative(project, from: workspaceRoot);
        print('  $relativePath');
      }
    }
    exit(0);
  }

  try {
    print('=' * 60);
    print('Versioner running');
    print('=' * 60);
    print('');
    
    final result = await _runWithConfig(config, basePath: Directory.current.path);

    print('');
    print('Versioner: Processed ${result.successCount + result.failureCount} project(s)');
    if (result.failureCount > 0) {
      print('  Failed: ${result.failureCount}');
    }

    if (result.failureCount > 0) exit(1);
  } catch (e) {
    stderr.writeln('Fatal error: $e');
    exit(1);
  }
}

/// Collect all projects that would be processed (for --list mode).
Future<List<String>> _collectProjects(VersionerConfig config) async {
  final verbose = config.verbose;
  final discovery = ProjectDiscovery(verbose: verbose);

  // Handle --project with patterns (comma-separated, globs, etc.)
  if (config.project != null) {
    return discovery.resolveProjectPatterns(
      config.project!,
      basePath: Directory.current.path,
      projectFilter: _isVersionProject,
    );
  }
  
  // Legacy --projects support (for backward compatibility)
  if (config.projects.isNotEmpty) {
    return await _findProjectsByGlob(
      config.projects,
      exclude: config.exclude,
      verbose: verbose,
    );
  } 
  
  if (config.scan != null) {
    return await _scanForProjects(
      config.scan!,
      recursive: config.recursive,
      exclude: config.exclude,
      recursionExclude: config.recursionExclude,
      verbose: verbose,
    );
  }
  
  return [];
}

/// Run the generator with the given configuration.
Future<ProcessingResult> _runWithConfig(VersionerConfig config, {required String basePath}) async {
  final result = ProcessingResult();
  final verbose = config.verbose;

  if (config.projects.isNotEmpty) {
    // Process projects matching glob patterns
    final projects = await _findProjectsByGlob(
      config.projects,
      exclude: config.exclude,
      verbose: verbose,
    );

    for (final projectPath in projects) {
      final subResult = await _processProjectWithRecursion(
        projectPath,
        config: config,
        recursive: config.recursive,
        recursionExclude: config.recursionExclude,
        exclude: config.exclude,
        verbose: verbose,
      );
      result.merge(subResult);
    }
  } else if (config.scan != null) {
    // Scan directory for projects
    final projects = await _scanForProjects(
      config.scan!,
      recursive: config.recursive,
      exclude: config.exclude,
      recursionExclude: config.recursionExclude,
      verbose: verbose,
    );

    for (final projectPath in projects) {
      final subResult = await _processProjectWithRecursion(
        projectPath,
        config: config,
        recursive: config.recursive,
        recursionExclude: config.recursionExclude,
        exclude: config.exclude,
        verbose: verbose,
      );
      result.merge(subResult);
    }
  } else if (config.project != null) {
    // Single project
    final subResult = await _processProjectWithRecursion(
      config.project!,
      config: config,
      recursive: config.recursive,
      recursionExclude: config.recursionExclude,
      exclude: config.exclude,
      verbose: verbose,
    );
    result.merge(subResult);
  }

  return result;
}

/// Process a project and optionally recurse into subprojects.
Future<ProcessingResult> _processProjectWithRecursion(
  String projectPath, {
  required VersionerConfig config,
  required bool recursive,
  required List<String> recursionExclude,
  required List<String> exclude,
  required bool verbose,
}) async {
  final result = ProcessingResult();
  final normalizedPath = p.normalize(p.absolute(projectPath));

  // Check for project-local tom_build.yaml
  final projectConfig = VersionerConfig.loadFromYaml(normalizedPath);
  if (projectConfig != null) {
    if (verbose) print('Found tom_build.yaml in $normalizedPath');
    
    // Validate paths in project config
    final validationError = _validateConfigPaths(projectConfig, normalizedPath);
    if (validationError != null) {
      stderr.writeln('Error in $normalizedPath/tom_build.yaml: $validationError');
      result.addFailure();
      return result;
    }
    
    // Merge configs and process
    final mergedConfig = config.merge(projectConfig);
    try {
      await _generateVersionFile(normalizedPath, mergedConfig, verbose: verbose);
      result.addSuccess();
    } catch (e) {
      stderr.writeln('Error processing $normalizedPath: $e');
      result.addFailure();
    }
  } else if (_isVersionProject(normalizedPath)) {
    // No tom_build.yaml but has build.yaml config or just pubspec.yaml
    try {
      await _generateVersionFile(normalizedPath, config, verbose: verbose);
      result.addSuccess();
    } catch (e) {
      stderr.writeln('Error processing $normalizedPath: $e');
      result.addFailure();
    }
  }

  // If recursive, find and process subprojects
  if (recursive) {
    final subprojects = await _findSubprojects(
      normalizedPath,
      recursionExclude: recursionExclude,
      exclude: exclude,
      verbose: verbose,
    );

    for (final subproject in subprojects) {
      final subResult = await _processProjectWithRecursion(
        subproject,
        config: config,
        recursive: true,
        recursionExclude: recursionExclude,
        exclude: exclude,
        verbose: verbose,
      );
      result.merge(subResult);
    }
  }

  return result;
}

/// Generate version file for a project.
Future<void> _generateVersionFile(
  String projectPath,
  VersionerConfig config, {
  required bool verbose,
}) async {
  final displayPath = p.relative(projectPath, from: Directory.current.path);
  print('Project: $displayPath');

  // Try loading from build.yaml if no specific output in config
  VersionerConfig effectiveConfig = config;
  final buildYamlConfig = VersionerConfig.loadFromBuildYaml(projectPath);
  if (buildYamlConfig != null) {
    if (verbose) print('  Using settings from build.yaml');
    effectiveConfig = effectiveConfig.merge(buildYamlConfig);
  }

  // Read pubspec.yaml
  final pubspecPath = p.join(projectPath, 'pubspec.yaml');
  final pubspecFile = File(pubspecPath);

  if (!pubspecFile.existsSync()) {
    throw Exception('pubspec.yaml not found in $projectPath');
  }

  final pubspecContent = await pubspecFile.readAsString();
  final pubspec = loadYaml(pubspecContent) as YamlMap;
  final packageName = pubspec['name'] as String? ?? 'unknown';

  // Get version
  final version = effectiveConfig.versionOverride ?? 
      pubspec['version']?.toString() ?? '0.0.0';

  // Get build timestamp
  final buildTime = DateTime.now().toUtc().toIso8601String();

  // Get git commit if requested
  String gitCommit = 'unknown';
  if (effectiveConfig.includeGitCommit) {
    gitCommit = await _getGitCommit(projectPath);
  }

  // Get and increment build number
  final buildNumber = await _getAndIncrementBuildNumber(projectPath);

  // Get Dart SDK version
  final dartSdkVersion = await _getDartSdkVersion();

  // Generate content
  final content = _generateVersionFileContent(
    packageName: packageName,
    version: version,
    buildTime: buildTime,
    gitCommit: gitCommit,
    buildNumber: buildNumber,
    dartSdkVersion: dartSdkVersion,
  );

  // Write output
  final outputPath = p.join(projectPath, effectiveConfig.output);
  final outputFile = File(outputPath);
  
  // Create directory if needed
  final outputDir = Directory(p.dirname(outputPath));
  if (!outputDir.existsSync()) {
    await outputDir.create(recursive: true);
  }
  
  await outputFile.writeAsString(content);

  final relativeOutput = p.relative(outputPath, from: projectPath);
  print('Generated: $relativeOutput (version: $version+$buildNumber)');
  print('');
}

Future<String> _getGitCommit(String projectPath) async {
  try {
    final result = await Process.run(
      'git',
      ['rev-parse', '--short', 'HEAD'],
      workingDirectory: projectPath,
    );
    if (result.exitCode == 0) {
      return (result.stdout as String).trim();
    }
  } catch (_) {}
  return 'unknown';
}

Future<String> _getDartSdkVersion() async {
  try {
    final result = await Process.run('dart', ['--version']);
    if (result.exitCode == 0) {
      final output = '${result.stdout}${result.stderr}'.trim();
      final match = RegExp(r'Dart SDK version:\s*(\S+)').firstMatch(output);
      if (match != null) return match.group(1) ?? 'unknown';
    }
  } catch (_) {}
  return 'unknown';
}

Future<int> _getAndIncrementBuildNumber(String projectPath) async {
  final stateFilePath = p.join(projectPath, 'tom_build_state.json');
  final stateFile = File(stateFilePath);
  int buildNumber = 1;

  try {
    if (stateFile.existsSync()) {
      final content = await stateFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      buildNumber = (json['buildNumber'] as int? ?? 0) + 1;
    }
  } catch (_) {
    buildNumber = 1;
  }

  // Write updated state
  try {
    final json = jsonEncode({
      'buildNumber': buildNumber,
      'lastBuildTime': DateTime.now().toUtc().toIso8601String(),
    });
    await stateFile.writeAsString(json);
  } catch (_) {}

  return buildNumber;
}

String _generateVersionFileContent({
  required String packageName,
  required String version,
  required String buildTime,
  required String gitCommit,
  required int buildNumber,
  required String dartSdkVersion,
}) {
  return '''
// GENERATED FILE - DO NOT EDIT
// Generated by versioner at $buildTime

/// Version information generated at build time.
/// 
/// This class contains static fields and methods for accessing
/// version information embedded during the build process.
class TomVersionInfo {
  TomVersionInfo._();

  /// Package version from pubspec.yaml
  static const String version = '$version';

  /// Build timestamp (ISO 8601 UTC format)
  static const String buildTime = '$buildTime';

  /// Git commit hash (short form)
  static const String gitCommit = '$gitCommit';

  /// Build number (increments with each build)
  static const int buildNumber = $buildNumber;

  /// Dart SDK version used to build
  static const String dartSdkVersion = '$dartSdkVersion';

  /// Short version string: version + build number
  /// Example: "1.0.0+42"
  static String get versionShort => '\$version+\$buildNumber';

  /// Medium version string: version + build number + git commit + build time
  /// Example: "1.0.0+42.abc1234 (2026-02-01T10:30:00.000Z)"
  static String get versionMedium => '\$version+\$buildNumber.\$gitCommit (\$buildTime)';

  /// Long version string: includes all available information including SDK version
  /// Example: "1.0.0+42.abc1234 (2026-02-01T10:30:00.000Z) [Dart 3.x.x]"
  static String get versionLong => '\$version+\$buildNumber.\$gitCommit (\$buildTime) [Dart \$dartSdkVersion]';
}
''';
}

/// Check if a directory is a version-enabled project.
bool _isVersionProject(String dirPath) {
  final pubspecFile = File(p.join(dirPath, 'pubspec.yaml'));
  if (!pubspecFile.existsSync()) return false;

  // Check for tom_build.yaml with versioner section
  if (hasTomBuildConfig(dirPath, _toolKey)) return true;

  // Check for build.yaml with version_builder consumer config
  if (hasBuildYamlConsumerConfig(dirPath, 'tom_version_builder:version_builder')) {
    return true;
  }

  return false;
}

/// Find subprojects within a project directory.
Future<List<String>> _findSubprojects(
  String projectPath, {
  required List<String> recursionExclude,
  required List<String> exclude,
  required bool verbose,
}) async {
  final subprojects = <String>[];
  final projectDir = Directory(projectPath);

  if (!projectDir.existsSync()) return subprojects;

  await _findSubprojectsRecursive(
    projectDir,
    projectPath,
    subprojects,
    recursionExclude: recursionExclude,
  );

  // Apply exclusions
  final filtered = _applyExclusions(subprojects, exclude);

  if (verbose && filtered.isNotEmpty) {
    print('Found ${filtered.length} subproject(s) in $projectPath');
  }

  return filtered;
}

Future<void> _findSubprojectsRecursive(
  Directory dir,
  String rootPath,
  List<String> subprojects, {
  required List<String> recursionExclude,
}) async {
  final recursionGlobs = recursionExclude.map((p) => Glob(p)).toList();

  try {
    for (final entity in dir.listSync()) {
      if (entity is! Directory) continue;

      final dirPath = entity.path;
      final dirName = p.basename(dirPath);
      final relativePath = p.relative(dirPath, from: rootPath);

      // Skip hidden and common non-project directories
      if (dirName.startsWith('.') ||
          dirName == 'build' ||
          dirName == '.dart_tool' ||
          dirName == 'node_modules') {
        continue;
      }

      // Check recursion exclusions
      bool excluded = false;
      for (final glob in recursionGlobs) {
        if (glob.matches(relativePath) || glob.matches(dirPath)) {
          excluded = true;
          break;
        }
      }
      if (excluded) continue;

      if (_isVersionProject(dirPath) || hasTomBuildConfig(dirPath, _toolKey)) {
        subprojects.add(p.normalize(dirPath));
      }

      await _findSubprojectsRecursive(
        entity,
        rootPath,
        subprojects,
        recursionExclude: recursionExclude,
      );
    }
  } catch (_) {}
}

/// Find projects matching glob patterns.
Future<List<String>> _findProjectsByGlob(
  List<String> patterns, {
  List<String> exclude = const [],
  required bool verbose,
}) async {
  final projects = <String>{};

  for (final pattern in patterns) {
    final glob = Glob(pattern);

    await for (final entity in glob.list()) {
      if (entity is Directory) {
        final dirPath = entity.path;
        if (_isVersionProject(dirPath) || hasTomBuildConfig(dirPath, _toolKey)) {
          projects.add(p.normalize(dirPath));
        }
      }
    }
  }

  return _applyExclusions(projects.toList(), exclude);
}

/// Scan directory for version projects.
Future<List<String>> _scanForProjects(
  String scanPath, {
  required bool recursive,
  List<String> exclude = const [],
  List<String> recursionExclude = const [],
  required bool verbose,
}) async {
  final scanDir = p.isAbsolute(scanPath)
      ? scanPath
      : p.join(Directory.current.path, scanPath);

  final discovery = ProjectDiscovery(
    verbose: verbose,
  );

  final allProjects = await discovery.scanForProjects(
    scanDir,
    recursive: recursive,
    toolKey: 'versioner',
  );

  // Filter to only version projects
  final versionProjects = allProjects.where((path) => _isVersionProject(path)).toList();

  return _applyExclusions(versionProjects, exclude);
}

List<String> _applyExclusions(List<String> projects, List<String> exclude) {
  if (exclude.isEmpty) return projects;

  final globs = exclude.map((p) => Glob(p)).toList();

  return projects.where((project) {
    for (final glob in globs) {
      if (glob.matches(project)) return false;
    }
    return true;
  }).toList();
}

void _printVersion() {
  try {
    const version = String.fromEnvironment('version', defaultValue: '1.0.0');
    const buildNumber = String.fromEnvironment('buildNumber', defaultValue: '0');
    const gitCommit = String.fromEnvironment('gitCommit', defaultValue: 'unknown');
    const buildTimestamp = String.fromEnvironment('buildTimestamp', defaultValue: '');

    print('Versioner Tool $version+$buildNumber');
    if (gitCommit != 'unknown') {
      print('Git: $gitCommit');
    }
    if (buildTimestamp.isNotEmpty) {
      print('Built: $buildTimestamp');
    }
  } catch (e) {
    print('Versioner Tool 1.0.0 (version info unavailable)');
  }
}

void _printUsage(ArgParser parser) {
  print('Version File Generator (versioner)');
  print('');
  print('Generates version.g.dart files from pubspec.yaml with build info.');
  print('');
  print('Usage:');
  print('  versioner [options]');
  print('  dart run tom_version_builder:versioner [options]');
  print('');
  print('Options:');
  print(parser.usage);
  print('');
  print('Configuration File (tom_build.yaml):');
  print('  Each project can have a tom_build.yaml file with a versioner: section.');
  print('');
  print('    # tom_build.yaml');
  print('    versioner:');
  print('      output: lib/src/version.g.dart');
  print('      includeGitCommit: true');
  print('      recursive: true');
  print('');
  print('Examples:');
  print('  # Generate version file for current project');
  print('  versioner');
  print('');
  print('  # Process project with custom output');
  print('  versioner --project=my_app --output=lib/version.dart');
  print('');
  print('  # Process all subprojects recursively');
  print('  versioner --project=. --recursive');
  print('');
  print('  # Exclude git commit hash');
  print('  versioner --no-git');
}
