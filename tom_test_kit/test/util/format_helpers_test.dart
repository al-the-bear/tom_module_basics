import 'package:test/test.dart';
import 'package:tom_test_kit/tom_test_kit.dart';

/// Test IDs: TK-FMT-1, TK-FMT-2, TK-FMT-3, TK-FMT-4, TK-FMT-5,
///           TK-FMT-6, TK-FMT-7
void main() {
  group('padTwo', () {
    test('TK-FMT-1: should zero-pad single digit', () {
      expect(padTwo(3), equals('03'));
    });

    test('TK-FMT-2: should not pad two-digit number', () {
      expect(padTwo(12), equals('12'));
    });

    test('TK-FMT-3: should zero-pad zero', () {
      expect(padTwo(0), equals('00'));
    });

    test('TK-FMT-4: should handle three-digit number without truncating', () {
      // padTwo only left-pads to width 2; larger numbers pass through as-is
      expect(padTwo(123), equals('123'));
    });
  });

  group('escapeMarkdownCell', () {
    test('TK-FMT-5: should escape pipe characters', () {
      expect(escapeMarkdownCell('a|b|c'), equals(r'a\|b\|c'));
    });

    test('TK-FMT-6: should return unchanged text without pipes', () {
      expect(escapeMarkdownCell('hello world'), equals('hello world'));
    });
  });

  group('baselineTimestamp', () {
    test('TK-FMT-7: should format as MMDD_HHMM', () {
      final dt = DateTime(2026, 2, 10, 14, 30);
      expect(baselineTimestamp(dt), equals('0210_1430'));
    });
  });
}
