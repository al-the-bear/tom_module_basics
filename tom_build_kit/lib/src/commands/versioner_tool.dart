import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';
import 'package:yaml/yaml.dart';

import 'tool_base.dart';

/// Configuration for the versioner tool.
class VersionerConfig {
  final String? project;
  final String? scan;
  final bool recursive;
  final List<String> exclude;
  final List<String> recursionExclude;
  final bool verbose;
  final String output;
  final bool includeGitCommit;
  final String? versionOverride;

  VersionerConfig({
    this.project,
    this.scan,
    this.recursive = false,
    this.exclude = const [],
    this.recursionExclude = const [],
    this.verbose = false,
    this.output = 'lib/src/version.g.dart',
    this.includeGitCommit = true,
    this.versionOverride,
  });

  /// Load config from tom_build.yaml.
  static VersionerConfig? loadFromYaml(String dir) {
    final config = TomBuildConfig.load(dir: dir, toolKey: 'versioner');
    if (config == null) return null;

    final options = config.toolOptions;
    return VersionerConfig(
      project: config.project,
      scan: config.scan,
      recursive: config.recursive,
      exclude: config.exclude,
      recursionExclude: config.recursionExclude,
      output: options['output'] as String? ?? 'lib/src/version.g.dart',
      includeGitCommit: options['includeGitCommit'] as bool? ?? true,
      versionOverride: options['version'] as String?,
    );
  }

  /// Load config from build.yaml.
  static VersionerConfig? loadFromBuildYaml(String dir,
      {String builderKey = 'tom_build_kit:version_builder'}) {
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

      return VersionerConfig(
        output: options['output'] as String? ?? 'lib/src/version.g.dart',
        includeGitCommit: options['includeGitCommit'] as bool? ?? true,
        versionOverride: options['version'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Merge with another config (other takes precedence).
  VersionerConfig merge(VersionerConfig other) {
    return VersionerConfig(
      project: other.project ?? project,
      scan: other.scan ?? scan,
      recursive: other.recursive || recursive,
      exclude: [...exclude, ...other.exclude],
      recursionExclude: [...recursionExclude, ...other.recursionExclude],
      verbose: other.verbose || verbose,
      output: other.output != 'lib/src/version.g.dart' ? other.output : output,
      includeGitCommit: other.includeGitCommit,
      versionOverride: other.versionOverride ?? versionOverride,
    );
  }
}

/// Versioner tool - generates version.g.dart files with build metadata.
///
/// Reads version from pubspec.yaml, adds git commit, build number,
/// Dart SDK version, and timestamp.
class VersionerTool extends ToolBase {
  @override
  String get toolKey => 'versioner';

  @override
  String get toolDescription =>
      'Generate version files with build metadata';

  @override
  void addToolOptions(ArgParser parser) {
    parser
      ..addOption('output',
          abbr: 'o',
          defaultsTo: 'lib/src/version.g.dart',
          help: 'Output file path relative to project')
      ..addFlag('no-git',
          negatable: false,
          help: 'Skip git commit hash')
      ..addOption('version',
          help: 'Override version string');
  }

  @override
  bool isToolProject(String dirPath) {
    final pubspec = File('$dirPath/pubspec.yaml');
    if (!pubspec.existsSync()) return false;
    return hasTomBuildConfig(dirPath, toolKey) ||
        _hasBuildYamlVersionConfig(dirPath);
  }

  bool _hasBuildYamlVersionConfig(String dirPath) {
    final file = File('$dirPath/build.yaml');
    if (!file.existsSync()) return false;
    try {
      final content = file.readAsStringSync();
      return content.contains('tom_build_kit:version_builder');
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
    final listMode = results['list'] as bool;
    final showMode = results['show'] as bool;

    // Load workspace-level config
    final basePath = Directory.current.path;
    var config = VersionerConfig.loadFromYaml(basePath) ?? VersionerConfig();

    // Override with CLI options
    config = config.merge(VersionerConfig(
      project: results['project'] as String?,
      scan: results['scan'] as String?,
      recursive: results['recursive'] as bool,
      exclude: results['exclude'] as List<String>,
      recursionExclude: results['recursion-exclude'] as List<String>,
      verbose: verbose,
      output: results['output'] as String,
      includeGitCommit: !(results['no-git'] as bool),
      versionOverride: results['version'] as String?,
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
      print('Projects with versioner configuration:');
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
        printBuildYamlSection(project, 'tom_build_kit:version_builder');
      }
      return true;
    }

    // Process each project
    var success = true;
    for (final projectPath in projects) {
      if (!await generateVersionFile(projectPath, config)) {
        success = false;
      }
    }

    return success;
  }

  /// Generate version.g.dart for a single project.
  Future<bool> generateVersionFile(
      String projectPath, VersionerConfig config) async {
    if (verbose) print('Processing: ${p.basename(projectPath)}');

    // Merge with project-level configs
    var projectConfig = config;
    final yamlConfig = VersionerConfig.loadFromYaml(projectPath);
    if (yamlConfig != null) {
      projectConfig = projectConfig.merge(yamlConfig);
    }
    final buildYamlConfig = VersionerConfig.loadFromBuildYaml(projectPath);
    if (buildYamlConfig != null) {
      projectConfig = projectConfig.merge(buildYamlConfig);
    }

    // Read pubspec.yaml for package name and version
    final pubspecFile = File('$projectPath/pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      print('  Error: No pubspec.yaml found in $projectPath');
      return false;
    }

    try {
      final pubspecContent = pubspecFile.readAsStringSync();
      final pubspec = loadYaml(pubspecContent) as YamlMap;
      final packageName = pubspec['name'] as String;
      final version =
          projectConfig.versionOverride ?? pubspec['version'] as String? ?? '0.0.0';

      // Get git commit
      String? gitCommit;
      if (projectConfig.includeGitCommit) {
        gitCommit = await _getGitCommit(projectPath);
      }

      // Get/increment build number
      final buildNumber = _getAndIncrementBuildNumber(projectPath);

      // Get Dart SDK version
      final dartSdkVersion = await _getDartSdkVersion();

      // Build timestamp
      final buildTime = DateTime.now().toUtc().toIso8601String();

      // Generate content
      final content = _generateVersionFileContent(
        packageName: packageName,
        version: version,
        buildTime: buildTime,
        gitCommit: gitCommit,
        buildNumber: buildNumber,
        dartSdkVersion: dartSdkVersion,
      );

      // Write file
      final outputPath = '$projectPath/${projectConfig.output}';
      final outputFile = File(outputPath);
      outputFile.parent.createSync(recursive: true);
      outputFile.writeAsStringSync(content);

      if (verbose) {
        print('  Generated: ${projectConfig.output}');
        print('    Version: $version');
        print('    Build: $buildNumber');
        if (gitCommit != null) print('    Git: $gitCommit');
      } else {
        print('  Version file generated: ${p.basename(projectPath)} '
            'v$version build $buildNumber');
      }

      return true;
    } catch (e) {
      print('  Error generating version file: $e');
      return false;
    }
  }

  /// Get short git commit hash.
  Future<String?> _getGitCommit(String projectPath) async {
    try {
      final result = await Process.run(
        'git',
        ['rev-parse', '--short', 'HEAD'],
        workingDirectory: projectPath,
      );
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
    } catch (_) {}
    return null;
  }

  /// Get and increment the build number from tom_build_state.json.
  int _getAndIncrementBuildNumber(String projectPath) {
    final stateFile = File('$projectPath/tom_build_state.json');
    int buildNumber = 1;

    if (stateFile.existsSync()) {
      try {
        final content = stateFile.readAsStringSync();
        final json = jsonDecode(content) as Map<String, dynamic>;
        buildNumber = (json['buildNumber'] as int? ?? 0) + 1;
      } catch (_) {}
    }

    // Write incremented build number
    try {
      stateFile.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'buildNumber': buildNumber,
          'lastBuild': DateTime.now().toUtc().toIso8601String(),
        }),
      );
    } catch (e) {
      if (verbose) print('  Warning: Could not write build state: $e');
    }

    return buildNumber;
  }

  /// Get Dart SDK version.
  Future<String?> _getDartSdkVersion() async {
    try {
      final result = await Process.run('dart', ['--version']);
      final output = result.stdout.toString() + result.stderr.toString();
      // Parse "Dart SDK version: 3.x.y ..." format
      final match = RegExp(r'Dart SDK version:\s+(\S+)').firstMatch(output);
      if (match != null) return match.group(1);
      // Fallback: try to get just the version number
      final versionMatch = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(output);
      return versionMatch?.group(1);
    } catch (_) {
      return null;
    }
  }

  /// Generate the version.g.dart file content.
  String _generateVersionFileContent({
    required String packageName,
    required String version,
    required String buildTime,
    String? gitCommit,
    int? buildNumber,
    String? dartSdkVersion,
  }) {
    final gitLine = gitCommit != null
        ? "  static const String gitCommit = '$gitCommit';"
        : "  static const String gitCommit = '';";
    final buildNumLine = buildNumber != null
        ? '  static const int buildNumber = $buildNumber;'
        : '  static const int buildNumber = 0;';
    final sdkLine = dartSdkVersion != null
        ? "  static const String dartSdkVersion = '$dartSdkVersion';"
        : "  static const String dartSdkVersion = '';";

    return '''// GENERATED FILE - DO NOT EDIT
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
$gitLine

  /// Build number (increments with each build)
$buildNumLine

  /// Dart SDK version used to build
$sdkLine

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

  void _printUsage(ArgParser parser) {
    print('Versioner Tool - $toolDescription');
    print('');
    print('Usage: versioner [options]');
    print('       buildkit :versioner [options]');
    print('');
    print('Options:');
    print(parser.usage);
  }
}
