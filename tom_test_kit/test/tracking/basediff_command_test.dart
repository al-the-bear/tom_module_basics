import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_test_kit/tom_test_kit.dart';

import 'test_helpers.dart';

/// Test IDs: TK-BDIF-1 through TK-BDIF-7
void main() {
  group('BaseDiffCommand', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('tk_basediff_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('TK-BDIF-1: returns false when no baseline file exists', () async {
      final result = await BaseDiffCommand.run(projectPath: tempDir.path);
      expect(result, isFalse);
    });

    test('TK-BDIF-2: returns true for single-run file (no diff)', () async {
      final tracking = createSingleRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);

      final result = await BaseDiffCommand.run(
        projectPath: tempDir.path,
        baselineFile: filePath,
      );
      // Single run means baseline compared to itself — no diff
      expect(result, isTrue);
    });

    test('TK-BDIF-3: returns true for multi-run file with diffs', () async {
      final tracking = createMultiRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);

      final result = await BaseDiffCommand.run(
        projectPath: tempDir.path,
        baselineFile: filePath,
      );
      expect(result, isTrue);
    });

    test('TK-BDIF-4: writes CSV diff output to file', () async {
      final tracking = createMultiRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);
      final outputPath = '${tempDir.path}/basediff.csv';

      final result = await BaseDiffCommand.run(
        projectPath: tempDir.path,
        baselineFile: filePath,
        output: OutputSpec(format: OutputFormat.csv, filePath: outputPath),
      );

      expect(result, isTrue);
      final outputFile = File(outputPath);
      expect(outputFile.existsSync(), isTrue);
      final content = outputFile.readAsStringSync();
      expect(content, contains('ID'));
      expect(content, contains('Change'));
    });

    test('TK-BDIF-5: writes Markdown diff output to file', () async {
      final tracking = createMultiRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);
      final outputPath = '${tempDir.path}/basediff.md';

      final result = await BaseDiffCommand.run(
        projectPath: tempDir.path,
        baselineFile: filePath,
        output: OutputSpec(format: OutputFormat.md, filePath: outputPath),
      );

      expect(result, isTrue);
      final outputFile = File(outputPath);
      expect(outputFile.existsSync(), isTrue);
      final content = outputFile.readAsStringSync();
      // Markdown tables have pipe separators
      expect(content, contains('|'));
    });

    test('TK-BDIF-6: report path without full flag writes markdown report',
        () async {
      final tracking = createMultiRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);
      final reportPath = '${tempDir.path}/report.md';

      // Create a fake last_testrun.json with matching test descriptions
      await writeLastTestRunJson(tempDir, testErrors: {
        'group C test C': 'Expected OK but got FAIL',
        'group A test A': null,
        'group B test B': null,
      });

      final result = await BaseDiffCommand.run(
        projectPath: tempDir.path,
        baselineFile: filePath,
        reportPath: reportPath,
      );

      expect(result, isTrue);
      final reportFile = File(reportPath);
      expect(reportFile.existsSync(), isTrue);
      final content = reportFile.readAsStringSync();
      expect(content, contains('# '));
      expect(content, contains('Summary'));
    });

    test('TK-BDIF-7: writes JSON diff output to file', () async {
      final tracking = createMultiRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);
      final outputPath = '${tempDir.path}/basediff.json';

      final result = await BaseDiffCommand.run(
        projectPath: tempDir.path,
        baselineFile: filePath,
        output: OutputSpec(format: OutputFormat.json, filePath: outputPath),
      );

      expect(result, isTrue);
      final outputFile = File(outputPath);
      expect(outputFile.existsSync(), isTrue);
      final content = outputFile.readAsStringSync();
      expect(content, contains('"rows"'));
    });
  });
}
