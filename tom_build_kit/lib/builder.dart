/// Builder entry points for build_runner integration.
///
/// This file exports the builder factory functions used by build_runner.
/// Configured in build.yaml with keys:
///   - tom_build_kit:version_builder
///   - tom_build_kit:cleanup_builder
///   - tom_build_kit:compiler_builder
library;

import 'package:build/build.dart';

import 'src/builders/version_builder.dart';
import 'src/builders/cleanup_builder.dart';
import 'src/builders/compiler_builder.dart';

/// Creates a [VersionBuilder] from build.yaml options.
Builder versionBuilder(BuilderOptions options) {
  final config = VersionBuilderConfig.fromOptions(options.config);
  return VersionBuilder(config);
}

/// Creates a [CleanupBuilder] from build.yaml options.
Builder cleanupBuilder(BuilderOptions options) {
  final config = CleanupBuilderConfig.fromOptions(options.config);
  return CleanupBuilder(config);
}

/// Creates a [CompilerBuilder] from build.yaml options.
Builder compilerBuilder(BuilderOptions options) {
  final config = CompilerBuilderConfig.fromOptions(options.config);
  return CompilerBuilder(config);
}
