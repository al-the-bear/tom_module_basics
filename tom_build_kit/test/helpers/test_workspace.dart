import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// TestLogger — per-test verbose output and log capture
// ---------------------------------------------------------------------------

/// Captures tool stdout/stderr for the current test and writes verbose
/// status lines (RUNNING / PASSED / FAILED) to the console.
///
/// Usage:
/// ```dart
/// late TestLogger log;
/// setUp(() { log = TestLogger(ws); });
/// tearDown(() { log.finish(); });
///
/// test('my test', () {
///   log.start('EXCL_BN01', 'versioner excludes _build by basename');
///   final result = await ws.runTool('versioner', [...]);
///   log.capture('versioner --list', result);
///   expect(projects, isNot(contains('_build')));
///   log.expectation('_build absent from list', true);
/// });
/// ```
class TestLogger {
  final TestWorkspace _ws;
  String _testId = '';
  String _testName = '';
  final _entries = <String>[];
  bool _failed = false;
  String? _failureReason;

  TestLogger(this._ws);

  /// Mark the beginning of a test. Prints a RUNNING line.
  void start(String testId, String testName) {
    _testId = testId;
    _testName = testName;
    _entries.clear();
    _failed = false;
    _failureReason = null;
    _entries.add('═══ $testId: $testName ═══');
    print('  ▶ RUNNING  $testId: $testName');
  }

  /// Capture the stdout/stderr from a [ProcessResult].
  void capture(String label, ProcessResult result) {
    _entries.add('--- $label (exit ${result.exitCode}) ---');
    final stdout = (result.stdout as String).trim();
    final stderr = (result.stderr as String).trim();
    if (stdout.isNotEmpty) {
      _entries.add('STDOUT:\n$stdout');
    }
    if (stderr.isNotEmpty) {
      _entries.add('STDERR:\n$stderr');
    }
  }

  /// Record an expectation result for the verbose output.
  void expectation(String description, bool passed) {
    final icon = passed ? '✓' : '✗';
    _entries.add('  $icon $description');
    if (!passed) {
      _failed = true;
      _failureReason ??= description;
    }
  }

  /// Call this in tearDown. Prints PASSED/FAILED and writes log on failure.
  ///
  /// If the test threw (the `test` package marks it failed), we detect it
  /// from [Invoker] internals via [_isCurrentTestFailed]. When we can't
  /// detect it reliably, we fall back to our own [_failed] flag.
  void finish() {
    if (_testId.isEmpty) return; // start() was never called

    // Check our own tracking flag (set via expectation())
    final didFail = _failed;

    if (didFail) {
      print('  ✗ FAILED   $_testId: $_testName'
          '${_failureReason != null ? ' — $_failureReason' : ''}');
      _writeLogFile();
    } else {
      print('  ✓ PASSED   $_testId: $_testName');
    }

    // Always write logs to the .test-log/ folder for review
    _writeLogFile(suffix: didFail ? '_FAILED' : '');
  }

  /// Write captured entries to `.test-log/<testId>_log.txt`.
  void _writeLogFile({String suffix = ''}) {
    final logDir = p.join(_ws.buildkitRoot, '.test-log');
    Directory(logDir).createSync(recursive: true);
    final safeName = _testId.replaceAll(RegExp(r'[^\w]'), '_');
    final logFile = File(p.join(logDir, '${safeName}${suffix}_log.txt')); // ignore: unnecessary_brace_in_string_interps
    logFile.writeAsStringSync(
      '${_entries.join('\n')}\n',
      mode: FileMode.write,
    );
  }
}

/// Shared test utilities for buildkit integration tests.
///
/// Manages fixture installation, git revert, and tool process execution
/// against the real workspace.
///
/// ## Workspace Protection
///
/// Integration tests modify real workspace files (config, generated code).
/// This class provides a full safety protocol:
///
/// 1. [requireCleanWorkspace] — fails if uncommitted changes exist
/// 2. [saveHeadRefs] — records HEAD SHAs for main repo + all submodules
/// 3. [revertAll] / [revertSubmodule] — restores files after each test
/// 4. [verifyHeadRefs] — post-test-suite check that no commits leaked
///
/// Tests that use `bk_skip.yaml` markers can check
/// [isSkippedRepo] to avoid git operations on those repos.
class TestWorkspace {
  /// Workspace root (contains bk_master.yaml).
  final String workspaceRoot;

  /// Path to the tom_build_kit project.
  final String buildkitRoot;

  /// Saved HEAD SHA refs for main repo and submodules.
  /// Key: path (workspaceRoot for main), Value: SHA.
  final Map<String, String> _savedHeadRefs = {};

  /// Submodule paths (relative to workspace root).
  List<String>? _submodulePaths;

  TestWorkspace._({required this.workspaceRoot, required this.buildkitRoot});

  /// Discover workspace by walking up from the buildkit project.
  factory TestWorkspace() {
    // Start from the package root (where pubspec.yaml is)
    final buildkitRoot = _findBuildkitRoot();
    final workspaceRoot = _findWorkspaceRoot(buildkitRoot);
    return TestWorkspace._(
      workspaceRoot: workspaceRoot,
      buildkitRoot: buildkitRoot,
    );
  }

  /// Find the buildkit project root (directory with pubspec.yaml).
  static String _findBuildkitRoot() {
    // When running `dart test`, cwd is the package root
    var dir = Directory.current.path;
    while (!File(p.join(dir, 'pubspec.yaml')).existsSync()) {
      final parent = p.dirname(dir);
      if (parent == dir) {
        throw StateError('Could not find buildkit project root');
      }
      dir = parent;
    }
    return dir;
  }

  /// Find workspace root by walking up looking for bk_master.yaml.
  static String _findWorkspaceRoot(String startDir) {
    var dir = startDir;
    while (true) {
      if (File(p.join(dir, 'bk_master.yaml')).existsSync()) {
        return dir;
      }
      final parent = p.dirname(dir);
      if (parent == dir) {
        throw StateError(
          'Could not find workspace root (no bk_master.yaml found '
          'above $startDir)',
        );
      }
      dir = parent;
    }
  }

  // ---------------------------------------------------------------------------
  // Workspace protection protocol
  // ---------------------------------------------------------------------------

  /// Skip file name that marks a repo as excluded from test git operations.
  static const skipFileName = 'bk_skip.yaml';

  /// Fail the test suite if the workspace has uncommitted changes.
  ///
  /// Call this in `setUpAll` before running any integration tests.
  /// Excludes submodule pointer changes in the main repo.
  ///
  /// All diagnostic info is embedded in the `fail()` message so it is
  /// visible regardless of which test reporter is active (expanded, compact,
  /// JSON, VS Code Test Explorer, etc.).
  Future<void> requireCleanWorkspace() async {
    print('    🔍 Checking workspace cleanliness...');
    final dirty = await hasUncommittedChanges();
    if (dirty.isNotEmpty) {
      final fileList = dirty.map((f) => '  $f').join('\n');
      final message = '\n'
          '╔══════════════════════════════════════════════════════╗\n'
          '║  WORKSPACE IS DIRTY — TESTS CANNOT RUN              ║\n'
          '╠══════════════════════════════════════════════════════╣\n'
          '║  Uncommitted changes detected:                      ║\n'
          '╚══════════════════════════════════════════════════════╝\n'
          '$fileList\n'
          '\n'
          'Integration tests require a clean workspace to guarantee\n'
          'safe revert after each test. Commit or stash all changes\n'
          'before running tests.\n';

      // Also write to log file for persistent debugging
      _writeInfraLog('workspace_dirty', message);

      fail(message);
    }
    print('    ✓ Workspace is clean');
  }

  /// Write an infrastructure diagnostic message to `.test-log/`.
  void _writeInfraLog(String name, String content) {
    final logDir = p.join(buildkitRoot, '.test-log');
    Directory(logDir).createSync(recursive: true);
    final logFile = File(p.join(logDir, '${name}_log.txt'));
    logFile.writeAsStringSync(
      '${DateTime.now().toIso8601String()}\n$content\n',
      mode: FileMode.write,
    );
  }

  /// Save HEAD SHA for the main repo and all submodules.
  ///
  /// Call this in `setUpAll` after [requireCleanWorkspace].
  /// Use [verifyHeadRefs] in `tearDownAll` to verify no commits leaked.
  Future<void> saveHeadRefs() async {
    print('    📸 Saving HEAD refs (backup for leak detection)...');
    _savedHeadRefs.clear();

    // Main repo
    final mainHead = await _getHeadSha(workspaceRoot);
    _savedHeadRefs[workspaceRoot] = mainHead;
    print('       main repo: ${mainHead.substring(0, 8)}');

    // Submodules (skip those with skip file)
    final subPaths = await getSubmodulePaths();
    for (final subPath in subPaths) {
      final absPath = p.join(workspaceRoot, subPath);
      if (isSkippedRepo(absPath)) {
        print('       $subPath: SKIPPED (has $skipFileName)');
        continue;
      }
      final sha = await _getHeadSha(absPath);
      _savedHeadRefs[absPath] = sha;
      print('       $subPath: ${sha.substring(0, 8)}');
    }
    print('    ✓ Saved ${_savedHeadRefs.length} HEAD refs');
  }

  /// Verify that HEAD SHAs haven't changed since [saveHeadRefs].
  ///
  /// Call this in `tearDownAll`. Fails the test if any repo has a
  /// different HEAD than the saved reference.
  Future<void> verifyHeadRefs() async {
    print('    🔒 Verifying HEAD refs (leak detection)...');
    if (_savedHeadRefs.isEmpty) {
      print('    ⚠️  No saved HEAD refs to verify. Was saveHeadRefs called?');
      return;
    }

    final mismatches = <String>[];
    for (final entry in _savedHeadRefs.entries) {
      final path = entry.key;
      final savedSha = entry.value;
      final currentSha = await _getHeadSha(path);
      final label = path == workspaceRoot
          ? 'main repo'
          : p.relative(path, from: workspaceRoot);
      if (currentSha != savedSha) {
        print('       ✗ $label: was ${savedSha.substring(0, 8)}, now ${currentSha.substring(0, 8)} — LEAKED!');
        mismatches.add('$label: was $savedSha, now $currentSha');
      } else {
        print('       ✓ $label: ${currentSha.substring(0, 8)} (unchanged)');
      }
    }

    if (mismatches.isNotEmpty) {
      final mismatchList = mismatches.map((m) => '  $m').join('\n');
      final message = '\n'
          '╔══════════════════════════════════════════════════════╗\n'
          '║  HEAD REFS CHANGED — POSSIBLE LEAKED COMMITS        ║\n'
          '╠══════════════════════════════════════════════════════╣\n'
          '║  The following repos have different HEADs than       ║\n'
          '║  before the test run started:                        ║\n'
          '╚══════════════════════════════════════════════════════╝\n'
          '$mismatchList\n'
          '\n'
          'This means a test accidentally created a commit that\n'
          'was not reverted. Investigate and fix manually.\n';

      _writeInfraLog('head_ref_leak', message);
      fail(message);
    }
    print('    ✓ All HEAD refs intact — no leaked commits');
  }

  /// Revert all changes and verify workspace is clean after test suite.
  ///
  /// Convenience method that combines revert + verify for `tearDownAll`.
  Future<void> tearDownProtocol() async {
    print('    🔄 Running tear-down protocol...');
    // Revert main repo
    await revertAll();

    // Revert submodules (skip those with skip file)
    for (final subPath in await getSubmodulePaths()) {
      final absPath = p.join(workspaceRoot, subPath);
      if (isSkippedRepo(absPath)) {
        print('    ⏭️  Skipping submodule $subPath (has $skipFileName)');
        continue;
      }
      await revertSubmodule(absPath);
    }

    // Verify no commits leaked
    await verifyHeadRefs();
    print('    ✓ Tear-down protocol complete');
  }

  /// Check if a directory has a bk_skip.yaml marker.
  ///
  /// Repos with this marker are excluded from test git operations
  /// (no commit check, no checkout revert).
  static bool isSkippedRepo(String dirPath) {
    return File(p.join(dirPath, skipFileName)).existsSync();
  }

  /// Get list of submodule paths (relative to workspace root).
  Future<List<String>> getSubmodulePaths() async {
    if (_submodulePaths != null) return _submodulePaths!;

    final result = await _git(
      ['submodule', 'status'],
      workingDirectory: workspaceRoot,
    );
    final output = result.stdout.toString().trim();
    if (output.isEmpty) {
      _submodulePaths = [];
      return _submodulePaths!;
    }

    // Format: " <sha> <path> (<branch>)" or "+<sha> <path> (<branch>)"
    _submodulePaths = output
        .split('\n')
        .map((line) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) return null;
          // Remove leading +/- and SHA
          final parts = trimmed.split(RegExp(r'\s+'));
          return parts.length >= 2 ? parts[1] : null;
        })
        .whereType<String>()
        .toList();

    return _submodulePaths!;
  }

  /// Get the current HEAD SHA for a git repo.
  Future<String> _getHeadSha(String repoPath) async {
    final result = await _git(
      ['rev-parse', 'HEAD'],
      workingDirectory: repoPath,
    );
    return result.stdout.toString().trim();
  }

  // ---------------------------------------------------------------------------
  // Fixture management
  // ---------------------------------------------------------------------------

  /// Path to the fixtures directory.
  String get fixturesDir => p.join(buildkitRoot, 'test', 'fixtures');

  /// Install a test fixture by copying its bk_master.yaml
  /// into the workspace root, overwriting the real one.
  Future<void> installFixture(String fixtureName) async {
    final src = File(p.join(fixturesDir, fixtureName, 'bk_master.yaml'));
    if (!src.existsSync()) {
      throw StateError('Fixture not found: ${src.path}');
    }
    final dst = File(p.join(workspaceRoot, 'bk_master.yaml'));
    await src.copy(dst.path);
    print('    📋 Installed fixture "$fixtureName" → bk_master.yaml');
  }

  // ---------------------------------------------------------------------------
  // Git revert
  // ---------------------------------------------------------------------------

  /// Revert all changes in the workspace root via `git checkout -- .`
  ///
  /// Note: This only reverts files tracked in the main repo, not in
  /// submodules. For submodule files, use [revertSubmodule].
  Future<void> revertAll() async {
    print('    ↩️  Reverting workspace (git checkout -- .)...');
    await _git(['checkout', '--', '.'], workingDirectory: workspaceRoot);
    print('    ✓ Workspace reverted');
  }

  /// Revert all changes in a submodule directory.
  Future<void> revertSubmodule(String submodulePath) async {
    final absPath = p.isAbsolute(submodulePath)
        ? submodulePath
        : p.join(workspaceRoot, submodulePath);
    final label = p.relative(absPath, from: workspaceRoot);
    print('    ↩️  Reverting submodule $label...');
    await _git(['checkout', '--', '.'], workingDirectory: absPath);
    print('    ✓ Submodule $label reverted');
  }

  /// Revert specific files (paths relative to workspace root).
  Future<void> revertFiles(List<String> relativePaths) async {
    await _git(
      ['checkout', '--', ...relativePaths],
      workingDirectory: workspaceRoot,
    );
  }

  /// Check if there are uncommitted changes for specific files.
  Future<bool> hasChanges(List<String> relativePaths) async {
    final result = await _git(
      ['diff', '--name-only', '--', ...relativePaths],
      workingDirectory: workspaceRoot,
    );
    return result.stdout.toString().trim().isNotEmpty;
  }

  /// Check if the workspace has any uncommitted changes (staged or unstaged)
  /// that could affect test results.
  ///
  /// Returns a list of changed file paths, or empty if clean.
  /// Excludes submodule pointer changes (xternal/) since those don't affect
  /// the test fixtures or tool behavior.
  Future<List<String>> hasUncommittedChanges() async {
    final result = await _git(
      ['status', '--porcelain'],
      workingDirectory: workspaceRoot,
    );
    final output = result.stdout.toString().trim();
    if (output.isEmpty) return [];
    return output
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        // Exclude submodule pointer changes — they don't affect tests
        .where((line) => !RegExp(r'^\s*M\s+xternal/').hasMatch(line))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Tool execution
  // ---------------------------------------------------------------------------

  /// Run a standalone buildkit tool (e.g., 'versioner', 'cleanup').
  ///
  /// Executes the tool binary directly via `dart run <path/to/bin/tool.dart>`.
  /// Runs from the workspace root so that path validation passes and
  /// workspace root discovery works correctly.
  Future<ProcessResult> runTool(
    String tool,
    List<String> args, {
    String? workingDirectory,
  }) async {
    final binPath = p.join(buildkitRoot, 'bin', '$tool.dart');
    print('    🔧 Running: $tool ${args.join(' ')}');
    final result = await Process.run(
      'dart',
      ['run', binPath, ...args],
      workingDirectory: workingDirectory ?? workspaceRoot,
    );
    print('    ✓ $tool exited with code ${result.exitCode}');
    return result;
  }

  /// Run a buildkit pipeline.
  ///
  /// Executes: `dart run <path/to/bin/buildkit.dart> <pipeline> <args>`
  /// Runs from the workspace root.
  Future<ProcessResult> runPipeline(
    String pipeline,
    List<String> args, {
    String? workingDirectory,
  }) async {
    final binPath = p.join(buildkitRoot, 'bin', 'buildkit.dart');
    print('    🔧 Running pipeline: buildkit $pipeline ${args.join(' ')}');
    final result = await Process.run(
      'dart',
      ['run', binPath, pipeline, ...args],
      workingDirectory: workingDirectory ?? workspaceRoot,
    );
    print('    ✓ buildkit $pipeline exited with code ${result.exitCode}');
    return result;
  }

  // ---------------------------------------------------------------------------
  // File helpers
  // ---------------------------------------------------------------------------

  /// Read a file relative to the workspace root.
  String readWorkspaceFile(String relativePath) {
    return File(p.join(workspaceRoot, relativePath)).readAsStringSync();
  }

  /// Check if a file exists relative to the workspace root.
  bool workspaceFileExists(String relativePath) {
    return File(p.join(workspaceRoot, relativePath)).existsSync();
  }

  /// Get the relative path from workspace root to a project.
  String relativeProjectPath(String projectAbsolutePath) {
    return p.relative(projectAbsolutePath, from: workspaceRoot);
  }

  /// Place a temporary `bk_skip.yaml` in a directory.
  ///
  /// Returns the absolute path to the created file. Use [removeSkipFile]
  /// or add the returned path to a cleanup list for tearDown.
  String placeSkipFile(String relativeDir) {
    final absPath =
        p.join(workspaceRoot, relativeDir, TestWorkspace.skipFileName);
    File(absPath).writeAsStringSync(
      '# Temporary skip file placed by integration test.\n'
      '# Should be removed automatically in tearDown.\n',
    );
    print('    📄 Placed skip file: $relativeDir/$skipFileName');
    return absPath;
  }

  /// Remove a temporary `tom_build_skip.yaml` from a directory.
  void removeSkipFile(String relativeDir) {
    final absPath =
        p.join(workspaceRoot, relativeDir, TestWorkspace.skipFileName);
    final file = File(absPath);
    if (file.existsSync()) {
      file.deleteSync();
      print('    🗑️  Removed skip file: $relativeDir/$skipFileName');
    }
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  Future<ProcessResult> _git(
    List<String> args, {
    required String workingDirectory,
  }) async {
    return Process.run('git', args, workingDirectory: workingDirectory);
  }
}
