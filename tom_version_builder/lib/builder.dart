/// Builder entry point for build_runner.
///
/// This file exports the builder factory function for use with build_runner.
library;

import 'package:build/build.dart';

import 'src/version_builder.dart';

/// Creates a [VersionBuilder] from build.yaml options.
///
/// Usage in build.yaml:
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
Builder versionBuilder(BuilderOptions options) {
  final config = VersionBuilderConfig.fromOptions(options.config);
  return VersionBuilder(config);
}
