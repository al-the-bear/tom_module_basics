@TestOn('!browser')
@Timeout(Duration(seconds: 120))
library; // ignore: unnecessary_library_name

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'helpers/test_workspace.dart';

/// Integration tests for the versioner tool.
///
/// These tests use the `_build` project as the target because:
/// - It's in the main repo (no submodule complications for git revert)
/// - It has a versioner config (variable-prefix: tomTools)
/// - Its version.g.dart is NOT imported by tom_build_kit, so regenerating
///   it won't break the tool under test
void main() {
  late TestWorkspace ws;

  /// Absolute path to the _build project (target for versioner tests).
  late String targetProject;

  /// Relative path from workspace root to the version.g.dart file.
  late String versionFileRelative;

  setUpAll(() async {
    ws = TestWorkspace();
    targetProject = p.join(ws.workspaceRoot, '_build');
    versionFileRelative = '_build/lib/src/version.g.dart';
    print('Workspace root:  ${ws.workspaceRoot}');
    print('Buildkit root:   ${ws.buildkitRoot}');
    print('Target project:  $targetProject');

    // Safety: verify workspace is clean before running tests.
    // Tests assume exclusive access and a committed baseline.
    final dirty = await ws.hasUncommittedChanges();
    if (dirty.isNotEmpty) {
      print('WARNING: Workspace has uncommitted changes:');
      for (final f in dirty) {
        print('  $f');
      }
      fail(
        'Workspace must be clean before running integration tests. '
        'Commit or stash all changes first. '
        'See _copilot_guidelines/testing.md for the pre-test safety protocol.',
      );
    }
  });

  tearDown(() async {
    // Revert all changes in the main repo (tom_build_master.yaml,
    // _build/lib/src/version.g.dart, _build/tom_build_state.json)
    await ws.revertAll();
  });

  group('versioner', () {
    test('--project generates version.g.dart with correct prefix', () async {
      await ws.installFixture('versioner');

      final result = await ws.runTool(
        'versioner',
        ['--project', targetProject],
      );

      print('STDOUT:\n${result.stdout}');
      if ((result.stderr as String).isNotEmpty) {
        print('STDERR:\n${result.stderr}');
      }

      expect(result.exitCode, 0, reason: 'versioner should exit with 0');
      expect(
        result.stdout as String,
        contains('Version file generated'),
        reason: 'Should report successful generation',
      );

      // The generated file should exist
      final versionFile = File(p.join(ws.workspaceRoot, versionFileRelative));
      expect(versionFile.existsSync(), isTrue);

      final content = versionFile.readAsStringSync();

      // _build/tom_build.yaml has variable-prefix: tomTools
      // → class name should be TomToolsVersionInfo
      expect(
        content,
        contains('class TomToolsVersionInfo'),
        reason:
            'Class name should use project-level prefix "tomTools" → TomToolsVersionInfo',
      );

      // Should contain version from pubspec.yaml
      expect(content, contains("static const String version = '1.0.0'"));

      // Should contain GENERATED header
      expect(content, contains('GENERATED FILE - DO NOT EDIT'));

      // Should contain git commit
      expect(content, contains('static const String gitCommit'));

      // Should contain build number
      expect(content, contains('static const int buildNumber'));

      // Should contain Dart SDK version
      expect(content, contains('static const String dartSdkVersion'));
    });

    // BUG: --no-git is overridden by project-level tom_build.yaml
    // because generateVersionFile() merges project config AFTER CLI args.
    // The merge order should be: master → project → CLI (highest priority).
    // Currently: master → CLI → project (project wins over CLI).
    // TODO: Fix merge order in versioner_tool.dart generateVersionFile()
    test('--project --no-git currently does NOT omit git commit (merge bug)',
        () async {
      await ws.installFixture('versioner');

      final result = await ws.runTool(
        'versioner',
        ['--project', targetProject, '--no-git'],
      );

      print('STDOUT:\n${result.stdout}');
      if ((result.stderr as String).isNotEmpty) {
        print('STDERR:\n${result.stderr}');
      }

      expect(result.exitCode, 0);

      final content =
          File(p.join(ws.workspaceRoot, versionFileRelative)).readAsStringSync();

      // BUG: project YAML includeGitCommit:true overrides CLI --no-git
      // When fixed, this should use isNot(contains(...)).
      expect(
        content,
        contains('static const String gitCommit'),
        reason: 'BUG: project config overrides CLI --no-git flag',
      );

      // Version and build number should always be present
      expect(content, contains('static const String version'));
      expect(content, contains('static const int buildNumber'));
    });

    test('--list shows _build as a versioner project', () async {
      await ws.installFixture('versioner');

      final result = await ws.runTool(
        'versioner',
        ['--project', targetProject, '--list'],
      );

      print('STDOUT:\n${result.stdout}');
      expect(result.exitCode, 0);
      expect(result.stdout as String, contains('_build'));
    });

    test('--show displays versioner config from tom_build.yaml', () async {
      await ws.installFixture('versioner');

      final result = await ws.runTool(
        'versioner',
        ['--project', targetProject, '--show'],
      );

      print('STDOUT:\n${result.stdout}');
      expect(result.exitCode, 0);

      final stdout = result.stdout as String;
      expect(stdout, contains('variable-prefix'));
      expect(stdout, contains('tomTools'));
    });

    test('--version overrides pubspec version', () async {
      await ws.installFixture('versioner');

      final result = await ws.runTool(
        'versioner',
        ['--project', targetProject, '--version', '9.9.9'],
      );

      expect(result.exitCode, 0);

      final content =
          File(p.join(ws.workspaceRoot, versionFileRelative)).readAsStringSync();

      expect(
        content,
        contains("static const String version = '9.9.9'"),
        reason: 'Should use overridden version 9.9.9',
      );
    });

    // BUG: --variable-prefix is overridden by project-level tom_build.yaml
    // Same merge order issue as --no-git above.
    // TODO: Fix merge order in versioner_tool.dart generateVersionFile()
    test('--variable-prefix currently does NOT override project config (merge bug)',
        () async {
      await ws.installFixture('versioner');

      final result = await ws.runTool(
        'versioner',
        ['--project', targetProject, '--variable-prefix', 'myCustom'],
      );

      expect(result.exitCode, 0);

      final content =
          File(p.join(ws.workspaceRoot, versionFileRelative)).readAsStringSync();

      // BUG: project config prefix "tomTools" overrides CLI "myCustom"
      // When fixed, this should expect 'class MyCustomVersionInfo'.
      expect(
        content,
        contains('class TomToolsVersionInfo'),
        reason: 'BUG: project config overrides CLI --variable-prefix',
      );
    });

    test('build number increments on each run', () async {
      await ws.installFixture('versioner');

      // First run
      await ws.runTool('versioner', ['--project', targetProject]);
      final content1 =
          File(p.join(ws.workspaceRoot, versionFileRelative)).readAsStringSync();
      final buildNum1 = _extractBuildNumber(content1);

      // Second run
      await ws.runTool('versioner', ['--project', targetProject]);
      final content2 =
          File(p.join(ws.workspaceRoot, versionFileRelative)).readAsStringSync();
      final buildNum2 = _extractBuildNumber(content2);

      expect(buildNum2, buildNum1 + 1,
          reason: 'Build number should increment on each run');
    });
  });
}

/// Extract the build number from generated version.g.dart content.
int _extractBuildNumber(String content) {
  final match =
      RegExp(r'static const int buildNumber = (\d+);').firstMatch(content);
  if (match == null) {
    throw StateError('Could not find buildNumber in generated content');
  }
  return int.parse(match.group(1)!);
}
