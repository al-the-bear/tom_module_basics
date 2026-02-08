import 'dart:io';

import 'package:path/path.dart' as p;

/// Shared test utilities for buildkit integration tests.
///
/// Manages fixture installation, git revert, and tool process execution
/// against the real workspace.
class TestWorkspace {
  /// Workspace root (contains tom_build_master.yaml).
  final String workspaceRoot;

  /// Path to the tom_build_kit project.
  final String buildkitRoot;

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
