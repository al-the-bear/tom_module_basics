import 'dart:convert';

import 'package:test/test.dart';
import 'package:tom_test_kit/tom_test_kit.dart';

/// Test IDs: TK-DTP-1 through TK-DTP-11
void main() {
  group('DartTestParser', () {
    group('parseJsonOutput', () {
      test('TK-DTP-1: should parse a passing test from JSON events', () {
        final lines = _makeJsonLines([
          _suiteEvent(0, 'test/my_test.dart'),
          _groupEvent(1, '', suiteId: 0),
          _testStartEvent(2, 'should pass', suiteId: 0, groupIds: [1]),
          _testDoneEvent(2, result: 'success'),
        ]);

        final results = DartTestParser.parseJsonOutput(lines);
        expect(results.totalTests, equals(1));
        expect(results.passedTests, equals(1));
        expect(results.failedTests, equals(0));
        expect(results.entries, hasLength(1));
        expect(results.entries.first.fullDescription, equals('should pass'));
        expect(results.entries.first.groups, isNull);
      });

      test('TK-DTP-2: should parse a failing test', () {
        final lines = _makeJsonLines([
          _suiteEvent(0, 'test/my_test.dart'),
          _groupEvent(1, '', suiteId: 0),
          _testStartEvent(2, 'should fail', suiteId: 0, groupIds: [1]),
          _testDoneEvent(2, result: 'failure'),
        ]);

        final results = DartTestParser.parseJsonOutput(lines);
        expect(results.failedTests, equals(1));
        expect(results.run.getResult('should fail'), equals(TestResult.fail));
      });

      test('TK-DTP-3: should parse a skipped test', () {
        final lines = _makeJsonLines([
          _suiteEvent(0, 'test/my_test.dart'),
          _groupEvent(1, '', suiteId: 0),
          _testStartEvent(2, 'should skip', suiteId: 0, groupIds: [1]),
          _testDoneEvent(2, result: 'success', skipped: true),
        ]);

        final results = DartTestParser.parseJsonOutput(lines);
        expect(results.skippedTests, equals(1));
        expect(results.run.getResult('should skip'), equals(TestResult.skip));
      });

      test('TK-DTP-4: should skip "loading" tests', () {
        final lines = _makeJsonLines([
          _suiteEvent(0, 'test/my_test.dart'),
          _testStartEvent(1, 'loading test/my_test.dart',
              suiteId: 0, groupIds: []),
          _testDoneEvent(1, result: 'success', hidden: true),
          _groupEvent(2, '', suiteId: 0),
          _testStartEvent(3, 'real test', suiteId: 0, groupIds: [2]),
          _testDoneEvent(3, result: 'success'),
        ]);

        final results = DartTestParser.parseJsonOutput(lines);
        expect(results.totalTests, equals(1));
        expect(results.entries.first.fullDescription, equals('real test'));
      });

      test('TK-DTP-5: should skip hidden tests', () {
        final lines = _makeJsonLines([
          _suiteEvent(0, 'test/my_test.dart'),
          _groupEvent(1, '', suiteId: 0),
          _testStartEvent(2, 'hidden test', suiteId: 0, groupIds: [1]),
          _testDoneEvent(2, result: 'success', hidden: true),
        ]);

        final results = DartTestParser.parseJsonOutput(lines);
        expect(results.totalTests, equals(0));
      });

      test('TK-DTP-6: should handle multiple tests mixed pass/fail', () {
        final lines = _makeJsonLines([
          _suiteEvent(0, 'test/my_test.dart'),
          _groupEvent(1, '', suiteId: 0),
          _testStartEvent(2, 'test A', suiteId: 0, groupIds: [1]),
          _testDoneEvent(2, result: 'success'),
          _testStartEvent(3, 'test B', suiteId: 0, groupIds: [1]),
          _testDoneEvent(3, result: 'failure'),
          _testStartEvent(4, 'test C', suiteId: 0, groupIds: [1]),
          _testDoneEvent(4, result: 'success', skipped: true),
        ]);

        final results = DartTestParser.parseJsonOutput(lines);
        expect(results.totalTests, equals(3));
        expect(results.passedTests, equals(1));
        expect(results.failedTests, equals(1));
        expect(results.skippedTests, equals(1));
      });

      test('TK-DTP-7: should skip non-JSON lines gracefully', () {
        final lines = [
          'Some random text',
          '',
          jsonEncode(_suiteEvent(0, 'test/my_test.dart')),
          jsonEncode(_groupEvent(1, '', suiteId: 0)),
          'Another non-json line',
          jsonEncode(_testStartEvent(2, 'test', suiteId: 0, groupIds: [1])),
          jsonEncode(_testDoneEvent(2, result: 'success')),
        ];

        final results = DartTestParser.parseJsonOutput(lines);
        expect(results.totalTests, equals(1));
      });

      test('TK-DTP-8: should handle empty input', () {
        final results = DartTestParser.parseJsonOutput([]);
        expect(results.totalTests, equals(0));
        expect(results.entries, isEmpty);
      });

      test('TK-DTP-9: should extract single group and strip from name', () {
        final lines = _makeJsonLines([
          _suiteEvent(0, 'test/my_test.dart'),
          _groupEvent(1, '', suiteId: 0),
          _groupEvent(2, 'padTwo', suiteId: 0),
          _testStartEvent(
              3, 'padTwo TK-FMT-1: should zero-pad single digit',
              suiteId: 0, groupIds: [1, 2]),
          _testDoneEvent(3, result: 'success'),
        ]);

        final results = DartTestParser.parseJsonOutput(lines);
        expect(results.entries, hasLength(1));
        final entry = results.entries.first;
        expect(entry.groups, equals('padTwo'));
        expect(entry.id, equals('TK-FMT-1'));
        expect(entry.description, equals('should zero-pad single digit'));
        expect(entry.fullDescription,
            equals('TK-FMT-1: should zero-pad single digit'));
      });

      test('TK-DTP-10: should extract nested groups with > separator', () {
        final lines = _makeJsonLines([
          _suiteEvent(0, 'test/my_test.dart'),
          _groupEvent(1, '', suiteId: 0),
          _groupEvent(2, 'DartTestParser', suiteId: 0),
          _groupEvent(3, 'DartTestParser parseJsonOutput', suiteId: 0),
          _testStartEvent(
              4, 'DartTestParser parseJsonOutput TK-DTP-1: should parse',
              suiteId: 0, groupIds: [1, 2, 3]),
          _testDoneEvent(4, result: 'success'),
        ]);

        final results = DartTestParser.parseJsonOutput(lines);
        final entry = results.entries.first;
        expect(entry.groups, equals('DartTestParser > parseJsonOutput'));
        expect(entry.id, equals('TK-DTP-1'));
        expect(entry.description, equals('should parse'));
      });

      test('TK-DTP-11: should handle test with only root group (no groups)',
          () {
        final lines = _makeJsonLines([
          _suiteEvent(0, 'test/my_test.dart'),
          _groupEvent(1, '', suiteId: 0),
          _testStartEvent(2, 'TK-1: bare test', suiteId: 0, groupIds: [1]),
          _testDoneEvent(2, result: 'success'),
        ]);

        final results = DartTestParser.parseJsonOutput(lines);
        final entry = results.entries.first;
        expect(entry.groups, isNull);
        expect(entry.id, equals('TK-1'));
        expect(entry.description, equals('bare test'));
        expect(entry.fullDescription, equals('TK-1: bare test'));
      });
    });
  });
}

// --- JSON event helpers ---

List<String> _makeJsonLines(List<Map<String, dynamic>> events) {
  return events.map((e) => jsonEncode(e)).toList();
}

Map<String, dynamic> _suiteEvent(int id, String path) => {
      'type': 'suite',
      'suite': {'id': id, 'path': path},
    };

Map<String, dynamic> _groupEvent(int id, String name, {required int suiteId}) =>
    {
      'type': 'group',
      'group': {'id': id, 'name': name, 'suiteID': suiteId},
    };

Map<String, dynamic> _testStartEvent(
  int id,
  String name, {
  required int suiteId,
  required List<int> groupIds,
}) =>
    {
      'type': 'testStart',
      'test': {
        'id': id,
        'name': name,
        'suiteID': suiteId,
        'groupIDs': groupIds,
      },
    };

Map<String, dynamic> _testDoneEvent(
  int testId, {
  required String result,
  bool skipped = false,
  bool hidden = false,
}) =>
    {
      'type': 'testDone',
      'testID': testId,
      'result': result,
      'skipped': skipped,
      'hidden': hidden,
    };
