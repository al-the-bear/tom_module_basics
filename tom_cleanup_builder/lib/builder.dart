/// Builder entry point for build_runner.
///
/// This file exports the builder factory function for use with build_runner.
library;

import 'package:build/build.dart';

import 'src/cleanup_builder.dart';

/// Creates a [CleanupBuilder] from build.yaml options.
///
/// Usage in build.yaml:
/// ```yaml
/// targets:
///   $default:
///     builders:
///       tom_cleanup_builder:cleanup_builder:
///         enabled: true
///         options:
///           cleanup:
///             - '**/*.g.dart'
///             - globs:
///                 - 'lib/generated/**'
///               excludes:
///                 - 'lib/generated/keep_me.dart'
///           excludes:  # Global excludes
///             - '**/important.g.dart'
/// ```
Builder cleanupBuilder(BuilderOptions options) {
  final config = CleanupBuilderConfig.fromOptions(options.config);
  return CleanupBuilder(config);
}
