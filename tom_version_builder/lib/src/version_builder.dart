/// Version file builder for build_runner.
///
/// This builder generates a version.g.dart file containing version information
/// from pubspec.yaml along with build timestamp, build number, and optional 
/// git commit hash.
///
/// ## Build State
///
/// The builder maintains a `tom_build_state.json` file in the project root
/// to track the build number, which increments with each build.
///
/// ## Usage
///
/// Add to your build.yaml:
///
/// ```yaml
/// targets:
///   $default:
///     builders:
///       tom_version_builder:version_builder:
///         enabled: true
///         options:
///           output: lib/src/version.g.dart
///           includeGitCommit: true
/// ```
///
/// Then run:
/// ```bash
/// dart run build_runner build
/// ```
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:build/build.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Configuration for the version builder.
class VersionBuilderConfig {
  /// Output path for the generated version file.
  final String output;

  /// Whether to include git commit hash.
  final bool includeGitCommit;

  /// Optional version override (defaults to pubspec.yaml version).
  final String? versionOverride;

  const VersionBuilderConfig({
    required this.output,
    this.includeGitCommit = true,
    this.versionOverride,
  });

  factory VersionBuilderConfig.fromOptions(Map<String, dynamic> options) {
    return VersionBuilderConfig(
      output: options['output'] as String? ?? 'lib/src/version.g.dart',
      includeGitCommit: options['includeGitCommit'] as bool? ?? true,
      versionOverride: options['version'] as String?,
    );
  }
}

/// Builder that generates version.g.dart files.
class VersionBuilder implements Builder {
  final VersionBuilderConfig config;

  VersionBuilder(this.config);

  /// Get the output path without lib/ prefix for build_extensions
  String get _outputWithoutLibPrefix {
    final output = config.output;
    if (output.startsWith('lib/')) {
      return output.substring(4); // Remove 'lib/' prefix
    }
    return output;
  }

  @override
  Map<String, List<String>> get buildExtensions {
    // Use $lib$ synthetic input - triggers once per library
    // Output path is relative to lib/ since $lib$ resolves to lib/
    return {
      r'$lib$': [_outputWithoutLibPrefix],
    };
  }

  @override
  Future<void> build(BuildStep buildStep) async {
    final packageName = buildStep.inputId.package;
    log.info('Generating version file for $packageName...');

    // Read pubspec.yaml
    final pubspecPath = p.join(p.current, 'pubspec.yaml');
    final pubspecFile = File(pubspecPath);

    if (!pubspecFile.existsSync()) {
      log.warning('pubspec.yaml not found at $pubspecPath');
      return;
    }

    final pubspecContent = await pubspecFile.readAsString();
    final pubspec = loadYaml(pubspecContent) as YamlMap;

    // Get version
    final version = config.versionOverride ?? pubspec['version']?.toString() ?? '0.0.0';

    // Get build timestamp
    final buildTime = DateTime.now().toUtc().toIso8601String();

    // Get git commit if requested
    String gitCommit = 'unknown';
    if (config.includeGitCommit) {
      gitCommit = await _getGitCommit();
    }

    // Get and increment build number
    final buildNumber = await _getAndIncrementBuildNumber();

    // Get Dart SDK version
    final dartSdkVersion = await _getDartSdkVersion();

    // Generate the version file content
    final content = _generateVersionFile(
      packageName: packageName,
      version: version,
      buildTime: buildTime,
      gitCommit: gitCommit,
      buildNumber: buildNumber,
      dartSdkVersion: dartSdkVersion,
    );

    // Write output
    final outputId = AssetId(packageName, config.output);
    await buildStep.writeAsString(outputId, content);

    log.info('Generated ${config.output} (version: $version, build: $buildNumber, commit: $gitCommit)');
  }

  Future<String> _getGitCommit() async {
    try {
      final result = await Process.run(
        'git',
        ['rev-parse', '--short', 'HEAD'],
        workingDirectory: p.current,
      );
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
    } catch (_) {}
    return 'unknown';
  }

  Future<String> _getDartSdkVersion() async {
    try {
      final result = await Process.run(
        'dart',
        ['--version'],
        workingDirectory: p.current,
      );
      if (result.exitCode == 0) {
        // Output format: "Dart SDK version: 3.x.x (stable) ..."
        final output = (result.stdout as String).trim();
        final match = RegExp(r'Dart SDK version:\s*(\S+)').firstMatch(output);
        if (match != null) {
          return match.group(1) ?? 'unknown';
        }
        // Fallback: try stderr (some versions output there)
        final stderrOutput = (result.stderr as String).trim();
        final stderrMatch = RegExp(r'Dart SDK version:\s*(\S+)').firstMatch(stderrOutput);
        if (stderrMatch != null) {
          return stderrMatch.group(1) ?? 'unknown';
        }
      }
    } catch (_) {}
    return 'unknown';
  }

  /// Get the build state file path
  String get _buildStateFilePath => p.join(p.current, 'tom_build_state.json');

  /// Get and increment the build number from tom_build_state.json
  Future<int> _getAndIncrementBuildNumber() async {
    final stateFile = File(_buildStateFilePath);
    int buildNumber = 1;

    try {
      if (stateFile.existsSync()) {
        final content = await stateFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        buildNumber = (json['buildNumber'] as int? ?? 0) + 1;
      }
    } catch (_) {
      // If file is corrupted or unreadable, start from 1
      buildNumber = 1;
    }

    // Write updated build state
    try {
      final json = jsonEncode({
        'buildNumber': buildNumber,
        'lastBuildTime': DateTime.now().toUtc().toIso8601String(),
      });
      await stateFile.writeAsString(json);
    } catch (e) {
      log.warning('Failed to write build state: $e');
    }

    return buildNumber;
  }

  String _generateVersionFile({
    required String packageName,
    required String version,
    required String buildTime,
    required String gitCommit,
    required int buildNumber,
    required String dartSdkVersion,
  }) {
    return '''
// GENERATED FILE - DO NOT EDIT
// Generated by tom_version_builder at $buildTime

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
}

/// Factory function for build_runner.
Builder versionBuilder(BuilderOptions options) {
  final config = VersionBuilderConfig.fromOptions(options.config);
  return VersionBuilder(config);
}
