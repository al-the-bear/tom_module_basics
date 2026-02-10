import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/tracking_file.dart';
import '../parser/dart_test_parser.dart';

/// Implements the `:test` subcommand.
///
/// Runs `dart test` and appends a new result column to the most recent
/// tracking file.
class TestCommand {
  /// Runs the test command for a single project.
  ///
  /// [projectPath] is the project directory.
  /// [trackingFilePath] overrides which tracking file to update.
  /// [testArgs] are additional arguments passed to `dart test`.
  /// [verbose] enables diagnostic output.
  ///
  /// Returns true on success, false on failure.
  static Future<bool> run({
    required String projectPath,
    String? trackingFilePath,
    List<String> testArgs = const [],
    bool verbose = false,
  }) async {
    // Find the tracking file
    final filePath =
        trackingFilePath ?? _findLatestTrackingFile(projectPath);

    if (filePath == null) {
      stderr.writeln('[$projectPath] No tracking file found. '
          'Run :baseline first to create one.');
      return false;
    }

    // Load existing tracking file
    final tracking = TrackingFile.load(filePath);
    if (tracking == null) {
      stderr.writeln('[$projectPath] Failed to parse tracking file: $filePath');
      return false;
    }

    if (verbose) {
      print('  Using tracking file: ${p.relative(filePath, from: projectPath)}');
    }

    // Run dart test
    final results = await DartTestParser.runAndParse(
      projectPath: projectPath,
      additionalArgs: testArgs,
      verbose: verbose,
    );

    if (results == null) {
      stderr.writeln('[$projectPath] Failed to run dart test.');
      return false;
    }

    // Add new run
    tracking.addRun(results.run, results.entries);

    // Write updated tracking file
    await tracking.write(filePath);

    // Print summary
    final relativePath = p.relative(filePath, from: projectPath);
    print('  Updated: $relativePath');
    print('  Tests: ${results.totalTests} '
        '(${results.passedTests} passed, '
        '${results.failedTests} failed'
        '${results.skippedTests > 0 ? ', ${results.skippedTests} skipped' : ''})');

    return true;
  }

  /// Finds the most recent `baseline_*.md` file in the project's doc/ directory.
  static String? _findLatestTrackingFile(String projectPath) {
    final docDir = Directory(p.join(projectPath, 'doc'));
    if (!docDir.existsSync()) return null;

    final files = docDir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith('baseline_') &&
            f.path.endsWith('.md'))
        .toList();

    if (files.isEmpty) return null;

    // Sort by name (timestamp in filename) — latest first
    files.sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
    return files.first.path;
  }
}
