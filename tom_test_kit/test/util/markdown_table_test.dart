import 'package:test/test.dart';
import 'package:tom_test_kit/tom_test_kit.dart';

/// Test IDs: TK-MDT-1 through TK-MDT-21
void main() {
  group('splitTableRow', () {
    test('TK-MDT-1: should split a simple row into cells', () {
      final cells = splitTableRow('| A | B | C |');
      expect(cells, hasLength(3));
      expect(cells[0].trim(), equals('A'));
      expect(cells[1].trim(), equals('B'));
      expect(cells[2].trim(), equals('C'));
    });

    test('TK-MDT-2: should handle escaped pipes within cells', () {
      final cells = splitTableRow(r'| a\|b | c |');
      expect(cells, hasLength(2));
      expect(cells[0].trim(), equals(r'a\|b'));
      expect(cells[1].trim(), equals('c'));
    });

    test('TK-MDT-3: should return empty list for non-table line', () {
      expect(splitTableRow('not a table'), isEmpty);
    });

    test('TK-MDT-4: should return empty list for empty string', () {
      expect(splitTableRow(''), isEmpty);
    });

    test('TK-MDT-5: should handle single-cell row', () {
      final cells = splitTableRow('| only |');
      expect(cells, hasLength(1));
      expect(cells[0].trim(), equals('only'));
    });
  });

  group('parseColumnTimestamp', () {
    test('TK-MDT-6: should parse Baseline header', () {
      final dt = parseColumnTimestamp('Baseline [02-10 14:30]');
      expect(dt, isNotNull);
      expect(dt!.month, equals(2));
      expect(dt.day, equals(10));
      expect(dt.hour, equals(14));
      expect(dt.minute, equals(30));
    });

    test('TK-MDT-7: should parse non-baseline header', () {
      final dt = parseColumnTimestamp('[03-15 09:00]');
      expect(dt, isNotNull);
      expect(dt!.month, equals(3));
      expect(dt.day, equals(15));
      expect(dt.hour, equals(9));
    });

    test('TK-MDT-8: should return null for invalid header', () {
      expect(parseColumnTimestamp('no timestamp here'), isNull);
    });

    test('TK-MDT-9: should return null for empty string', () {
      expect(parseColumnTimestamp(''), isNull);
    });
  });

  group('parseResultCell', () {
    test('TK-MDT-10: should parse OK/OK as ok', () {
      expect(parseResultCell('OK/OK'), equals(TestResult.ok));
    });

    test('TK-MDT-11: should parse X/OK as fail', () {
      expect(parseResultCell('X/OK'), equals(TestResult.fail));
    });

    test('TK-MDT-12: should parse -/OK as skip', () {
      expect(parseResultCell('-/OK'), equals(TestResult.skip));
    });

    test('TK-MDT-13: should parse --/OK as absent', () {
      expect(parseResultCell('--/OK'), equals(TestResult.absent));
    });

    test('TK-MDT-14: should return absent for unknown cell', () {
      expect(parseResultCell('???'), equals(TestResult.absent));
    });
  });

  group('parseEntryFromLabel', () {
    test(
      'TK-MDT-15: should parse full label with ID, date, and expectation',
      () {
        final entry = parseEntryFromLabel(
          'TK-BUG-1: Some test [2026-02-10 08:00] (FAIL)',
        );
        expect(entry.id, equals('TK-BUG-1'));
        expect(entry.description, equals('Some test'));
        expect(entry.creationDate, equals(DateTime(2026, 2, 10, 8, 0)));
        expect(entry.expectation, equals('FAIL'));
      },
    );

    test('TK-MDT-16: should parse label without ID', () {
      final entry = parseEntryFromLabel('Some test without ID');
      expect(entry.id, isNull);
      expect(entry.description, equals('Some test without ID'));
    });

    test(
      'TK-MDT-17: should parse label with ID but no date or expectation',
      () {
        final entry = parseEntryFromLabel('TK-1: Simple description');
        expect(entry.id, equals('TK-1'));
        expect(entry.description, equals('Simple description'));
        expect(entry.expectation, equals('OK'));
        expect(entry.creationDate, isNull);
      },
    );

    test(
      'TK-MDT-18: should default expectation to OK when PASS is specified',
      () {
        final entry = parseEntryFromLabel('Test that passes (PASS)');
        expect(entry.expectation, equals('OK'));
      },
    );
  });

  group('parseEntryFromColumns', () {
    test('TK-MDT-19: should parse ID, groups, and description columns', () {
      final entry = parseEntryFromColumns(
        id: 'TK-FMT-1',
        groups: 'padTwo',
        description: 'should zero-pad single digit',
      );
      expect(entry.id, equals('TK-FMT-1'));
      expect(entry.groups, equals('padTwo'));
      expect(entry.description, equals('should zero-pad single digit'));
      // fullDescription does NOT include (PASS) - dart test only includes
      // (FAIL) if explicitly in the test name
      expect(
        entry.fullDescription,
        equals('TK-FMT-1: should zero-pad single digit'),
      );
    });

    test('TK-MDT-20: should handle empty ID and groups', () {
      final entry = parseEntryFromColumns(
        id: '',
        groups: '',
        description: 'bare test',
      );
      expect(entry.id, isNull);
      expect(entry.groups, isNull);
      expect(entry.description, equals('bare test'));
      // fullDescription does NOT include (PASS)
      expect(entry.fullDescription, equals('bare test'));
    });

    test('TK-MDT-21: should extract date and FAIL from description', () {
      final entry = parseEntryFromColumns(
        id: 'TK-1',
        groups: 'grp',
        description: 'some test [2026-02-10 08:00] (FAIL)',
      );
      expect(entry.id, equals('TK-1'));
      expect(entry.groups, equals('grp'));
      expect(entry.description, equals('some test'));
      expect(entry.creationDate, equals(DateTime(2026, 2, 10, 8, 0)));
      expect(entry.expectation, equals('FAIL'));
      expect(
        entry.fullDescription,
        equals('TK-1: some test [2026-02-10 08:00] (FAIL)'),
      );
    });
  });
}
