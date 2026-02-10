import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/tracking_file.dart';
import '../util/file_helpers.dart';
import '../util/output_formatter.dart';
import 'diff_helper.dart';

/// Implements the `:basediff` subcommand.
///
/// Shows the difference between the baseline run and the most recent run.
class BaseDiffCommand {
  /// Runs the command for a single project.
  ///
  /// Returns true on success, false on failure.
  static Future<bool> run({
    required String projectPath,
    String? baselineFile,
    OutputSpec? output,
    bool full = false,
    String? reportPath,
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

    if (tracking.runs.length < 2) {
      print('  Only ${tracking.runs.length} run(s) — need at least 2 for diff.');
      return true;
    }

    final baseline = tracking.runs.first;
    final latest = tracking.runs.last;

    if (full && !DiffHelper.validateLastTestRun(projectPath, tracking)) {
      stderr.writeln(
          'Error: doc/last_testrun.json is missing or does not match '
          'the latest run. Re-run tests first.');
      return false;
    }

    final rows = DiffHelper.computeDiff(tracking, baseline, latest);

    if (verbose) {
      final rel = p.relative(filePath, from: projectPath);
      print('  File: $rel');
      print('  Comparing: baseline → latest (${rows.length} difference(s))');
    }

    if (reportPath != null || reportPath == '') {
      await DiffHelper.writeReport(
        rows: rows,
        labelA: 'Baseline',
        labelB: 'Latest',
        projectPath: projectPath,
        filePath: reportPath!.isEmpty ? null : reportPath,
        title: 'Baseline vs Latest — ${p.basename(filePath)}',
      );
    } else {
      final spec = output ?? OutputSpec.defaultSpec;
      await DiffHelper.writeDiff(
        rows: rows,
        labelA: 'Baseline',
        labelB: 'Latest',
        output: spec,
        title: 'Baseline vs Latest',
      );
    }

    return true;
  }
}
