import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_test_kit/tom_test_kit.dart';

import 'test_helpers.dart';

/// Test IDs: TK-RUNS-1 through TK-RUNS-5
void main() {
  group('RunsCommand', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('tk_runs_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('TK-RUNS-1: returns false when no baseline file exists', () async {
      final result = await RunsCommand.run(projectPath: tempDir.path);
      expect(result, isFalse);
    });

    test('TK-RUNS-2: returns true for single-run tracking file', () async {
      final tracking = createSingleRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);

      final result = await RunsCommand.run(
        projectPath: tempDir.path,
        baselineFile: filePath,
      );
      expect(result, isTrue);
    });

    test('TK-RUNS-3: returns true for multi-run tracking file', () async {
      final tracking = createMultiRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);

      final result = await RunsCommand.run(
        projectPath: tempDir.path,
        baselineFile: filePath,
      );
      expect(result, isTrue);
    });

    test('TK-RUNS-4: writes CSV output to file', () async {
      final tracking = createMultiRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);
      final outputPath = '${tempDir.path}/runs_output.csv';

      final result = await RunsCommand.run(
        projectPath: tempDir.path,
        baselineFile: filePath,
        output: OutputSpec(format: OutputFormat.csv, filePath: outputPath),
      );

      expect(result, isTrue);
      final outputFile = File(outputPath);
      expect(outputFile.existsSync(), isTrue);
      final content = outputFile.readAsStringSync();
      // CSV should have header + 3 data rows
      final lines =
          content.split('\n').where((l) => l.trim().isNotEmpty).toList();
      expect(lines.length, equals(4)); // header + 3 runs
      expect(lines.first, contains('#'));
      expect(lines.first, contains('Timestamp'));
      expect(lines.first, contains('Type'));
      // First run should be baseline
      expect(lines[1], contains('baseline'));
    });

    test('TK-RUNS-5: writes JSON output to file', () async {
      final tracking = createMultiRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);
      final outputPath = '${tempDir.path}/runs_output.json';

      final result = await RunsCommand.run(
        projectPath: tempDir.path,
        baselineFile: filePath,
        output: OutputSpec(format: OutputFormat.json, filePath: outputPath),
      );

      expect(result, isTrue);
      final outputFile = File(outputPath);
      expect(outputFile.existsSync(), isTrue);
      final content = outputFile.readAsStringSync();
      expect(content, contains('"rows"'));
      expect(content, contains('"headers"'));
    });
  });
}
