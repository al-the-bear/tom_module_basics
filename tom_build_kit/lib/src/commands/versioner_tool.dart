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
  final String? variablePrefix;

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
    this.variablePrefix,
  });

  /// Load config from buildkit.yaml.
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
      variablePrefix: options['variable-prefix'] as String? ??
          options['variablePrefix'] as String?,
    );
  }

  /// Load config from buildkit_master.yaml (workspace level).
  static VersionerConfig? loadFromMasterYaml(String dir) {
    final config = TomBuildConfig.loadMaster(dir: dir, toolKey: 'versioner');
    if (config == null) return null;

    final options = config.toolOptions;
    return VersionerConfig(
      output: options['output'] as String? ?? 'lib/src/version.g.dart',
      includeGitCommit: options['includeGitCommit'] as bool? ?? true,
      versionOverride: options['version'] as String?,
      variablePrefix: options['variable-prefix'] as String? ??
          options['variablePrefix'] as String?,
    );
  }

  /// Merge with another config (this takes precedence for explicitly set values).
  ///
  /// The caller is the higher-priority config (e.g., CLI args).
  /// The [other] parameter is the lower-priority config (e.g., project YAML).
  /// For boolean fields that may have been explicitly set via CLI, the caller
  /// wins. For nullable fields, the caller's non-null value wins.
  /// List fields are merged additively (union).
  VersionerConfig merge(VersionerConfig other) {
    return VersionerConfig(
      project: project ?? other.project,
      scan: scan ?? other.scan,
      recursive: recursive || other.recursive,
      exclude: [...exclude, ...other.exclude],
      recursionExclude: [...recursionExclude, ...other.recursionExclude],
      verbose: verbose || other.verbose,
      output: output != 'lib/src/version.g.dart' ? output : other.output,
      includeGitCommit: includeGitCommit,
      versionOverride: versionOverride ?? other.versionOverride,
      variablePrefix: variablePrefix ?? other.variablePrefix,
    );
  }

  /// Get the generated class name based on variablePrefix.
  ///
  /// If [variablePrefix] is set, generates `{Prefix}VersionInfo`.
  /// Otherwise generates `TomVersionInfo`.
  String get className {
    if (variablePrefix == null || variablePrefix!.isEmpty) {
      return 'TomVersionInfo';
    }
    final prefix = variablePrefix!;
    final capitalized = prefix[0].toUpperCase() + prefix.substring(1);
    return '${capitalized}VersionInfo';
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
          help: 'Override version string')
      ..addOption('variable-prefix',
          help: 'Prefix for generated class name (e.g., "myApp" → MyAppVersionInfo)');
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
    final wsRoot = ToolBase.findWorkspaceRoot(basePath);
    final wsConfig = VersionerConfig.loadFromMasterYaml(wsRoot) ?? VersionerConfig();

    // Build CLI config (highest priority)
    final cliConfig = VersionerConfig(
      project: results['project'] as String?,
      scan: results['scan'] as String?,
      recursive: results['recursive'] as bool,
      exclude: results['exclude'] as List<String>,
      recursionExclude: results['recursion-exclude'] as List<String>,
      verbose: verbose,
      output: results['output'] as String,
      includeGitCommit: !(results['no-git'] as bool),
      versionOverride: results['version'] as String?,
      variablePrefix: results['variable-prefix'] as String?,
    );

    // Merge: CLI > workspace (CLI takes precedence)
    var config = cliConfig.merge(wsConfig);

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
      excludeProjects: results['exclude-projects'] as List<String>,
      recursionExclude: config.recursionExclude,
      basePath: basePath,
    );

    if (findProjectsError) return false;

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
        printTomBuildYamlSection(project, 'versioner');
      }
      return true;
    }

    // Process each project
    var success = true;
    for (final projectPath in projects) {
      if (!await generateVersionFile(projectPath, cliConfig, wsConfig)) {
        success = false;
      }
    }

    return success;
  }

  /// Generate version.g.dart for a single project.
  ///
  /// Merge order: CLI > project > workspace.
  /// [cliConfig] contains values from CLI args (highest priority).
  /// [wsConfig] contains workspace-level defaults (lowest priority).
  /// Project-level config is loaded inside this method.
  Future<bool> generateVersionFile(
      String projectPath, VersionerConfig cliConfig, VersionerConfig wsConfig) async {
    if (verbose) print('Processing: ${p.basename(projectPath)}');

    // 3-way merge: CLI > project > workspace
    final yamlConfig = VersionerConfig.loadFromYaml(projectPath);
    VersionerConfig projectConfig;
    if (yamlConfig != null) {
      // Project config wins over workspace, then CLI wins over both
      projectConfig = cliConfig.merge(yamlConfig.merge(wsConfig));
    } else {
      // No project config — CLI wins over workspace
      projectConfig = cliConfig.merge(wsConfig);
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
        className: projectConfig.className,
      );

      // Write file (skip in dry-run mode)
      final outputPath = '$projectPath/${projectConfig.output}';
      if (dryRun) {
        print('  [DRY RUN] Would generate: ${projectConfig.output}');
        print('    Version: $version');
        print('    Build: $buildNumber');
        if (gitCommit != null) print('    Git: $gitCommit');
        print('    Class: ${projectConfig.className}');
        return true;
      }

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
    String className = 'TomVersionInfo',
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
class $className {
  $className._();

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
    print('       dart run tom_build_kit:versioner [options]');
    print('       versioner version');
    print('');
    print('Options:');
    print(parser.usage);
    print('');
    print('Configuration (buildkit.yaml):');
    print('  versioner:');
    print('    output: lib/src/version.g.dart');
    print('    includeGitCommit: true');
    print('    variablePrefix: myapp  # generates MyappVersionInfo');
    print('    version: "1.0.0"  # optional override');
    print('');
    print('Generated file: {Prefix}VersionInfo class with version, buildTime,');
    print('  gitCommit, buildNumber, dartSdkVersion, and convenience getters');
    print('  (versionShort, versionMedium, versionLong).');
  }
}
