import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_test_kit/tom_test_kit.dart';

import 'test_helpers.dart';

/// Test IDs: TK-DIF-1 through TK-DIF-6
void main() {
  group('DiffCommand', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('tk_diff_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('TK-DIF-1: returns false when no baseline file exists', () async {
      final result = await DiffCommand.run(
        projectPath: tempDir.path,
        timestamps: ['0210_1430', '0211_1000'],
      );
      expect(result, isFalse);
    });

    test('TK-DIF-2: returns true when comparing two valid timestamps',
        () async {
      final tracking = createMultiRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);

      // Timestamps: baseline=02-10_1430, run2=02-11_1000, run3=02-12_1645
      final result = await DiffCommand.run(
        projectPath: tempDir.path,
        timestamps: ['02-10_1430', '02-11_1000'],
        baselineFile: filePath,
      );
      expect(result, isTrue);
    });

    test('TK-DIF-3: returns false for invalid timestamp', () async {
      final tracking = createMultiRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);

      final result = await DiffCommand.run(
        projectPath: tempDir.path,
        timestamps: ['99-99_9999', '02-11_1000'],
        baselineFile: filePath,
      );
      expect(result, isFalse);
    });

    test('TK-DIF-4: succeeds with single timestamp (vs latest)', () async {
      final tracking = createMultiRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);

      // Single timestamp compares against latest run
      final result = await DiffCommand.run(
        projectPath: tempDir.path,
        timestamps: ['02-10_1430'],
        baselineFile: filePath,
      );
      expect(result, isTrue);
    });

    test('TK-DIF-5: writes CSV diff output to file', () async {
      final tracking = createMultiRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);
      final outputPath = '${tempDir.path}/diff.csv';

      final result = await DiffCommand.run(
        projectPath: tempDir.path,
        timestamps: ['02-10_1430', '02-12_1645'],
        baselineFile: filePath,
        output: OutputSpec(format: OutputFormat.csv, filePath: outputPath),
      );

      expect(result, isTrue);
      final outputFile = File(outputPath);
      expect(outputFile.existsSync(), isTrue);
      final content = outputFile.readAsStringSync();
      expect(content, contains('Change'));
    });

    test('TK-DIF-6: accepts space-format timestamps', () async {
      final tracking = createMultiRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);

      // findRunByTimestamp also supports "MM-DD HH:MM" format
      final result = await DiffCommand.run(
        projectPath: tempDir.path,
        timestamps: ['02-10 14:30', '02-11 10:00'],
        baselineFile: filePath,
      );
      expect(result, isTrue);
    });
  });
}
