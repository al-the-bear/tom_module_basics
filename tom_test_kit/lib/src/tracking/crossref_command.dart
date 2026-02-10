import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/tracking_file.dart';
import '../util/file_helpers.dart';
import '../util/output_formatter.dart';

/// Implements the `:crossreference` subcommand.
///
/// Creates a table mapping each test to its source file and line number.
/// Output columns: Test ID, Group, Description, Source File, Line, Relative Link.
class CrossReferenceCommand {
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

    // Build cross-reference from test entries
    final headers = [
      'ID',
      'Group',
      'Description',
      'Source File',
      'Line',
      'Link',
    ];
    final rows = <List<String>>[];

    for (final entry in tracking.sortedEntries()) {
      final suite = entry.suite ?? '';
      final line = _findTestLine(projectPath, entry.fullDescription, suite);
      final relativeSuite =
          suite.isNotEmpty ? p.relative(suite, from: projectPath) : '';
      final link = line != null && relativeSuite.isNotEmpty
          ? '$relativeSuite#L$line'
          : relativeSuite;

      rows.add([
        entry.id ?? '',
        entry.groups ?? '',
        entry.description,
        relativeSuite,
        line?.toString() ?? '',
        link,
      ]);
    }

    final spec = output ?? OutputSpec.defaultSpec;
    await OutputWriter(spec).writeTable(
      headers: headers,
      rows: rows,
      title: 'Test Cross-Reference',
    );

    return true;
  }

  /// Attempts to find the line number of a test in its source file.
  ///
  /// Searches for the test description string in the file content.
  /// Returns the line number (1-based) or null if not found.
  static int? _findTestLine(
    String projectPath,
    String fullDescription,
    String suitePath,
  ) {
    if (suitePath.isEmpty) return null;

    final filePath =
        p.isAbsolute(suitePath) ? suitePath : p.join(projectPath, suitePath);
    final file = File(filePath);
    if (!file.existsSync()) return null;

    try {
      final lines = file.readAsLinesSync();
      // Search for the test description in the file
      // Look for test('description or group('description patterns
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Extract the description part from fullDescription
        // (strip ID prefix if present)
        final colonIdx = fullDescription.indexOf(':');
        final searchStr = colonIdx > 0 && colonIdx < 20
            ? fullDescription.substring(colonIdx + 1).trim()
            : fullDescription;

        if (line.contains("'$searchStr'") ||
            line.contains('"$searchStr"')) {
          return i + 1; // 1-based
        }
      }
    } catch (_) {
      // Ignore file read errors
    }
    return null;
  }
}
