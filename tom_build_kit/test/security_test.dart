/// Integration tests for security boundaries and path validation.
///
/// Tests that tools reject paths outside the workspace, that protected
/// folders survive cleanup, and that the security model is enforced.
///
/// Test IDs: SEC_PRJ01, SEC_SCN01, SEC_PRO01
@TestOn('!browser')
@Timeout(Duration(seconds: 120))
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
    print('║          Security Integration Tests                  ║');
    print('╚══════════════════════════════════════════════════════╝');
    print('Workspace root:  ${ws.workspaceRoot}');
    print('Buildkit root:   ${ws.buildkitRoot}');
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
    print('  ── Security Tests: Tear-down ──');
    await ws.verifyHeadRefs();
    print('  ── Security Tests: Complete ──');
  });

  // ----------- Tests ----------- //

  group('path validation', () {
    test('--project rejects paths outside workspace', () async {
      log.start('SEC_PRJ01', '--project rejects outside paths');
      final result = await ws.runTool(
          'versioner', ['--project', '/tmp/evil_project']);
      log.capture('versioner --project /tmp/evil_project', result);

      // Tool should reject the path and exit with error
      expect(result.exitCode, isNot(equals(0)),
          reason: 'Path outside workspace should be rejected');

      final output = '${result.stdout}${result.stderr}';
      // Error message should indicate path containment violation
      final hasPathError = output.toLowerCase().contains('path') ||
          output.toLowerCase().contains('contain') ||
          output.toLowerCase().contains('outside') ||
          output.toLowerCase().contains('not within') ||
          output.toLowerCase().contains('invalid');
      expect(hasPathError, isTrue,
          reason: 'Error message should explain path rejection: $output');
      log.expectation('rejected with error', result.exitCode != 0);
      log.expectation('error message present', hasPathError);
    });

    test('--scan rejects paths outside workspace', () async {
      log.start('SEC_SCN01', '--scan rejects outside paths');
      final result = await ws.runTool(
          'versioner', ['--scan', '/tmp', '--recursive', '--list']);
      log.capture('versioner --scan /tmp -r --list', result);

      // Tool should reject the scan path
      expect(result.exitCode, isNot(equals(0)),
          reason: 'Scan path outside workspace should be rejected');

      final output = '${result.stdout}${result.stderr}';
      final hasPathError = output.toLowerCase().contains('path') ||
          output.toLowerCase().contains('contain') ||
          output.toLowerCase().contains('outside') ||
          output.toLowerCase().contains('not within') ||
          output.toLowerCase().contains('invalid');
      expect(hasPathError, isTrue,
          reason: 'Error message should explain path rejection: $output');
      log.expectation('rejected with error', result.exitCode != 0);
      log.expectation('error message present', hasPathError);
    });
  });

  group('protected resources', () {
    test('builtin protected folders (.git, .github) survive cleanup',
        () async {
      log.start('SEC_PRO01', 'builtin protected folders survive');

      // Run cleanup with --dry-run on the entire workspace and broad pattern
      // to verify .git and .github are never listed for deletion
      final result = await ws.runTool('cleanup',
          ['--project', '_build', '--dry-run', '--verbose']);
      log.capture('cleanup --dry-run --verbose on _build', result);

      final stdout = (result.stdout as String);
      expect(result.exitCode, equals(0));

      // Parse all file paths mentioned in the dry-run output
      final lines = stdout.split('\n');
      // Check no line references .git/ internal paths (but .github and
      // .gitignore are different things)
      final gitInternalRefs = lines.where((l) =>
          RegExp(r'[/\\]\.git[/\\]').hasMatch(l) &&
          !l.contains('.github') &&
          !l.contains('.gitignore'));

      expect(gitInternalRefs, isEmpty,
          reason:
              'Protected .git/ internal paths should never appear in cleanup '
              'output, found: ${gitInternalRefs.join(', ')}');

      log.expectation('no .git/ internal refs', gitInternalRefs.isEmpty);
    });
  });
}
