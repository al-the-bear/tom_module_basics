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
///
/// Search matches against test ID, description, group path, and the full
/// test path (groups + description). If the search string matches a test ID
/// exactly, only that test is returned. Otherwise all substring matches are
/// shown.
class HistoryCommand {
  /// Runs the command for a single project.
  ///
  /// [searchTerm] is matched case-insensitively against:
  /// - Test ID (e.g., "TK-RUN-5") — exact match returns only that test
  /// - Test description text
  /// - Group path
  /// - Full test path (group + description combined)
  ///
  /// Returns true on success, false on failure.
  static Future<bool> run({
    required String projectPath,
    required String searchTerm,
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

    // Search priority:
    // 1. Exact ID match (case-insensitive) → single result
    // 2. Substring match on ID, description, groups, or full path
    final query = searchTerm.toLowerCase();

    // Check for exact ID match first
    final exactIdMatch = tracking.entries.entries.where((e) {
      final id = e.value.id;
      return id != null && id.toLowerCase() == query;
    }).toList();

    final matches = exactIdMatch.isNotEmpty
        ? exactIdMatch
        : tracking.entries.entries.where((e) {
            final entry = e.value;
            // Match against full path (group + description), ID, description,
            // and groups individually
            return e.key.toLowerCase().contains(query) ||
                (entry.id != null &&
                    entry.id!.toLowerCase().contains(query)) ||
                entry.description.toLowerCase().contains(query) ||
                (entry.groups != null &&
                    entry.groups!.toLowerCase().contains(query));
          }).toList();

    if (matches.isEmpty) {
      stderr.writeln('  No tests matching "$searchTerm".');
      if (verbose) {
        stderr.writeln('  Search matches against test ID, description, '
            'group path, and full test path.');
      }
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
        : '${matches.length} tests matching "$searchTerm"';
    final title = 'History: $matchLabel';

    await OutputWriter(spec).writeTable(
      headers: headers,
      rows: rows,
      title: title,
    );

    return true;
  }
}
