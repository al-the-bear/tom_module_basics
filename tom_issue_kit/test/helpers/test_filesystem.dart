/// Generic filesystem utilities for testing.
///
/// This module provides reusable utilities for creating and managing
/// temporary test directories and files. Designed to be factored out
/// into a standalone test-support package.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

// =============================================================================
// TestDirectory - Managed temporary directory for tests
// =============================================================================

/// A managed temporary directory for test isolation.
///
/// Creates a unique temporary directory that is automatically cleaned up
/// when [dispose] is called. Provides convenience methods for creating
/// files and subdirectories.
///
/// Usage:
/// ```dart
/// late TestDirectory testDir;
///
/// setUp(() {
///   testDir = TestDirectory.create('my_test');
/// });
///
/// tearDown(() {
///   testDir.dispose();
/// });
///
/// test('example', () {
///   testDir.writeFile('src/main.dart', 'void main() {}');
///   final content = testDir.readFile('src/main.dart');
///   expect(content, contains('main'));
/// });
/// ```
class TestDirectory {
  final Directory _directory;

  TestDirectory._(this._directory);

  /// Creates a new temporary test directory.
  ///
  /// [prefix] is prepended to the directory name for identification.
  /// The directory is created in the system temp directory.
  factory TestDirectory.create([String prefix = 'test']) {
    final dir = Directory.systemTemp.createTempSync('${prefix}_');
    return TestDirectory._(dir);
  }

  /// The absolute path to the test directory.
  String get path => _directory.path;

  /// Resolves a relative [path] to an absolute path within this directory.
  String resolve(String path) => p.join(_directory.path, path);

  /// Creates a file with the given [content] at [relativePath].
  ///
  /// Parent directories are created automatically.
  /// Returns the absolute path to the created file.
  String writeFile(String relativePath, String content) {
    final file = File(resolve(relativePath));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    return file.path;
  }

  /// Reads the content of a file at [relativePath].
  ///
  /// Throws if the file doesn't exist.
  String readFile(String relativePath) {
    return File(resolve(relativePath)).readAsStringSync();
  }

  /// Checks if a file exists at [relativePath].
  bool fileExists(String relativePath) {
    return File(resolve(relativePath)).existsSync();
  }

  /// Creates an empty directory at [relativePath].
  ///
  /// Parent directories are created automatically.
  /// Returns the absolute path to the created directory.
  String createDir(String relativePath) {
    final dir = Directory(resolve(relativePath));
    dir.createSync(recursive: true);
    return dir.path;
  }

  /// Checks if a directory exists at [relativePath].
  bool dirExists(String relativePath) {
    return Directory(resolve(relativePath)).existsSync();
  }

  /// Lists files in [relativePath] (non-recursive).
  ///
  /// Returns relative paths from [relativePath].
  List<String> listFiles(String relativePath) {
    final dir = Directory(resolve(relativePath));
    if (!dir.existsSync()) return [];
    return dir
        .listSync()
        .whereType<File>()
        .map((f) => p.basename(f.path))
        .toList();
  }

  /// Deletes the file at [relativePath].
  void deleteFile(String relativePath) {
    File(resolve(relativePath)).deleteSync();
  }

  /// Cleans up the test directory and all contents.
  void dispose() {
    if (_directory.existsSync()) {
      _directory.deleteSync(recursive: true);
    }
  }
}

// =============================================================================
// TestProject - Simulated Dart project structure
// =============================================================================

/// A simulated Dart project for testing build tools and analyzers.
///
/// Creates a realistic project structure with pubspec.yaml, lib/, test/,
/// and optional configuration files. Useful for testing tools that
/// operate on Dart projects.
class TestProject {
  final TestDirectory _root;
  final String name;
  final String projectId;

  TestProject._(this._root, this.name, this.projectId);

  /// Creates a test project with the given [name] and [projectId].
  ///
  /// Generates a basic project structure:
  /// - pubspec.yaml
  /// - lib/{name}.dart (library export)
  /// - test/ (empty directory)
  factory TestProject.create({
    required String name,
    String projectId = 'TP',
    String? prefix,
  }) {
    final root = TestDirectory.create(prefix ?? 'proj_$name');
    final project = TestProject._(root, name, projectId);
    project._initStructure();
    return project;
  }

  void _initStructure() {
    // Create pubspec.yaml
    _root.writeFile('pubspec.yaml', '''
name: $name
description: Test project
version: 1.0.0
environment:
  sdk: ^3.0.0
''');

    // Create library export
    _root.writeFile('lib/$name.dart', '''
/// $name library.
library;
''');

    // Create test directory
    _root.createDir('test');
  }

  /// The absolute path to the project root.
  String get path => _root.path;

  /// Resolves a relative [path] to an absolute path.
  String resolve(String path) => _root.resolve(path);

  /// Writes a file relative to the project root.
  String writeFile(String relativePath, String content) =>
      _root.writeFile(relativePath, content);

  /// Reads a file relative to the project root.
  String readFile(String relativePath) => _root.readFile(relativePath);

  /// Checks if a file exists relative to the project root.
  bool fileExists(String relativePath) => _root.fileExists(relativePath);

  /// Adds a test file with the given content.
  ///
  /// [relativePath] is relative to the test/ directory.
  String addTestFile(String relativePath, String content) {
    return writeFile('test/$relativePath', content);
  }

  /// Adds a source file with the given content.
  ///
  /// [relativePath] is relative to the lib/src/ directory.
  String addSourceFile(String relativePath, String content) {
    return writeFile('lib/src/$relativePath', content);
  }

  /// Adds a tom_project.yaml configuration file.
  void addProjectConfig({String? module}) {
    writeFile('tom_project.yaml', '''
name: $name
project_id: $projectId
${module != null ? 'module: $module' : ''}
''');
  }

  /// Adds a baseline file to doc/.
  ///
  /// [filename] should be like 'baseline_0213_1030.csv'.
  /// [content] is the CSV content.
  String addBaseline(String filename, String content) {
    return writeFile('doc/$filename', content);
  }

  /// Cleans up the project directory.
  void dispose() => _root.dispose();
}

// =============================================================================
// TestWorkspace - Simulated multi-project workspace
// =============================================================================

/// A simulated workspace containing multiple test projects.
///
/// Useful for testing tools that traverse workspace structures.
class TestWorkspace {
  final TestDirectory _root;
  final List<TestProject> _projects = [];

  TestWorkspace._(this._root);

  /// Creates a new test workspace.
  factory TestWorkspace.create([String prefix = 'workspace']) {
    return TestWorkspace._(TestDirectory.create(prefix));
  }

  /// The absolute path to the workspace root.
  String get path => _root.path;

  /// Resolves a relative [path] to an absolute path.
  String resolve(String path) => _root.resolve(path);

  /// The projects in this workspace.
  List<TestProject> get projects => List.unmodifiable(_projects);

  /// Adds a project to the workspace.
  ///
  /// The project is created as a subdirectory of the workspace.
  TestProject addProject({
    required String name,
    String projectId = 'TP',
    String? subdir,
  }) {
    final projectPath = subdir ?? name;

    // Create project structure within workspace
    final pubspec = '''
name: $name
description: Test project
version: 1.0.0
environment:
  sdk: ^3.0.0
''';
    _root.writeFile('$projectPath/pubspec.yaml', pubspec);
    _root.writeFile('$projectPath/lib/$name.dart', '''
/// $name library.
library;
''');
    _root.createDir('$projectPath/test');

    // Create a wrapper that points to the subdirectory
    final project = _WorkspaceProject(
      _root,
      projectPath,
      name,
      projectId,
    );
    _projects.add(project);
    return project;
  }

  /// Writes a workspace configuration file.
  void addWorkspaceConfig(String content) {
    _root.writeFile('tom_workspace.yaml', content);
  }

  /// Cleans up the workspace and all projects.
  void dispose() {
    _root.dispose();
  }
}

/// A project that exists within a workspace.
class _WorkspaceProject extends TestProject {
  _WorkspaceProject(
    TestDirectory workspace,
    String subdir,
    String name,
    String projectId,
  ) : super._(
          TestDirectory._(_createSubdir(workspace, subdir)),
          name,
          projectId,
        );

  static Directory _createSubdir(TestDirectory workspace, String subdir) {
    final dir = Directory(workspace.resolve(subdir));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  @override
  void _initStructure() {
    // Structure is created by TestWorkspace.addProject
  }

  @override
  void dispose() {
    // Don't dispose — workspace owns the directory
  }
}

// =============================================================================
// Test File Content Generators
// =============================================================================

/// Generates test file content with issue-linked test IDs.
///
/// Useful for testing tools that scan for test ID patterns.
class TestFileGenerator {
  TestFileGenerator._();

  /// Generates a test file with issue-linked test descriptions.
  ///
  /// [testCases] is a list of (testId, description) pairs.
  static String dartTestFile({
    required String projectId,
    required List<({String testId, String description})> testCases,
    String? imports,
  }) {
    final buffer = StringBuffer();
    buffer.writeln("import 'package:test/test.dart';");
    if (imports != null) buffer.writeln(imports);
    buffer.writeln();
    buffer.writeln('void main() {');

    for (final tc in testCases) {
      buffer.writeln("  test('${tc.testId}: ${tc.description}', () {");
      buffer.writeln('    // Test body');
      buffer.writeln('  });');
      buffer.writeln();
    }

    buffer.writeln('}');
    return buffer.toString();
  }

  /// Generates a baseline CSV with test results.
  ///
  /// [results] maps testId to status (e.g., 'OK', 'X', 'OK/X').
  static String baselineCsv(Map<String, String> results) {
    final buffer = StringBuffer();
    buffer.writeln('ID,Groups,Description,Run1');
    for (final entry in results.entries) {
      buffer.writeln('${entry.key},,test description,${entry.value}');
    }
    return buffer.toString();
  }

  /// Generates a stub test entry (issue-linked but no project-specific part).
  static String stubTest({
    required String projectId,
    required int issueNumber,
  }) {
    return "  test('$projectId-$issueNumber: stub for issue #$issueNumber', () {});";
  }

  /// Generates a full test entry (with project-specific part).
  static String fullTest({
    required String projectId,
    required int issueNumber,
    required String projectSpecific,
    required String description,
  }) {
    return "  test('$projectId-$issueNumber-$projectSpecific: $description', () {});";
  }
}

// =============================================================================
// Assertions helpers
// =============================================================================

/// Matcher extensions for test results.
extension TestResultMatchers on String {
  /// Whether this string looks like a passing test status.
  bool get isPassingStatus => startsWith('OK') || this == 'OK';

  /// Whether this string looks like a failing test status.
  bool get isFailingStatus => startsWith('X') || this == 'X';

  /// Whether this string indicates a regression (OK→X).
  bool get isRegression {
    if (!contains('/')) return false;
    final parts = split('/');
    return parts.length == 2 &&
        parts[0].trim() == 'X' &&
        parts[1].trim() == 'OK';
  }

  /// Whether this string indicates a fix (X→OK).
  bool get isFix {
    if (!contains('/')) return false;
    final parts = split('/');
    return parts.length == 2 &&
        parts[0].trim() == 'OK' &&
        parts[1].trim() == 'X';
  }
}
