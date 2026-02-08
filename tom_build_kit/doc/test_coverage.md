# Tom Build Kit — Test Coverage Plan

This document lists all testable features across buildkit tools and tracks test implementation status.

For the testing strategy, safety protocol, and test infrastructure, see [_copilot_guidelines/testing.md](../_copilot_guidelines/testing.md).

## Status Legend

- ✅ Test implemented and passing
- 🐛 Test implemented, documents a known bug
- ⬜ Test not yet implemented

---

## Overview

| # | Feature Area | Tests | Status | Test File | Details |
|---|-------------|-------|--------|-----------|---------|
| 1 | [ToolBase — Shared Infrastructure](#1-toolbase--shared-infrastructure) | 14 | ⬜ | `toolbase_test.dart` | [→](#1-toolbase--shared-infrastructure) |
| 2 | [Versioner — Version File Generation](#2-versioner--version-file-generation) | 7 | 5✅ 2🐛 | `versioner_test.dart` | [→](#2-versioner--version-file-generation) |
| 3 | [Cleanup — File Deletion](#3-cleanup--file-deletion) | 8 | ⬜ | `cleanup_test.dart` | [→](#3-cleanup--file-deletion) |
| 4 | [Compiler — Cross-Platform Compilation](#4-compiler--cross-platform-compilation) | 6 | ⬜ | `compiler_test.dart` | [→](#4-compiler--cross-platform-compilation) |
| 5 | [Runner — Build Runner Wrapper](#5-runner--build-runner-wrapper) | 5 | ⬜ | `runner_test.dart` | [→](#5-runner--build-runner-wrapper) |
| 6 | [Dependencies — Dependency Tree](#6-dependencies--dependency-tree) | 4 | ⬜ | `dependencies_test.dart` | [→](#6-dependencies--dependency-tree) |
| 7 | [VersionBump — Version Bumping](#7-versionbump--version-bumping) | 5 | ⬜ | `versionbump_test.dart` | [→](#7-versionbump--version-bumping) |
| 8 | [BuildKit — Pipeline Orchestrator](#8-buildkit--pipeline-orchestrator) | 9 | ⬜ | `buildkit_test.dart` | [→](#8-buildkit--pipeline-orchestrator) |
| 9 | [Config Merge — Merge Precedence](#9-config-merge--merge-precedence) | 4 | ⬜ | `config_merge_test.dart` | [→](#9-config-merge--merge-precedence) |
| 10 | [Security — Path & Command Validation](#10-security--path--command-validation) | 4 | ⬜ | `security_test.dart` | [→](#10-security--path--command-validation) |
| — | **Total** | **66** | **5✅ 2🐛 59⬜** | | |

---

## 1. ToolBase — Shared Infrastructure

**Test file:** `test/toolbase_test.dart`

These features are shared by all tools. Test via any tool (e.g., versioner or dependencies) since they all inherit from `ToolBase`.

| # | Feature | Status | How to Test |
|---|---------|--------|-------------|
| 1.1 | Version argument (`version`, `--version`, `-version`) | ⬜ | Run tool with `version` as first arg. Verify stdout contains tool name and version string. |
| 1.2 | `--help` flag | ⬜ | Run tool with `--help`. Verify exit code 0 and stdout contains usage text. |
| 1.3 | `--list` with `--scan` and `--recursive` | ⬜ | Run versioner `--scan . --recursive --list`. Verify output lists discovered projects. |
| 1.4 | `--exclude` glob filtering | ⬜ | Run versioner `--scan . -r --list --exclude 'zom_*'`. Verify no `zom_` projects in output. |
| 1.5 | `--recursion-exclude` during scanning | ⬜ | Run with `--recursion-exclude node_modules`. Verify node_modules subdirs not scanned. |
| 1.6 | Workspace root discovery | ⬜ | Run tool from workspace root vs from a subdirectory. Both should find `tom_build_master.yaml`. |
| 1.7 | `--exclude-projects` folder name filtering | ⬜ | Run versioner `--scan . -r --list --exclude-projects 'tom_d4rt*'`. Verify no `tom_d4rt*` folders in output. |
| 1.8 | `--exclude-projects` from master YAML | ⬜ | Set `exclude-projects: ['tom_test_*']` in master YAML navigation. Run `--list`. Verify excluded. |
| 1.9 | `tom_build_skip.yaml` skips directory | ⬜ | Place `tom_build_skip.yaml` in a project dir. Run `--list`. Verify project excluded. |
| 1.10 | `tom_build_skip.yaml` skips subdirectories | ⬜ | Place skip file in parent dir. Run `--scan` recursively. Verify no children found. |
| 1.11 | `--exclude-projects` with relative path pattern | ⬜ | Run versioner `--scan . -r --list --exclude-projects 'xternal/tom_module_basics/*'`. Verify all projects under that submodule excluded. |
| 1.12 | `--exclude-projects` with `**` glob path pattern | ⬜ | Run versioner `--scan . -r --list --exclude-projects '**/tom_module_basics/*'`. Verify same exclusion regardless of leading path. |
| 1.13 | `--exclude-projects` combined basename + path patterns | ⬜ | Run versioner `--scan . -r --list --exclude-projects 'zom_*' --exclude-projects 'xternal/tom_module_basics/*'`. Verify both pattern types applied. |
| 1.14 | `--exclude-projects` pattern auto-detection | ⬜ | Verify patterns without `/` or `**` match basename only (e.g. `tom_basics` excludes `tom_basics` but not `xternal/tom_module_basics/tom_basics`). Verify patterns with `/` match workspace-relative path. |

---

## 2. Versioner — Version File Generation

**Test file:** `test/versioner_test.dart`

Target project: `_build` (main repo, has `variable-prefix: tomTools` in its `tom_build.yaml`).

| # | Feature | Status | How to Test |
|---|---------|--------|-------------|
| 2.1 | Generates `version.g.dart` with correct class name | ✅ | Run versioner `--project _build`. Verify file contains `class TomToolsVersionInfo`. |
| 2.2 | `--no-git` omits git commit field | 🐛 | Run with `--no-git`. Verify `gitCommit` absent. **BUG:** Project config overrides CLI. See issues.md #12. |
| 2.3 | `--list` shows matching projects | ✅ | Run with `--list`. Verify `_build` appears in output. |
| 2.4 | `--show` displays project config | ✅ | Run with `--show`. Verify `variable-prefix` and `tomTools` appear. |
| 2.5 | `--version` overrides pubspec version | ✅ | Run with `--version 9.9.9`. Verify `version = '9.9.9'` in output. |
| 2.6 | `--variable-prefix` overrides project config | 🐛 | Run with `--variable-prefix myCustom`. Verify class name. **BUG:** Project config overrides CLI. See issues.md #12. |
| 2.7 | Build number increments on each run | ✅ | Run versioner twice. Extract `buildNumber` from each. Verify second = first + 1. |

---

## 3. Cleanup — File Deletion

**Test file:** `test/cleanup_test.dart`

Target project: `_build` (has cleanup config) or a test project.

| # | Feature | Status | How to Test |
|---|---------|--------|-------------|
| 3.1 | Deletes files matching glob patterns | ⬜ | Create temp `.g.dart` files in target project. Run cleanup. Verify files deleted. |
| 3.2 | `--dry-run` lists files without deleting | ⬜ | Create temp files. Run with `--dry-run`. Verify files still exist and stdout lists them. |
| 3.3 | `excludes` patterns prevent deletion | ⬜ | Create a `version.g.dart` file. Configure exclude for it. Run cleanup. Verify it survives. |
| 3.4 | Protected folders are never deleted | ⬜ | Attempt cleanup on directory containing `.git` or `.github`. Verify those are untouched. |
| 3.5 | `--max-files` safety limit triggers abort | ⬜ | Create >100 matching files. Run without `--force`. Verify exit code != 0 and files remain. |
| 3.6 | `--force` skips safety limit | ⬜ | Create >100 matching files. Run with `--force`. Verify deletion proceeds. |
| 3.7 | `--list` shows cleanup-configured projects | ⬜ | Run with `--list`. Verify projects with `cleanup:` config appear. |
| 3.8 | `--show` displays cleanup config | ⬜ | Run with `--show`. Verify cleanup sections are displayed. |

---

## 4. Compiler — Cross-Platform Compilation

**Test file:** `test/compiler_test.dart`

Target project: `_build` or another project with `compiler:` config.

| # | Feature | Status | How to Test |
|---|---------|--------|-------------|
| 4.1 | `--list` shows compiler-configured projects | ⬜ | Run with `--list`. Verify only projects with `compiler:` config appear. |
| 4.2 | `--show` displays compiler config | ⬜ | Run with `--show`. Verify compile sections, targets, and pre/postcompile displayed. |
| 4.3 | `--dry-run` shows commands without executing | ⬜ | Run with `--dry-run`. Verify stdout shows planned compilation commands. No binaries produced. |
| 4.4 | `--targets` filters target platforms | ⬜ | Run with `--targets linux-x64`. Verify only linux-x64 compilation attempted. |
| 4.5 | Placeholder resolution in commandlines | ⬜ | Configure `commandline` with `${file}`, `${target-platform}`. Run. Verify placeholders resolved in verbose output. |
| 4.6 | Precompile/postcompile phases execute | ⬜ | Configure pre/postcompile steps (e.g., `echo` commands). Run. Verify all phases execute in order. |

---

## 5. Runner — Build Runner Wrapper

**Test file:** `test/runner_test.dart`

Target project: Any project with `build.yaml` (e.g., `_build`).

| # | Feature | Status | How to Test |
|---|---------|--------|-------------|
| 5.1 | `--list` shows runner-eligible projects | ⬜ | Run with `--list`. Verify projects with `build.yaml` appear. |
| 5.2 | `--show` displays runner config and builders | ⬜ | Run with `--show`. Verify builder names and filter config displayed. |
| 5.3 | `--dry-run` shows build_runner command | ⬜ | Run with `--dry-run`. Verify planned command shown without execution. |
| 5.4 | `--include-builders` filters to specific builders | ⬜ | Run with `--include-builders reflection`. Verify only reflection builder runs. |
| 5.5 | `--command clean` runs build_runner clean | ⬜ | Run with `--command clean`. Verify build_runner clean executed successfully. |

---

## 6. Dependencies — Dependency Tree

**Test file:** `test/dependencies_test.dart`

Target project: Any project with dependencies (e.g., `_build`).

| # | Feature | Status | How to Test |
|---|---------|--------|-------------|
| 6.1 | Default mode shows normal dependencies | ⬜ | Run dependencies. Verify stdout lists `->` prefixed dependency names. |
| 6.2 | `--dev` shows dev dependencies only | ⬜ | Run with `--dev`. Verify stdout lists `+>` prefixed dependencies. No `->` entries. |
| 6.3 | `--all` shows both normal and dev | ⬜ | Run with `--all`. Verify both `->` and `+>` entries present. |
| 6.4 | `--deep` shows recursive dependency tree | ⬜ | Run with `--deep`. Verify indented tree output with transitive dependencies. |

---

## 7. VersionBump — Version Bumping

**Test file:** `test/versionbump_test.dart`

Target project: `_build` (has `version:` in pubspec.yaml).

**Note:** VersionBump currently has a `-v` abbreviation conflict bug (issues.md #13) that prevents the tool from starting. Tests should document this and be adjusted once the bug is fixed.

| # | Feature | Status | How to Test |
|---|---------|--------|-------------|
| 7.1 | Default patch bump | ⬜ | Run versionbump on `_build`. Verify `version:` in pubspec.yaml incremented patch (e.g., 1.0.0 → 1.0.1). |
| 7.2 | `--minor` bump for specific project | ⬜ | Run with `--minor _build`. Verify minor version bumped (e.g., 1.0.0 → 1.1.0). |
| 7.3 | `--major` bump for specific project | ⬜ | Run with `--major _build`. Verify major version bumped (e.g., 1.0.0 → 2.0.0). |
| 7.4 | Build counter reset after bump | ⬜ | Run versionbump. Verify `tom_build_state.json` has `buildNumber: 0`. |
| 7.5 | `--dry-run` shows planned bumps without changing files | ⬜ | Run with `--dry-run`. Verify pubspec.yaml unchanged and stdout shows planned bump. |

---

## 8. BuildKit — Pipeline Orchestrator

**Test file:** `test/buildkit_test.dart`

Uses workspace-level pipeline configuration from `tom_build_master.yaml`.

| # | Feature | Status | How to Test |
|---|---------|--------|-------------|
| 8.1 | `--list` shows available pipelines | ⬜ | Run `buildkit --list`. Verify pipeline names from `tom_build_master.yaml` are listed. |
| 8.2 | `--help` shows usage | ⬜ | Run `buildkit --help`. Verify usage text displayed. |
| 8.3 | Direct command execution (`:versioner`) | ⬜ | Run `buildkit :versioner --project _build`. Verify versioner executes. |
| 8.4 | Pipeline execution (`build`, `clean`) | ⬜ | Run `buildkit clean --project _build`. Verify pipeline steps execute in order. |
| 8.5 | `--dry-run` on pipeline | ⬜ | Run `buildkit build --dry-run --project _build`. Verify no changes made. |
| 8.6 | Per-step option suppression (`-s-`, `-v-`) | ⬜ | Run `buildkit :versioner -s- --project _build`. Verify `-s` not passed to versioner. |
| 8.7 | Shell command execution in pipeline | ⬜ | Configure pipeline step with `shell echo hello`. Run. Verify "hello" in output. |
| 8.8 | `--exclude-projects` filters pipeline targets | ⬜ | Run `buildkit build --exclude-projects 'zom_*'`. Verify no `zom_` projects processed by any pipeline step. |
| 8.9 | `--exclude` combined with `--exclude-projects` | ⬜ | Run `buildkit build --exclude '*.g.dart' --exclude-projects 'xternal/tom_module_basics/*'`. Verify both file-level and project-level exclusions applied independently. |

---

## 9. Config Merge — Merge Precedence

**Test file:** `test/config_merge_test.dart`

Tests that verify the config merge hierarchy works correctly across all tools.

| # | Feature | Status | How to Test |
|---|---------|--------|-------------|
| 9.1 | Workspace defaults apply when project has no config | ⬜ | Use fixture with workspace-level `versioner:` prefix. Target project without `versioner:` in `tom_build.yaml`. Verify workspace prefix used. |
| 9.2 | Project config overrides workspace config | ⬜ | Use fixture with workspace prefix `testDefault`. Target project with `tomTools`. Verify project prefix used. |
| 9.3 | CLI args override project config (after bug fix) | ⬜ | Run with `--variable-prefix myCustom`. Verify `MyCustomVersionInfo`. **Blocked by issues.md #12.** |
| 9.4 | Additive merge for list fields (excludes, protected-folders) | ⬜ | Configure workspace and project with different exclude patterns. Verify both patterns applied (union). |

---

## 10. Security — Path & Command Validation

**Test file:** `test/security_test.dart`

Tests that verify security boundaries are enforced.

| # | Feature | Status | How to Test |
|---|---------|--------|-------------|
| 10.1 | `--project` rejects paths outside workspace | ⬜ | Run versioner `--project /tmp/evil`. Verify non-zero exit code and error message about path containment. |
| 10.2 | `--scan` rejects paths outside workspace | ⬜ | Run versioner `--scan /tmp`. Verify rejection. |
| 10.3 | Protected folders survive cleanup | ⬜ | Configure cleanup that would match `.git/` contents. Run. Verify `.git/` untouched. |
| 10.4 | Pipeline rejects unknown commands | ⬜ | Configure pipeline with `rm -rf /`. Run. Verify command rejected (not an allowed binary or `shell ` prefix). |

---

## Known Bugs Affecting Tests

These bugs are tracked in [issues.md](issues.md) and affect test expectations:

| Issue | Bug | Impact on Tests |
|-------|-----|-----------------|
| #12 | Versioner config merge-order | Tests 2.2, 2.6, 9.3 document current (buggy) behavior instead of expected behavior |
| #13 | VersionBump `-v` abbreviation conflict | All versionbump tests (7.x) will fail until bug is fixed — tool cannot start |
| #14 | BuiltinCommands dry-run inconsistency | Pipeline dry-run tests (8.5) may not fully verify tool-level dry-run |
