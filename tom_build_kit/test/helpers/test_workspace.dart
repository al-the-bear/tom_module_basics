import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

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
/// Tests that use `tom_build_skip.yaml` markers can check
/// [isSkippedRepo] to avoid git operations on those repos.
class TestWorkspace {
  /// Workspace root (contains tom_build_master.yaml).
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

  /// Find workspace root by walking up looking for tom_build_master.yaml.
  static String _findWorkspaceRoot(String startDir) {
    var dir = startDir;
    while (true) {
      if (File(p.join(dir, 'tom_build_master.yaml')).existsSync()) {
        return dir;
      }
      final parent = p.dirname(dir);
      if (parent == dir) {
        throw StateError(
          'Could not find workspace root (no tom_build_master.yaml found '
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
  static const skipFileName = 'tom_build_skip.yaml';

  /// Fail the test suite if the workspace has uncommitted changes.
  ///
  /// Call this in `setUpAll` before running any integration tests.
  /// Excludes submodule pointer changes in the main repo.
  Future<void> requireCleanWorkspace() async {
    final dirty = await hasUncommittedChanges();
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
  }

  /// Save HEAD SHA for the main repo and all submodules.
  ///
  /// Call this in `setUpAll` after [requireCleanWorkspace].
  /// Use [verifyHeadRefs] in `tearDownAll` to verify no commits leaked.
  Future<void> saveHeadRefs() async {
    _savedHeadRefs.clear();

    // Main repo
    final mainHead = await _getHeadSha(workspaceRoot);
    _savedHeadRefs[workspaceRoot] = mainHead;

    // Submodules (skip those with skip file)
    for (final subPath in await getSubmodulePaths()) {
      final absPath = p.join(workspaceRoot, subPath);
      if (isSkippedRepo(absPath)) continue;
      final sha = await _getHeadSha(absPath);
      _savedHeadRefs[absPath] = sha;
    }
  }

  /// Verify that HEAD SHAs haven't changed since [saveHeadRefs].
  ///
  /// Call this in `tearDownAll`. Fails the test if any repo has a
  /// different HEAD than the saved reference.
  Future<void> verifyHeadRefs() async {
    if (_savedHeadRefs.isEmpty) {
      print('WARNING: No saved HEAD refs to verify. Was saveHeadRefs called?');
      return;
    }

    final mismatches = <String>[];
    for (final entry in _savedHeadRefs.entries) {
      final path = entry.key;
      final savedSha = entry.value;
      final currentSha = await _getHeadSha(path);
      if (currentSha != savedSha) {
        final label = path == workspaceRoot
            ? 'main repo'
            : p.relative(path, from: workspaceRoot);
        mismatches.add('$label: was $savedSha, now $currentSha');
      }
    }

    if (mismatches.isNotEmpty) {
      fail(
        'HEAD refs changed during test run (possible leaked commits):\n'
        '  ${mismatches.join('\n  ')}',
      );
    }
  }

  /// Revert all changes and verify workspace is clean after test suite.
  ///
  /// Convenience method that combines revert + verify for `tearDownAll`.
  Future<void> tearDownProtocol() async {
    // Revert main repo
    await revertAll();

    // Revert submodules (skip those with skip file)
    for (final subPath in await getSubmodulePaths()) {
      final absPath = p.join(workspaceRoot, subPath);
      if (isSkippedRepo(absPath)) continue;
      await revertSubmodule(absPath);
    }

    // Verify no commits leaked
    await verifyHeadRefs();
  }

  /// Check if a directory has a tom_build_skip.yaml marker.
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

  /// Install a test fixture by copying its tom_build_master.yaml
  /// into the workspace root, overwriting the real one.
  Future<void> installFixture(String fixtureName) async {
    final src = File(p.join(fixturesDir, fixtureName, 'tom_build_master.yaml'));
    if (!src.existsSync()) {
      throw StateError('Fixture not found: ${src.path}');
    }
    final dst = File(p.join(workspaceRoot, 'tom_build_master.yaml'));
    await src.copy(dst.path);
  }

  // ---------------------------------------------------------------------------
  // Git revert
  // ---------------------------------------------------------------------------

  /// Revert all changes in the workspace root via `git checkout -- .`
  ///
  /// Note: This only reverts files tracked in the main repo, not in
  /// submodules. For submodule files, use [revertSubmodule].
  Future<void> revertAll() async {
    await _git(['checkout', '--', '.'], workingDirectory: workspaceRoot);
  }

  /// Revert all changes in a submodule directory.
  Future<void> revertSubmodule(String submodulePath) async {
    final absPath = p.isAbsolute(submodulePath)
        ? submodulePath
        : p.join(workspaceRoot, submodulePath);
    await _git(['checkout', '--', '.'], workingDirectory: absPath);
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
    return Process.run(
      'dart',
      ['run', binPath, ...args],
      workingDirectory: workingDirectory ?? workspaceRoot,
    );
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
    return Process.run(
      'dart',
      ['run', binPath, pipeline, ...args],
      workingDirectory: workingDirectory ?? workspaceRoot,
    );
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
