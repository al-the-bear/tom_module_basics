import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/test_entry.dart';
import '../model/test_run.dart';
import '../model/tracking_file.dart';
import '../util/file_helpers.dart';
import '../util/output_formatter.dart';

/// Implements the `:flaky` subcommand.
///
/// Lists tests that have inconsistent results across runs — i.e., tests that
/// sometimes pass and sometimes fail. This is useful for identifying
/// non-deterministic or environment-sensitive tests.
class FlakyCommand {
  /// Runs the command for a single project.
  ///
  /// Returns true on success, false on failure.
  static Future<bool> run({
    required String projectPath,
    String? baselineFile,
    OutputSpec? output,
    bool verbose = false,
  }) async {
    final filePath = baselineFile ?? findLatestTrackingFile(projectPath);
    if (filePath == null) {
      stderr.writeln('[$projectPath] No baseline file found.');
      return false;
    }

    final tracking = TrackingFile.load(filePath);
    if (tracking == null) {
      stderr.writeln('[$projectPath] Failed to parse: $filePath');
      return false;
    }

    if (verbose) {
      final rel = p.relative(filePath, from: projectPath);
      print('  File: $rel');
    }

    if (tracking.runs.length < 2) {
      print('  Need at least 2 runs to detect flaky tests.');
      return true;
    }

    // Find tests with mixed OK/X results (ignoring absent and skip)
    final flakyTests = <_FlakyEntry>[];

    for (final entry in tracking.entries.entries) {
      final key = entry.key;
      var passCount = 0;
      var failCount = 0;
      var totalRuns = 0;

      for (final run in tracking.runs) {
        final result = run.getResult(key);
        if (result == TestResult.ok) {
          passCount++;
          totalRuns++;
        } else if (result == TestResult.fail) {
          failCount++;
          totalRuns++;
        }
        // skip and absent don't count toward flakiness
      }

      // A test is flaky if it has both passes and failures
      if (passCount > 0 && failCount > 0) {
        final flipCount = _countFlips(tracking, key);
        flakyTests.add(_FlakyEntry(
          testEntry: entry.value,
          passCount: passCount,
          failCount: failCount,
          totalRuns: totalRuns,
          flipCount: flipCount,
        ));
      }
    }

    // Sort by flip count descending (most flaky first)
    flakyTests.sort((a, b) => b.flipCount.compareTo(a.flipCount));

    if (flakyTests.isEmpty) {
      print('  No flaky tests detected across ${tracking.runs.length} runs.');
      return true;
    }

    final spec = output ?? OutputSpec.defaultSpec;
    final headers = ['ID', 'Description', 'Pass', 'Fail', 'Flips', 'Rate'];
    final rows = <List<String>>[];

    for (final flaky in flakyTests) {
      final rate = (flaky.failCount / flaky.totalRuns * 100).round();
      rows.add([
        flaky.testEntry.id ?? '',
        flaky.testEntry.description,
        '${flaky.passCount}',
        '${flaky.failCount}',
        '${flaky.flipCount}',
        '$rate%',
      ]);
    }

    final title = 'Flaky tests (${flakyTests.length} found '
        'across ${tracking.runs.length} runs)';

    await OutputWriter(spec).writeTable(
      headers: headers,
      rows: rows,
      title: title,
    );

    return true;
  }

  /// Counts the number of pass/fail transitions (flips) across runs.
  ///
  /// A flip is when a test goes from OK→X or X→OK between consecutive runs.
  /// More flips = more flaky.
  static int _countFlips(TrackingFile tracking, String testKey) {
    var flips = 0;
    TestResult? lastMeaningful;

    for (final run in tracking.runs) {
      final result = run.getResult(testKey);
      // Only consider OK and fail for flip detection
      if (result != TestResult.ok && result != TestResult.fail) continue;

      if (lastMeaningful != null && result != lastMeaningful) {
        flips++;
      }
      lastMeaningful = result;
    }

    return flips;
  }
}

/// Internal data class for a flaky test entry.
class _FlakyEntry {
  final TestEntry testEntry;
  final int passCount;
  final int failCount;
  final int totalRuns;
  final int flipCount;

  _FlakyEntry({
    required this.testEntry,
    required this.passCount,
    required this.failCount,
    required this.totalRuns,
    required this.flipCount,
  });
}
