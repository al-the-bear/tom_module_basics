# Build Kit Configuration Refactoring

## Status: Complete — v4

### Execution Summary

**Completed:**
- ✅ TODO 1: Rename workspace config to `tom_build_master.yaml`, add `findWorkspaceRoot()` to ToolBase, update all tools
- ✅ TODO 2: Migrate all tool config to `tom_build.yaml`:
  - Versioner `variablePrefix` from `build.yaml` to project `tom_build.yaml` (7 projects)
  - Astgen conversion config from `build.yaml` to `tom_build.yaml` (test project)
  - D4rtgen bridge config from `build.yaml`/`d4rt_bridging.json` to `tom_build.yaml` (3 production + 4 examples)
- ✅ TODO 3: Remove `build.yaml` reading from all tools:
  - Versioner and runner: done in v3
  - Astgen: `--config` default changed to `tom_build.yaml`, removed `build.yaml` fallback
  - D4rtgen: `BuildConfigLoader.loadFromBuildYaml()` → `loadFromTomBuildYaml()`, removed JSON fallback
  - D4rtgen CLI: updated `_isD4rtProject()`, `_processProjectDirect()`, `_printBuildYamlSection()`
  - Cleaned `build.yaml` files: removed `d4rt_bridge_builder` sections (kept version_builder, reflection_generator)
- ✅ TODO 4: Navigation/scanning redesign:
  - Added shared `navigation:` section to `tom_build_master.yaml`
  - Removed `scan:`/`recursive:` from individual tool sections in master config
  - `TomBuildConfig._loadFromFile()` merges `navigation:` section as defaults
  - Fixed `recursionExclude` bug: now properly passed from `ToolBase.findProjects()` → `ProjectDiscovery.scanForProjects()`
  - `ProjectDiscovery.scanForProjects()` accepts and applies `recursionExclude` glob patterns
- ✅ TODO 5: Full astgen/d4rtgen tool adaptation (config format migration)
- ✅ TODO 6: Unified config loading via `TomBuildConfig.loadMaster()` across all tools
- ✅ TODO 7: Standard pipelines (generate, clean, test, analyze, format, deps, ast, bridges)
- ✅ TODO 8: Unified merge rules — `ConfigMerger` utility with three strategies:
  - `mergeSections()`: project replaces workspace if non-empty
  - `mergeAdditive()`: union of workspace + project (deduplicated)
  - `mergeScalar()`: project overrides if explicitly set
  - `mergeMaps()`: project entries override workspace entries
- ✅ Bug fixes: Cleanup activation bug, d4rtgen toolKey, `-R`/`-r` flag swap
- ✅ Deleted all 6 `d4rt_bridging.json` files (production + examples)

**Commits (Phase 1 — v3):**
- `6b8f512` (tom_module_basics): buildkit config refactoring — all tool updates
- `942b257` (tom_module_d4rt): fix d4rtgen toolKey, add versioner variable-prefix
- `f339623` (tom2): rename tom_build_master.yaml, project config migrations, standard pipelines

**Commits (Phase 2 — v4):**
- `4a84a7d` (tom_module_basics): migrate astgen from build.yaml to tom_build.yaml
- `74a5df1` (tom_module_d4rt): migrate d4rtgen from build.yaml/d4rt_bridging.json to tom_build.yaml
- `4e8030d` (tom2): migrate d4rtgen config, clean build.yaml files, delete d4rt_bridging.json
- `910807d` (tom_module_basics): shared navigation section, ConfigMerger, recursionExclude fix
- `2ba238b` (tom2): add navigation section to tom_build_master.yaml

## Overview

This document captures the refactoring plan for Build Kit's configuration loading, merging, and file layout. The goal is to achieve **predictable, uniform behavior** across all tools with a clear workspace→project config hierarchy.

### Design Principles

1. **Single config file per level**: `tom_build_master.yaml` at workspace root, `tom_build.yaml` per project
2. **`build.yaml` is for build_runner only**: The only builder remaining in `build.yaml` is the reflection builder
3. **All buildkit tool config lives in `tom_build.yaml`**: versioner, compiler, cleanup, runner, astgen, d4rtgen
4. **Runner wraps build_runner**: The runner tool executes `dart run build_runner` under the hood, providing an integrated build experience within buildkit
5. **Scanning is always active**: `--scan .` is the implicit default; `--project` disables scanning
6. **No backward compatibility needed**: Single workspace, full migration
7. **External tools (astgen, d4rtgen) are first-class**: Treated as internal commands, may become built-in later

---

## TODO 1: Rename Workspace Root Config to `tom_build_master.yaml`

### Problem

The workspace root and project folders both use `tom_build.yaml`, making it ambiguous which is the "master" config. Tools currently use `Directory.current.path` as "workspace root" which is wrong — if you `cd` into a project, the project config becomes the "workspace" config.

### Change

- Rename the **workspace root** config from `tom_build.yaml` to `tom_build_master.yaml`
- Project-level configs remain `tom_build.yaml`
- All tools traverse **upwards** from the project directory to find `tom_build_master.yaml`
- This gives every tool a reliable workspace root discovery mechanism

### Implementation

1. Rename `/tom_build.yaml` → `/tom_build_master.yaml` in the workspace root
2. Add a shared `findWorkspaceRoot(String startDir)` utility in `ToolBase` that traverses up looking for `tom_build_master.yaml`
3. All tools call this once to establish the workspace root path
4. Update `PipelineConfig.load()` to use `tom_build_master.yaml` for workspace-level config
5. Update `buildkit.dart` `_findWorkspaceRoot()` to look for `tom_build_master.yaml`
6. Update all documentation references

### Files to Change

| File | Change |
|------|--------|
| `tom_build.yaml` (workspace root) | Rename to `tom_build_master.yaml` |
| `tool_base.dart` | Add `findWorkspaceRoot()` method |
| `pipeline_config.dart` | Use `tom_build_master.yaml` for workspace config |
| `buildkit.dart` | Update `_findWorkspaceRoot()` |
| `versioner_tool.dart` | Use `findWorkspaceRoot()` from ToolBase |
| `compiler_tool.dart` | Use `findWorkspaceRoot()` from ToolBase |
| `runner_tool.dart` | Remove own `_findWorkspaceRoot()`, use ToolBase's |
| `cleanup_tool.dart` | Use `findWorkspaceRoot()` from ToolBase |

---

## TODO 2: Migrate All Tool Config to `tom_build.yaml`

### Problem

Configuration is scattered across three file types:
- `tom_build.yaml` / `tom_build_master.yaml` — buildkit tool config
- `build.yaml` — build_runner config AND versioner/runner/astgen config mixed in
- `d4rt_bridging.json` — d4rtgen legacy config

### Change

**`build.yaml` is reserved exclusively for build_runner configuration** (targets, builders, global_options). The only builder that remains is the **reflection builder**.

All other configuration moves to `tom_build.yaml`:

| Current Location | Tool | Move To |
|-----------------|------|---------|
| `build.yaml` → `tom_build_kit:version_builder.options` | versioner | `tom_build.yaml` → `versioner:` |
| `build.yaml` → `tom_build_kit.build_runner` | runner (builder filter) | `tom_build.yaml` → `build_runner:` |
| `build.yaml` → top-level `astgen:` key | astgen | `tom_build.yaml` → `astgen:` |
| `build.yaml` → `tom_d4rt_generator:d4rt_bridge_builder.options` | d4rtgen | `tom_build.yaml` → `d4rtgen:` |
| `d4rt_bridging.json` | d4rtgen (legacy) | `tom_build.yaml` → `d4rtgen:` |

### Versioner Migration Detail

The `variablePrefix` option only exists in `build.yaml` (build_runner builder) but NOT in the versioner CLI. The versioner CLI always generates `TomVersionInfo` as class name. This is a discrepancy.

**Resolution**: Add `variablePrefix` support to the versioner CLI tool and migrate the setting:

Projects with custom `variablePrefix` in `build.yaml`:

| Project | Current `variablePrefix` |
|---------|-------------------------|
| `tom_tools` | `tomTools` |
| `tom_d4rt` | `d4rt` |
| `tom_build_kit` | `buildkit` |
| `tom_d4rt_astgen` | `astgenTool` |
| `tom_d4rt_generator` | `d4rtGen` |
| `tom_dartscript_bridges` | `dcli` |
| `tom_dartscript_extension` | `tomD4rt` |

### D4rtgen Migration Detail

**Bug found**: The d4rtgen binary uses `toolKey = 'dartgen'` but the workspace `tom_build.yaml` names the section `d4rtgen:`. The tool never finds workspace-level config.

**Resolution**: Fix the toolKey to `d4rtgen` and migrate bridge config from `build.yaml`/`d4rt_bridging.json` to `tom_build.yaml` `d4rtgen:` section.

7 projects have `d4rt_bridging.json` files. After migration, `d4rt_bridging.json` support will be **completely removed** from d4rtgen — the tool will only read from `tom_build.yaml`.

### Astgen Migration Detail

Astgen already uses a non-standard `astgen:` top-level key in `build.yaml` (NOT a build_runner section). This moves cleanly to `tom_build.yaml` `astgen:` section with identical structure.

---

## TODO 3: Disable Reading Configuration from `build.yaml` in All Tools

### Change

After TODO 2 migration is complete:

1. **Versioner**: Remove `loadFromBuildYaml()` call — stop reading `build.yaml`
2. **Runner**: Remove `BuilderFilterConfig.loadFromBuildYaml()` — builder filter comes from `tom_build.yaml` only. Note: the runner tool executes `dart run build_runner` under the hood — `build.yaml` is still read by build_runner itself for builder definitions (reflection builder), but the runner tool no longer reads it for its own config.
3. **Astgen**: Remove `build.yaml` astgen section reading
4. **D4rtgen**: Remove `build.yaml` bridge builder options reading; remove all `d4rt_bridging.json` code
5. **ToolBase**: Remove `loadBuildYaml()` and `printBuildYamlSection()` helper methods

The 4-level runner builder filter precedence becomes 3-level:
1. CLI args (highest)
2. Project `tom_build.yaml` → `build_runner.include-builders` / `exclude-builders`
3. Workspace `tom_build_master.yaml` → `build_runner.include-builders` / `exclude-builders`

---

## TODO 4: Navigation and Scanning Behavior

### Design

**Scanning is always active** unless `--project` is specified. When you run a tool in a folder, it automatically scans that folder for projects (`--scan .` is the implicit default).

The question of **recursive** scanning (scanning inside found projects for nested projects) is controlled by a separate mechanism.

### Behavior

| Invocation | What Happens |
|-----------|-------------|
| `tool` (no args) | Scans current directory for projects (`--scan .` implied) |
| `tool --project tom_core` | Processes only the specified project — no scanning |
| `tool -s /path/to/dir` | Scans the specified directory for projects |

### Project Discovery Logic

When scanning a directory:

1. If `tom_build.yaml` (or `pubspec.yaml`) exists in the current folder → the **first (and only) project** is found at that location
2. Subfolder scanning only happens if:
   - `recursive: true` is set (workspace default), OR
   - `scan-subfolders` is defined in the project's `tom_build.yaml`
3. If neither `recursive` nor `scan-subfolders` is active → only the single project in the current folder is processed

### Recursive / Scan-Subfolders

When the scanner is **inside a project** (detected by `pubspec.yaml`), the `recursive` setting controls whether it descends into subfolders to find nested projects.

**Precedence** (highest to lowest):

1. CLI `--recursive` / `-r` / `--no-recursive`
2. Project-level `tom_build.yaml` → `navigation.scan-subfolders` (overrides workspace `recursive` for this project)
3. Workspace-level `tom_build_master.yaml` → `navigation.recursive` (default: `true`)

**`scan-subfolders` vs `recursive`**:
- `recursive: true/false` — workspace-level default in `tom_build_master.yaml`
- `scan-subfolders` — project-level override in `tom_build.yaml`. Can be:
  - `true` — same as recursive for this project
  - `false` — don't scan into this project's subfolders
  - `[glob, ...]` — scan only these subfolders (globs allowed)
- Only `recursive` OR `scan-subfolders` is effective per project, not both
- A project-level `scan-subfolders` overrides the workspace `recursive` for that project
- `tom_build_master.yaml` cannot have `scan-subfolders` (workspace-level only uses `recursive`)

### No Per-Tool Navigation

Navigation options (`scan`, `project`, `recursive`, `exclude`, `recursion-exclude`) are **removed from individual tool sections** in YAML config. They remain as CLI options.

```yaml
# tom_build_master.yaml
navigation:
  recursive: true
  exclude:              # Workspace-level exclude patterns
    - 'zom_*'
  recursion-exclude:    # Workspace-level recursion exclude patterns
    - 'node_modules'
```

```yaml
# tom_build.yaml (project level) — optional
navigation:
  scan-subfolders: false   # Or: scan-subfolders: ['packages/*', 'modules/*']
```

### CLI-Only Options

These options are **never** read from YAML config:
- `--scan` / `-s` (always `.` unless specified)
- `--project` / `-p`
- `--dry-run` / `-n`
- `--list` / `-l`
- `--show`
- `--help`

---

## TODO 5: Adapt External Tools (Astgen, D4rtgen)

### Status

Astgen and d4rtgen are external tools but part of the same family. They must be integrated like internal commands and may become internal commands in the future.

### Current State

| Tool | Reads `tom_build.yaml` | Reads `build.yaml` | Own config file | Tool key issue |
|------|:---------------------:|:------------------:|:--------------:|---------------|
| **astgen** | ✅ `astgen:` section | ✅ non-standard `astgen:` key | ❌ | None — uses `'astgen'` |
| **d4rtgen** | ⚠️ `dartgen:` section | ✅ bridge builder options | ✅ `d4rt_bridging.json` | **Bug**: uses `'dartgen'` but YAML has `d4rtgen:` |

### Required Changes

**Astgen**:
1. Remove `build.yaml` reading for astgen config
2. Read conversion config (`convert:` entries) from `tom_build.yaml` `astgen:` section only
3. Update `isAstgenProject()` to check `tom_build.yaml` only

**D4rtgen**:
1. Fix `_toolKey` from `'dartgen'` to `'d4rtgen'`
2. Migrate bridge config from `build.yaml` / `d4rt_bridging.json` to `tom_build.yaml` `d4rtgen:` section
3. Remove `build.yaml` reading for bridge options
4. Remove all `d4rt_bridging.json` loading code — d4rtgen will only read from `tom_build.yaml`
5. Delete all `d4rt_bridging.json` files from projects after migration
6. Update `_isD4rtProject()` to check `tom_build.yaml` only

### Config Migration

**Astgen** — move from `build.yaml` to `tom_build.yaml`:
```yaml
# tom_build.yaml (project level)
astgen:
  convert:
    - entrypoints:
        - lib/src/ast/
      output: lib/src/ast_d4rt/
      root: lib/
      exclude: []
      preserve_structure: true
      include_sourcemap: true
```

**D4rtgen** — move from `build.yaml`/`d4rt_bridging.json` to `tom_build.yaml`:
```yaml
# tom_build.yaml (project level)
d4rtgen:
  name: my_bridge
  modules:
    - name: core
      classes: [MyClass, MyOtherClass]
  helpersImport: 'package:my_package/helpers.dart'
  generateBarrel: true
  barrelPath: lib/src/bridges/
```

---

## TODO 6: Unify Config Loading via `TomBuildConfig`

### Problem

Currently:
- **Versioner** uses `TomBuildConfig.load()` from `tom_build_base` ✅
- **Cleanup** has its own `CleanupConfig.loadFromYaml()` ❌
- **Compiler** has its own `CompilerConfig.loadFromYaml()` ❌
- **Runner** has its own `BuildRunnerConfig.loadFromYaml()` ❌

### Packages Using `tom_build_base`

| Package | How it uses `tom_build_base` |
|---------|----------------------------|
| **tom_build_kit** | All built-in tools (versioner, compiler, cleanup, runner, etc.) |
| **tom_build** (legacy `_build/`) | Original build tool — uses `TomBuildConfig` |
| **tom_build_cli** | CLI frontend for buildkit |
| **tom_d4rt_astgen** | Astgen tool — uses `TomBuildConfig` for config loading |
| **tom_d4rt_generator** | D4rtgen tool — uses `TomBuildConfig` for config loading |
| **tom_dartscript_bridges** | Bridge generation — uses `TomBuildConfig` |
| **tom_d4rt_dcli** | DCli integration — uses `TomBuildConfig` |

All 7 consumers must be updated when `TomBuildConfig` changes (e.g., `tom_build_master.yaml` rename, navigation changes).

### Change

All tools use `TomBuildConfig` for initial YAML loading, then extract tool-specific fields from `toolOptions`.

### Enhancement to `TomBuildConfig`

- Remove navigation fields (per TODO 4)
- Keep `toolOptions` as the extensible bag for tool-specific config
- Add `loadMaster(startDir)` that traverses up to find and load `tom_build_master.yaml`
- Add `loadProject(projectDir)` that loads `tom_build.yaml` from a project directory
- Both return typed `TomBuildConfig` with the tool section extracted into `toolOptions`

---

## TODO 7: Standard Pipelines

### Design

Define standard pipelines in `tom_build_master.yaml` to execute typical scripting needs:
- Per project with a single command
- For the complete workspace
- With filtering options to restrict to certain projects or targets

### Proposed Standard Pipelines

```yaml
buildkit:
  pipelines:
    # =====================================================================
    # WORKSPACE-WIDE PIPELINES
    # =====================================================================

    # Full build pipeline (default)
    build:
      executable: true
      core:
        - commands:
            - cleanup
            - versioner
            - runner
            - compiler

    # Code generation only (no compile)
    generate:
      executable: true
      core:
        - commands:
            - runner
            - versioner

    # Clean all build artifacts
    clean:
      executable: true
      core:
        - commands:
            - cleanup

    # Run tests across workspace
    test:
      executable: true
      core:
        - commands:
            - shell dart test

    # Run analysis across workspace
    analyze:
      executable: true
      core:
        - commands:
            - shell dart analyze

    # Format check across workspace
    format:
      executable: true
      core:
        - commands:
            - shell dart format --set-exit-if-changed .

    # Resolve dependencies across workspace
    deps:
      executable: true
      core:
        - commands:
            - pubget

    # =====================================================================
    # RELEASE WORKFLOW PIPELINES
    # =====================================================================

    # Pre-release validation (deactivate overrides, validate, test)
    prerelease:
      executable: true
      core:
        # Deactivate local path overrides
        - commands:
            - shell test -f pubspec_overrides.yaml && mv pubspec_overrides.yaml pubspec_overrides.yaml.dev || true
        # Resolve from pub.dev
        - commands:
            - shell dart pub get
        # Validate
        - commands:
            - shell dart analyze
        - commands:
            - shell dart test
        - commands:
            - shell dart format --set-exit-if-changed .
        # Check release readiness
        - commands:
            - 'shell if grep -F "path:" pubspec.yaml >/dev/null 2>&1; then echo "ERROR: pubspec.yaml contains path: dependencies"; exit 1; fi'
        - commands:
            - 'shell if [ -n "$(git status --porcelain .)" ]; then echo "ERROR: Uncommitted changes"; git status --short .; exit 1; fi'
        - commands:
            - 'shell if grep -qF "publish_to: none" pubspec.yaml 2>/dev/null; then echo "OK: private package"; elif grep -qF "publish_to:" pubspec.yaml 2>/dev/null; then echo "OK: publish_to set"; else echo "WARNING: No publish_to field"; fi'
        - commands:
            - 'shell if [ ! -f LICENSE ] && [ ! -f LICENSE.md ]; then echo "WARNING: No LICENSE file"; fi'
        - commands:
            - 'shell if [ -f CHANGELOG.md ]; then VERSION=$(grep "^version:" pubspec.yaml | sed "s/version: *//"); if ! grep -qF "$VERSION" CHANGELOG.md; then echo "WARNING: No CHANGELOG entry for $VERSION"; fi; fi'

    # Restore development mode (reactivate overrides)
    predevelopment:
      executable: true
      core:
        - commands:
            - shell test -f pubspec_overrides.yaml.dev && mv pubspec_overrides.yaml.dev pubspec_overrides.yaml || true
        - commands:
            - shell dart pub get

    # =====================================================================
    # EXTERNAL TOOL PIPELINES
    # =====================================================================

    # Run AST generation
    ast:
      executable: true
      core:
        - commands:
            - astgen

    # Run D4rt bridge generation
    bridges:
      executable: true
      core:
        - commands:
            - d4rtgen

    # Run reflection generation
    reflect:
      executable: true
      core:
        - commands:
            - runner
```

### Usage Examples

```bash
# Full build across workspace
buildkit build

# Generate code only
buildkit generate

# Test all projects
buildkit test

# Pre-release validation
buildkit prerelease

# Chain multiple pipelines
buildkit clean build test

# Restrict to specific projects (via --exclude)
buildkit build --exclude 'zom_*'
```

---

## TODO 8: Configuration Merge Rules

### Unified Rules

Define **three categories** of config fields with uniform merge behavior across all tools:

#### Category 1: Section Lists

**Rule: Project replaces workspace if non-empty.**

These are "what to do" definitions. A project that defines its own compile targets fully replaces workspace defaults.

| Tool | Section List Fields |
|------|-------------------|
| compiler | `compiles`, `precompile`, `postcompile` |
| cleanup | `cleanup` (glob sections) |
| buildkit | `pipelines.<name>` (per pipeline name) |
| astgen | `convert` (conversion entries) |
| d4rtgen | `modules` (bridge modules) |

#### Category 2: Additive Lists

**Rule: Always additive (union of workspace + project).**

Guard/filter lists where both levels should contribute.

| Tool | Additive List Fields |
|------|---------------------|
| cleanup | `excludes`, `protected-folders` |
| buildkit | `allowed-binaries` |
| navigation | `exclude`, `recursion-exclude` |
| runner | `include-builders`, `exclude-builders` |

#### Category 3: Scalar Values

**Rule: Project overrides workspace if explicitly set.**

Standard cascading defaults — workspace provides defaults, projects override what's different.

| Tool | Scalar Fields |
|------|--------------|
| versioner | `output`, `includeGitCommit`, `variablePrefix` |
| runner | `command`, `delete-conflicting`, `config`, `release` |
| cleanup | `maxFiles` |
| navigation | `recursive` (overridden by project `scan-subfolders`) |

### Implementation

Shared `ConfigMerger` utility:

```dart
class ConfigMerger {
  /// Category 1: Project replaces workspace if non-empty
  static List<T> mergeSections<T>(List<T> workspace, List<T> project) {
    return project.isNotEmpty ? project : workspace;
  }

  /// Category 2: Always additive (union)
  static List<String> mergeAdditive(List<String> workspace, List<String> project) {
    return {...workspace, ...project}.toList();
  }

  /// Category 3: Project overrides if explicitly set
  static T mergeScalar<T>(T workspace, T? project, {T? defaultValue}) {
    if (project == null) return workspace;
    if (defaultValue != null && project == defaultValue) return workspace;
    return project;
  }
}
```

---

## Tool Defaults Reference

All tools can run without `tom_build_master.yaml`. Some require project-level `tom_build.yaml`.

### Configuration-Free Tools

These tools need **no configuration** in `tom_build.yaml` or `tom_build_master.yaml` — they are purely CLI-driven:

- **dependencies** — reads `pubspec.yaml` directly, all options via CLI
- **versionbump** — reads/writes `pubspec.yaml`, all options via CLI (`--minor`, `--major`, `--versioner`)

They should never appear as tool sections in config files.

### All Tools

| Tool | Runs without any config? | Hard-coded defaults | Requires project `tom_build.yaml`? |
|------|:------------------------:|--------------------|------------------------------------|
| **versioner** | ✅ | `output: lib/src/version.g.dart`, `includeGitCommit: true` | No — but `isToolProject` checks for `versioner:` section |
| **versionbump** | ✅ | Patch bump, reset counter to 0 | No — any project with `pubspec.yaml` + `version:` |
| **compiler** | ❌ | None | Yes — needs `compiler:` with `compiles:` |
| **runner** | ✅ | `command: build`, `deleteConflicting: true` | No — needs `build.yaml` to exist |
| **cleanup** | ❌ | Default globs: `build/`, `.dart_tool/build/`, `**/*.g.dart`, `**/*.r.dart`, `**/*.b.dart`, `**/*.reflection.dart`, `**/*.reflectable.dart` | Yes — but just `cleanup:` (empty section) is enough to activate with defaults |
| **dependencies** | ✅ | Shows all dep types | No — reads `pubspec.yaml` directly |
| **buildkit** | ⚠️ Partial | Built-in commands work | No — but no pipelines without config |
| **astgen** | ❌ | None | Yes — needs `astgen:` with `convert:` |
| **d4rtgen** | ❌ | None | Yes — needs `d4rtgen:` with bridge config |

---

## Resolved Questions

### Q1: Should `tom_build_master.yaml` support non-buildkit sections?

**Yes.** Astgen and d4rtgen are external but part of the same family. They must be integrated like internal commands and may become internal commands in the future. All tool sections (`astgen:`, `d4rtgen:`, `versioner:`, `compiler:`, etc.) belong in `tom_build_master.yaml` as workspace-level defaults.

### Q2: `scan-subfolders` behavior?

`scan-subfolders` is an optional attribute in the project-level `navigation:` section:
- `true` / `false` — boolean control
- `[glob, ...]` — list of subfolders to scan (globs allowed)
- Only `recursive` OR `scan-subfolders` is effective per project, not both
- Project-level `scan-subfolders` overrides workspace `recursive` for that project
- `tom_build_master.yaml` cannot have `scan-subfolders` (workspace-level only uses `recursive`)

### Q3: What happens without `tom_build_master.yaml`?

All tools work without it using their hard-coded defaults (see Tool Defaults table above). No warning needed — it's a valid scenario for standalone project usage. Buildkit pipelines require either workspace or project-level pipeline definitions.

### Q4: Backward compatibility?

**No backward compatibility.** This is a single workspace with no external users. Full migration to the new structure.

---

## Discovered Issues

### Cleanup Activation Bug

Currently, `cleanup:` (bare key with no value) parses as `null` in YAML, causing `hasTomBuildConfig('cleanup')` to return `false`. This means the project isn't discovered during scanning. Fix: treat a `null` value the same as an empty map — the presence of the key alone should be enough to activate the tool with workspace defaults or hard-coded defaults.

### D4rtgen Tool Key Bug

The d4rtgen binary uses `const _toolKey = 'dartgen'` but the workspace config names the section `d4rtgen:`. The tool never finds workspace-level config. Must be fixed to `'d4rtgen'`.

### Versioner `variablePrefix` Gap

The build_runner version builder supports `variablePrefix` to customize the generated class name (e.g., `TomToolsVersionInfo` instead of `TomVersionInfo`). The versioner CLI tool does not support this — it always generates `TomVersionInfo`. Must add `variablePrefix` support to the versioner CLI before removing `build.yaml` reading.

Affected projects: `tom_tools`, `tom_d4rt`, `tom_build_kit`, `tom_d4rt_astgen`, `tom_d4rt_generator`, `tom_dartscript_bridges`, `tom_dartscript_extension`.

---

## Implementation Order

| Step | TODO | Dependencies | Scope |
|------|------|--------------|-------|
| 1 | TODO 1: Rename to `tom_build_master.yaml` | None | Workspace root + all tools |
| 2 | TODO 6: Unify config loading via `TomBuildConfig` | TODO 1 | `tom_build_base` + all tool configs |
| 3 | TODO 4: Navigation/scanning redesign | TODO 1, 6 | All tool configs + `ToolBase` |
| 4 | TODO 2: Migrate config from `build.yaml` to `tom_build.yaml` | TODO 6 | All projects, versioner (add `variablePrefix`) |
| 5 | TODO 5: Adapt astgen and d4rtgen | TODO 2 | `tom_d4rt_astgen`, `tom_d4rt_generator` |
| 6 | TODO 3: Disable `build.yaml` reading | TODO 2, 5 | All tools |
| 7 | TODO 8: Apply unified merge rules | TODO 1-6 | All tool configs |
| 8 | TODO 7: Standard pipelines | TODO 1 | `tom_build_master.yaml` |

---

## File Layout After Refactoring

### Workspace Root

```
tom_build_master.yaml          # Workspace defaults + pipelines
├── navigation:
│     recursive: true
│     exclude: ['zom_*']
├── versioner:                 # Default versioner settings
├── compiler:                  # Default compiler settings (if any)
├── cleanup:                   # Default cleanup patterns (if any)
├── build_runner:              # Default runner settings
├── astgen:                    # Default astgen settings (if any)
├── d4rtgen:                   # Default d4rtgen settings (if any)
└── buildkit:
      allowed-binaries: [...]
      pipelines:
        build: ...
        generate: ...
        test: ...
        prerelease: ...
        predevelopment: ...
```

### Project Level

```
tom_build.yaml                 # Project-specific overrides
├── navigation:
│     scan-subfolders: false   # Optional
├── versioner:                 # Override output, variablePrefix, etc.
├── compiler:
│     compiles: [...]          # Project-specific compile targets
├── cleanup:                   # Project-specific cleanup patterns
├── d4rtgen:                   # Bridge generation config
└── astgen:                    # AST conversion config

build.yaml                     # build_runner ONLY
└── targets:
      $default:
        builders:
          tom_reflection_generator:...   # Reflection builder only
```