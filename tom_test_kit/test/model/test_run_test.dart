import 'package:test/test.dart';
import 'package:tom_test_kit/tom_test_kit.dart';

/// Test IDs: TK-RUN-1 through TK-RUN-13
void main() {
  group('TestResult', () {
    test('TK-RUN-1: should have correct labels', () {
      expect(TestResult.ok.label, equals('OK'));
      expect(TestResult.fail.label, equals('X'));
      expect(TestResult.skip.label, equals('-'));
      expect(TestResult.absent.label, equals('--'));
    });
  });

  group('TestRun', () {
    group('columnHeader', () {
      test('TK-RUN-2: should include Baseline prefix when isBaseline is true',
          () {
        final run = TestRun(
          timestamp: DateTime(2026, 2, 10, 14, 30),
          isBaseline: true,
        );
        expect(run.columnHeader, equals('Baseline [02-10 14:30]'));
      });

      test('TK-RUN-3: should omit prefix when isBaseline is false', () {
        final run = TestRun(
          timestamp: DateTime(2026, 3, 15, 9, 5),
        );
        expect(run.columnHeader, equals('[03-15 09:05]'));
      });
    });

    group('setResult / getResult', () {
      test('TK-RUN-4: should store and retrieve a result', () {
        final run = TestRun(timestamp: DateTime.now());
        run.setResult('my test', TestResult.ok);
        expect(run.getResult('my test'), equals(TestResult.ok));
      });

      test('TK-RUN-5: should return absent for unknown test', () {
        final run = TestRun(timestamp: DateTime.now());
        expect(run.getResult('nonexistent'), equals(TestResult.absent));
      });
    });

    group('constructor', () {
      test('TK-RUN-6: should accept pre-populated results map', () {
        final run = TestRun(
          timestamp: DateTime.now(),
          results: {'a': TestResult.ok, 'b': TestResult.fail},
        );
        expect(run.getResult('a'), equals(TestResult.ok));
        expect(run.getResult('b'), equals(TestResult.fail));
      });
    });
  });

  group('resultSortPriority', () {
    test('TK-RUN-7: regression (X/OK) should be highest priority', () {
      expect(resultSortPriority(TestResult.fail, 'OK'), equals(0));
    });

    test('TK-RUN-8: expected failure (X/X) should be priority 1', () {
      expect(resultSortPriority(TestResult.fail, 'FAIL'), equals(1));
    });

    test('TK-RUN-9: progress (OK/X) should be priority 2', () {
      expect(resultSortPriority(TestResult.ok, 'FAIL'), equals(2));
    });

    test('TK-RUN-10: healthy (OK/OK) should be priority 3', () {
      expect(resultSortPriority(TestResult.ok, 'OK'), equals(3));
    });

    test('TK-RUN-11: skip should be priority 4', () {
      expect(resultSortPriority(TestResult.skip, 'OK'), equals(4));
    });

    test('TK-RUN-12: absent should be priority 5', () {
      expect(resultSortPriority(TestResult.absent, 'OK'), equals(5));
    });
  });

  group('formatResultCell', () {
    test('TK-RUN-13: should format as result/expectation', () {
      expect(formatResultCell(TestResult.ok, 'OK'), equals('OK/OK'));
      expect(formatResultCell(TestResult.fail, 'FAIL'), equals('X/X'));
      expect(formatResultCell(TestResult.ok, 'FAIL'), equals('OK/X'));
      expect(formatResultCell(TestResult.skip, 'OK'), equals('-/OK'));
    });
  });

  group('SortableTestEntry', () {
    test('TK-RUN-14: should compute sort priority from entry and result', () {
      final entry = TestEntry(
        fullDescription: 'test',
        description: 'test',
        expectation: 'OK',
      );
      final sortable = SortableTestEntry(entry, TestResult.fail);
      // X/OK = regression = priority 0
      expect(sortable.sortPriority, equals(0));
    });
  });
}
