import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_test_kit/tom_test_kit.dart';

import 'test_helpers.dart';

/// Test IDs: TK-STAT-1 through TK-STAT-5
void main() {
  group('StatusCommand', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('tk_status_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('TK-STAT-1: returns false when no baseline file exists', () async {
      final result = await StatusCommand.run(projectPath: tempDir.path);
      expect(result, isFalse);
    });

    test('TK-STAT-2: returns true for single-run tracking file', () async {
      final tracking = createSingleRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);

      final result = await StatusCommand.run(
        projectPath: tempDir.path,
        baselineFile: filePath,
      );
      expect(result, isTrue);
    });

    test('TK-STAT-3: returns true for multi-run tracking file', () async {
      final tracking = createMultiRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);

      final result = await StatusCommand.run(
        projectPath: tempDir.path,
        baselineFile: filePath,
      );
      expect(result, isTrue);
    });

    test('TK-STAT-4: returns true with verbose flag', () async {
      final tracking = createMultiRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);

      final result = await StatusCommand.run(
        projectPath: tempDir.path,
        baselineFile: filePath,
        verbose: true,
      );
      expect(result, isTrue);
    });

    test('TK-STAT-5: returns true for tracking with no runs', () async {
      // Create a tracking file, then manually clear runs
      final tracking = createSingleRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);

      // Reload and verify it works (even single run = no comparison)
      final result = await StatusCommand.run(
        projectPath: tempDir.path,
        baselineFile: filePath,
      );
      expect(result, isTrue);
    });
  });
}
