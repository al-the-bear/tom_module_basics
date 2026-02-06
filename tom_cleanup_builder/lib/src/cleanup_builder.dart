/// Cleanup builder for removing generated and temporary files.
///
/// This builder can be configured via build.yaml to remove files matching
/// glob patterns during the build process.
///
/// ## Configuration
///
/// ```yaml
/// targets:
///   $default:
///     builders:
///       tom_cleanup_builder:cleanup_builder:
///         enabled: true
///         options:
///           cleanup:
///             - '**/*.g.dart'
///             - '**/*.freezed.dart'
///             - globs:
///                 - 'lib/generated/**'
///                 - 'test/fixtures/**'
///               excludes:
///                 - 'lib/generated/keep_me.dart'
///           excludes:  # Global excludes
///             - '**/important.g.dart'
/// ```
library;

import 'dart:async';
import 'dart:io';

import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;

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

/// Configuration for the cleanup builder.
class CleanupBuilderConfig {
  /// List of cleanup sections.
  final List<CleanupSection> cleanupSections;

  /// Global excludes applied to all sections.
  final List<String> globalExcludes;

  CleanupBuilderConfig({
    required this.cleanupSections,
    this.globalExcludes = const [],
  });

  factory CleanupBuilderConfig.fromOptions(Map<String, dynamic> options) {
    final cleanupRaw = options['cleanup'];
    final excludesRaw = options['excludes'];

    final sections = <CleanupSection>[];
    if (cleanupRaw is List) {
      for (final item in cleanupRaw) {
        sections.add(CleanupSection.fromJson(item));
      }
    }

    final globalExcludes = <String>[];
    if (excludesRaw is String) {
      globalExcludes.add(excludesRaw);
    } else if (excludesRaw is List) {
      globalExcludes.addAll(excludesRaw.cast<String>());
    }

    return CleanupBuilderConfig(
      cleanupSections: sections,
      globalExcludes: globalExcludes,
    );
  }
}

/// A builder that cleans up files matching glob patterns.
class CleanupBuilder implements Builder {
  final CleanupBuilderConfig config;

  CleanupBuilder(this.config);

  @override
  Map<String, List<String>> get buildExtensions => const {
        r'$lib$': ['.cleanup.done'],
      };

  @override
  Future<void> build(BuildStep buildStep) async {
    // Get the package root
    final packageRoot = Directory.current.path;

    log.info('Running cleanup in: $packageRoot');

    var filesDeleted = 0;

    // Process each cleanup section
    for (final section in config.cleanupSections) {
      // Determine which excludes to use
      final effectiveExcludes = section.excludes.isEmpty
          ? config.globalExcludes
          : section.excludes;

      final excludeGlobs = effectiveExcludes.map((p) => Glob(p)).toList();

      // Process each glob pattern
      for (final pattern in section.globs) {
        try {
          final glob = Glob(pattern);

          // Change to package root for glob matching
          final originalDir = Directory.current;
          Directory.current = packageRoot;

          try {
            for (final entity in glob.listSync()) {
              if (entity is! File) continue;

              final filePath = entity.path;
              final relativePath = p.relative(filePath, from: packageRoot);

              // Check if file matches any exclude pattern
              var excluded = false;
              for (final excludeGlob in excludeGlobs) {
                if (excludeGlob.matches(relativePath)) {
                  excluded = true;
                  log.fine('Excluding: $relativePath');
                  break;
                }
              }

              if (excluded) continue;

              // Delete the file
              try {
                entity.deleteSync();
                filesDeleted++;
                log.info('Deleted: $relativePath');
              } catch (e) {
                log.warning('Failed to delete $relativePath: $e');
              }
            }
          } finally {
            Directory.current = originalDir;
          }
        } catch (e) {
          log.warning('Error processing pattern "$pattern": $e');
        }
      }
    }

    log.info('Cleanup complete. Deleted $filesDeleted file(s)');

    // Write a marker file to indicate cleanup is done
    await buildStep.writeAsString(
      buildStep.allowedOutputs.first,
      'Cleanup completed at ${DateTime.now()}\n'
      'Deleted: $filesDeleted file(s)\n',
    );
  }
}
