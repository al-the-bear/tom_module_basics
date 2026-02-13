/// Test scanner for discovering issue-linked tests in workspace projects.
///
/// Scans test directories for test ID patterns matching the convention:
/// - Issue-linked: `<PROJECT_ID>-<issue-number>-<project-specific>`
/// - Regular: `<PROJECT_ID>-<project-specific>`
///
/// Used by traversal-based executors (:scan, :testing, :verify, :validate,
/// :promote, :sync, :aggregate).
library;

import 'dart:io';

/// A discovered test ID in a source file.
class TestIdMatch {
  /// The full test ID (e.g., 'D4-42-PAR-7').
  final String testId;

  /// The project ID prefix (e.g., 'D4').
  final String projectId;

  /// The issue number, if this is an issue-linked test.
  final int? issueNumber;

  /// The project-specific part (e.g., 'PAR-7').
  final String projectSpecific;

  /// Absolute path to the test file.
  final String filePath;

  /// Line number (1-based) where the test was found.
  final int line;

  /// The full test description string.
  final String description;

  TestIdMatch({
    required this.testId,
    required this.projectId,
    this.issueNumber,
    required this.projectSpecific,
    required this.filePath,
    required this.line,
    required this.description,
  });

  /// Whether this is an issue-linked test (has issue number).
  bool get isIssueLinked => issueNumber != null;

  /// Whether this is a stub (no project-specific part after issue number).
  bool get isStub => projectSpecific.isEmpty;

  @override
  String toString() => 'TestIdMatch($testId at $filePath:$line)';
}

/// Scans project test directories for test ID patterns.
///
/// This class encapsulates filesystem operations for scanning, making it
/// easy to mock for testing.
class TestScanner {
  /// Pattern matching test descriptions in Dart test files.
  ///
  /// Matches: test('ID: description ...', or group('ID: description ...', etc.
  /// Captures the ID part before the colon.
  static final _testDescriptionPattern = RegExp(
    r"""(?:test|group)\s*\(\s*['"]([A-Z][A-Z0-9]*(?:-\d+)?(?:-[A-Z][A-Z0-9]*(?:-\d+)?)*)\s*:""",
  );

  /// Pattern to decompose a test ID into its parts.
  ///
  /// Group 1: project ID (e.g., 'D4')
  /// Group 2: optional issue number (e.g., '42')
  /// Group 3: project-specific part (e.g., 'PAR-7')
  static final _testIdPattern = RegExp(
    r'^([A-Z][A-Z0-9]+)-(?:(\d+)-)?(.+)$',
  );

  /// Scan a project directory for all test IDs.
  ///
  /// Walks the `test/` subdirectory of [projectPath], reading all
  /// `*_test.dart` files and extracting test ID patterns.
  ///
  /// Returns a list of [TestIdMatch] for all discovered tests.
  List<TestIdMatch> scanProject(String projectPath) {
    final testDir = Directory('$projectPath/test');
    if (!testDir.existsSync()) return [];

    final results = <TestIdMatch>[];
    final testFiles = testDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('_test.dart'));

    for (final file in testFiles) {
      results.addAll(_scanFile(file));
    }

    return results;
  }

  /// Scan a project for tests linked to a specific issue.
  ///
  /// Returns only [TestIdMatch] entries where [TestIdMatch.issueNumber]
  /// matches [issueNumber].
  List<TestIdMatch> scanForIssue(String projectPath, int issueNumber) {
    return scanProject(projectPath)
        .where((m) => m.issueNumber == issueNumber)
        .toList();
  }

  /// Scan a single test file for test IDs.
  List<TestIdMatch> _scanFile(File file) {
    final results = <TestIdMatch>[];
    final lines = file.readAsLinesSync();

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final descMatch = _testDescriptionPattern.firstMatch(line);
      if (descMatch == null) continue;

      final rawId = descMatch.group(1)!;
      final idMatch = _testIdPattern.firstMatch(rawId);
      if (idMatch == null) continue;

      final projectId = idMatch.group(1)!;
      final issueStr = idMatch.group(2);
      final projectSpecific = idMatch.group(3)!;

      results.add(TestIdMatch(
        testId: rawId,
        projectId: projectId,
        issueNumber: issueStr != null ? int.tryParse(issueStr) : null,
        projectSpecific: projectSpecific,
        filePath: file.path,
        line: i + 1,
        description: line.trim(),
      ));
    }

    return results;
  }

  /// Read the latest testkit baseline from a project.
  ///
  /// Looks for `doc/baseline_*.csv` files and returns the contents of
  /// the most recent one (sorted alphabetically, last wins).
  ///
  /// Returns null if no baseline exists.
  String? readLatestBaseline(String projectPath) {
    final docDir = Directory('$projectPath/doc');
    if (!docDir.existsSync()) return null;

    final baselines = docDir
        .listSync()
        .whereType<File>()
        .where((f) => f.uri.pathSegments.last.startsWith('baseline_') &&
            f.path.endsWith('.csv'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    if (baselines.isEmpty) return null;
    return baselines.last.readAsStringSync();
  }

  /// Parse a testkit baseline CSV into a map of test ID → status.
  ///
  /// The baseline CSV has columns: ID, Groups, Description, then result columns.
  /// We extract the ID and the last result column value.
  Map<String, String> parseBaseline(String csvContent) {
    final lines = csvContent.split('\n');
    if (lines.length < 2) return {};

    final results = <String, String>{};
    // Header has: ID, Groups, Description, then date-based result columns
    final headerParts = _parseCsvLine(lines[0]);
    if (headerParts.length < 4) return {};

    for (var i = 1; i < lines.length; i++) {
      final parts = _parseCsvLine(lines[i]);
      if (parts.length < 4) continue;
      final id = parts[0].trim();
      if (id.isEmpty) continue;
      // Last column is the most recent result
      final status = parts.last.trim();
      results[id] = status;
    }

    return results;
  }

  /// Simple CSV line parser that handles quoted fields.
  List<String> _parseCsvLine(String line) {
    final parts = <String>[];
    var current = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if (c == ',' && !inQuotes) {
        parts.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(c);
      }
    }
    parts.add(current.toString());
    return parts;
  }
}
