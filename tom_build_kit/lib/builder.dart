/// Builder entry points for build_runner integration.
///
/// This file exports the builder factory functions used by build_runner.
/// Configured in build.yaml with key:
///   - tom_build_kit:version_builder
///
/// Note: Cleanup and compilation are handled by their respective CLI tools
/// rather than build_runner builders, because builder execution order is
/// not predictable in general.
library;

import 'package:build/build.dart';

import 'src/builders/version_builder.dart';

/// Creates a [VersionBuilder] from build.yaml options.
Builder versionBuilder(BuilderOptions options) {
  final config = VersionBuilderConfig.fromOptions(options.config);
  return VersionBuilder(config);
}
