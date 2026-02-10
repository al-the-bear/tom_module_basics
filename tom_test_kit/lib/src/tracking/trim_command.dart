import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/tracking_file.dart';
import '../util/file_helpers.dart';
import '../util/format_helpers.dart';

/// Implements the `:trim` subcommand.
///
/// Removes old run columns, keeping only the last N runs. The baseline
/// run (first column) is always preserved regardless of N. This keeps
/// the CSV file manageable over time.
class TrimCommand {
  /// Runs the command for a single project.
  ///
  /// [keepCount] is the number of most recent runs to keep. The baseline
  /// run is always included, so the actual column count may be keepCount + 1
  /// if the baseline would otherwise be trimmed.
  ///
  /// Returns true on success, false on failure.
  static Future<bool> run({
    required String projectPath,
    required int keepCount,
    String? baselineFile,
    bool force = false,
    bool verbose = false,
  }) async {
    if (keepCount < 1) {
      stderr.writeln('Error: --keep must be at least 1.');
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

    final rel = p.relative(filePath, from: projectPath);
    final totalRuns = tracking.runs.length;

    if (totalRuns <= keepCount) {
      print('  $rel: $totalRuns run(s) — nothing to trim (keeping $keepCount).');
      return true;
    }

    // Calculate how many to remove
    // Always preserve the baseline (first run) — it anchors expectations.
    // From the remaining runs, keep the last (keepCount - 1).
    final hasBaseline = tracking.runs.isNotEmpty && tracking.runs.first.isBaseline;
    final int removeCount;
    if (hasBaseline && keepCount < totalRuns) {
      // Keep baseline + last (keepCount - 1) runs
      // Remove everything in between
      removeCount = totalRuns - keepCount;
    } else {
      removeCount = totalRuns - keepCount;
    }

    if (removeCount <= 0) {
      print('  $rel: Nothing to trim.');
      return true;
    }

    // Show what will be removed
    final runsToRemove = <String>[];
    // If baseline is preserved, we remove runs at indices 1..(removeCount)
    // If no baseline, we remove runs at indices 0..(removeCount - 1)
    final startIdx = hasBaseline ? 1 : 0;
    final endIdx = startIdx + removeCount;

    for (var i = startIdx; i < endIdx && i < totalRuns; i++) {
      final run = tracking.runs[i];
      final ts =
          '${padTwo(run.timestamp.month)}-${padTwo(run.timestamp.day)} '
          '${padTwo(run.timestamp.hour)}:${padTwo(run.timestamp.minute)}';
      final label = run.isBaseline ? 'Baseline $ts' : ts;
      runsToRemove.add(label);
    }

    print('  $rel: $totalRuns runs → keeping $keepCount'
        '${hasBaseline ? ' + baseline' : ''}');
    print('  Removing ${runsToRemove.length} run(s):');
    for (final label in runsToRemove) {
      print('    - $label');
    }

    // Confirm unless --force
    if (!force) {
      stdout.write('  Continue? (y/N) ');
      final answer = stdin.readLineSync()?.trim().toLowerCase() ?? '';
      if (answer != 'y' && answer != 'yes') {
        print('  Cancelled.');
        return true;
      }
    }

    // Build the trimmed run list
    final keptRuns = <int>[];

    if (hasBaseline) {
      keptRuns.add(0); // Always keep baseline
      // Keep the last (keepCount - 1) runs from the non-baseline runs
      for (var i = endIdx; i < totalRuns; i++) {
        keptRuns.add(i);
      }
    } else {
      // Keep the last keepCount runs
      for (var i = totalRuns - keepCount; i < totalRuns; i++) {
        keptRuns.add(i);
      }
    }

    // Remove results for trimmed runs and rebuild the runs list
    final newRuns = keptRuns.map((i) => tracking.runs[i]).toList();
    tracking.runs
      ..clear()
      ..addAll(newRuns);

    // Write the trimmed file
    await tracking.write(filePath);
    print('  Trimmed to ${tracking.runs.length} run(s). Saved: $rel');

    return true;
  }
}
