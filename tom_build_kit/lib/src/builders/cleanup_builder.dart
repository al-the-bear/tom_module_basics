import 'dart:async';

import 'package:build/build.dart';

/// Configuration for a cleanup section in build.yaml.
class CleanupBuilderSection {
  final List<String> globs;
  final List<String> excludes;

  CleanupBuilderSection({
    required this.globs,
    this.excludes = const [],
  });

  factory CleanupBuilderSection.fromJson(dynamic json) {
    if (json is String) {
      return CleanupBuilderSection(globs: [json]);
    }
    if (json is Map) {
      final globs = _toStringList(json['globs'] ?? json['glob']);
      final excludes = _toStringList(json['excludes'] ?? json['exclude']);
      return CleanupBuilderSection(globs: globs, excludes: excludes);
    }
    throw ArgumentError('CleanupBuilderSection must be a string or map');
  }

  static List<String> _toStringList(dynamic value) {
    if (value == null) return [];
    if (value is String) return [value];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }
}

/// Configuration for the cleanup builder.
class CleanupBuilderConfig {
  final List<CleanupBuilderSection> sections;
  final List<String> globalExcludes;

  const CleanupBuilderConfig({
    this.sections = const [],
    this.globalExcludes = const [],
  });

  /// Load from build.yaml options.
  factory CleanupBuilderConfig.fromOptions(Map<String, dynamic> options) {
    final sections = <CleanupBuilderSection>[];
    final cleanupList = options['cleanup'];
    if (cleanupList is List) {
      for (final item in cleanupList) {
        sections.add(CleanupBuilderSection.fromJson(item));
      }
    }

    final globalExcludes =
        CleanupBuilderSection._toStringList(options['excludes'] ?? options['exclude']);

    return CleanupBuilderConfig(
      sections: sections,
      globalExcludes: globalExcludes,
    );
  }
}

/// Build_runner builder for cleanup.
///
/// Validates cleanup configuration during build_runner runs.
/// The actual cleanup is done by the CLI tool (CleanupTool).
class CleanupBuilder implements Builder {
  final CleanupBuilderConfig config;

  CleanupBuilder(this.config);

  @override
  Map<String, List<String>> get buildExtensions => {
        r'$lib$': ['.cleanup.done'],
      };

  @override
  Future<void> build(BuildStep buildStep) async {
    log.info('Cleanup builder configured with '
        '${config.sections.length} cleanup sections');
    if (config.globalExcludes.isNotEmpty) {
      log.info('Global excludes: ${config.globalExcludes.join(', ')}');
    }
  }
}
