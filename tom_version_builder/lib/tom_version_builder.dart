/// Version file builder for build_runner.
///
/// This package provides a builder that generates version.g.dart files
/// containing version information from pubspec.yaml along with build
/// timestamp and optional git commit hash.
///
/// ## Usage
///
/// 1. Add to your pubspec.yaml dev_dependencies:
/// ```yaml
/// dev_dependencies:
///   tom_version_builder:
///     path: ../path/to/tom_version_builder
/// ```
///
/// 2. Add to your build.yaml:
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
/// 3. Run:
/// ```bash
/// dart run build_runner build
/// ```
library;

export 'src/version_builder.dart' show VersionBuilderConfig;
