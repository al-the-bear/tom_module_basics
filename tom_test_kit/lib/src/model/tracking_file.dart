import 'dart:io';

import 'test_entry.dart';
import 'test_run.dart';
import '../util/format_helpers.dart';
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

  /// Writes the tracking file to disk as markdown.
  Future<void> write(String filePath) async {
    final sorted = sortedEntries();
    final buf = StringBuffer();

    // Header
    buf.writeln('# Test Result Tracking');
    buf.writeln();

    // Summary
    if (runs.isNotEmpty) {
      final latestRun = runs.last;
      var passCount = 0;
      var failCount = 0;
      var skipCount = 0;
      for (final entry in sorted) {
        final result = latestRun.getResult(entry.fullDescription);
        switch (result) {
          case TestResult.ok:
            passCount++;
          case TestResult.fail:
            failCount++;
          case TestResult.skip:
            skipCount++;
          case TestResult.absent:
            break;
        }
      }
      buf.writeln('## Summary');
      buf.writeln();
      buf.writeln('| Metric | Count |');
      buf.writeln('|--------|-------|');
      buf.writeln('| Total | ${sorted.length} |');
      buf.writeln('| Passed | $passCount |');
      buf.writeln('| Failed | $failCount |');
      if (skipCount > 0) buf.writeln('| Skipped | $skipCount |');
      buf.writeln();
    }

    // Table
    buf.writeln('## Results');
    buf.writeln();

    // Table header
    buf.write('| ID | Groups | Description |');
    for (final run in runs) {
      buf.write(' ${run.columnHeader} |');
    }
    buf.writeln();

    // Separator
    buf.write('|---|---|---|');
    for (var i = 0; i < runs.length; i++) {
      buf.write('---|');
    }
    buf.writeln();

    // Rows
    for (final entry in sorted) {
      buf.write('| ${escapeMarkdownCell(entry.id ?? '')} |');
      buf.write(' ${escapeMarkdownCell(entry.groups ?? '')} |');
      buf.write(' ${escapeMarkdownCell(entry.descriptionLabel)} |');
      for (final run in runs) {
        final result = run.getResult(entry.fullDescription);
        buf.write(' ${formatResultCell(result, entry.expectation)} |');
      }
      buf.writeln();
    }

    buf.writeln();
    buf.writeln('## Legend');
    buf.writeln();
    buf.writeln('| Cell | Meaning |');
    buf.writeln('|------|---------|');
    buf.writeln('| OK/OK | Passed as expected |');
    buf.writeln('| X/OK | **Regression** — failed unexpectedly |');
    buf.writeln('| X/FAIL | Known failure — expected |');
    buf.writeln('| OK/FAIL | **Progress** — passed unexpectedly |');
    buf.writeln('| SKIP/OK | Skipped — needs attention |');
    buf.writeln('| -/OK | Not present in this run |');

    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(buf.toString());
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

  /// Parses a tracking file from its markdown content.
  static TrackingFile? _parse(String content) {
    final lines = content.split('\n');

    // Find the results table — support both new 3-column and old 1-column format
    var headerIdx =
        lines.indexWhere((l) => l.startsWith('| ID | Groups | Description |'));
    final isNewFormat = headerIdx != -1;

    if (!isNewFormat) {
      headerIdx =
          lines.indexWhere((l) => l.startsWith('| ID / Description |'));
    }
    if (headerIdx == -1) return null;

    final headerLine = lines[headerIdx];
    final separatorIdx = headerIdx + 1;
    if (separatorIdx >= lines.length) return null;

    // Parse column headers to extract run timestamps
    final headerCells = splitTableRow(headerLine);
    if (headerCells.length < 2) return null;

    // Fixed columns: 3 for new format (ID, Groups, Description), 1 for old
    final fixedColumns = isNewFormat ? 3 : 1;

    final runs = <TestRun>[];
    for (var i = fixedColumns; i < headerCells.length; i++) {
      final cell = headerCells[i].trim();
      final isBaseline = cell.startsWith('Baseline');
      final timestamp = parseColumnTimestamp(cell);
      if (timestamp != null) {
        runs.add(TestRun(
          timestamp: timestamp,
          isBaseline: isBaseline,
        ));
      }
    }

    // Parse data rows
    final entries = <String, TestEntry>{};
    for (var i = separatorIdx + 1; i < lines.length; i++) {
      final line = lines[i];
      if (!line.startsWith('|') || line.trim().isEmpty) break;

      final cells = splitTableRow(line);
      if (cells.isEmpty) continue;

      TestEntry entry;
      int resultStartCol;

      if (isNewFormat) {
        if (cells.length < 3) continue;
        entry = parseEntryFromColumns(
          id: cells[0].trim().replaceAll('\\|', '|'),
          groups: cells[1].trim().replaceAll('\\|', '|'),
          description: cells[2].trim().replaceAll('\\|', '|'),
        );
        resultStartCol = 3;
      } else {
        final label = cells[0].trim().replaceAll('\\|', '|');
        entry = parseEntryFromLabel(label);
        resultStartCol = 1;
      }

      entries[entry.fullDescription] = entry;

      // Parse result cells
      for (var j = resultStartCol;
          j < cells.length && j - resultStartCol < runs.length;
          j++) {
        final resultStr = cells[j].trim();
        final result = parseResultCell(resultStr);
        runs[j - resultStartCol].setResult(entry.fullDescription, result);
      }
    }

    return TrackingFile(entries: entries, runs: runs);
  }
}
