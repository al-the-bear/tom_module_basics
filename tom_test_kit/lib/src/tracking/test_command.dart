import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/tracking_file.dart';
import '../parser/dart_test_parser.dart';
import '../util/file_helpers.dart';
import 'baseline_command.dart';

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
  /// [createBaseline] if true, creates a baseline when no tracking file exists.
  ///
  /// Returns true on success, false on failure.
  static Future<bool> run({
    required String projectPath,
    String? trackingFilePath,
    List<String> testArgs = const [],
    bool verbose = false,
    bool createBaseline = false,
  }) async {
    // Find the tracking file
    final filePath =
        trackingFilePath ?? findLatestTrackingFile(projectPath);

    if (filePath == null) {
      if (createBaseline) {
        if (verbose) {
          print('  No tracking file found — creating baseline.');
        }
        return BaselineCommand.run(
          projectPath: projectPath,
          testArgs: testArgs,
          verbose: verbose,
        );
      }
      stderr.writeln('[$projectPath] No tracking file found. '
          'Run :baseline first, or use --baseline to create one.');
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

    // Save raw JSON output for inspection
    await saveLastTestRunJson(projectPath, results.rawJsonLines);

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
}
