import 'dart:io';

import 'test_entry.dart';
import 'test_run.dart';
import '../util/markdown_table.dart';

/// Manages the tracking file: reading, writing, and appending runs.
class TrackingFile {
  /// All tracked test entries, keyed by full description.
  final Map<String, TestEntry> entries;

  /// All runs in chronological order.
  final List<TestRun> runs;

  TrackingFile({
    Map<String, TestEntry>? entries,
    List<TestRun>? runs,
  })  : entries = entries ?? {},
        runs = runs ?? [];

  /// Creates a new tracking file from a baseline run.
  factory TrackingFile.fromBaseline(
    List<TestEntry> testEntries,
    TestRun baselineRun,
  ) {
    final entries = <String, TestEntry>{};
    for (final entry in testEntries) {
      entries[entry.fullDescription] = entry;
    }
    return TrackingFile(
      entries: entries,
      runs: [baselineRun],
    );
  }

  /// Adds a new run and merges any new test entries.
  void addRun(TestRun run, List<TestEntry> newEntries) {
    // Add any entries not already tracked
    for (final entry in newEntries) {
      entries.putIfAbsent(entry.fullDescription, () => entry);
    }

    // Mark tests not present in this run
    for (final key in entries.keys) {
      if (!run.results.containsKey(key)) {
        run.setResult(key, TestResult.absent);
      }
    }

    runs.add(run);
  }

  /// Returns entries sorted by the standard sort order based on the latest run.
  List<TestEntry> sortedEntries() {
    if (runs.isEmpty) return entries.values.toList();

    final latestRun = runs.last;
    final sortable = entries.values.map((entry) {
      final result = latestRun.getResult(entry.fullDescription);
      return SortableTestEntry(entry, result);
    }).toList();

    sortable.sort((a, b) {
      // Primary: result priority
      final priorityCompare = a.sortPriority.compareTo(b.sortPriority);
      if (priorityCompare != 0) return priorityCompare;

      // Secondary: creation date (oldest first)
      return a.entry.sortDate.compareTo(b.entry.sortDate);
    });

    return sortable.map((s) => s.entry).toList();
  }

  /// Writes the tracking file to disk as CSV.
  ///
  /// The main results table comes first (header row + data rows), followed
  /// by an empty line separator and a summary section.
  Future<void> write(String filePath) async {
    final sorted = sortedEntries();
    final buf = StringBuffer();

    // --- Results table (header row first for tool compatibility) ---

    // Header row
    buf.write('ID,Groups,Description');
    for (final run in runs) {
      buf.write(',${_escapeCsv(run.columnHeader)}');
    }
    buf.writeln();

    // Data rows
    for (final entry in sorted) {
      buf.write('${_escapeCsv(entry.id ?? '')},');
      buf.write('${_escapeCsv(entry.groups ?? '')},');
      buf.write(_escapeCsv(entry.descriptionLabel));
      for (final run in runs) {
        final result = run.getResult(entry.fullDescription);
        buf.write(',${formatResultCell(result, entry.expectation)}');
      }
      buf.writeln();
    }



    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(buf.toString());
  }

  /// Escapes a value for CSV output.
  ///
  /// Wraps in double-quotes if the value contains commas, double-quotes,
  /// or newlines. Internal double-quotes are doubled.
  static String _escapeCsv(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Loads a tracking file from disk.
  ///
  /// Returns null if the file doesn't exist or can't be parsed.
  static TrackingFile? load(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    final content = file.readAsStringSync();
    return _parse(content);
  }

  /// Parses a tracking file from its CSV content.
  static TrackingFile? _parse(String content) {
    final lines = content.split('\n');
    if (lines.isEmpty) return null;

    // The first line must be the header row starting with ID,Groups,Description
    final headerLine = lines[0].trim();
    if (!headerLine.startsWith('ID,Groups,Description')) return null;

    // Parse column headers to extract run timestamps
    final headerCells = _splitCsvRow(headerLine);
    if (headerCells.length < 3) return null;

    final runs = <TestRun>[];
    for (var i = 3; i < headerCells.length; i++) {
      final cell = headerCells[i].trim();
      final parsed = parseColumnHeader(cell);
      if (parsed != null) {
        runs.add(TestRun(
          timestamp: parsed.timestamp,
          isBaseline: parsed.isBaseline,
          comment: parsed.comment,
        ));
      }
    }

    // Parse data rows (stop at empty line or end)
    final entries = <String, TestEntry>{};
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) break;

      final cells = _splitCsvRow(line);
      if (cells.length < 3) continue;

      final entry = parseEntryFromColumns(
        id: cells[0],
        groups: cells[1],
        description: cells[2],
      );
      entries[entry.fullDescription] = entry;

      // Parse result cells
      for (var j = 3; j < cells.length && j - 3 < runs.length; j++) {
        final resultStr = cells[j].trim();
        final result = parseResultCell(resultStr);
        runs[j - 3].setResult(entry.fullDescription, result);
      }
    }

    return TrackingFile(entries: entries, runs: runs);
  }

  /// Splits a CSV row into cells, handling quoted fields.
  static List<String> _splitCsvRow(String row) {
    final cells = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < row.length; i++) {
      final ch = row[i];
      if (inQuotes) {
        if (ch == '"') {
          // Check for escaped quote ""
          if (i + 1 < row.length && row[i + 1] == '"') {
            buf.write('"');
            i++; // Skip next quote
          } else {
            inQuotes = false;
          }
        } else {
          buf.write(ch);
        }
      } else {
        if (ch == '"') {
          inQuotes = true;
        } else if (ch == ',') {
          cells.add(buf.toString());
          buf.clear();
        } else {
          buf.write(ch);
        }
      }
    }
    cells.add(buf.toString());
    return cells;
  }
}
