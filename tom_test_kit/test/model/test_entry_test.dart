import 'package:test/test.dart';
import 'package:tom_test_kit/tom_test_kit.dart';

/// Test IDs: TK-ENT-1 through TK-ENT-7
void main() {
  group('TestEntry', () {
    group('displayLabel', () {
      test('TK-ENT-1: should include ID and description when ID is present',
          () {
        final entry = TestEntry(
          id: 'TK-1',
          fullDescription: 'TK-1: some test',
          description: 'some test',
        );
        expect(entry.displayLabel, equals('TK-1: some test'));
      });

      test('TK-ENT-2: should omit ID prefix when ID is null', () {
        final entry = TestEntry(
          fullDescription: 'bare description',
          description: 'bare description',
        );
        expect(entry.displayLabel, equals('bare description'));
      });

      test('TK-ENT-3: should include creation date when present', () {
        final entry = TestEntry(
          fullDescription: 'test',
          description: 'test',
          creationDate: DateTime(2026, 2, 10, 8, 0),
        );
        expect(entry.displayLabel, contains('[2026-02-10 08:00]'));
      });

      test('TK-ENT-4: should omit date when creationDate is null', () {
        final entry = TestEntry(
          fullDescription: 'test',
          description: 'test',
        );
        expect(entry.displayLabel, isNot(contains('[')));
      });
    });

    group('sortDate', () {
      test('TK-ENT-5: should return creationDate when present', () {
        final date = DateTime(2026, 1, 1);
        final entry = TestEntry(
          fullDescription: 'test',
          description: 'test',
          creationDate: date,
        );
        expect(entry.sortDate, equals(date));
      });

      test('TK-ENT-6: should return far-future date when creationDate is null',
          () {
        final entry = TestEntry(
          fullDescription: 'test',
          description: 'test',
        );
        expect(entry.sortDate.year, equals(9999));
      });
    });

    group('expectation', () {
      test('TK-ENT-7: should default to OK', () {
        final entry = TestEntry(
          fullDescription: 'test',
          description: 'test',
        );
        expect(entry.expectation, equals('OK'));
      });
    });
  });
}
