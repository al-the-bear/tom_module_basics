@TestOn('!browser')
@Timeout(Duration(seconds: 120))
library; // ignore: unnecessary_library_name

import 'package:test/test.dart';

import 'helpers/test_workspace.dart';

/// Integration tests for the dependencies tool.
///
/// Target project: `_build` (has many path dependencies to other workspace
/// projects, plus dev dependencies like build_runner and test).
void main() {
  late TestWorkspace ws;
  late TestLogger log;

  setUpAll(() async {
    ws = TestWorkspace();
    print('');
    print('╔══════════════════════════════════════════════════════╗');
    print('║          Dependencies Integration Tests              ║');
    print('╚══════════════════════════════════════════════════════╝');
    print('Workspace root:  ${ws.workspaceRoot}');
    print('Buildkit root:   ${ws.buildkitRoot}');

    // Full workspace protection protocol
    await ws.requireCleanWorkspace();
    await ws.saveHeadRefs();
  });

  setUp(() async {
    log = TestLogger(ws);
    await ws.installFixture('exclusion');
  });

  tearDown(() async {
    log.finish();
    await ws.revertAll();
  });

  tearDownAll(() async {
    print('');
    print('  ── Dependencies Tests: Tear-down ──');
    await ws.verifyHeadRefs();
    print('  ── Dependencies Tests: Complete ──');
  });

  // ---------------------------------------------------------------------------
  // Tests
  // ---------------------------------------------------------------------------

  group('dependencies', () {
    test('default mode shows normal dependencies', () async {
      log.start('DEP_NRM01', 'default shows normal dependencies');
      final result =
          await ws.runTool('dependencies', ['--project', '_build']);
      log.capture('dependencies --project _build', result);

      final stdout = (result.stdout as String);
      expect(result.exitCode, equals(0));

      // Normal deps use -> prefix
      expect(stdout, contains('->'),
          reason: 'Expected -> prefixed normal dependencies');

      // Should contain known _build dependencies
      expect(stdout, contains('tom_build_cli'),
          reason: 'Expected tom_build_cli in normal deps');

      // Should NOT show dev deps (+> prefix) in default mode
      final lines = stdout.split('\n');
      final devLines = lines.where((l) => l.contains('+>'));
      expect(devLines, isEmpty,
          reason: 'Default mode should not show dev dependencies');

      log.expectation('has -> entries', stdout.contains('->'));
      log.expectation('no +> entries', devLines.isEmpty);
    });

    test('--dev shows dev dependencies only', () async {
      log.start('DEP_DEV01', '--dev shows dev dependencies');
      final result =
          await ws.runTool('dependencies', ['--project', '_build', '--dev']);
      log.capture('dependencies --project _build --dev', result);

      final stdout = (result.stdout as String);
      expect(result.exitCode, equals(0));

      // Dev deps use +> prefix
      expect(stdout, contains('+>'),
          reason: 'Expected +> prefixed dev dependencies');

      // Should contain known _build dev dependencies
      expect(stdout, contains('build_runner'),
          reason: 'Expected build_runner in dev deps');

      // Should NOT show normal deps (-> prefix) in --dev mode
      final lines = stdout.split('\n');
      final normalLines = lines.where((l) => l.contains('->'));
      expect(normalLines, isEmpty,
          reason: '--dev mode should not show normal dependencies');

      log.expectation('has +> entries', stdout.contains('+>'));
      log.expectation('no -> entries', normalLines.isEmpty);
    });

    test('--all shows both normal and dev dependencies', () async {
      log.start('DEP_ALL01', '--all shows both types');
      final result =
          await ws.runTool('dependencies', ['--project', '_build', '--all']);
      log.capture('dependencies --project _build --all', result);

      final stdout = (result.stdout as String);
      expect(result.exitCode, equals(0));

      // Should show both normal and dev deps
      expect(stdout, contains('->'),
          reason: 'Expected normal dependencies with --all');
      expect(stdout, contains('+>'),
          reason: 'Expected dev dependencies with --all');

      log.expectation('has -> entries', stdout.contains('->'));
      log.expectation('has +> entries', stdout.contains('+>'));
    });

    test('--deep shows indented transitive dependency tree (bug #16)',
        () async {
      log.start('DEP_DRP01', '--deep shows indented transitive tree');
      // Bug #16: _resolveDependencyPath() resolves relative paths against
      // Directory.current.path (workspace root) instead of the project
      // directory. All relative path deps fail to resolve, so no sub-trees
      // are explored and --deep produces identical flat output to normal mode.
      final result =
          await ws.runTool('dependencies', ['--project', '_build', '--deep']);
      log.capture('dependencies --project _build --deep', result);

      final stdout = (result.stdout as String);
      expect(result.exitCode, equals(0));

      // _build has path dependencies to other workspace projects (e.g.
      // tom_build_cli, tom_basics). Those projects have their own deps.
      // INTENDED behavior: deep mode shows indented sub-dependencies
      // with 2+ spaces of leading indentation for transitive deps.
      final lines = stdout.split('\n');
      final indentedDepLines = lines.where((l) =>
          l.startsWith('  ') &&
          (l.trimLeft().startsWith('->') || l.trimLeft().startsWith('+>')));
      expect(indentedDepLines, isNotEmpty,
          reason: 'Deep mode should show indented transitive dependencies '
              '(sub-deps of path dependencies). Got only flat output.');

      log.expectation(
          'has indented sub-deps', indentedDepLines.isNotEmpty);
    },
        skip: 'Bug #16: --deep fails to resolve relative path dependencies '
            '(resolves against CWD instead of project directory)');

    test('--deep output differs from normal mode (bug #16)', () async {
      log.start('DEP_DRP02', '--deep output differs from normal');
      // Bug #16: Because path deps can't be resolved, --deep produces
      // identical output to normal mode.

      // Run normal mode
      final normalResult =
          await ws.runTool('dependencies', ['--project', '_build']);
      final normalStdout = (normalResult.stdout as String);

      // Run deep mode
      final deepResult =
          await ws.runTool('dependencies', ['--project', '_build', '--deep']);
      final deepStdout = (deepResult.stdout as String);

      expect(normalResult.exitCode, equals(0));
      expect(deepResult.exitCode, equals(0));

      // Count dependency lines in each mode
      final normalDepLines = normalStdout
          .split('\n')
          .where((l) => l.trimLeft().startsWith('->'))
          .length;
      final deepDepLines = deepStdout
          .split('\n')
          .where((l) => l.trimLeft().startsWith('->'))
          .length;

      // INTENDED behavior: deep mode shows MORE dependency entries because
      // it recursively follows path dependencies and shows their transitive deps.
      expect(deepDepLines, greaterThan(normalDepLines),
          reason: '--deep should show more dependencies than normal mode '
              '(transitive deps of path dependencies). '
              'Normal: $normalDepLines, Deep: $deepDepLines');

      log.expectation(
          'deep has more deps', deepDepLines > normalDepLines);
    },
        skip: 'Bug #16: --deep produces identical output to normal mode '
            '(path resolution resolves against CWD instead of project dir)');

    test('--deep --dev shows recursive dev dependency tree', () async {
      log.start('DEP_CBD01', '--deep --dev combined flags');
      // Test that --deep and --dev can be combined.
      // Should show dev dependencies recursively (if path deps have dev deps).
      final result = await ws.runTool(
          'dependencies', ['--project', '_build', '--deep', '--dev']);
      log.capture('dependencies --project _build --deep --dev', result);

      final stdout = (result.stdout as String);
      final stderr = (result.stderr as String);
      expect(result.exitCode, equals(0),
          reason: 'Combined --deep --dev should not crash. '
              'Stderr: ${stderr.substring(0, stderr.length.clamp(0, 300))}');

      // Should show dev dependencies (+> prefix)
      expect(stdout, contains('+>'),
          reason: '--dev mode should show +> prefixed dev dependencies');

      // Should NOT show normal deps (-> prefix) in --dev mode
      final lines = stdout.split('\n');
      final normalLines = lines.where((l) => l.trimLeft().startsWith('->'));
      expect(normalLines, isEmpty,
          reason: '--deep --dev should only show dev dependencies, '
              'not normal deps');

      log.expectation('has dev deps', stdout.contains('+>'));
      log.expectation('no normal deps', normalLines.isEmpty);
    });

    test('--project with non-existent path gives clear error', () async {
      log.start('DEP_ERR01', 'non-existent --project error');
      // Bug #19: Dependencies tool returns exit code 0 for non-existent
      // --project path instead of reporting an error. When a user explicitly
      // specifies --project, the tool should validate the path exists.
      final result = await ws.runTool(
          'dependencies', ['--project', '_build/nonexistent']);
      log.capture('dependencies --project _build/nonexistent', result);

      // INTENDED behavior: non-existent project should produce a clear error
      expect(result.exitCode, isNot(equals(0)),
          reason: 'Non-existent --project path should fail with non-zero exit. '
              'Got exit code ${result.exitCode}');

      final combined = '${result.stdout}\n${result.stderr}';
      final hasError =
          combined.toLowerCase().contains('error') ||
          combined.toLowerCase().contains('not found') ||
          combined.toLowerCase().contains('does not exist') ||
          combined.toLowerCase().contains('no pubspec');
      expect(hasError, isTrue,
          reason: 'Should show clear error for non-existent project path');

      log.expectation('non-zero exit', result.exitCode != 0);
      log.expectation('has error message', hasError);
    },
        skip: 'Bug #19: Dependencies tool returns exit code 0 for '
            'non-existent --project path (no validation)');
  });
}
