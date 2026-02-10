import 'dart:io';

import 'test_entry.dart';
import 'test_run.dart';

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
    buf.write('| ID / Description |');
    for (final run in runs) {
      buf.write(' ${run.columnHeader} |');
    }
    buf.writeln();

    // Separator
    buf.write('|---|');
    for (var i = 0; i < runs.length; i++) {
      buf.write('---|');
    }
    buf.writeln();

    // Rows
    for (final entry in sorted) {
      buf.write('| ${_escapeMarkdown(entry.displayLabel)} |');
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

  /// Escapes pipe characters in markdown table cells.
  static String _escapeMarkdown(String text) {
    return text.replaceAll('|', '\\|');
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

    // Find the results table
    final headerIdx = lines.indexWhere((l) => l.startsWith('| ID / Description |'));
    if (headerIdx == -1) return null;

    final headerLine = lines[headerIdx];
    final separatorIdx = headerIdx + 1;
    if (separatorIdx >= lines.length) return null;

    // Parse column headers to extract run timestamps
    final headerCells = _splitTableRow(headerLine);
    if (headerCells.length < 2) return null;

    final runs = <TestRun>[];
    for (var i = 1; i < headerCells.length; i++) {
      final cell = headerCells[i].trim();
      final isBaseline = cell.startsWith('Baseline');
      final timestamp = _parseColumnTimestamp(cell);
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

      final cells = _splitTableRow(line);
      if (cells.isEmpty) continue;

      final label = cells[0].trim().replaceAll('\\|', '|');
      // Re-parse the label to extract test entry metadata
      final entry = _parseEntryFromLabel(label);
      entries[entry.fullDescription] = entry;

      // Parse result cells
      for (var j = 1; j < cells.length && j - 1 < runs.length; j++) {
        final resultStr = cells[j].trim();
        final result = _parseResultCell(resultStr);
        runs[j - 1].setResult(entry.fullDescription, result);
      }
    }

    return TrackingFile(entries: entries, runs: runs);
  }

  /// Splits a markdown table row into cells.
  static List<String> _splitTableRow(String row) {
    // Handle escaped pipes
    final cleaned = row.trim();
    if (!cleaned.startsWith('|') || !cleaned.endsWith('|')) return [];

    final inner = cleaned.substring(1, cleaned.length - 1);
    final cells = <String>[];
    final buf = StringBuffer();
    for (var i = 0; i < inner.length; i++) {
      if (inner[i] == '|' && (i == 0 || inner[i - 1] != '\\')) {
        cells.add(buf.toString());
        buf.clear();
      } else {
        buf.write(inner[i]);
      }
    }
    cells.add(buf.toString());
    return cells;
  }

  /// Parses `[MM-DD HH:MM]` from a column header.
  static DateTime? _parseColumnTimestamp(String header) {
    final match = RegExp(r'\[(\d{2})-(\d{2})\s+(\d{2}):(\d{2})\]').firstMatch(header);
    if (match == null) return null;

    final now = DateTime.now();
    return DateTime(
      now.year,
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
    );
  }

  /// Parses a result cell back into a [TestResult].
  static TestResult _parseResultCell(String cell) {
    if (cell.startsWith('OK')) return TestResult.ok;
    if (cell.startsWith('X')) return TestResult.fail;
    if (cell.startsWith('SKIP')) return TestResult.skip;
    if (cell.startsWith('-')) return TestResult.absent;
    return TestResult.absent;
  }

  /// Parses a test entry from a display label.
  static TestEntry _parseEntryFromLabel(String label) {
    // Try to parse ID, description, date, expectation
    String? id;
    var description = label;
    DateTime? creationDate;
    var expectation = 'OK';

    // Extract ID (text before first colon)
    final colonIdx = label.indexOf(':');
    if (colonIdx > 0 && colonIdx < 20) {
      id = label.substring(0, colonIdx).trim();
      description = label.substring(colonIdx + 1).trim();
    }

    // Extract creation date [YYYY-MM-DD HH:MM]
    final dateMatch =
        RegExp(r'\[(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})\]').firstMatch(description);
    if (dateMatch != null) {
      creationDate = DateTime(
        int.parse(dateMatch.group(1)!),
        int.parse(dateMatch.group(2)!),
        int.parse(dateMatch.group(3)!),
        int.parse(dateMatch.group(4)!),
        int.parse(dateMatch.group(5)!),
      );
      description = description.replaceFirst(dateMatch.group(0)!, '').trim();
    }

    // Extract expected result (PASS)/(FAIL) from remaining description
    final expectMatch = RegExp(r'\((PASS|FAIL)\)\s*$').firstMatch(description);
    if (expectMatch != null) {
      expectation = expectMatch.group(1) == 'FAIL' ? 'FAIL' : 'OK';
      description = description.replaceFirst(expectMatch.group(0)!, '').trim();
    }

    return TestEntry(
      id: id,
      fullDescription: label,
      description: description,
      creationDate: creationDate,
      expectation: expectation,
    );
  }
}
