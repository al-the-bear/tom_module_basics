/// Example showing how to use tom_version_builder.
///
/// This package is a build_runner builder. To use it:
///
/// 1. Add to your build.yaml:
/// ```yaml
/// targets:
///   $default:
///     builders:
///       tom_version_builder:version_builder:
///         enabled: true
///         options:
///           output: lib/src/version.g.dart
/// ```
///
/// 2. Run: dart run build_runner build
///
/// 3. Import the generated file in your code:
/// ```dart
/// import 'src/version.g.dart';
/// print('Version: $packageVersion');
/// print('Build: $buildTimestamp');
/// ```
void main() {
  print('tom_version_builder is a build_runner builder.');
  print('See the library documentation for usage instructions.');
}
