import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_test_kit/tom_test_kit.dart';

import 'test_helpers.dart';

/// Test IDs: TK-FLKY-1 through TK-FLKY-6
void main() {
  group('FlakyCommand', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('tk_flaky_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('TK-FLKY-1: returns false when no baseline file exists', () async {
      final result = await FlakyCommand.run(projectPath: tempDir.path);
      expect(result, isFalse);
    });

    test('TK-FLKY-2: returns true with message when only 1 run', () async {
      final tracking = createSingleRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);

      // FlakyCommand needs >= 2 runs
      final result = await FlakyCommand.run(
        projectPath: tempDir.path,
        baselineFile: filePath,
      );
      expect(result, isTrue); // Returns true but prints "need 2 runs"
    });

    test('TK-FLKY-3: detects flaky tests in multi-run tracking', () async {
      final tracking = createFlakyTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);

      final result = await FlakyCommand.run(
        projectPath: tempDir.path,
        baselineFile: filePath,
      );
      expect(result, isTrue);
    });

    test('TK-FLKY-4: returns true with no flaky tests for stable data',
        () async {
      // Create tracking where all tests are stable across runs
      final entries = [
        TestEntry(
          id: 'TK-S1',
          fullDescription: 'stable test 1',
          description: 'stable test 1',
        ),
      ];
      final baseline = TestRun(
        timestamp: DateTime(2026, 3, 1, 10, 0),
        isBaseline: true,
        results: {'stable test 1': TestResult.ok},
      );
      final tracking = TrackingFile.fromBaseline(entries, baseline);
      tracking.addRun(
        TestRun(
          timestamp: DateTime(2026, 3, 2, 10, 0),
          results: {'stable test 1': TestResult.ok},
        ),
        [],
      );

      final filePath = await writeTrackingToTemp(tracking, tempDir);
      final result = await FlakyCommand.run(
        projectPath: tempDir.path,
        baselineFile: filePath,
      );
      expect(result, isTrue); // No flaky tests detected
    });

    test('TK-FLKY-5: writes CSV output to file', () async {
      final tracking = createFlakyTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);
      final outputPath = '${tempDir.path}/flaky.csv';

      final result = await FlakyCommand.run(
        projectPath: tempDir.path,
        baselineFile: filePath,
        output: OutputSpec(format: OutputFormat.csv, filePath: outputPath),
      );

      expect(result, isTrue);
      final content = File(outputPath).readAsStringSync();
      expect(content, contains('ID'));
      expect(content, contains('Flips'));
      // Should detect TK-A and TK-B as flaky
      final lines =
          content.split('\n').where((l) => l.trim().isNotEmpty).toList();
      expect(lines.length,
          greaterThanOrEqualTo(3)); // header + at least 2 flaky tests
    });

    test('TK-FLKY-6: writes JSON output to file', () async {
      final tracking = createFlakyTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);
      final outputPath = '${tempDir.path}/flaky.json';

      final result = await FlakyCommand.run(
        projectPath: tempDir.path,
        baselineFile: filePath,
        output: OutputSpec(format: OutputFormat.json, filePath: outputPath),
      );

      expect(result, isTrue);
      final content = File(outputPath).readAsStringSync();
      expect(content, contains('"rows"'));
      expect(content, contains('Flips'));
    });
  });
}
