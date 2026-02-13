/// Unit tests for TestScanner.
///
/// Tests that the scanner correctly discovers test IDs in source files
/// and handles baselines, edge cases, and various patterns.
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_issue_kit/src/services/test_scanner.dart';

void main() {
  late TestScanner scanner;
  late Directory tempDir;

  setUp(() {
    scanner = TestScanner();
    tempDir = Directory.systemTemp.createTempSync('test_scanner_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  /// Helper to create a test file with content.
  File createTestFile(String relativePath, String content) {
    final file = File('${tempDir.path}/$relativePath');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    return file;
  }

  // ===========================================================================
  // IK-SCN: TestScanner.scanProject
  // ===========================================================================

  group('IK-SCN: scanProject [2026-02-13]', () {
    test('IK-SCN-1: finds issue-linked test IDs in test files', () {
      createTestFile('test/parser/array_parser_test.dart', '''
import 'package:test/test.dart';

void main() {
  test('D4-42-PAR-7: Array parser crashes on empty arrays [2026-02-10] (FAIL)', () {
    // test body
  });

  test('D4-42-PAR-8: Array parser null element [2026-02-10] (FAIL)', () {
    // test body
  });
}
''');

      final results = scanner.scanProject(tempDir.path);

      expect(results, hasLength(2));
      expect(results[0].testId, 'D4-42-PAR-7');
      expect(results[0].projectId, 'D4');
      expect(results[0].issueNumber, 42);
      expect(results[0].projectSpecific, 'PAR-7');
      expect(results[0].isIssueLinked, isTrue);
      expect(results[0].line, 4);
      expect(results[1].testId, 'D4-42-PAR-8');
    });

    test('IK-SCN-2: finds regular (non-issue-linked) test IDs', () {
      createTestFile('test/parser_test.dart', '''
import 'package:test/test.dart';

void main() {
  test('D4-PAR-15: Parser handles nested arrays', () {});
}
''');

      final results = scanner.scanProject(tempDir.path);

      expect(results, hasLength(1));
      expect(results[0].testId, 'D4-PAR-15');
      expect(results[0].projectId, 'D4');
      expect(results[0].issueNumber, isNull);
      expect(results[0].projectSpecific, 'PAR-15');
      expect(results[0].isIssueLinked, isFalse);
    });

    test('IK-SCN-3: returns empty when no test directory exists', () {
      final results = scanner.scanProject(tempDir.path);
      expect(results, isEmpty);
    });

    test('IK-SCN-4: scans recursively through test subdirectories', () {
      createTestFile('test/a/one_test.dart', '''
void main() {
  test('D4-1-A-1: test a', () {});
}
''');
      createTestFile('test/b/c/two_test.dart', '''
void main() {
  test('D4-2-B-1: test b', () {});
}
''');

      final results = scanner.scanProject(tempDir.path);

      expect(results, hasLength(2));
      final ids = results.map((r) => r.testId).toSet();
      expect(ids, containsAll(['D4-1-A-1', 'D4-2-B-1']));
    });

    test('IK-SCN-5: ignores non-test dart files', () {
      createTestFile('test/helpers.dart', '''
void main() {
  test('D4-99-HLP-1: should be ignored', () {});
}
''');
      createTestFile('lib/src/widget.dart', '''
void main() {
  test('D4-99-WDG-1: also ignored', () {});
}
''');

      final results = scanner.scanProject(tempDir.path);
      expect(results, isEmpty);
    });

    test('IK-SCN-6: detects group-level test IDs', () {
      createTestFile('test/parser_test.dart', '''
void main() {
  group('D4-42-PAR: Array parser tests', () {
    test('D4-42-PAR-7: empty arrays', () {});
  });
}
''');

      final results = scanner.scanProject(tempDir.path);

      // Should find both the group ID and test ID
      expect(results, hasLength(2));
      final ids = results.map((r) => r.testId).toSet();
      expect(ids, contains('D4-42-PAR-7'));
    });
  });

  // ===========================================================================
  // IK-SCN-ISS: TestScanner.scanForIssue
  // ===========================================================================

  group('IK-SCN-ISS: scanForIssue [2026-02-13]', () {
    test('IK-SCN-ISS-1: returns only tests matching the issue number', () {
      createTestFile('test/parser_test.dart', '''
void main() {
  test('D4-42-PAR-7: linked to 42', () {});
  test('D4-56-PAR-8: linked to 56', () {});
  test('D4-PAR-15: no issue link', () {});
}
''');

      final results = scanner.scanForIssue(tempDir.path, 42);

      expect(results, hasLength(1));
      expect(results[0].testId, 'D4-42-PAR-7');
      expect(results[0].issueNumber, 42);
    });

    test('IK-SCN-ISS-2: returns empty when no tests match issue', () {
      createTestFile('test/parser_test.dart', '''
void main() {
  test('D4-PAR-15: no issue link', () {});
}
''');

      final results = scanner.scanForIssue(tempDir.path, 99);
      expect(results, isEmpty);
    });
  });

  // ===========================================================================
  // IK-SCN-BL: TestScanner.readLatestBaseline
  // ===========================================================================

  group('IK-SCN-BL: readLatestBaseline [2026-02-13]', () {
    test('IK-SCN-BL-1: reads the most recent baseline file', () {
      createTestFile('doc/baseline_0210_1400.csv', 'old baseline');
      createTestFile('doc/baseline_0211_0800.csv', 'new baseline');

      final content = scanner.readLatestBaseline(tempDir.path);

      expect(content, 'new baseline');
    });

    test('IK-SCN-BL-2: returns null when no baselines exist', () {
      final content = scanner.readLatestBaseline(tempDir.path);
      expect(content, isNull);
    });

    test('IK-SCN-BL-3: returns null when doc directory does not exist', () {
      // tempDir has no doc/ subdirectory
      final content = scanner.readLatestBaseline(tempDir.path);
      expect(content, isNull);
    });
  });

  // ===========================================================================
  // IK-SCN-PB: TestScanner.parseBaseline
  // ===========================================================================

  group('IK-SCN-PB: parseBaseline [2026-02-13]', () {
    test('IK-SCN-PB-1: parses baseline CSV into ID-status map', () {
      const csv = 'ID,Groups,Description,0211_0800\n'
          'D4-42-PAR-7,"parser","Array crash",OK/X\n'
          'D4-42-PAR-8,"parser","Null element",X/X\n';

      final parsed = scanner.parseBaseline(csv);

      expect(parsed['D4-42-PAR-7'], 'OK/X');
      expect(parsed['D4-42-PAR-8'], 'X/X');
    });

    test('IK-SCN-PB-2: handles quoted fields with commas', () {
      const csv = 'ID,Groups,Description,0211_0800\n'
          'D4-PAR-15,"parser,core","Test, with commas",OK/OK\n';

      final parsed = scanner.parseBaseline(csv);

      expect(parsed['D4-PAR-15'], 'OK/OK');
    });

    test('IK-SCN-PB-3: returns empty for minimal input', () {
      final parsed = scanner.parseBaseline('');
      expect(parsed, isEmpty);
    });
  });
}
