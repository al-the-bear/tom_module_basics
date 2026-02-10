import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tom_test_kit/tom_test_kit.dart';

/// Test IDs: TK-FIL-1, TK-FIL-2, TK-FIL-3, TK-FIL-4, TK-FIL-5
void main() {
  group('defaultBaselinePath', () {
    test('TK-FIL-1: should create path with MMDD_HHMM timestamp', () {
      final fixed = DateTime(2026, 2, 10, 14, 30);
      final result = defaultBaselinePath('/project', now: fixed);
      expect(result, equals(p.join('/project', 'doc', 'baseline_0210_1430.csv')));
    });

    test('TK-FIL-2: should zero-pad month and day', () {
      final fixed = DateTime(2026, 1, 5, 9, 7);
      final result = defaultBaselinePath('/project', now: fixed);
      expect(result, contains('baseline_0105_0907.csv'));
    });
  });

  group('findLatestTrackingFile', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('tk_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('TK-FIL-3: should return null when doc/ does not exist', () {
      expect(findLatestTrackingFile(tempDir.path), isNull);
    });

    test('TK-FIL-4: should return null when no baseline files exist', () {
      Directory(p.join(tempDir.path, 'doc')).createSync();
      File(p.join(tempDir.path, 'doc', 'readme.md')).writeAsStringSync('');
      expect(findLatestTrackingFile(tempDir.path), isNull);
    });

    test('TK-FIL-5: should return the latest baseline file by name sort', () {
      final docDir = Directory(p.join(tempDir.path, 'doc'))..createSync();
      File(p.join(docDir.path, 'baseline_0210_0900.csv'))
          .writeAsStringSync('old');
      File(p.join(docDir.path, 'baseline_0210_1400.csv'))
          .writeAsStringSync('new');
      File(p.join(docDir.path, 'baseline_0209_2300.csv'))
          .writeAsStringSync('oldest');

      final result = findLatestTrackingFile(tempDir.path);
      expect(result, isNotNull);
      expect(p.basename(result!), equals('baseline_0210_1400.csv'));
    });
  });
}
