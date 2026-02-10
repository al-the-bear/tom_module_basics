import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_test_kit/tom_test_kit.dart';

import 'test_helpers.dart';

/// Test IDs: TK-XREF-1 through TK-XREF-5
void main() {
  group('CrossReferenceCommand', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('tk_xref_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('TK-XREF-1: returns false when no baseline file exists', () async {
      final result =
          await CrossReferenceCommand.run(projectPath: tempDir.path);
      expect(result, isFalse);
    });

    test('TK-XREF-2: returns true for tracking file without suite info',
        () async {
      final tracking = createSingleRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);

      final result = await CrossReferenceCommand.run(
        projectPath: tempDir.path,
        baselineFile: filePath,
      );
      expect(result, isTrue);
    });

    test('TK-XREF-3: writes CSV cross-reference to file', () async {
      final tracking = createSingleRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);
      final outputPath = '${tempDir.path}/xref.csv';

      final result = await CrossReferenceCommand.run(
        projectPath: tempDir.path,
        baselineFile: filePath,
        output: OutputSpec(format: OutputFormat.csv, filePath: outputPath),
      );

      expect(result, isTrue);
      final content = File(outputPath).readAsStringSync();
      expect(content, contains('ID'));
      expect(content, contains('Source File'));
      expect(content, contains('Line'));
    });

    test('TK-XREF-4: returns true with verbose flag', () async {
      final tracking = createSingleRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);

      final result = await CrossReferenceCommand.run(
        projectPath: tempDir.path,
        baselineFile: filePath,
        verbose: true,
      );
      expect(result, isTrue);
    });

    test('TK-XREF-5: writes JSON cross-reference to file', () async {
      final tracking = createSingleRunTracking();
      final filePath = await writeTrackingToTemp(tracking, tempDir);
      final outputPath = '${tempDir.path}/xref.json';

      final result = await CrossReferenceCommand.run(
        projectPath: tempDir.path,
        baselineFile: filePath,
        output: OutputSpec(format: OutputFormat.json, filePath: outputPath),
      );

      expect(result, isTrue);
      final content = File(outputPath).readAsStringSync();
      expect(content, contains('"rows"'));
      expect(content, contains('"headers"'));
    });
  });
}
