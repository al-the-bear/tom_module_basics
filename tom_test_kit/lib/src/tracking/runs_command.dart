import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/tracking_file.dart';
import '../util/file_helpers.dart';
import '../util/format_helpers.dart';
import '../util/output_formatter.dart';

/// Implements the `:runs` subcommand.
///
/// Lists the timestamps (and comments) of all test runs in the most recent
/// or specified baseline file.
class RunsCommand {
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

    final spec = output ?? OutputSpec.defaultSpec;
    final headers = ['#', 'Timestamp', 'Type', 'Comment'];
    final rows = <List<String>>[];

    for (var i = 0; i < tracking.runs.length; i++) {
      final run = tracking.runs[i];
      final ts = '${padTwo(run.timestamp.month)}-${padTwo(run.timestamp.day)} '
          '${padTwo(run.timestamp.hour)}:${padTwo(run.timestamp.minute)}';
      rows.add([
        '${i + 1}',
        ts,
        run.isBaseline ? 'baseline' : 'run',
        run.comment ?? '',
      ]);
    }

    final title = 'Runs in ${p.basename(filePath)}';
    await OutputWriter(spec).writeTable(
      headers: headers,
      rows: rows,
      title: title,
    );

    return true;
  }
}
