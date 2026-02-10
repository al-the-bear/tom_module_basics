import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tom_test_kit/tom_test_kit.dart';

import 'test_helpers.dart';

/// Test IDs: TK-RST-1 through TK-RST-6
void main() {
  group('ResetCommand', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('tk_reset_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('TK-RST-1: returns true when no doc directory exists', () async {
      final result = await ResetCommand.run(
        projectPath: tempDir.path,
        force: true,
      );
      expect(result, isTrue);
    });

    test('TK-RST-2: returns true when doc directory is empty', () async {
      Directory(p.join(tempDir.path, 'doc')).createSync(recursive: true);

      final result = await ResetCommand.run(
        projectPath: tempDir.path,
        force: true,
      );
      expect(result, isTrue);
    });

    test('TK-RST-3: deletes baseline CSV files', () async {
      final tracking = createSingleRunTracking();
      await writeTrackingToTemp(tracking, tempDir);

      // Verify file exists
      final docDir = Directory(p.join(tempDir.path, 'doc'));
      expect(
        docDir.listSync().whereType<File>().where(
              (f) => p.basename(f.path).startsWith('baseline_'),
            ),
        isNotEmpty,
      );

      final result = await ResetCommand.run(
        projectPath: tempDir.path,
        force: true,
      );
      expect(result, isTrue);

      // Verify baseline files deleted
      final remaining = docDir.listSync().whereType<File>().where(
            (f) => p.basename(f.path).startsWith('baseline_'),
          );
      expect(remaining, isEmpty);
    });

    test('TK-RST-4: deletes last_testrun.json', () async {
      await writeLastTestRunJson(tempDir, testErrors: {
        'some test': null,
      });

      final jsonFile = File(p.join(tempDir.path, 'doc', 'last_testrun.json'));
      expect(jsonFile.existsSync(), isTrue);

      final result = await ResetCommand.run(
        projectPath: tempDir.path,
        force: true,
      );
      expect(result, isTrue);
      expect(jsonFile.existsSync(), isFalse);
    });

    test('TK-RST-5: deletes both baseline CSV and last_testrun.json',
        () async {
      final tracking = createSingleRunTracking();
      await writeTrackingToTemp(tracking, tempDir);
      await writeLastTestRunJson(tempDir, testErrors: {
        'some test': null,
      });

      final result = await ResetCommand.run(
        projectPath: tempDir.path,
        force: true,
      );
      expect(result, isTrue);

      // Both should be gone
      final docDir = Directory(p.join(tempDir.path, 'doc'));
      final csvFiles = docDir.listSync().whereType<File>().where(
            (f) => p.basename(f.path).startsWith('baseline_'),
          );
      expect(csvFiles, isEmpty);
      expect(
          File(p.join(tempDir.path, 'doc', 'last_testrun.json')).existsSync(),
          isFalse);
    });

    test('TK-RST-6: preserves non-tracking files in doc/', () async {
      final docDir = Directory(p.join(tempDir.path, 'doc'));
      docDir.createSync(recursive: true);

      // Create a non-tracking file
      File(p.join(docDir.path, 'README.md')).writeAsStringSync('# Doc');

      // Create a baseline file
      final tracking = createSingleRunTracking();
      await writeTrackingToTemp(tracking, tempDir);

      final result = await ResetCommand.run(
        projectPath: tempDir.path,
        force: true,
      );
      expect(result, isTrue);

      // README.md should still exist
      expect(
          File(p.join(docDir.path, 'README.md')).existsSync(), isTrue);
      // Baseline should be gone
      final csvFiles = docDir.listSync().whereType<File>().where(
            (f) => p.basename(f.path).startsWith('baseline_'),
          );
      expect(csvFiles, isEmpty);
    });
  });
}
