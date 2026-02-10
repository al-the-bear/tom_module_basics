import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_test_kit/tom_test_kit.dart';

import 'test_helpers.dart';

/// Test IDs: TK-DIFH-1 through TK-DIFH-10
void main() {
  group('DiffHelper', () {
    group('computeDiff', () {
      test('TK-DIFH-1: returns empty list when runs are identical', () {
        final entries = [
          TestEntry(
            id: 'TK-1',
            fullDescription: 'test one',
            description: 'test one',
          ),
        ];
        final run = TestRun(
          timestamp: DateTime(2026, 2, 10, 14, 30),
          isBaseline: true,
          results: {'test one': TestResult.ok},
        );
        final tracking = TrackingFile.fromBaseline(entries, run);

        final runCopy = TestRun(
          timestamp: DateTime(2026, 2, 11, 10, 0),
          results: {'test one': TestResult.ok},
        );
        tracking.addRun(runCopy, []);

        final diff = DiffHelper.computeDiff(
          tracking,
          tracking.runs[0],
          tracking.runs[1],
        );
        expect(diff, isEmpty);
      });

      test('TK-DIFH-2: detects regression (OK → FAIL)', () {
        final tracking = createMultiRunTracking();

        // Compare baseline vs run2: test A goes OK → FAIL
        final diff = DiffHelper.computeDiff(
          tracking,
          tracking.runs[0], // baseline
          tracking.runs[1], // run2
        );

        expect(diff, isNotEmpty);
        final regressions = diff.where(
          (r) =>
              r.resultA == TestResult.ok && r.resultB == TestResult.fail,
        );
        expect(regressions, isNotEmpty);
      });

      test('TK-DIFH-3: detects fix (FAIL → OK)', () {
        final tracking = createMultiRunTracking();

        // Compare baseline vs run2: test B goes FAIL → OK
        final diff = DiffHelper.computeDiff(
          tracking,
          tracking.runs[0],
          tracking.runs[1],
        );

        final fixes = diff.where(
          (r) =>
              r.resultA == TestResult.fail && r.resultB == TestResult.ok,
        );
        expect(fixes, isNotEmpty);
      });

      test('TK-DIFH-4: sorts regressions before fixes', () {
        final tracking = createMultiRunTracking();

        final diff = DiffHelper.computeDiff(
          tracking,
          tracking.runs[0],
          tracking.runs[1],
        );

        // Regressions should come first (lower priority number)
        if (diff.length >= 2) {
          expect(diff.first.priority, lessThanOrEqualTo(diff.last.priority));
        }
      });
    });

    group('findRunByTimestamp', () {
      test('TK-DIFH-5: finds run by MM-DD_HHMM format', () {
        final tracking = createMultiRunTracking();

        // Baseline timestamp: DateTime(2026, 2, 10, 14, 30) → 02-10_1430
        final run = DiffHelper.findRunByTimestamp(tracking, '02-10_1430');
        expect(run, isNotNull);
        expect(run!.isBaseline, isTrue);
      });

      test('TK-DIFH-6: finds run by MM-DD HH:MM format', () {
        final tracking = createMultiRunTracking();

        // Run 2: DateTime(2026, 2, 11, 10, 0) → 02-11 10:00
        final run = DiffHelper.findRunByTimestamp(tracking, '02-11 10:00');
        expect(run, isNotNull);
        expect(run!.comment, equals('second run'));
      });

      test('TK-DIFH-7: returns null for non-matching timestamp', () {
        final tracking = createMultiRunTracking();

        final run = DiffHelper.findRunByTimestamp(tracking, '9999_9999');
        expect(run, isNull);
      });
    });

    group('writeDiff', () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('tk_diffhelper_test_');
      });

      tearDown(() {
        tempDir.deleteSync(recursive: true);
      });

      test('TK-DIFH-8: writes diff rows to CSV file', () async {
        final tracking = createMultiRunTracking();
        final diff = DiffHelper.computeDiff(
          tracking,
          tracking.runs[0],
          tracking.runs[1],
        );

        final outputPath = '${tempDir.path}/diff.csv';
        await DiffHelper.writeDiff(
          rows: diff,
          labelA: 'Baseline',
          labelB: 'Run 2',
          output: OutputSpec(format: OutputFormat.csv, filePath: outputPath),
        );

        final content = File(outputPath).readAsStringSync();
        expect(content, contains('ID'));
        expect(content, contains('Change'));
        expect(content, contains('Baseline'));
        expect(content, contains('Run 2'));
      });

      test('TK-DIFH-9: writes empty diff with no rows', () async {
        final outputPath = '${tempDir.path}/empty_diff.csv';
        await DiffHelper.writeDiff(
          rows: [],
          labelA: 'A',
          labelB: 'B',
          output: OutputSpec(format: OutputFormat.csv, filePath: outputPath),
        );

        final content = File(outputPath).readAsStringSync();
        // Should have header row only
        final lines =
            content.split('\n').where((l) => l.trim().isNotEmpty).toList();
        expect(lines.length, equals(1)); // header only
      });
    });

    group('DiffRow', () {
      test('TK-DIFH-10: changeLabel reflects regression/fix/other', () {
        final entry = TestEntry(
          fullDescription: 'test',
          description: 'test',
        );

        // Regression: OK → FAIL
        final regression = DiffRow(
          entry: entry,
          resultA: TestResult.ok,
          resultB: TestResult.fail,
        );
        expect(regression.changeLabel.toLowerCase(), contains('regression'));

        // Fix: FAIL → OK
        final fix = DiffRow(
          entry: entry,
          resultA: TestResult.fail,
          resultB: TestResult.ok,
        );
        expect(fix.changeLabel.toLowerCase(), contains('fix'));
      });
    });
  });
}
