import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/test_run.dart';
import '../model/tracking_file.dart';
import '../util/file_helpers.dart';
import '../util/format_helpers.dart';
import '../util/output_formatter.dart';
import 'diff_helper.dart';

/// Implements the `:diff` subcommand.
///
/// Compares two runs by timestamp. Supports:
/// - `:diff <timestamp>` — compare latest vs the specified run
/// - `:diff <timestamp1> <timestamp2>` — compare any two runs
///
/// Timestamps use `MM-DD HH:MM` or `MM-DD_HHMM` format.
class DiffCommand {
  /// Runs the command for a single project.
  ///
  /// [timestamps] contains 1 or 2 timestamp strings.
  ///
  /// Returns true on success, false on failure.
  static Future<bool> run({
    required String projectPath,
    required List<String> timestamps,
    String? baselineFile,
    OutputSpec? output,
    bool full = false,
    String? reportPath,
    bool verbose = false,
  }) async {
    if (timestamps.isEmpty || timestamps.length > 2) {
      stderr.writeln('Error: :diff requires 1 or 2 timestamp(s).');
      stderr.writeln(
          'Usage: testkit :diff <timestamp> or :diff <ts1> <ts2>');
      return false;
    }

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

    // Resolve runs
    final runA = DiffHelper.findRunByTimestamp(tracking, timestamps[0]);
    if (runA == null) {
      stderr.writeln('Error: No run found for timestamp "${timestamps[0]}".');
      _printAvailableRuns(tracking);
      return false;
    }

    final runB = timestamps.length == 2
        ? DiffHelper.findRunByTimestamp(tracking, timestamps[1])
        : tracking.runs.last;

    if (runB == null) {
      stderr.writeln('Error: No run found for timestamp "${timestamps[1]}".');
      _printAvailableRuns(tracking);
      return false;
    }

    if (full && !DiffHelper.validateLastTestRun(projectPath, tracking)) {
      stderr.writeln(
          'Error: doc/last_testrun.json is missing or does not match '
          'the latest run. Re-run tests first.');
      return false;
    }

    final rows = DiffHelper.computeDiff(tracking, runA, runB);

    final labelA = _runLabel(runA);
    final labelB = _runLabel(runB);

    if (verbose) {
      final rel = p.relative(filePath, from: projectPath);
      print('  File: $rel');
      print('  Comparing: $labelA → $labelB (${rows.length} difference(s))');
    }

    if (reportPath != null) {
      await DiffHelper.writeReport(
        rows: rows,
        labelA: labelA,
        labelB: labelB,
        projectPath: projectPath,
        filePath: reportPath.isEmpty ? null : reportPath,
        title: '$labelA vs $labelB — ${p.basename(filePath)}',
      );
    } else {
      final spec = output ?? OutputSpec.defaultSpec;
      await DiffHelper.writeDiff(
        rows: rows,
        labelA: labelA,
        labelB: labelB,
        output: spec,
        title: '$labelA vs $labelB',
      );
    }

    return true;
  }

  static String _runLabel(TestRun run) {
    final ts = '${padTwo(run.timestamp.month)}-${padTwo(run.timestamp.day)} '
        '${padTwo(run.timestamp.hour)}:${padTwo(run.timestamp.minute)}';
    if (run.isBaseline) return 'Baseline [$ts]';
    return '[$ts]';
  }

  static void _printAvailableRuns(TrackingFile tracking) {
    stderr.writeln('Available runs:');
    for (final run in tracking.runs) {
      final ts =
          '${padTwo(run.timestamp.month)}-${padTwo(run.timestamp.day)} '
          '${padTwo(run.timestamp.hour)}:${padTwo(run.timestamp.minute)}';
      final type = run.isBaseline ? ' (baseline)' : '';
      stderr.writeln('  $ts$type');
    }
  }
}
