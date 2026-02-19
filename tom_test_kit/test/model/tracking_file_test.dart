import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tom_test_kit/tom_test_kit.dart';

/// Test IDs: TK-TRK-1 through TK-TRK-9
void main() {
  group('TrackingFile', () {
    group('fromBaseline', () {
      test(
        'TK-TRK-1: should create tracking file with entries and one run',
        () {
          final entries = [
            TestEntry(fullDescription: 'test A', description: 'test A'),
            TestEntry(
              fullDescription: 'test B',
              description: 'test B',
              expectation: 'FAIL',
            ),
          ];
          final run = TestRun(
            timestamp: DateTime(2026, 2, 10, 14, 30),
            isBaseline: true,
            results: {'test A': TestResult.ok, 'test B': TestResult.fail},
          );

          final tracking = TrackingFile.fromBaseline(entries, run);

          expect(tracking.entries, hasLength(2));
          expect(tracking.runs, hasLength(1));
          expect(tracking.runs.first.isBaseline, isTrue);
        },
      );
    });

    group('addRun', () {
      test('TK-TRK-2: should append a run and merge new entries', () {
        final baseline = _createBaselineTracking();
        final newRun = TestRun(
          timestamp: DateTime(2026, 2, 10, 15, 0),
          results: {'test A': TestResult.ok, 'new test': TestResult.ok},
        );
        final newEntries = [
          TestEntry(fullDescription: 'new test', description: 'new test'),
        ];

        baseline.addRun(newRun, newEntries);

        expect(baseline.runs, hasLength(2));
        expect(baseline.entries, hasLength(3)); // A, B, new
      });

      test('TK-TRK-3: should mark missing tests as absent in new run', () {
        final baseline = _createBaselineTracking();
        final newRun = TestRun(
          timestamp: DateTime(2026, 2, 10, 15, 0),
          results: {'test A': TestResult.ok},
          // test B is not in results
        );

        baseline.addRun(newRun, []);

        expect(newRun.getResult('test B'), equals(TestResult.absent));
      });
    });

    group('sortedEntries', () {
      test('TK-TRK-4: should sort regressions before healthy tests', () {
        final entries = [
          TestEntry(fullDescription: 'healthy', description: 'healthy'),
          TestEntry(fullDescription: 'regression', description: 'regression'),
        ];
        final run = TestRun(
          timestamp: DateTime.now(),
          isBaseline: true,
          results: {'healthy': TestResult.ok, 'regression': TestResult.fail},
        );
        final tracking = TrackingFile.fromBaseline(entries, run);
        final sorted = tracking.sortedEntries();

        // regression (X/OK = priority 0) should come before healthy (OK/OK = priority 3)
        expect(sorted.first.fullDescription, equals('regression'));
        expect(sorted.last.fullDescription, equals('healthy'));
      });

      test(
        'TK-TRK-5: should sort by creation date within same priority group',
        () {
          final entries = [
            TestEntry(
              fullDescription: 'newer',
              description: 'newer',
              creationDate: DateTime(2026, 3, 1),
            ),
            TestEntry(
              fullDescription: 'older',
              description: 'older',
              creationDate: DateTime(2026, 1, 1),
            ),
          ];
          final run = TestRun(
            timestamp: DateTime.now(),
            isBaseline: true,
            results: {'newer': TestResult.ok, 'older': TestResult.ok},
          );
          final tracking = TrackingFile.fromBaseline(entries, run);
          final sorted = tracking.sortedEntries();

          // Both OK/OK (priority 3), older creation date first
          expect(sorted.first.fullDescription, equals('older'));
          expect(sorted.last.fullDescription, equals('newer'));
        },
      );
    });

    group('write and load round-trip', () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('tk_trk_test_');
      });

      tearDown(() {
        tempDir.deleteSync(recursive: true);
      });

      test(
        'TK-TRK-6: should write and reload a baseline tracking file',
        () async {
          final entries = [
            TestEntry(
              id: 'TK-1',
              fullDescription: 'TK-1: basic test',
              description: 'basic test',
              groups: 'myGroup',
              creationDate: DateTime(2026, 2, 10, 8, 0),
            ),
          ];
          final run = TestRun(
            timestamp: DateTime(2026, 2, 10, 14, 30),
            isBaseline: true,
            results: {'TK-1: basic test': TestResult.ok},
          );
          final tracking = TrackingFile.fromBaseline(entries, run);

          final filePath = p.join(tempDir.path, 'doc', 'baseline_test.csv');
          await tracking.write(filePath);

          final loaded = TrackingFile.load(filePath);
          expect(loaded, isNotNull);
          expect(loaded!.entries, hasLength(1));
          expect(loaded.runs, hasLength(1));
          expect(loaded.runs.first.isBaseline, isTrue);
          // Verify groups survived round-trip
          final entry = loaded.entries.values.first;
          expect(entry.groups, equals('myGroup'));
          expect(entry.id, equals('TK-1'));
        },
      );

      test('TK-TRK-7: should preserve results across round-trip', () async {
        // fullDescription does NOT include (PASS) - only (FAIL) if explicitly
        // in the test name. This matches dart test's actual output format.
        final entries = [
          TestEntry(
            fullDescription: 'passing test',
            description: 'passing test',
          ),
          TestEntry(
            fullDescription: 'failing test (FAIL)',
            description: 'failing test',
            expectation: 'FAIL',
          ),
        ];
        final run = TestRun(
          timestamp: DateTime(2026, 2, 10, 14, 30),
          isBaseline: true,
          results: {
            'passing test': TestResult.ok,
            'failing test (FAIL)': TestResult.fail,
          },
        );
        final tracking = TrackingFile.fromBaseline(entries, run);

        final filePath = p.join(tempDir.path, 'doc', 'tracking.csv');
        await tracking.write(filePath);

        final loaded = TrackingFile.load(filePath)!;
        final loadedRun = loaded.runs.first;
        expect(loadedRun.getResult('passing test'), equals(TestResult.ok));
        expect(
          loadedRun.getResult('failing test (FAIL)'),
          equals(TestResult.fail),
        );
      });

      test(
        'TK-TRK-8: should preserve multiple runs across round-trip',
        () async {
          // fullDescription does NOT include (PASS)
          final entries = [
            TestEntry(fullDescription: 'test A', description: 'test A'),
          ];
          final baselineRun = TestRun(
            timestamp: DateTime(2026, 2, 10, 14, 30),
            isBaseline: true,
            results: {'test A': TestResult.ok},
          );
          final tracking = TrackingFile.fromBaseline(entries, baselineRun);

          final secondRun = TestRun(
            timestamp: DateTime(2026, 2, 10, 15, 0),
            results: {'test A': TestResult.fail},
          );
          tracking.addRun(secondRun, []);

          final filePath = p.join(tempDir.path, 'doc', 'multi_run.csv');
          await tracking.write(filePath);

          final loaded = TrackingFile.load(filePath)!;
          expect(loaded.runs, hasLength(2));
          expect(loaded.runs[0].getResult('test A'), equals(TestResult.ok));
          expect(loaded.runs[1].getResult('test A'), equals(TestResult.fail));
        },
      );
    });

    group('load', () {
      test('TK-TRK-9: should return null for non-existent file', () {
        expect(TrackingFile.load('/nonexistent/path.csv'), isNull);
      });
    });
  });
}

/// Helper to create a simple baseline tracking file for tests.
TrackingFile _createBaselineTracking() {
  final entries = [
    TestEntry(fullDescription: 'test A', description: 'test A'),
    TestEntry(
      fullDescription: 'test B',
      description: 'test B',
      expectation: 'FAIL',
    ),
  ];
  final run = TestRun(
    timestamp: DateTime(2026, 2, 10, 14, 30),
    isBaseline: true,
    results: {'test A': TestResult.ok, 'test B': TestResult.fail},
  );
  return TrackingFile.fromBaseline(entries, run);
}
