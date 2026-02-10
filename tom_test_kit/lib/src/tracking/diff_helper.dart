import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/test_entry.dart';
import '../model/test_run.dart';
import '../model/tracking_file.dart';
import '../util/format_helpers.dart';
import '../util/output_formatter.dart';

/// Shared logic for diff commands (:basediff, :lastdiff, :diff).
///
/// Compares two runs from a tracking file and outputs the differences.
class DiffHelper {
  /// Computes differences between two runs.
  ///
  /// Returns rows where the result changed between [runA] and [runB].
  static List<DiffRow> computeDiff(
    TrackingFile tracking,
    TestRun runA,
    TestRun runB,
  ) {
    final rows = <DiffRow>[];

    for (final entry in tracking.entries.values) {
      final key = entry.fullDescription;
      final resultA = runA.getResult(key);
      final resultB = runB.getResult(key);

      if (resultA != resultB) {
        rows.add(DiffRow(
          entry: entry,
          resultA: resultA,
          resultB: resultB,
        ));
      }
    }

    // Sort: regressions first, then fixes, then other changes
    rows.sort((a, b) => a.priority.compareTo(b.priority));
    return rows;
  }

  /// Outputs diff rows in the specified format.
  static Future<void> writeDiff({
    required List<DiffRow> rows,
    required String labelA,
    required String labelB,
    required OutputSpec output,
    String? title,
  }) async {
    final headers = ['ID', 'Groups', 'Description', labelA, labelB, 'Change'];
    final tableRows = rows.map<List<String>>((r) => [
          r.entry.id ?? '',
          r.entry.groups ?? '',
          r.entry.description,
          r.resultA.label,
          r.resultB.label,
          r.changeLabel,
        ]).toList();

    await OutputWriter(output).writeTable(
      headers: headers,
      rows: tableRows,
      title: title,
    );
  }

  /// Generates a full report in Markdown with detailed test information
  /// from last_testrun.json.
  static Future<void> writeReport({
    required List<DiffRow> rows,
    required String labelA,
    required String labelB,
    required String projectPath,
    String? filePath,
    String? title,
  }) async {
    final jsonFile = File(p.join(projectPath, 'doc', 'last_testrun.json'));
    if (!jsonFile.existsSync()) {
      stderr.writeln('Error: doc/last_testrun.json not found.');
      stderr.writeln(
          'Run tests first to generate the JSON output file.');
      return;
    }

    // Parse last_testrun.json for detailed error info
    final jsonContent = jsonFile.readAsStringSync();
    final testDetails = _parseTestDetails(jsonContent);

    final buf = StringBuffer();
    buf.writeln('# ${title ?? 'Test Diff Report'}');
    buf.writeln();

    // Summary table
    buf.writeln('## Summary');
    buf.writeln();
    buf.writeln('| ID | Groups | Description | $labelA | $labelB | Change |');
    buf.writeln('| -- | ------ | ----------- | '
        '${'-' * labelA.length} | ${'-' * labelB.length} | ------ |');

    for (final row in rows) {
      buf.writeln('| ${row.entry.id ?? ''} '
          '| ${row.entry.groups ?? ''} '
          '| ${row.entry.description} '
          '| ${row.resultA.label} '
          '| ${row.resultB.label} '
          '| ${row.changeLabel} |');
    }
    buf.writeln();

    // Details for failed tests
    final failedRows =
        rows.where((r) => r.resultB == TestResult.fail).toList();
    if (failedRows.isNotEmpty) {
      buf.writeln('## Failure Details');
      buf.writeln();

      for (final row in failedRows) {
        final detail = testDetails[row.entry.fullDescription];
        buf.writeln('### ${row.entry.id ?? row.entry.description}');
        buf.writeln();
        if (row.entry.groups != null) {
          buf.writeln('**Group:** ${row.entry.groups}');
        }
        buf.writeln('**Description:** ${row.entry.description}');
        buf.writeln('**Change:** ${row.changeLabel}');
        buf.writeln();

        if (detail != null) {
          if (detail.errorMessage != null) {
            buf.writeln('**Error:**');
            buf.writeln('```');
            buf.writeln(detail.errorMessage);
            buf.writeln('```');
            buf.writeln();
          }
          if (detail.stackTrace != null) {
            buf.writeln('**Stack trace:**');
            buf.writeln('```');
            buf.writeln(detail.stackTrace);
            buf.writeln('```');
            buf.writeln();
          }
        } else {
          buf.writeln('_No detailed information available._');
          buf.writeln();
        }
      }
    }

    final content = buf.toString();
    if (filePath != null) {
      final file = File(filePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
    } else {
      stdout.write(content);
    }
  }

  /// Validates that last_testrun.json matches the latest run in the tracking
  /// file (for --full mode).
  static bool validateLastTestRun(
    String projectPath,
    TrackingFile tracking,
  ) {
    final jsonFile = File(p.join(projectPath, 'doc', 'last_testrun.json'));
    if (!jsonFile.existsSync()) return false;

    final jsonContent = jsonFile.readAsStringSync();
    final testDetails = _parseTestDetails(jsonContent);
    if (testDetails.isEmpty) return false;

    // Check that at least 80% of tests in the latest run are also
    // present in the JSON output (allowing for minor differences)
    final latestRun = tracking.runs.last;
    var matchCount = 0;
    var totalChecked = 0;
    for (final key in tracking.entries.keys) {
      final result = latestRun.getResult(key);
      if (result == TestResult.absent) continue;
      totalChecked++;
      if (testDetails.containsKey(key)) matchCount++;
    }

    if (totalChecked == 0) return true;
    return matchCount / totalChecked >= 0.5;
  }

  /// Parses last_testrun.json for detailed test information.
  static Map<String, TestDetail> _parseTestDetails(String jsonContent) {
    final details = <String, TestDetail>{};
    final lines = jsonContent.split('\n');

    final testNames = <int, String>{};
    final testErrors = <int, String>{};
    final testStackTraces = <int, String>{};
    final testDurations = <int, int>{};
    final testPrintOutput = <int, List<String>>{};

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      Map<String, dynamic> json;
      try {
        json = jsonDecode(line) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }

      final type = json['type'] as String?;
      if (type == null) continue;

      switch (type) {
        case 'testStart':
          final test = json['test'] as Map<String, dynamic>?;
          if (test != null) {
            testNames[test['id'] as int] = test['name'] as String? ?? '';
          }

        case 'error':
          final testId = json['testID'] as int?;
          if (testId != null) {
            testErrors[testId] = json['error'] as String? ?? '';
            testStackTraces[testId] =
                json['stackTrace'] as String? ?? '';
          }

        case 'print':
          final testId = json['testID'] as int?;
          if (testId != null) {
            testPrintOutput
                .putIfAbsent(testId, () => [])
                .add(json['message'] as String? ?? '');
          }

        case 'testDone':
          final testId = json['testID'] as int?;
          if (testId != null) {
            final time = json['time'] as int?;
            if (time != null) testDurations[testId] = time;

            final name = testNames[testId];
            if (name != null && name.isNotEmpty && !name.startsWith('loading ')) {
              details[name] = TestDetail(
                errorMessage: testErrors[testId],
                stackTrace: testStackTraces[testId],
                durationMs: testDurations[testId],
                printOutput: testPrintOutput[testId],
              );
            }
          }
      }
    }

    return details;
  }

  /// Finds a run by its timestamp string (MM-DD HH:MM format).
  static TestRun? findRunByTimestamp(
    TrackingFile tracking,
    String timestampStr,
  ) {
    // Parse MM-DD HH:MM or MM-DD_HHMM formats
    final normalized = timestampStr
        .replaceAll('[', '')
        .replaceAll(']', '')
        .trim();

    for (final run in tracking.runs) {
      final ts = '${padTwo(run.timestamp.month)}-${padTwo(run.timestamp.day)} '
          '${padTwo(run.timestamp.hour)}:${padTwo(run.timestamp.minute)}';
      final tsCompact =
          '${padTwo(run.timestamp.month)}-${padTwo(run.timestamp.day)}_'
          '${padTwo(run.timestamp.hour)}${padTwo(run.timestamp.minute)}';
      if (normalized == ts || normalized == tsCompact) {
        return run;
      }
    }
    return null;
  }
}

/// Detailed information about a test from JSON output.
class TestDetail {
  final String? errorMessage;
  final String? stackTrace;
  final int? durationMs;
  final List<String>? printOutput;

  TestDetail({
    this.errorMessage,
    this.stackTrace,
    this.durationMs,
    this.printOutput,
  });
}

/// A single row of a diff result.
class DiffRow {
  final TestEntry entry;
  final TestResult resultA;
  final TestResult resultB;

  DiffRow({
    required this.entry,
    required this.resultA,
    required this.resultB,
  });

  /// Human-readable change label.
  String get changeLabel {
    if (resultA == TestResult.ok && resultB == TestResult.fail) {
      return 'REGRESSION';
    }
    if (resultA == TestResult.fail && resultB == TestResult.ok) {
      return 'FIXED';
    }
    if (resultB == TestResult.absent) return 'REMOVED';
    if (resultA == TestResult.absent) return 'NEW';
    return '${resultA.label} → ${resultB.label}';
  }

  /// Sort priority: regressions first, then other changes, then fixes.
  int get priority {
    if (resultA == TestResult.ok && resultB == TestResult.fail) return 0;
    if (resultA == TestResult.fail && resultB == TestResult.ok) return 4;
    if (resultB == TestResult.absent) return 3;
    if (resultA == TestResult.absent) return 2;
    return 1;
  }
}
