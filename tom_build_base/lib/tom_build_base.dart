/// Tom Build Base - Shared configuration and traversal logic for Tom build tools.
///
/// This library provides common infrastructure for Tom build tools that use
/// `tom_build.yaml` configuration files and need to traverse project directories.
///
/// ## Features
///
/// - Unified `tom_build.yaml` configuration loading
/// - Project directory traversal with glob pattern support
/// - Path containment validation
/// - Processing result tracking
///
/// ## Usage
///
/// ```dart
/// import 'package:tom_build_base/tom_build_base.dart';
///
/// // Load tool-specific config from tom_build.yaml
/// final config = TomBuildConfig.load(
///   dir: Directory.current.path,
///   toolKey: 'dartgen',
/// );
///
/// // Use project scanner for traversal
/// final scanner = ProjectScanner(
///   isProjectCallback: (path) => File('$path/pubspec.yaml').existsSync(),
/// );
///
/// // Check if build.yaml defines a builder (should be ignored by CLI tools)
/// if (isBuildYamlBuilderDefinition(projectPath)) {
///   print('Skipping builder definition package');
///   return;
/// }
/// ```
library;

export 'src/build_yaml_utils.dart';

export 'src/build_config.dart';
export 'src/path_utils.dart';
export 'src/processing_result.dart';
export 'src/project_discovery.dart';
export 'src/project_scanner.dart';
