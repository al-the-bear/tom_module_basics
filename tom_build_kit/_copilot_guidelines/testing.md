# Tom Build Kit — Testing Guidelines

## Test Strategy: Workspace Integration Tests

Buildkit tests are **integration tests** that run against the **real workspace**. They exercise the actual CLI tools by spawning them as child processes, then verify outcomes through file system checks and git diffs.

### Core Mechanism

1. **Replace** `tom_build_master.yaml` at the workspace root with a test-specific fixture
2. **Run** the buildkit command via `Process.run('dart', ['run', 'tom_build_kit:<tool>', ...])`
3. **Verify** results: exit code, stdout/stderr output, generated/modified files
4. **Revert** all changes via `git checkout` (both `tom_build_master.yaml` and any project files)

Since `tom_build_master.yaml` is tracked by git, no backup/rename is needed — `git checkout` restores it after each test.

### Directory Layout

```
tom_build_kit/
  test/
    helpers/
      test_workspace.dart      # Shared utilities: fixture swap, git revert, process runner
    fixtures/
      versioner/
        tom_build_master.yaml   # Minimal master config for versioner tests
      cleanup/
        tom_build_master.yaml   # Minimal master config for cleanup tests
      pipeline/
        tom_build_master.yaml   # Pipeline-specific configs
    versioner_test.dart         # Versioner tool integration tests
    cleanup_test.dart           # Cleanup tool integration tests
    pipeline_test.dart          # Buildkit pipeline integration tests
```

### Fixture Design Principles

- Each fixture `tom_build_master.yaml` targets **1–2 small projects** (e.g., `tom_build_kit` itself, `tom_d4rt_astgen`) to keep tests fast
- Fixtures define only the **minimum config** needed for the specific test
- The `navigation:` section in fixtures uses explicit `exclude:` patterns to limit scope

### Test Helper Pattern

The shared `TestWorkspace` helper provides:

```dart
class TestWorkspace {
  /// Path to the workspace root (found by walking up from buildkit dir)
  final String workspaceRoot;

  /// Path to the tom_build_kit project
  final String buildkitRoot;

  /// Copy a fixture tom_build_master.yaml into the workspace root
  Future<void> installFixture(String fixturePath);

  /// Revert all git changes in workspace root (tom_build_master.yaml + generated files)
  Future<void> revertAll();

  /// Revert specific files via git checkout
  Future<void> revertFiles(List<String> relativePaths);

  /// Run a buildkit tool as a child process
  Future<ProcessResult> runTool(String tool, List<String> args, {String? workingDirectory});

  /// Run buildkit with a pipeline
  Future<ProcessResult> runPipeline(String pipeline, List<String> args, {String? workingDirectory});
}
```

### Git Revert Strategy

After each test (in `tearDown`):
1. `git checkout -- tom_build_master.yaml` — restore workspace config
2. `git checkout -- <project>/lib/src/version.g.dart` — restore generated files
3. `git checkout -- <project>/tom_build_state.json` — restore build state

For broader reverts: `git checkout -- .` from workspace root (use sparingly).

### Key Considerations

- **Working directory matters**: Tools discover the workspace root by walking up from `cwd`. Set `workingDirectory` on `Process.run` appropriately.
- **Build state**: The versioner writes `tom_build_state.json` (build number). Always revert this.
- **No mocking**: These are true integration tests — they exercise the real tool chain.
- **Test isolation**: Each test gets a fresh fixture and clean git state. Tests must not depend on execution order.
- **Process timeout**: Set reasonable timeouts (30–60s) since `dart run` has startup overhead.

### Commands to Test

| Tool | Key Behaviors | Verification |
|------|--------------|--------------|
| `versioner` | Generates `version.g.dart` with correct prefix, version, git hash | File contents, variable names |
| `cleanup` | Deletes files matching glob patterns | File absence after run |
| `compiler` | Invokes `dart compile` per config | Exit code, `--list` output |
| `runner` | Wraps `build_runner` | Exit code, `--list` output |
| `dependencies` | Shows dependency tree | Stdout output |
| `versionbump` | Bumps version in pubspec.yaml | File contents |
| `buildkit` (pipelines) | Executes steps in order | Combined tool outputs, exit code |

### Running Tests

```bash
cd xternal/tom_module_basics/tom_build_kit
dart test
```

Tests should also be runnable individually:

```bash
dart test test/versioner_test.dart
```
