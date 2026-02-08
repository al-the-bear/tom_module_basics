# Tom Build Kit — BuildKit Orchestrator User Guide

BuildKit is the pipeline-based build orchestration tool for the Tom workspace. It provides a unified interface to run named build pipelines, invoke individual tools directly, and process multiple projects in sequence.

For the individual tool reference, see [tools_user_guide.md](tools_user_guide.md).

---

## Table of Contents

- [Quick Start](#quick-start)
- [Installation](#installation)
- [Command Line Usage](#command-line-usage)
  - [Options](#options)
  - [Project Selection](#project-selection)
- [Execution Steps](#execution-steps)
  - [Pipelines](#pipelines)
  - [Direct Commands](#direct-commands)
  - [Mixed Execution](#mixed-execution)
- [Pipeline Configuration](#pipeline-configuration)
  - [Pipeline Properties](#pipeline-properties)
  - [Step Structure](#step-structure)
  - [Pipeline Phases](#pipeline-phases)
- [Built-in Commands](#built-in-commands)
- [Allowed Binaries](#allowed-binaries)
- [Git Operations](#git-operations)
- [Shell Commands](#shell-commands)
  - [Variable Expansion](#variable-expansion)
  - [Environment Variables](#environment-variables)
  - [Multi-Line Shell Scripts](#multi-line-shell-scripts)
  - [Stdin Piping](#stdin-piping)
- [Platform Filtering](#platform-filtering)
  - [Platform Aliases](#platform-aliases)
- [Per-Tool Option Override](#per-tool-option-override)
- [Project Scanning](#project-scanning)
  - [Scan Behavior](#scan-behavior)
  - [Exclusion Filters](#exclusion-filters)
- [Configuration Hierarchy](#configuration-hierarchy)
- [Command Security](#command-security)
- [Examples](#examples)

---

## Quick Start

```bash
# Run a single pipeline
buildkit build

# Run multiple pipelines in sequence
buildkit clean build

# Run tool commands directly
buildkit :versioner :compiler

# Mix pipelines and commands
buildkit build :cleanup --force

# Dry-run to preview what would be executed
buildkit -n build

# List available pipelines
buildkit --list

# Show help for a built-in command
buildkit help :compiler
```

---

## Installation

```bash
# Run directly with dart
dart run tom_build_kit:buildkit [options] <steps>

# Or compile to executable
dart compile exe bin/buildkit.dart -o buildkit
```

---

## Command Line Usage

```text
Usage: buildkit [options] <pipeline|:command> [args...] [<pipeline|:command> [args...]]...
       buildkit help :<command>      Show help for a built-in command
       buildkit --version            Show version information
```

### Options

| Flag | Short | Description |
|------|-------|-------------|
| `--help` | `-h` | Show help |
| `--version` | `-V` | Show version |
| `--verbose` | `-v` | Verbose output |
| `--dry-run` | `-n` | Show what would be executed without running |
| `--list` | `-l` | List available pipelines |
| `--scan <dir>` | `-s` | Scan directory for projects |
| `--recursive` | `-r` | Scan directories recursively |
| `--project <path>` | `-p` | Project(s) to run on |
| `--root <dir>` | `-R` | Root directory for configuration lookup |
| `--git-scan` | `-g` | Scan for git repositories instead of build projects |
| `--exclude <pattern>` | `-x` | Exclude patterns — path-based globs (multi-option) |
| `--exclude-projects <pattern>` | — | Exclude projects by name or path (multi-option) |

> **Important:** Global options must appear **before** the pipeline or command name. Options placed after the pipeline name are silently ignored (BuildKit will print a warning if it detects this).

### Project Selection

The `--project` option supports multiple specification methods:

| Method | Example |
|--------|---------|
| Single project | `--project=my_app` |
| Comma-separated | `--project='project1,project2,project3'` |
| Glob patterns | `--project='tom_*_builder'` |
| Path globs | `--project='xternal/tom_module_d4rt/*'` |
| Current dir children | `--project='./*'` |
| Recursive from current | `--project='./**/*'` |

Without `--project` or `--scan`, BuildKit operates on the current directory.

---

## Execution Steps

BuildKit supports two types of execution steps that can be freely combined.

### Pipelines

Pipelines are named sequences of commands defined in `tom_build.yaml` or `tom_build_master.yaml`. They are invoked by name:

```bash
buildkit build          # Run the "build" pipeline
buildkit clean build    # Run "clean" then "build" in sequence
```

### Direct Commands

Tool commands are invoked with a `:` prefix, bypassing pipeline configuration:

```bash
buildkit :versioner                         # Run versioner
buildkit :compiler --targets linux-x64      # Run compiler with arguments
buildkit :versioner :compiler :runner       # Run multiple tools in sequence
```

Arguments following a `:command` are passed to that command until the next step begins.

### Mixed Execution

Pipelines and direct commands can be mixed freely:

```bash
buildkit build :cleanup --force :versioner
```

This runs:

1. The `build` pipeline (all its configured steps)
2. The `cleanup` command with `--force`
3. The `versioner` command

**Output format:** Each step is clearly separated:

```text
________ Running build

[pipeline output...]

________ Running :cleanup --force

[cleanup output...]

________ Running :versioner

[versioner output...]
```

---

## Pipeline Configuration

Pipelines are defined in `tom_build_master.yaml` (workspace level) or `tom_build.yaml` (project level) under the `buildkit:` key:

```yaml
buildkit:
  allowed-binaries:
    - astgen
    - d4rtgen

  pipelines:
    clean:
      executable: true
      core:
        - commands:
            - cleanup
            - shell rm -rf build/

    build:
      executable: true
      runBefore: clean
      core:
        - commands:
            - versioner
            - runner
            - compiler

    deploy:
      executable: true
      runAfter: build
      precore:
        - commands:
            - shell echo "Preparing deployment..."
      core:
        - commands:
            - shell rsync -av build/ server:/app/
```

### Pipeline Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `executable` | bool | `true` | Whether the pipeline can be invoked from the command line. Non-executable pipelines can still be called as dependencies via `runBefore`/`runAfter`. |
| `runBefore` | String or List | — | Pipeline(s) to run **before** this one |
| `runAfter` | String or List | — | Pipeline(s) to run **after** this one |
| `precore` | List\<Step\> | — | Steps to run before core |
| `core` | List\<Step\> | — | Main pipeline steps |
| `postcore` | List\<Step\> | — | Steps to run after core |

### Step Structure

Each step in `precore`, `core`, or `postcore` is a map:

```yaml
core:
  - commands:
      - versioner
      - compiler
    platforms:
      - darwin-arm64
      - linux-x64
```

| Field | Type | Description |
|-------|------|-------------|
| `commands` | List\<String\> | Commands to execute in this step |
| `platforms` | List\<String\> | Platforms this step applies to (empty or omitted = all platforms) |

### Pipeline Phases

Pipeline execution follows this order:

```text
runBefore pipelines → precore → core → postcore → runAfter pipelines
```

**Dependency resolution:**

- `runBefore`/`runAfter` references are resolved recursively
- Circular dependencies are detected and reported as errors
- Already-executed pipelines are skipped (no duplicate execution)

---

## Built-in Commands

Built-in commands run the respective tools directly via their Dart implementation — no external process is spawned.

| Command | Description |
|---------|-------------|
| `versioner` | Generate `version.g.dart` files with build metadata |
| `versionbumper` | Bump `pubspec.yaml` versions across projects |
| `compiler` | Cross-platform Dart compilation |
| `runner` | `build_runner` wrapper with builder filtering |
| `cleanup` | Clean generated and temporary files |
| `dependencies` | Dependency tree visualization |
| `pubget` | Run `dart pub get` on projects |
| `pubgetall` | Shortcut for `pubget --scan . --recursive` |
| `git` | Run git commands across all workspace repositories (requires `--git-scan`) |

Commands can include arguments in pipeline definitions:

```yaml
core:
  - commands:
      - versioner --no-git
      - compiler --dry-run
      - runner --command build
```

When a pipeline specifies `--project`, built-in commands automatically receive the project path (unless `--project` is already in their arguments).

**Get help for a specific command:**

```bash
buildkit help :compiler
buildkit help :versioner
```

---

## Allowed Binaries

Beyond built-in commands, additional binaries can be explicitly allowed for execution:

```yaml
buildkit:
  allowed-binaries:
    - astgen
    - d4rtgen
    - ws_prepper
    - ws_analyzer
```

**Internal allowed binaries** (always available without configuration): `astgen`, `d4rtgen`, `reflector`, `reflectiongenerator`, `ws_prepper`, `ws_analyzer`.

Allowed binaries are invoked via `:name` syntax or as pipeline step commands:

```bash
buildkit :astgen --project _build
```

```yaml
core:
  - commands:
      - astgen --project _build
```

The `allowed-binaries` lists from workspace and project configs are merged additively.

---

## Git Operations

BuildKit can scan the workspace for git repositories and run git commands across all of them in a single invocation.

### Git Scan Flag

The `--git-scan` (`-g`) flag tells BuildKit to discover all git repositories in the workspace instead of scanning for build projects. It searches:

- The workspace root directory
- Subdirectories under `xternal/` (external sub-workspaces)
- Subdirectories under `xternal_apps/` (external applications)

Both regular git repositories (`.git/` directory) and git submodules (`.git` file) are detected.

### The :git Command

Use the `:git` command with `--git-scan` to run git commands across all discovered repositories:

```bash
# Check status of all repositories
buildkit -g :git status --short

# Pull latest changes in all repositories
buildkit -g :git pull

# Show recent commits across all repos
buildkit -g :git log --oneline -3

# Fetch all remotes
buildkit -g :git fetch --all
```

Each repository's output is prefixed with its directory name for easy identification:

```
________ Running :git status --short in (tom2)
 M _build/pubspec.yaml

________ Running :git status --short in (tom_module_basics)
 M tom_build_kit/bin/buildkit.dart

________ Running :git status --short in (tom_module_d4rt)
(clean)
```

The `--dry-run` (`-n`) and `--verbose` (`-v`) flags work with `:git`:

```bash
# Preview which repos would be affected
buildkit -g -n :git pull

# Verbose output with full git command details
buildkit -g -v :git status --short
```

**Get help:**

```bash
buildkit help :git
```

> **Note:** The `:git` command requires `--git-scan` (`-g`). Without it, BuildKit reports an error. Regular project scanning (`--scan`) is not relevant for git operations.

---

## Shell Commands

Shell commands are prefixed with `shell` and execute arbitrary shell commands:

```yaml
core:
  - commands:
      - shell rm -rf build/
      - shell echo "Build complete"
      - shell rsync -av dist/ server:/app/
```

> **Note:** The `shell` prefix is only valid in pipeline configuration. Direct `:shell` commands from the command line are not supported — use `shell` in a pipeline step instead.

### Variable Expansion

Shell commands support these variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `${project}` | Path to the current project directory | `/path/to/my_app` |
| `${root}` | Path to the workspace root directory | `/path/to/workspace` |
| `${current-platform-vs}` | VS Code platform format | `darwin-arm64` |
| `${current-os}` | Operating system | `macos`, `linux`, `windows` |

**Example:**

```yaml
core:
  - commands:
      - shell cp build/app ${root}/_bin/${current-platform-vs}/
```

### Environment Variables

Shell commands are executed with these environment variables set:

| Variable | Value |
|----------|-------|
| `BUILDKIT_PROJECT` | Current project path |
| `BUILDKIT_ROOT` | Workspace root path |
| `BUILDKIT_PLATFORM` | Current platform (VS Code format) |

### Multi-Line Shell Scripts

Instead of individual shell commands, you can write entire shell scripts using YAML literal block scalars (`|`). The script body follows the `shell` keyword on a new line:

```yaml
core:
  - commands:
      - |
        shell
        echo "Starting build..."
        mkdir -p build/output
        if [ -f "build/app" ]; then
          strip build/app
          echo "Binary stripped"
        fi
        echo "Build complete"
```

Multi-line shell scripts are executed as a single script via `sh -c`. All variable expansion (`${project}`, `${root}`, etc.) and environment variables (`BUILDKIT_PROJECT`, etc.) work the same as single-line shell commands.

> **Tip:** Use YAML literal block scalar `|` to preserve newlines exactly as written. The folded block scalar `>` collapses newlines into spaces and is not suitable for shell scripts.

### Stdin Piping

You can pipe multi-line content to a command's stdin using the `stdin` prefix. The first line specifies the command to run, and subsequent lines provide the stdin content:

```yaml
core:
  - commands:
      - |
        stdin dcli
        import 'dart:io';
        void main() {
          print('Hello from DartScript!');
          print('Platform: ${Platform.operatingSystem}');
        }
```

This executes `dcli` and pipes the Dart code to its standard input. Useful for:

- **DartScript execution** — pipe Dart scripts to `dcli` or `d4rt` for cross-platform scripting
- **Data processing** — pipe JSON/YAML content to processing tools
- **Code generation** — pipe template content to generators

**Important:** Variable expansion (`${project}`, etc.) is applied only to the command line (first line after `stdin`), not to the stdin content. This prevents conflicts with language-specific `$` syntax (e.g., Dart string interpolation).

```yaml
core:
  - commands:
      # Variables expanded in command, NOT in stdin body
      - |
        stdin myprocessor --output ${project}/build/result.txt
        Content that uses $dartVariable safely
        without BuildKit expanding it
```

---

## Platform Filtering

Steps can be filtered by platform to run only on specific operating systems or architectures:

```yaml
core:
  # Run on all platforms
  - commands:
      - versioner

  # Run only on macOS
  - commands:
      - shell codesign --sign - build/app
    platforms:
      - macos

  # Run only on Linux x64
  - commands:
      - shell strip build/app
    platforms:
      - linux-x64

  # Run on all ARM64 platforms
  - commands:
      - shell echo "ARM64 build"
    platforms:
      - darwin-arm64
      - linux-arm64
```

### Platform Aliases

| Alias | Matches |
|-------|---------|
| `macos`, `darwin` | All macOS platforms |
| `linux` | All Linux platforms |
| `windows`, `win32` | All Windows platforms |
| `darwin-*` | Glob — all macOS architectures |
| `linux-*` | Glob — all Linux architectures |
| `*-arm64` | Glob — all ARM64 platforms |

---

## Per-Tool Option Override

When chaining commands, global options (like `--scan`, `--verbose`, `--dry-run`) are inherited by all steps. Use the `-X-` syntax to suppress a specific option for one command:

```bash
# Scan with cleanup but NOT with compiler
buildkit -s . :cleanup -s- --project tom_* :compiler

# Verbose for versioner but not for runner
buildkit -v :versioner :runner -v-

# Dry-run for all except versioner
buildkit -n :versioner -n- :compiler :runner
```

| Suppression | Effect |
|-------------|--------|
| `-s-` | Suppress `--scan` for this command |
| `-v-` | Suppress `--verbose` for this command |
| `-n-` | Suppress `--dry-run` for this command |

The `-X-` syntax works for any single-letter option flag.

---

## Project Scanning

BuildKit can scan directories to find and process multiple projects:

```bash
# Scan current directory for projects
buildkit build --scan .

# Scan recursively (including nested projects)
buildkit build --scan . --recursive

# Short form
buildkit build -s . -r
```

### Scan Behavior

**Always skipped during scanning:**

- `.dart_tool`, `.git`, `.idea`, `.vscode`
- `build`, `node_modules`, `coverage`
- `.pub-cache`, `.pub`, `__pycache__`
- Hidden directories (starting with `.`)

**Skipped inside projects (with `--recursive`):**

- Source dirs: `bin`, `lib`, `src`
- Build dirs: `build`, `out`, `dist`
- Asset dirs: `assets`, `fonts`, `images`
- Platform dirs: `android`, `ios`, `macos`, `windows`, `linux`, `web`

### Exclusion Filters

BuildKit supports the same exclusion mechanisms as individual tools:

```bash
# Exclude by path glob
buildkit build -s . -r --exclude "zom_*"

# Exclude projects by name
buildkit build -s . -r --exclude-projects "_build"

# Exclude projects by path pattern
buildkit build -s . -r --exclude-projects "xternal/tom_module_basics/*"

# Combined
buildkit build -s . -r --exclude-projects "zom_*" --exclude-projects "core/*"
```

Projects with `tom_build_skip.yaml` are automatically skipped. Master YAML `navigation.exclude-projects` patterns are merged automatically.

---

## Configuration Hierarchy

Configuration is loaded in priority order:

| Priority | Source | Merge Behavior |
|----------|--------|----------------|
| 1 (highest) | **Command-line arguments** | Overrides all |
| 2 | **Project `tom_build.yaml`** | **Replaces** workspace pipelines for matching names |
| 3 (lowest) | **Workspace `tom_build_master.yaml`** | Base pipeline definitions |

**Important:** Project-level pipeline definitions **completely replace** workspace-level definitions for the same pipeline name — there is no merging of pipeline steps across levels.

**Allowed binaries** are **additive** across internal defaults, workspace config, and project config.

---

## Command Security

BuildKit enforces strict command security:

1. **Built-in commands** — Always allowed (`versioner`, `compiler`, etc.)
2. **Configured pipelines** — Pipeline names from `tom_build.yaml` / `tom_build_master.yaml`
3. **Allowed binaries** — Explicitly listed in `buildkit.allowed-binaries`
4. **Shell commands** — Only via `shell` prefix in pipeline configuration
5. **Everything else** — **Rejected** with an "Unknown command" error

Arbitrary shell commands cannot be executed via `:command` syntax. To run shell commands, use the `shell` prefix in a pipeline step.

---

## Examples

### Basic Build Pipeline

```yaml
buildkit:
  pipelines:
    build:
      core:
        - commands:
            - versioner
            - runner
            - compiler
```

```bash
buildkit build
```

### Clean and Build with Dependencies

```yaml
buildkit:
  pipelines:
    clean:
      core:
        - commands:
            - cleanup
            - shell rm -rf build/

    build:
      runBefore: clean
      core:
        - commands:
            - versioner
            - runner
            - compiler
```

```bash
buildkit build    # Automatically runs clean first
```

### Cross-Platform Build with Code Signing

```yaml
buildkit:
  pipelines:
    build:
      core:
        - commands:
            - versioner
            - compiler

      postcore:
        # macOS code signing
        - commands:
            - shell codesign --sign - build/app
          platforms:
            - macos

        # Linux stripping
        - commands:
            - shell strip build/app
          platforms:
            - linux
```

### Running Multiple Tools Directly

```bash
# Generate version, run build_runner, then compile
buildkit :versioner :runner :compiler

# With arguments
buildkit :versioner --no-git :compiler --targets linux-x64
```

### Workspace-Wide Build

```bash
# Build all projects in workspace
buildkit build --scan . --recursive

# List projects that would be processed
buildkit build -s . -r --list

# Exclude test projects
buildkit build -s . -r --exclude-projects "zom_*"
```

### Pub Get Across Workspace

```bash
# Run dart pub get on all projects
buildkit :pubgetall

# Show only projects with errors
buildkit :pubgetall --errors

# Show projects with available updates
buildkit :pubgetall --updates
```

### Dry Run

```bash
# See what build would execute
buildkit -n build

# Dry-run a specific tool
buildkit -n :versioner --project _build

# Verbose dry-run of the full pipeline
buildkit -v -n build -s . -r
```

### Summary Output

After processing all projects, BuildKit prints a summary:

```text
============================================================
Build Kit Summary
============================================================
Projects processed: 12
Status: SUCCESS
```
