import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/test_run.dart';
import '../model/tracking_file.dart';
import '../util/file_helpers.dart';
import '../util/format_helpers.dart';
import '../util/output_formatter.dart';

/// Implements the `:history` subcommand.
///
/// Shows all results for a specific test across all runs, making it easy
/// to track regressions and fixes over time.
class HistoryCommand {
  /// Runs the command for a single project.
  ///
  /// [testName] is a search string matched against test full descriptions.
  /// It can be a substring, test ID, or exact description. If multiple tests
  /// match, all are shown.
  ///
  /// Returns true on success, false on failure.
  static Future<bool> run({
    required String projectPath,
    required String testName,
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

    // Find matching tests (case-insensitive substring match)
    final query = testName.toLowerCase();
    final matches = tracking.entries.entries.where((e) {
      final key = e.key.toLowerCase();
      final entry = e.value;
      return key.contains(query) ||
          (entry.id != null && entry.id!.toLowerCase().contains(query));
    }).toList();

    if (matches.isEmpty) {
      stderr.writeln('  No tests matching "$testName".');
      return false;
    }

    final spec = output ?? OutputSpec.defaultSpec;

    // Build header: Test, then one column per run timestamp
    final headers = <String>['Test'];
    for (final run in tracking.runs) {
      final ts =
          '${padTwo(run.timestamp.month)}-${padTwo(run.timestamp.day)} '
          '${padTwo(run.timestamp.hour)}:${padTwo(run.timestamp.minute)}';
      final label = run.isBaseline ? 'B $ts' : ts;
      headers.add(label);
    }

    // Build rows: one per matching test
    final rows = <List<String>>[];
    for (final match in matches) {
      final entry = match.value;
      final label = entry.id != null
          ? '${entry.id}: ${entry.description}'
          : entry.description;

      final row = <String>[label];
      for (final run in tracking.runs) {
        final result = run.getResult(match.key);
        row.add(formatResultCell(result, entry.expectation));
      }
      rows.add(row);
    }

    final matchLabel = matches.length == 1
        ? matches.first.value.description
        : '${matches.length} tests matching "$testName"';
    final title = 'History: $matchLabel';

    await OutputWriter(spec).writeTable(
      headers: headers,
      rows: rows,
      title: title,
    );

    return true;
  }
}
