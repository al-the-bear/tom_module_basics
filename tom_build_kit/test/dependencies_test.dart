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

    test('--deep shows recursive dependency tree', () async {
      log.start('DEP_DRP01', '--deep shows recursive tree');
      final result =
          await ws.runTool('dependencies', ['--project', '_build', '--deep']);
      log.capture('dependencies --project _build --deep', result);

      final stdout = (result.stdout as String);
      expect(result.exitCode, equals(0));

      // Deep mode should show dependencies
      expect(stdout, contains('->'),
          reason: 'Deep mode should show dependencies');

      // Deep mode should show the project header
      expect(stdout, contains('_build'),
          reason: 'Deep mode should show project name');

      // Verify deep output contains at least as many deps as normal mode
      // (deep may show additional transitive deps, or same if all are leaf nodes)
      final depLines = stdout.split('\n').where(
          (l) => l.trimLeft().startsWith('->') || l.trimLeft().startsWith('+>'));
      expect(depLines, isNotEmpty,
          reason: 'Deep mode should list dependency entries');

      log.expectation('has dependency output', stdout.contains('->'));
      log.expectation(
          'dependency lines found', depLines.isNotEmpty);
    });
  });
}
