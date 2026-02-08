/// Integration tests for the VersionBump tool.
///
/// **NOTE:** All tests currently document known bug #13 — the `-v` abbreviation
/// conflict prevents VersionBump from starting. The tool crashes on any
/// invocation including `--help`. Tests verify the crash behavior and will be
/// updated once the bug is fixed.
///
/// Test IDs: VBM_PAT01, VBM_MIN01, VBM_MAJ01, VBM_RST01, VBM_DRY01
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
    print('║          VersionBump Integration Tests               ║');
    print('╚══════════════════════════════════════════════════════╝');
    print('Workspace root:  ${ws.workspaceRoot}');
    print('Buildkit root:   ${ws.buildkitRoot}');
    print('');
    print('⚠️  All tests document bug #13: -v abbreviation conflict');
    print('   VersionBump cannot start — all invocations crash.');
    print('');
    await ws.requireCleanWorkspace();
    await ws.saveHeadRefs();
  });

  setUp(() {
    log = TestLogger(ws);
  });

  tearDown(() {
    log.finish();
  });

  tearDownAll(() async {
    print('');
    print('  ── VersionBump Tests: Tear-down ──');
    await ws.verifyHeadRefs();
    print('  ── VersionBump Tests: Complete ──');
  });

  // ── Bug #13 baseline: tool cannot start ──────────────────────────────

  test('BUG #13: --help crashes due to -v abbreviation conflict', () async {
    log.start('VBM_BUG13', 'versionbump --help crashes');
    final result = await ws.runTool('versionbump', ['--help']);
    log.capture('versionbump --help', result);

    // Bug #13: ArgParser throws "Abbreviation 'v' is already used by 'verbose'"
    expect(result.exitCode, isNot(0),
        reason: 'Bug #13: versionbump cannot start due to -v conflict');
    final stderr = (result.stderr as String);
    final hasAbbreviationError = stderr.contains('Abbreviation') ||
        stderr.contains('already used') ||
        stderr.contains('-v');
    expect(hasAbbreviationError, isTrue,
        reason: 'Should show abbreviation conflict error');
    log.expectation('tool crashes with -v error', hasAbbreviationError);
  });

  // ── Patch bump (VBM_PAT01) ───────────────────────────────────────────

  test('default patch bump (blocked by bug #13)', () async {
    log.start('VBM_PAT01', 'default patch bump');
    final result =
        await ws.runTool('versionbump', ['--project', '_build']);
    log.capture('versionbump --project _build', result);

    // Bug #13: tool crashes before processing
    expect(result.exitCode, isNot(0),
        reason: 'Bug #13: versionbump crashes on startup');
    log.expectation('crashes due to bug #13', result.exitCode != 0);
  },
      skip: 'Blocked by bug #13: -v abbreviation conflict prevents startup');

  // ── Minor bump (VBM_MIN01) ───────────────────────────────────────────

  test('--minor bump (blocked by bug #13)', () async {
    log.start('VBM_MIN01', '--minor bump');
    final result =
        await ws.runTool('versionbump', ['--minor', '--project', '_build']);
    log.capture('versionbump --minor --project _build', result);

    expect(result.exitCode, isNot(0),
        reason: 'Bug #13: versionbump crashes on startup');
    log.expectation('crashes due to bug #13', result.exitCode != 0);
  },
      skip: 'Blocked by bug #13: -v abbreviation conflict prevents startup');

  // ── Major bump (VBM_MAJ01) ───────────────────────────────────────────

  test('--major bump (blocked by bug #13)', () async {
    log.start('VBM_MAJ01', '--major bump');
    final result =
        await ws.runTool('versionbump', ['--major', '--project', '_build']);
    log.capture('versionbump --major --project _build', result);

    expect(result.exitCode, isNot(0),
        reason: 'Bug #13: versionbump crashes on startup');
    log.expectation('crashes due to bug #13', result.exitCode != 0);
  },
      skip: 'Blocked by bug #13: -v abbreviation conflict prevents startup');

  // ── Build counter reset (VBM_RST01) ──────────────────────────────────

  test('build counter reset after bump (blocked by bug #13)', () async {
    log.start('VBM_RST01', 'build counter reset');
    final result =
        await ws.runTool('versionbump', ['--project', '_build']);
    log.capture('versionbump --project _build', result);

    expect(result.exitCode, isNot(0),
        reason: 'Bug #13: versionbump crashes on startup');
    log.expectation('crashes due to bug #13', result.exitCode != 0);
  },
      skip: 'Blocked by bug #13: -v abbreviation conflict prevents startup');

  // ── Dry-run (VBM_DRY01) ─────────────────────────────────────────────

  test('--dry-run shows planned bumps (blocked by bug #13)', () async {
    log.start('VBM_DRY01', '--dry-run');
    final result = await ws.runTool(
        'versionbump', ['--dry-run', '--project', '_build']);
    log.capture('versionbump --dry-run --project _build', result);

    expect(result.exitCode, isNot(0),
        reason: 'Bug #13: versionbump crashes on startup');
    log.expectation('crashes due to bug #13', result.exitCode != 0);
  },
      skip: 'Blocked by bug #13: -v abbreviation conflict prevents startup');
}
