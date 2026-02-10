import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_test_kit/tom_test_kit.dart';

import 'test_helpers.dart';

/// Test IDs: TK-LDIF-1 through TK-LDIF-5
void main() {
  group('LastDiffCommand', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('tk_lastdiff_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('TK-LDIF-1: returns false when no baseline file exists', () async {
      final result = await LastDiffCommand.run(projectPath: tempDir.path);
      expect(result, isFalse);
    });

    test('TK-LDIF-2: returns true for single-run file (no diff)', () async {
      final tracking = createSingleRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);

      final result = await LastDiffCommand.run(
        projectPath: tempDir.path,
        baselineFile: filePath,
      );
      expect(result, isTrue);
    });

    test('TK-LDIF-3: returns true for multi-run and detects diffs', () async {
      final tracking = createMultiRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);

      // LastDiff compares run N-1 vs run N (last two runs)
      final result = await LastDiffCommand.run(
        projectPath: tempDir.path,
        baselineFile: filePath,
      );
      expect(result, isTrue);
    });

    test('TK-LDIF-4: writes CSV output to file', () async {
      final tracking = createMultiRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);
      final outputPath = '${tempDir.path}/lastdiff.csv';

      final result = await LastDiffCommand.run(
        projectPath: tempDir.path,
        baselineFile: filePath,
        output: OutputSpec(format: OutputFormat.csv, filePath: outputPath),
      );

      expect(result, isTrue);
      final outputFile = File(outputPath);
      expect(outputFile.existsSync(), isTrue);
    });

    test('TK-LDIF-5: report option generates markdown report', () async {
      final tracking = createMultiRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);
      final reportPath = '${tempDir.path}/lastdiff_report.md';

      // Create last_testrun.json with matching full descriptions
      await writeLastTestRunJson(tempDir, testErrors: {
        'group C test C': 'Failure message',
        'group A test A': null,
        'group B test B': null,
      });

      // Use reportPath without full flag (avoids validateLastTestRun)
      final result = await LastDiffCommand.run(
        projectPath: tempDir.path,
        baselineFile: filePath,
        reportPath: reportPath,
      );

      expect(result, isTrue);
      final reportFile = File(reportPath);
      expect(reportFile.existsSync(), isTrue);
    });
  });
}
