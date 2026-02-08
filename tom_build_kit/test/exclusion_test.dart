@TestOn('!browser')
@Timeout(Duration(seconds: 180))
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'helpers/test_workspace.dart';

/// Integration tests for project exclusion features.
///
/// Tests cover:
/// - `--exclude-projects` with basename patterns (e.g. `_build`)
/// - `--exclude-projects` with path patterns (e.g. `core/*`)
/// - `tom_build_skip.yaml` marker file exclusion
/// - All 6 standalone tools + buildkit
///
/// These tests use `--scan . --recursive --list` to discover projects,
/// then verify that exclusion filters remove expected entries from stdout.
void main() {
  late TestWorkspace ws;

  /// Temporary skip files placed during tests (cleaned up in tearDown).
  final tempSkipFiles = <String>[];

  setUpAll(() async {
    ws = TestWorkspace();
    print('Workspace root:  ${ws.workspaceRoot}');
    print('Buildkit root:   ${ws.buildkitRoot}');

    // Full workspace protection protocol
    await ws.requireCleanWorkspace();
    await ws.saveHeadRefs();
  });

  setUp(() async {
    // Install the exclusion test fixture
    await ws.installFixture('exclusion');
  });

  tearDown(() async {
    // Remove any temporary skip files placed during this test
    for (final skipFilePath in tempSkipFiles) {
      final file = File(skipFilePath);
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
    tempSkipFiles.clear();

    // Revert all changes in the main repo (fixture, etc.)
    await ws.revertAll();
  });

  tearDownAll(() async {
    // Verify no commits leaked during the test run
    await ws.verifyHeadRefs();
  });

  // ---------------------------------------------------------------------------
  // Helper: run a tool with --scan . --recursive --list and return stdout
  // ---------------------------------------------------------------------------

  /// Runs a standalone tool with `--scan . --recursive --list` plus any
  /// additional args. Returns stdout as a String.
  Future<String> runToolList(
    String tool, {
    List<String> extraArgs = const [],
  }) async {
    final result = await ws.runTool(
      tool,
      ['--scan', '.', '--recursive', '--list', ...extraArgs],
    );
    if (result.exitCode != 0) {
      print('STDERR ($tool):\n${result.stderr}');
    }
    expect(result.exitCode, 0, reason: '$tool --list should exit with 0');
    return result.stdout as String;
  }

  /// Parse project paths from --list output.
  ///
  /// The format is two-space indent per project line.
  List<String> parseListOutput(String stdout) {
    return stdout
        .split('\n')
        .where((line) => line.startsWith('  ') && line.trim().isNotEmpty)
        .map((line) => line.trim())
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Group: --exclude-projects with basename patterns
  // ---------------------------------------------------------------------------

  group('--exclude-projects basename patterns', () {
    test('versioner excludes _build by basename', () async {
      final stdout = await runToolList('versioner',
          extraArgs: ['--exclude-projects', '_build']);
      final projects = parseListOutput(stdout);
      expect(projects, isNot(contains('_build')),
          reason: '_build should be excluded by --exclude-projects');
      // Should still have other versioner projects
      expect(projects.isNotEmpty, isTrue,
          reason: 'Other versioner projects should remain');
    });

    test('cleanup excludes _build by basename', () async {
      final stdout = await runToolList('cleanup',
          extraArgs: ['--exclude-projects', '_build']);
      final projects = parseListOutput(stdout);
      expect(projects, isNot(contains('_build')));
      expect(projects.isNotEmpty, isTrue);
    });

    test('compiler excludes _build by basename', () async {
      final stdout = await runToolList('compiler',
          extraArgs: ['--exclude-projects', '_build']);
      final projects = parseListOutput(stdout);
      expect(projects, isNot(contains('_build')));
      expect(projects.isNotEmpty, isTrue);
    });

    test('dependencies excludes _build by basename', () async {
      final stdout = await runToolList('dependencies',
          extraArgs: ['--exclude-projects', '_build']);
      final projects = parseListOutput(stdout);
      expect(projects, isNot(contains('_build')));
      expect(projects.isNotEmpty, isTrue);
    });

    test('runner excludes devops/tom_build_cli by basename', () async {
      final stdout = await runToolList('runner',
          extraArgs: ['--exclude-projects', 'tom_build_cli']);
      final projects = parseListOutput(stdout);
      // No project should match basename tom_build_cli
      for (final proj in projects) {
        expect(p.basename(proj), isNot(equals('tom_build_cli')),
            reason: 'tom_build_cli should be excluded');
      }
      expect(projects.isNotEmpty, isTrue);
    });

    // BUG: VersionBump has a -v abbreviation conflict (issues.md #13)
    // that prevents the tool from starting. Test documents the crash.
    test('versionbump crashes due to -v conflict (known bug #13)', () async {
      final result = await ws.runTool(
        'versionbump',
        ['--scan', '.', '--recursive', '--list',
         '--exclude-projects', '_build'],
      );
      // BUG: Tool crashes before processing any args
      expect(result.exitCode, 255,
          reason: 'BUG #13: versionbump crashes due to -v abbreviation conflict');
      expect(result.stderr as String, contains('Abbreviation "v" is already used'));
    });

    test('glob pattern excludes multiple projects', () async {
      final stdout = await runToolList('dependencies',
          extraArgs: ['--exclude-projects', 'tom_core_*']);
      final projects = parseListOutput(stdout);
      for (final proj in projects) {
        expect(p.basename(proj), isNot(startsWith('tom_core_')),
            reason: 'All tom_core_* projects should be excluded');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Group: --exclude-projects with path patterns
  // ---------------------------------------------------------------------------

  group('--exclude-projects path patterns', () {
    test('path pattern excludes core/* projects', () async {
      final stdout = await runToolList('dependencies',
          extraArgs: ['--exclude-projects', 'core/*']);
      final projects = parseListOutput(stdout);
      for (final proj in projects) {
        expect(proj, isNot(startsWith('core/')),
            reason: 'All core/ projects should be excluded by path pattern');
      }
      expect(projects.isNotEmpty, isTrue);
    });

    test('path pattern excludes devops/** from runner', () async {
      final stdout = await runToolList('runner',
          extraArgs: ['--exclude-projects', 'devops/**']);
      final projects = parseListOutput(stdout);
      for (final proj in projects) {
        expect(proj, isNot(startsWith('devops/')),
            reason: 'devops/ projects should be excluded');
      }
    });

    test('** glob matches nested paths in dependencies', () async {
      final stdout = await runToolList('dependencies',
          extraArgs: ['--exclude-projects', '**/tom_core_*']);
      final projects = parseListOutput(stdout);
      for (final proj in projects) {
        expect(p.basename(proj), isNot(startsWith('tom_core_')),
            reason: '** pattern should match tom_core_* at any depth');
      }
    });

    test('combined basename + path patterns', () async {
      final stdout = await runToolList(
        'dependencies',
        extraArgs: [
          '--exclude-projects', '_build',
          '--exclude-projects', 'core/*',
        ],
      );
      final projects = parseListOutput(stdout);
      expect(projects, isNot(contains('_build')),
          reason: '_build excluded by basename');
      for (final proj in projects) {
        expect(proj, isNot(startsWith('core/')),
            reason: 'core/* excluded by path');
      }
      expect(projects.isNotEmpty, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Group: tom_build_skip.yaml marker file
  // ---------------------------------------------------------------------------

  group('tom_build_skip.yaml marker file', () {
    test('skip file excludes project from versioner', () async {
      // Place a temporary skip file in _build
      tempSkipFiles.add(ws.placeSkipFile('_build'));

      final stdout = await runToolList('versioner');
      final projects = parseListOutput(stdout);
      expect(projects, isNot(contains('_build')),
          reason: '_build with skip file should be excluded');
    });

    test('skip file excludes project from cleanup', () async {
      tempSkipFiles.add(ws.placeSkipFile('_build'));

      final stdout = await runToolList('cleanup');
      final projects = parseListOutput(stdout);
      expect(projects, isNot(contains('_build')));
    });

    test('skip file excludes project from compiler', () async {
      tempSkipFiles.add(ws.placeSkipFile('_build'));

      final stdout = await runToolList('compiler');
      final projects = parseListOutput(stdout);
      expect(projects, isNot(contains('_build')));
    });

    test('skip file excludes project from dependencies', () async {
      tempSkipFiles.add(ws.placeSkipFile('_build'));

      final stdout = await runToolList('dependencies');
      final projects = parseListOutput(stdout);
      expect(projects, isNot(contains('_build')));
    });

    test('skip file excludes project from runner', () async {
      // Place skip file in a project that has build.yaml
      tempSkipFiles.add(ws.placeSkipFile('devops/tom_build_cli'));

      final stdout = await runToolList('runner');
      final projects = parseListOutput(stdout);
      for (final proj in projects) {
        expect(proj, isNot(equals('devops/tom_build_cli')),
            reason: 'tom_build_cli with skip file should be excluded');
      }
    });

    // BUG: VersionBump -v abbreviation conflict (issues.md #13)
    test('versionbump skip file crashes due to -v conflict (known bug #13)',
        () async {
      tempSkipFiles.add(ws.placeSkipFile('_build'));

      final result = await ws.runTool(
        'versionbump',
        ['--scan', '.', '--recursive', '--list'],
      );
      expect(result.exitCode, 255,
          reason: 'BUG #13: versionbump crashes due to -v abbreviation conflict');
    });

    test('skip file in parent excludes all children', () async {
      // Place skip file in core/ — should exclude core/tom_core_kernel, etc.
      tempSkipFiles.add(ws.placeSkipFile('core'));

      final stdout = await runToolList('dependencies');
      final projects = parseListOutput(stdout);
      for (final proj in projects) {
        expect(proj, isNot(startsWith('core/')),
            reason: 'All core/ children should be excluded by parent skip file');
      }
    });

    test('skip file is cleaned up in tearDown', () async {
      // This test verifies our own cleanup mechanism
      final skipPath = ws.placeSkipFile('_build');
      tempSkipFiles.add(skipPath);

      expect(File(skipPath).existsSync(), isTrue,
          reason: 'Skip file should exist after placement');

      // The actual cleanup happens in tearDown — just verify it was placed
    });
  });

  // ---------------------------------------------------------------------------
  // Group: buildkit --exclude-projects
  // ---------------------------------------------------------------------------

  group('buildkit --exclude-projects', () {
    test('buildkit excludes _build by basename', () async {
      // buildkit runs per-project, so we verify _build never appears
      // in the output when excluded. Use --scan with a small scope.
      final result = await ws.runTool(
        'buildkit',
        [
          '--scan', '.', '--recursive', '--verbose',
          '--exclude-projects', '_build',
          ':versioner', '--list',
        ],
      );
      final stdout = result.stdout as String;
      // In verbose mode, buildkit lists discovered projects with "  - "
      // The excluded project should never appear
      expect(stdout, isNot(contains('/_build')),
          reason: '_build should not appear when excluded by basename');
    });

    test('buildkit excludes by path pattern', () async {
      final result = await ws.runTool(
        'buildkit',
        [
          '--scan', '.', '--recursive', '--verbose',
          '--exclude-projects', 'core/*',
          ':versioner', '--list',
        ],
      );
      final stdout = result.stdout as String;
      // core/ projects should not appear
      expect(stdout, isNot(contains('/core/tom_core_')),
          reason: 'core/ projects should not appear when excluded by path');
    });

    test('buildkit respects tom_build_skip.yaml', () async {
      tempSkipFiles.add(ws.placeSkipFile('_build'));

      final result = await ws.runTool(
        'buildkit',
        [
          '--scan', '.', '--recursive', '--verbose',
          ':versioner', '--list',
        ],
      );
      final stdout = result.stdout as String;
      // Verbose mode lists discovered projects with "  - <relative-path>"
      // The skip message itself will contain the project name, so we check
      // that _build does not appear in the project listing lines.
      final projectLines = stdout
          .split('\n')
          .where((line) => line.startsWith('  - '))
          .toList();
      for (final line in projectLines) {
        expect(line, isNot(contains('_build')),
            reason:
                '_build with skip file should not appear in project listing');
      }
      // Verify the skip message IS present (proves the feature is active)
      expect(stdout, contains('Skipping (tom_build_skip.yaml)'),
          reason: 'Should log skip message for _build in verbose mode');
    });
  });

  // ---------------------------------------------------------------------------
  // Group: exclude-projects from master YAML
  // ---------------------------------------------------------------------------

  group('master YAML exclude-projects', () {
    test('master YAML exclude-projects filters projects', () async {
      // Write a custom fixture with exclude-projects in navigation
      final masterPath =
          p.join(ws.workspaceRoot, 'tom_build_master.yaml');
      File(masterPath).writeAsStringSync('''
navigation:
  exclude:
    - 'xternal_apps/**'
    - 'cloud/**'
    - 'sqm/**'
    - 'uam/**'
    - 'ai_build/**'
    - 'zom_workspaces/**'
  exclude-projects:
    - '_build'

versioner:
  variable-prefix: testDefault
''');

      final stdout = await runToolList('dependencies');
      final projects = parseListOutput(stdout);
      expect(projects, isNot(contains('_build')),
          reason: '_build should be excluded by master YAML exclude-projects');
      expect(projects.isNotEmpty, isTrue);
    });

    test('master YAML path pattern exclude-projects', () async {
      final masterPath =
          p.join(ws.workspaceRoot, 'tom_build_master.yaml');
      File(masterPath).writeAsStringSync('''
navigation:
  exclude:
    - 'xternal_apps/**'
    - 'cloud/**'
    - 'sqm/**'
    - 'uam/**'
    - 'ai_build/**'
    - 'zom_workspaces/**'
  exclude-projects:
    - 'core/*'

versioner:
  variable-prefix: testDefault
''');

      final stdout = await runToolList('dependencies');
      final projects = parseListOutput(stdout);
      for (final proj in projects) {
        expect(proj, isNot(startsWith('core/')),
            reason: 'core/ excluded by master YAML path pattern');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Group: baseline (no exclusion) — verify projects are found without filters
  // ---------------------------------------------------------------------------

  group('baseline (no exclusion)', () {
    test('versioner finds _build without exclusions', () async {
      final stdout = await runToolList('versioner');
      final projects = parseListOutput(stdout);
      expect(projects, contains('_build'),
          reason: '_build should be found when no exclusions applied');
    });

    test('dependencies finds core projects without exclusions', () async {
      final stdout = await runToolList('dependencies');
      final projects = parseListOutput(stdout);
      final coreProjects =
          projects.where((p) => p.startsWith('core/')).toList();
      expect(coreProjects, isNotEmpty,
          reason: 'core/ projects should be found when no exclusions applied');
    });

    test('runner finds projects without exclusions', () async {
      final stdout = await runToolList('runner');
      final projects = parseListOutput(stdout);
      expect(projects.isNotEmpty, isTrue,
          reason: 'Runner should find projects with build.yaml');
    });
  });
}
