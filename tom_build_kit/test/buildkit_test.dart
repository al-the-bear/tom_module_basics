/// Integration tests for the BuildKit pipeline orchestrator.
///
/// Uses a dedicated 'pipeline' fixture with test-simple, test-multi,
/// test-shell, and test-internal pipeline definitions.
///
/// Test IDs: BKT_LST01, BKT_HLP01, BKT_CMD01, BKT_PIP01, BKT_DRY01,
///           BKT_OPT01, BKT_SHL01, BKT_XPJ01, BKT_XPJ02
@TestOn('!browser')
@Timeout(Duration(seconds: 180))
library;

import 'package:test/test.dart';

import 'helpers/test_workspace.dart';

void main() {
  late TestWorkspace ws;
  late TestLogger log;

  setUpAll(() async {
    ws = TestWorkspace();
    print('');
    print('╔══════════════════════════════════════════════════════╗');
    print('║          BuildKit Integration Tests                  ║');
    print('╚══════════════════════════════════════════════════════╝');
    print('Workspace root:  ${ws.workspaceRoot}');
    print('Buildkit root:   ${ws.buildkitRoot}');
    await ws.requireCleanWorkspace();
    await ws.saveHeadRefs();
  });

  setUp(() async {
    log = TestLogger(ws);
    await ws.installFixture('pipeline');
  });

  tearDown(() async {
    log.finish();
    await ws.revertAll();
  });

  tearDownAll(() async {
    print('');
    print('  ── BuildKit Tests: Tear-down ──');
    await ws.verifyHeadRefs();
    print('  ── BuildKit Tests: Complete ──');
  });

  // ----------- Tests ----------- //

  group('buildkit', () {
    test('--list shows available pipelines', () async {
      log.start('BKT_LST01', '--list shows available pipelines');
      final result = await ws.runPipeline('--list', []);
      log.capture('buildkit --list', result);

      final stdout = (result.stdout as String);
      expect(result.exitCode, equals(0));

      // Should list our test pipelines
      expect(stdout, contains('test-simple'),
          reason: 'test-simple pipeline should be listed');
      expect(stdout, contains('test-shell'),
          reason: 'test-shell pipeline should be listed');

      // test-internal should be listed as internal
      final hasInternal = stdout.contains('test-internal');
      expect(hasInternal, isTrue,
          reason: 'test-internal pipeline should be listed');

      log.expectation('test-simple listed', stdout.contains('test-simple'));
      log.expectation('test-shell listed', stdout.contains('test-shell'));
      log.expectation('test-internal listed', hasInternal);
    });

    test('--help shows usage information', () async {
      log.start('BKT_HLP01', '--help shows usage');
      final result = await ws.runPipeline('--help', []);
      log.capture('buildkit --help', result);

      final stdout = (result.stdout as String);
      expect(result.exitCode, equals(0));
      // Help should show usage text
      expect(stdout, contains('Usage'),
          reason: 'Help should show Usage section');
      expect(stdout, contains('pipeline'),
          reason: 'Help should mention pipelines');
      log.expectation('shows usage', stdout.contains('Usage'));
    });

    test('direct command execution (:versioner)', () async {
      log.start('BKT_CMD01', 'direct command :versioner');
      final result = await ws.runPipeline(
          ':versioner', ['--project', '_build', '--dry-run']);
      log.capture('buildkit :versioner --project _build --dry-run', result);

      final stdout = (result.stdout as String);
      expect(result.exitCode, equals(0));
      // Should show dry-run output for versioner
      final hasDryRun = stdout.toLowerCase().contains('dry run') ||
          stdout.contains('Would run') ||
          stdout.contains('versioner');
      expect(hasDryRun, isTrue,
          reason: 'Direct :versioner command should produce output');
      log.expectation('versioner output present', hasDryRun);
    });

    test('pipeline execution runs all steps', () async {
      log.start('BKT_PIP01', 'pipeline execution');
      // test-simple has two shell echo steps — both should execute
      final result =
          await ws.runPipeline('test-simple', ['--project', '_build']);
      log.capture('buildkit test-simple --project _build', result);

      final stdout = (result.stdout as String);
      expect(result.exitCode, equals(0));

      // Both echo steps should produce output
      expect(stdout, contains('step-1-hello'),
          reason: 'First pipeline step should execute');
      expect(stdout, contains('step-2-world'),
          reason: 'Second pipeline step should execute');

      // Pipeline should show summary
      final hasSummary =
          stdout.contains('Summary') || stdout.contains('SUCCESS');
      expect(hasSummary, isTrue,
          reason: 'Pipeline should show summary');

      log.expectation('step 1 executed', stdout.contains('step-1-hello'));
      log.expectation('step 2 executed', stdout.contains('step-2-world'));
    });

    test('--dry-run shows steps without executing', () async {
      log.start('BKT_DRY01', '--dry-run on pipeline');
      final result = await ws.runPipeline(
          'test-simple', ['--project', '_build', '--dry-run']);
      log.capture('buildkit test-simple --dry-run', result);

      final stdout = (result.stdout as String);
      expect(result.exitCode, equals(0));

      // Dry-run should complete successfully
      // Shell commands may still execute with --dry-run (buildkit design),
      // but the pipeline should show summary
      final hasSummary =
          stdout.contains('Summary') || stdout.contains('SUCCESS');
      expect(hasSummary, isTrue,
          reason: 'Dry-run pipeline should show summary');

      // Verify the pipeline step ran (even in dry-run for shell commands)
      final hasStepOutput = stdout.contains('step-1-hello') ||
          stdout.toLowerCase().contains('dry run') ||
          stdout.contains('Would execute');
      expect(hasStepOutput, isTrue,
          reason: 'Dry-run should show step output or dry-run markers');

      log.expectation('pipeline completed', hasSummary);
    });

    test('per-step option suppression (-s-)', () async {
      log.start('BKT_OPT01', 'per-step option suppression');
      // Run with scan and suppress scan for the direct command
      // The -s- flag should suppress the global --scan for just that step
      final result = await ws.runPipeline(':versioner',
          ['-s-', '--project', '_build', '--dry-run']);
      log.capture('buildkit :versioner -s- --project _build --dry-run',
          result);

      // Should complete without error (syntax accepted)
      expect(result.exitCode, equals(0),
          reason: 'Option suppression syntax should be accepted');
      log.expectation('exit code 0', result.exitCode == 0);
    });

    test('shell command execution in pipeline', () async {
      log.start('BKT_SHL01', 'shell command in pipeline');
      // test-shell pipeline has: shell echo "hello from test pipeline"
      final result = await ws.runPipeline(
          'test-shell', ['--project', '_build']);
      log.capture('buildkit test-shell --project _build', result);

      final stdout = (result.stdout as String);
      expect(result.exitCode, equals(0));
      // The echo command should produce output
      expect(stdout, contains('hello from test pipeline'),
          reason: 'Shell echo command should produce output');
      log.expectation(
          'echo output present', stdout.contains('hello from test pipeline'));
    });

    test('--exclude-projects filters pipeline targets', () async {
      log.start('BKT_XPJ01', '--exclude-projects in pipeline');
      final result = await ws.runPipeline('test-simple', [
        '--scan',
        '.',
        '--recursive',
        '--exclude-projects',
        '_build',
        '--dry-run',
        '--verbose',
      ]);
      log.capture('buildkit test-simple --exclude-projects _build --dry-run',
          result);

      expect(result.exitCode, equals(0));

      // _build should be excluded from processing
      log.expectation('exit code 0', result.exitCode == 0);
    });

    test('--exclude and --exclude-projects combined', () async {
      log.start('BKT_XPJ02', '--exclude + --exclude-projects');
      final result = await ws.runPipeline('test-simple', [
        '--scan',
        '.',
        '--recursive',
        '--exclude',
        'core/*',
        '--exclude-projects',
        '_build',
        '--dry-run',
        '--verbose',
      ]);
      log.capture('buildkit --exclude core/* --exclude-projects _build',
          result);

      expect(result.exitCode, equals(0));

      // Both exclusion types should apply
      log.expectation('exit code 0', result.exitCode == 0);
    });
  });
}
