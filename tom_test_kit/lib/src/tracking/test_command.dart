import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/test_run.dart';
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
  /// [failedOnly] if true, only re-run failed tests (X/OK, X/X).
  /// [mismatchedOnly] if true, only re-run tests that don't match expectation
  ///   (X/OK, OK/X).
  /// [noUpdate] if true, runs tests and prints summary without updating
  ///   baseline.
  ///
  /// Returns true on success, false on failure.
  static Future<bool> run({
    required String projectPath,
    String? trackingFilePath,
    List<String> testArgs = const [],
    bool verbose = false,
    bool createBaseline = false,
    String? comment,
    bool failedOnly = false,
    bool mismatchedOnly = false,
    bool noUpdate = false,
  }) async {
    // Find the tracking file
    final filePath = trackingFilePath ?? findLatestTrackingFile(projectPath);

    if (filePath == null) {
      if (createBaseline) {
        if (verbose) {
          print('  No tracking file found — creating baseline.');
        }
        return BaselineCommand.run(
          projectPath: projectPath,
          testArgs: testArgs,
          verbose: verbose,
          comment: comment,
        );
      }
      stderr.writeln(
        '[$projectPath] No tracking file found. '
        'Run :baseline first, or use --baseline to create one.',
      );
      return false;
    }

    // Load existing tracking file
    final tracking = TrackingFile.load(filePath);
    if (tracking == null) {
      stderr.writeln('[$projectPath] Failed to parse tracking file: $filePath');
      return false;
    }

    if (verbose) {
      print(
        '  Using tracking file: ${p.relative(filePath, from: projectPath)}',
      );
    }

    // Build effective test args, potentially filtering by --failed/--mismatched
    var effectiveTestArgs = [...testArgs];

    if (failedOnly || mismatchedOnly) {
      final filterNames = _getFilteredTestNames(
        tracking,
        failedOnly: failedOnly,
        mismatchedOnly: mismatchedOnly,
      );

      if (filterNames.isEmpty) {
        print('  No tests match the filter criteria.');
        return true;
      }

      if (verbose) {
        print('  Filtering to ${filterNames.length} test(s)');
      }

      // Add --name patterns to filter tests
      for (final name in filterNames) {
        // Escape regex special characters in test name
        final escaped = _escapeRegex(name);
        effectiveTestArgs.addAll(['--name', '^$escaped\$']);
      }
    }

    // Run dart test
    final results = await DartTestParser.runAndParse(
      projectPath: projectPath,
      additionalArgs: effectiveTestArgs,
      verbose: verbose,
    );

    if (results == null) {
      stderr.writeln('[$projectPath] Failed to run dart test.');
      return false;
    }

    // Save raw JSON output for inspection
    await saveLastTestRunJson(projectPath, results.rawJsonLines);

    // Add comment to the run if specified
    if (comment != null) {
      results.run.comment = comment;
    }

    // In no-update mode, print summary with expectation comparison
    if (noUpdate) {
      final summary = _computeSummary(tracking: tracking, results: results);
      print(
        '  Ok ${summary.okCount}${summary.unexpectedOk > 0 ? ' (${summary.unexpectedOk} unexpected)' : ''} '
        'Failed ${summary.failedCount}${summary.expectedFail > 0 ? ' (${summary.expectedFail} expected)' : ''} '
        'Skipped ${summary.skippedCount}',
      );
      return true;
    }

    // Add new run
    tracking.addRun(results.run, results.entries);

    // Write updated tracking file
    await tracking.write(filePath);

    // Print summary
    final relativePath = p.relative(filePath, from: projectPath);
    print('  Updated: $relativePath');
    print(
      '  Tests: ${results.totalTests} '
      '(${results.passedTests} passed, '
      '${results.failedTests} failed'
      '${results.skippedTests > 0 ? ', ${results.skippedTests} skipped' : ''})',
    );

    return true;
  }

  /// Returns test names that should be re-run based on filter criteria.
  ///
  /// [failedOnly] selects tests with X/OK or X/X results (failed tests).
  /// [mismatchedOnly] selects tests with X/OK or OK/X results (mismatched).
  static List<String> _getFilteredTestNames(
    TrackingFile tracking, {
    required bool failedOnly,
    required bool mismatchedOnly,
  }) {
    if (tracking.runs.isEmpty) return [];

    final latestRun = tracking.runs.last;
    final names = <String>[];

    for (final entry in tracking.entries.entries) {
      final fullDescription = entry.key;
      final testEntry = entry.value;
      final result = latestRun.getResult(fullDescription);
      final expectation = testEntry.expectation;

      // Convert expectation to match result labels for comparison
      final isFailed = result == TestResult.fail;
      final expectsOk = expectation == 'OK';
      final expectsFail = expectation == 'FAIL';
      final isOk = result == TestResult.ok;

      // X/OK or X/X: failed tests
      final isFailedTest = isFailed;
      // X/OK or OK/X: mismatched tests
      final isMismatchedTest = (isFailed && expectsOk) || (isOk && expectsFail);

      if ((failedOnly && isFailedTest) ||
          (mismatchedOnly && isMismatchedTest)) {
        names.add(fullDescription);
      }
    }

    return names;
  }

  /// Escapes regex special characters in a string.
  static String _escapeRegex(String input) {
    return input.replaceAllMapped(
      RegExp(r'[.*+?^${}()|[\]\\]'),
      (match) => '\\${match.group(0)}',
    );
  }

  /// Computes summary statistics comparing results against expectations.
  static _NoUpdateSummary _computeSummary({
    required TrackingFile tracking,
    required DartTestResults results,
  }) {
    var okCount = 0;
    var failedCount = 0;
    var skippedCount = 0;
    var unexpectedOk = 0;
    var expectedFail = 0;

    for (final entry in results.entries) {
      final result = results.run.results[entry.fullDescription];

      // Get expectation from tracking file or new entry
      final trackingEntry = tracking.entries[entry.fullDescription];
      final expectation = trackingEntry?.expectation ?? entry.expectation;
      final expectsFail = expectation == 'FAIL';

      switch (result) {
        case TestResult.ok:
          okCount++;
          if (expectsFail) unexpectedOk++;
        case TestResult.fail:
          failedCount++;
          if (expectsFail) expectedFail++;
        case TestResult.skip:
        case TestResult.absent:
        case null:
          skippedCount++;
      }
    }

    return _NoUpdateSummary(
      okCount: okCount,
      failedCount: failedCount,
      skippedCount: skippedCount,
      unexpectedOk: unexpectedOk,
      expectedFail: expectedFail,
    );
  }
}

/// Summary statistics for no-update mode.
class _NoUpdateSummary {
  final int okCount;
  final int failedCount;
  final int skippedCount;
  final int unexpectedOk;
  final int expectedFail;

  _NoUpdateSummary({
    required this.okCount,
    required this.failedCount,
    required this.skippedCount,
    required this.unexpectedOk,
    required this.expectedFail,
  });
}
