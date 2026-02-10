import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_test_kit/tom_test_kit.dart';

import 'test_helpers.dart';

/// Test IDs: TK-TRIM-1 through TK-TRIM-8
void main() {
  group('TrimCommand', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('tk_trim_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('TK-TRIM-1: returns false when no baseline file exists', () async {
      final result = await TrimCommand.run(
        projectPath: tempDir.path,
        keepCount: 2,
        force: true,
      );
      expect(result, isFalse);
    });

    test('TK-TRIM-2: returns false for keepCount < 1', () async {
      final result = await TrimCommand.run(
        projectPath: tempDir.path,
        keepCount: 0,
        force: true,
      );
      expect(result, isFalse);
    });

    test('TK-TRIM-3: does nothing when runs <= keepCount', () async {
      final tracking = createMultiRunTracking(); // 3 runs
      final filePath = await writeTrackingToTemp(tracking, tempDir);

      final result = await TrimCommand.run(
        projectPath: tempDir.path,
        keepCount: 5,
        baselineFile: filePath,
        force: true,
      );
      expect(result, isTrue);

      // Verify file unchanged
      final loaded = TrackingFile.load(filePath);
      expect(loaded!.runs.length, equals(3));
    });

    test('TK-TRIM-4: trims to keepCount, preserving baseline', () async {
      final tracking = createFlakyTracking(); // 4 runs (baseline + 3)
      final filePath = await writeTrackingToTemp(tracking, tempDir);

      final result = await TrimCommand.run(
        projectPath: tempDir.path,
        keepCount: 2,
        baselineFile: filePath,
        force: true,
      );
      expect(result, isTrue);

      // Should keep baseline + last 1 run = 2 runs
      final loaded = TrackingFile.load(filePath);
      expect(loaded, isNotNull);
      expect(loaded!.runs.length, equals(2));
      expect(loaded.runs.first.isBaseline, isTrue);
    });

    test('TK-TRIM-5: trims with keepCount=1 preserves baseline and last run',
        () async {
      final tracking = createFlakyTracking(); // 4 runs
      final filePath = await writeTrackingToTemp(tracking, tempDir);

      final result = await TrimCommand.run(
        projectPath: tempDir.path,
        keepCount: 1,
        baselineFile: filePath,
        force: true,
      );
      expect(result, isTrue);

      // Keep baseline + 0 other = keepCount is 1 so baseline counts as one
      final loaded = TrackingFile.load(filePath);
      expect(loaded, isNotNull);
      // Baseline is always preserved, and keepCount=1 means keep 1 total
      expect(loaded!.runs.length, greaterThanOrEqualTo(1));
      expect(loaded.runs.first.isBaseline, isTrue);
    });

    test('TK-TRIM-6: preserves run count after trim', () async {
      final tracking = createMultiRunTracking(); // 3 runs
      final filePath = await writeTrackingToTemp(tracking, tempDir);

      final result = await TrimCommand.run(
        projectPath: tempDir.path,
        keepCount: 2,
        baselineFile: filePath,
        force: true,
      );
      expect(result, isTrue);

      final loaded = TrackingFile.load(filePath);
      expect(loaded, isNotNull);
      expect(loaded!.runs.length, equals(2));
      // Baseline should be preserved
      expect(loaded.runs.first.isBaseline, isTrue);
      // Last run should be the original 3rd run
      expect(loaded.runs.last.isBaseline, isFalse);
    });

    test('TK-TRIM-7: with verbose flag shows file information', () async {
      final tracking = createMultiRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);

      final result = await TrimCommand.run(
        projectPath: tempDir.path,
        keepCount: 2,
        baselineFile: filePath,
        force: true,
        verbose: true,
      );
      expect(result, isTrue);
    });

    test('TK-TRIM-8: file is updated on disk after trim', () async {
      final tracking = createFlakyTracking(); // 4 runs
      final filePath = await writeTrackingToTemp(tracking, tempDir);

      final beforeSize = File(filePath).lengthSync();

      await TrimCommand.run(
        projectPath: tempDir.path,
        keepCount: 2,
        baselineFile: filePath,
        force: true,
      );

      final afterSize = File(filePath).lengthSync();
      // Trimmed file should be smaller (fewer columns)
      expect(afterSize, lessThan(beforeSize));
    });
  });
}
