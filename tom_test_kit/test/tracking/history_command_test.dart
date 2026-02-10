import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_test_kit/tom_test_kit.dart';

import 'test_helpers.dart';

/// Test IDs: TK-HIST-1 through TK-HIST-7
void main() {
  group('HistoryCommand', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('tk_history_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('TK-HIST-1: returns false when no baseline file exists', () async {
      final result = await HistoryCommand.run(
        projectPath: tempDir.path,
        searchTerm: 'test',
      );
      expect(result, isFalse);
    });

    test('TK-HIST-2: returns true for exact ID match', () async {
      final tracking = createMultiRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);

      final result = await HistoryCommand.run(
        projectPath: tempDir.path,
        searchTerm: 'TK-A',
        baselineFile: filePath,
      );
      expect(result, isTrue);
    });

    test('TK-HIST-3: returns true for substring match on description',
        () async {
      final tracking = createMultiRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);

      final result = await HistoryCommand.run(
        projectPath: tempDir.path,
        searchTerm: 'test A',
        baselineFile: filePath,
      );
      expect(result, isTrue);
    });

    test('TK-HIST-4: returns false for no matching tests', () async {
      final tracking = createMultiRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);

      final result = await HistoryCommand.run(
        projectPath: tempDir.path,
        searchTerm: 'nonexistent_test_xyz',
        baselineFile: filePath,
      );
      expect(result, isFalse);
    });

    test('TK-HIST-5: returns true for case-insensitive ID match', () async {
      final tracking = createMultiRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);

      // IDs are TK-A, TK-B, TK-C — search should be case-insensitive
      final result = await HistoryCommand.run(
        projectPath: tempDir.path,
        searchTerm: 'tk-a',
        baselineFile: filePath,
      );
      expect(result, isTrue);
    });

    test('TK-HIST-6: returns true for group name match', () async {
      final tracking = createMultiRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);

      final result = await HistoryCommand.run(
        projectPath: tempDir.path,
        searchTerm: 'group A',
        baselineFile: filePath,
      );
      expect(result, isTrue);
    });

    test('TK-HIST-7: writes CSV output to file', () async {
      final tracking = createMultiRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);
      final outputPath = '${tempDir.path}/history.csv';

      final result = await HistoryCommand.run(
        projectPath: tempDir.path,
        searchTerm: 'test',
        baselineFile: filePath,
        output: OutputSpec(format: OutputFormat.csv, filePath: outputPath),
      );

      expect(result, isTrue);
      final content = File(outputPath).readAsStringSync();
      // Should have header + rows for matching tests
      final lines =
          content.split('\n').where((l) => l.trim().isNotEmpty).toList();
      expect(lines.length, greaterThanOrEqualTo(2)); // header + at least 1 row
    });
  });
}
