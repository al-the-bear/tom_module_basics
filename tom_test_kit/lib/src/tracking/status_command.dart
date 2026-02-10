import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/test_run.dart';
import '../model/tracking_file.dart';
import '../util/file_helpers.dart';

/// Implements the `:status` subcommand.
///
/// Shows a quick summary: total tests, pass/fail/skip counts, regressions,
/// and progress since baseline and since last run.
class StatusCommand {
  /// Runs the command for a single project.
  ///
  /// Returns true on success, false on failure.
  static Future<bool> run({
    required String projectPath,
    String? baselineFile,
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

    final rel = p.relative(filePath, from: projectPath);
    print('  File: $rel');
    print('  Runs: ${tracking.runs.length}');

    if (tracking.runs.isEmpty) {
      print('  No runs recorded.');
      return true;
    }

    final totalTests = tracking.entries.length;
    final latestRun = tracking.runs.last;
    final baseline = tracking.runs.first;

    // Current counts
    var passCount = 0;
    var failCount = 0;
    var skipCount = 0;
    var absentCount = 0;
    for (final key in tracking.entries.keys) {
      switch (latestRun.getResult(key)) {
        case TestResult.ok:
          passCount++;
        case TestResult.fail:
          failCount++;
        case TestResult.skip:
          skipCount++;
        case TestResult.absent:
          absentCount++;
      }
    }

    print('  Tests: $totalTests '
        '($passCount passed, $failCount failed'
        '${skipCount > 0 ? ', $skipCount skipped' : ''}'
        '${absentCount > 0 ? ', $absentCount absent' : ''})');

    // Compare with baseline
    if (tracking.runs.length >= 2) {
      final cmp = _compareTwoRuns(tracking, baseline, latestRun);
      print('');
      print('  Since baseline:');
      print('    Regressions: ${cmp.$1}');
      print('    Fixes:       ${cmp.$2}');
    }

    // Compare with previous run
    if (tracking.runs.length >= 2) {
      final previousRun = tracking.runs[tracking.runs.length - 2];
      final cmp = _compareTwoRuns(tracking, previousRun, latestRun);
      print('');
      print('  Since last run:');
      print('    Regressions: ${cmp.$1}');
      print('    Fixes:       ${cmp.$2}');
    }

    return true;
  }

  /// Compares two runs and returns (regressions, fixes) counts.
  ///
  /// A regression is a test that was OK in [older] but is now X in [newer].
  /// A fix is a test that was X in [older] but is now OK in [newer].
  static (int regressions, int fixes) _compareTwoRuns(
    TrackingFile tracking,
    TestRun older,
    TestRun newer,
  ) {
    var regressions = 0;
    var fixes = 0;

    for (final key in tracking.entries.keys) {
      final oldResult = older.getResult(key);
      final newResult = newer.getResult(key);

      if (oldResult == TestResult.ok && newResult == TestResult.fail) {
        regressions++;
      } else if (oldResult == TestResult.fail && newResult == TestResult.ok) {
        fixes++;
      }
    }

    return (regressions, fixes);
  }
}
