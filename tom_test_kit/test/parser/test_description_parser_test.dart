import 'package:test/test.dart';
import 'package:tom_test_kit/tom_test_kit.dart';

/// Test IDs: TK-TDP-1 through TK-TDP-10
void main() {
  group('TestDescriptionParser', () {
    group('parse', () {
      test('TK-TDP-1: should extract ID before first colon', () {
        final entry = TestDescriptionParser.parse('TK-BUG-1: some test');
        expect(entry.id, equals('TK-BUG-1'));
        expect(entry.description, equals('some test'));
      });

      test('TK-TDP-2: should extract creation date [YYYY-MM-DD HH:MM]', () {
        final entry =
            TestDescriptionParser.parse('test [2026-02-10 08:00]');
        expect(entry.creationDate, equals(DateTime(2026, 2, 10, 8, 0)));
      });

      test('TK-TDP-3: should extract FAIL expectation', () {
        final entry = TestDescriptionParser.parse('test (FAIL)');
        expect(entry.expectation, equals('FAIL'));
      });

      test('TK-TDP-4: should extract PASS expectation as OK', () {
        final entry = TestDescriptionParser.parse('test (PASS)');
        expect(entry.expectation, equals('OK'));
      });

      test('TK-TDP-5: should default expectation to OK when absent', () {
        final entry = TestDescriptionParser.parse('simple test');
        expect(entry.expectation, equals('OK'));
      });

      test('TK-TDP-6: should parse full description with all components', () {
        final entry = TestDescriptionParser.parse(
            'I-BUG-14a: Records with named fields [2026-02-10 08:00] (FAIL)');
        expect(entry.id, equals('I-BUG-14a'));
        expect(entry.description, equals('Records with named fields'));
        expect(entry.creationDate, equals(DateTime(2026, 2, 10, 8, 0)));
        expect(entry.expectation, equals('FAIL'));
      });

      test('TK-TDP-7: should preserve fullDescription as-is', () {
        const desc = 'TK-1: something [2026-01-01 00:00] (PASS)';
        final entry = TestDescriptionParser.parse(desc);
        expect(entry.fullDescription, equals(desc));
      });

      test('TK-TDP-8: should handle description without any metadata', () {
        final entry = TestDescriptionParser.parse('bare test name');
        expect(entry.id, isNull);
        expect(entry.description, equals('bare test name'));
        expect(entry.creationDate, isNull);
        expect(entry.expectation, equals('OK'));
      });

      test('TK-TDP-9: should store suite when provided', () {
        final entry = TestDescriptionParser.parse(
          'test',
          suite: 'test/my_test.dart',
        );
        expect(entry.suite, equals('test/my_test.dart'));
      });

      test('TK-TDP-10: should handle ID-only description (no extra text)', () {
        final entry = TestDescriptionParser.parse('TK-1:');
        expect(entry.id, equals('TK-1'));
        expect(entry.description, isEmpty);
      });
    });
  });
}
