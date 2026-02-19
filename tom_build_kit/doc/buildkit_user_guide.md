# Tom Build Kit — BuildKit Orchestrator User Guide

BuildKit is the pipeline-based build orchestration tool for the Tom workspace. It provides a unified interface to run named build pipelines, invoke individual tools directly, and process multiple projects in sequence.

For the individual tool reference, see [tools_user_guide.md](tools_user_guide.md).

## Related Documentation

This package extends the shared infrastructure from **tom_build_base**:

- [CLI Tools Navigation](../../tom_build_base/doc/cli_tools_navigation.md) — Standard CLI commands, execution modes, and navigation options
- [Build Base User Guide](../../tom_build_base/doc/build_base_user_guide.md) — Configuration loading, project discovery, and workspace mode

---

## Table of Contents

- [Quick Start](#quick-start)
- [Installation](#installation)
- [Command Line Usage](#command-line-usage)
  - [Options](#options)
  - [Project Selection](#project-selection)
- [Execution Modes](#execution-modes)
  - [Project Mode](#project-mode)
  - [Workspace Mode](#workspace-mode)
  - [Sub-Workspace Handling](#sub-workspace-handling)
- [Execution Steps](#execution-steps)
  - [Pipelines](#pipelines)
  - [Direct Commands](#direct-commands)
  - [Mixed Execution](#mixed-execution)
- [Pipeline Configuration](#pipeline-configuration)
  - [Pipeline Properties](#pipeline-properties)
  - [Step Structure](#step-structure)
  - [Pipeline Phases](#pipeline-phases)
- [Built-in Commands](#built-in-commands)
  - [DCli Command](#dcli-command)
  - [Execute Command](#execute-command)
  - [Status Command](#status-command)
- [Command Prefix Matching](#command-prefix-matching)
- [Macros](#macros)
  - [Defining Macros](#defining-macros)
  - [Using Macros](#using-macros)
  - [Managing Macros](#managing-macros)
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

# Command prefix matching (unambiguous prefixes work)
buildkit :vers :comp          # Matches :versioner :compiler

# Execute shell command in each folder
buildkit -i :execute "echo ${folder.name}"
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
| `--build-order` | `-b` | Sort projects in dependency build order |
| `--project <path>` | `-p` | Project(s) to run on |
| `--root [dir]` | `-R` | Workspace root (bare: detected, path: specified workspace) |
| `--workspace-recursion` | `-w` | Shell out to sub-workspaces instead of skipping |
| `--inner-first-git` | `-i` | Scan git repos, process innermost (deepest) first |
| `--outer-first-git` | `-o` | Scan git repos, process outermost (shallowest) first |
| `--top-repo` | `-T` | Find topmost git repo by traversing up from current directory (requires `-i` or `-o`) |
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

## Execution Modes

BuildKit has two execution modes that affect default behavior and how projects are discovered.

### Project Mode

**Project Mode** is the default when running BuildKit without traversal options. It operates on the current directory with sensible defaults applied:

```bash
# These are equivalent in project mode:
buildkit :versioner :compiler
buildkit --scan . --recursive --build-order :versioner :compiler
```

Default behavior in Project Mode:
- Scans from current directory (`--scan .`)
- Scans recursively (`--recursive`)
- Processes projects in dependency order (`--build-order`)

### Workspace Mode

**Workspace Mode** is triggered when using any traversal option:

| Trigger | Description |
|---------|-------------|
| `-R` (bare) | Run from detected workspace root |
| `-R <path>` | Run in specified workspace (must have `buildkit_master.yaml`) |
| `-s <path>` | Scan from specified directory (when path ≠ "`.`") |
| `-i` | Scan git repos innermost first |
| `-o` | Scan git repos outermost first |

In Workspace Mode:
- No automatic defaults are applied
- You explicitly control scanning behavior
- Sub-workspaces are skipped by default

```bash
# Workspace mode examples:
buildkit -R :compiler                     # Run from workspace root
buildkit -R xternal/mod :compiler         # Run in sub-workspace
buildkit -s devops -r :versioner          # Scan specific folder
```

### Sub-Workspace Handling

Sub-workspaces are directories containing `buildkit_master.yaml`. They represent separate workspaces that may have their own build configuration.

**Default behavior:** Sub-workspaces are skipped during recursive scans, similar to `buildkit_skip.yaml`.

**To process sub-workspaces:** Use the `-w` / `--workspace-recursion` flag to shell out to each sub-workspace:

```bash
# Process all workspaces including sub-workspaces
buildkit -w -R :versioner :compiler

# What happens:
# 1. BuildKit runs in the main workspace
# 2. For each sub-workspace, it shells out: bk :versioner :compiler
# 3. Each sub-workspace uses its own buildkit_master.yaml configuration
```

This ensures each workspace is processed with its own configuration context.

---

## Execution Steps

BuildKit supports two types of execution steps that can be freely combined.

### Pipelines

Pipelines are named sequences of commands defined in `buildkit.yaml` or `buildkit_master.yaml`. They are invoked by name:

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

Pipelines are defined in `buildkit_master.yaml` (workspace level) or `buildkit.yaml` (project level) under the `buildkit:` key:

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

Built-in commands run the respective tools directly via their Dart implementation — no external process is spawned. The `dcli` and `git` commands are exceptions that spawn external processes.

| Command | Description |
|---------|-------------|
| `versioner` | Generate `version.versioner.dart` files with build metadata |
| `bumpversion` | Bump `pubspec.yaml` versions across projects |
| `compiler` | Cross-platform Dart compilation |
| `runner` | `build_runner` wrapper with builder filtering |
| `cleanup` | Clean generated and temporary files |
| `dependencies` | Dependency tree visualization |
| `pubget` | Run `dart pub get` on projects |
| `pubgetall` | Shortcut for `pubget --scan . --recursive` |
| `pubupdate` | Run `dart pub upgrade` on projects |
| `pubupdateall` | Shortcut for `pubupdate --scan . --recursive` |
| `publisher` | Show publishing status for all projects |
| `git` | Run git commands across all workspace repositories |
| `gitstatus` | Show git status for all repositories |
| `gitcommit` | Commit and push all repositories |
| `gitpull` | Pull latest from all repositories |
| `gitbranch` | Branch management across repositories |
| `gittag` | Tag management across repositories |
| `gitclean` | Clean untracked files from repositories |
| `gitcheckout` | Checkout branches/tags across repositories |
| `gitreset` | Reset repositories to specific state |
| `gitsync` | Sync (fetch + merge/rebase) all repositories |
| `status` | Show buildkit version, binary status, and git state |
| `dcli` | Execute Dart scripts/expressions via dcli |
| `execute` | Run shell commands in each folder with placeholder substitution (aliases: `exec`, `x`) |

Commands can include arguments in pipeline definitions:

```yaml
core:
  - commands:
      - versioner --no-git
      - compiler --dry-run
      - runner --command build
```

When a pipeline specifies `--project`, built-in commands automatically receive the project path (unless `--project` is already in their arguments). The `dcli` command is exempt from `--project` injection — it uses the working directory instead.

**Get help for a specific command:**

```bash
buildkit help :compiler
buildkit help :versioner
buildkit help :dcli
```

### DCli Command

The `dcli` command executes Dart scripts or expressions via the dcli runtime in each project directory.

**Syntax:**

```bash
buildkit :dcli <file|expression> [-init-source <file>] [-no-init-source]
bk :dcli <file|expression> [-init-source <file>] [-no-init-source]
```

Only `-init-source <file>` and `-no-init-source` are allowed in the buildkit context. All other dcli options are rejected.

#### Path Notations

| Notation | Resolves To | Example |
|----------|-------------|---------|
| `~w/path` | Workspace root | `~w/tool/setup.dart` → `<root>/tool/setup.dart` |
| `~s/path` | `_scripts/` folder | `~s/build_hook.dart` → `<root>/_scripts/build_hook.dart` |
| `::name` | `_scripts/bin/` folder | `::poll_binaries` → `<root>/_scripts/bin/poll_binaries.dart` |

If the filename has no extension, `.dart` is automatically appended.

#### Expression Mode

If the argument is wrapped in double quotes, it is treated as a Dart expression and always executed (no file existence check):

```bash
bk :dcli "print(DateTime.now())"
bk :dcli "print(Platform.operatingSystem)"
```

#### Optional Script Pattern

For file targets, the command is **only executed if the file exists**. If the file is not found, the step is silently skipped (returns success). This enables optional per-project build scripts:

```bash
# Only runs in projects that have a build_hook.dart script
bk :dcli build_hook.dart

# Run workspace-level script if it exists
bk :dcli ~s/pre_build.dart
```

#### Pipeline Usage

```yaml
buildkit:
  pipelines:
    build:
      executable: true
      precore:
        - commands:
            - dcli ~s/build_hook.dart -no-init-source
      core:
        - commands:
            - versioner
            - compiler
```

#### Compiler Usage

The dcli command can also be used in compiler `precompile` and `postcompile` sections:

```yaml
compiler:
  precompile:
    - command: dcli ~s/pre_compile.dart
  postcompile:
    - command: dcli ~s/post_compile.dart -no-init-source
```

### Execute Command

The `execute` command runs shell commands in each traversed folder with placeholder substitution. This is an internal command (no standalone executable).

**Aliases:** `exec`, `x`

**Syntax:**

```bash
buildkit -i :execute "echo ${folder.name}"
buildkit -i :execute --condition dart.exists "dart pub get"
buildkit -i :x "echo ${folder.name}"       # Using alias
```

**Options:**

| Option | Description |
|--------|-------------|
| `-c, --condition` | Boolean placeholder condition to filter folders |

**Placeholders:**

| Placeholder | Description |
|-------------|-------------|
| `${root}` | Workspace root path |
| `${folder}` | Current folder absolute path |
| `${folder.name}` | Current folder name (last segment) |
| `${folder.relative}` | Folder path relative to root |
| `${current-os}` | Operating system |
| `${current-arch}` | Architecture |
| `${current-platform}` | Combined platform |
| `${dart.exists}` | true if folder has pubspec.yaml |
| `${flutter.exists}` | true if folder has flutter project |
| `${git.exists}` | true if folder is a git repository |
| `${dart.name}` | Package name from pubspec.yaml |
| `${dart.version}` | Version from pubspec.yaml |
| `${git.branch}` | Current branch name |
| `${git.dirty}` | Whether repo has uncommitted changes |

**Ternary expressions:**

```bash
buildkit -i :execute "echo ${dart.publishable?(Ready to publish):(Local only)}"
```

> See [tools_user_guide.md — Execute](tools_user_guide.md#execute) for the full placeholder reference.

### Status Command

The `status` command shows the current buildkit version, binary installation status, and git repository state. This is an internal command (no standalone executable).

**Syntax:**

```bash
bk :status [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--json` | Output in JSON format |
| `-v`, `--verbose` | Show detailed file and commit information |
| `--skip-binaries` | Skip binary version checks |
| `--skip-git` | Skip git status checks |

**Output Sections:**

1. **Source Version** — Version, build number, git commit, build time, Dart SDK from `version.versioner.dart`
2. **Binary Status** — Checks each tool by running `<tool> --version`:
   - ✓ Current — Matches source version
   - ⚠ Outdated — Different version/build/commit
   - ✗ Unavailable — Not found in PATH
   - ? Non-conformant — Version format not recognized
3. **Git Status** — Pending changes and unpushed commits

**Examples:**

```bash
# Quick status check
bk :status

# Verbose with file and commit details
bk :status -v

# JSON output for scripting
bk :status --json

# Only check git status (faster)
bk :status --skip-binaries

# Scan all git repos in workspace
bk :status -i
```

**Example Output:**

```
╔═══════════════════════════════════════════════════════════════╗
║                     BUILDKIT STATUS                           ║
╚═══════════════════════════════════════════════════════════════╝

Source Version
──────────────
  Version:      1.6.0+11
  Git Commit:   abc1234
  Build Time:   2026-02-10T14:30:00.000Z
  Dart SDK:     3.10.4

Binary Status
─────────────
  ✓ Current (18): buildkit, buildsorter, bumpversion, ...
  ✗ Unavailable (7): gitcompare, gitmerge, ...

Git Status
──────────
  Pending Changes: 1 repo(s), 5 file(s)
    (Specify --verbose to see the 5 modified files)

  Unpushed Commits: 1 repo(s), 3 commit(s)
    (Specify --verbose to see the 3 unpushed commits)
```

---

## Macros

Macros are reusable command sequences that can be defined, expanded, and managed. They are stored in `buildkit_master.yaml` in the workspace root.

### Defining Macros

Use the `define` command to create a macro:

```bash
bk define cv=:versioner :compiler
bk define cvc=:cleanup :versioner :compiler
bk define test=:runner --command build
```

Macros support argument placeholders:

| Placeholder | Description |
|-------------|-------------|
| `$1` - `$9` | Positional arguments |
| `$$` | All arguments |

Example with placeholders:

```bash
bk define run=:runner --command $$
bk @run build          # Expands to: :runner --command build
bk @run clean build    # Expands to: :runner --command clean build
```

### Using Macros

Invoke a macro with the `@` prefix:

```bash
bk @cv                 # Expands to: :versioner :compiler
bk @cvc                # Expands to: :cleanup :versioner :compiler
bk @test               # Expands to: :runner --command build
```

Macros can be combined with other commands:

```bash
bk :cleanup @cv        # Run cleanup, then expand cv macro
bk @cv :compiler       # Expand macro, then run compiler again
```

### Managing Macros

**List all macros:**

```bash
bk defines
```

Output:

```text
Defined macros:
  cv=:versioner :compiler
  cvc=:cleanup :versioner :compiler
  test=:runner --command build
```

**Remove a macro:**

```bash
bk undefine cv
```

**Get help:**

```bash
bk help :define
bk help :undefine
bk help :defines
```

---

## Command Prefix Matching

Command names can be abbreviated to their shortest unambiguous prefix:

```bash
# These are equivalent:
buildkit :versioner :compiler
buildkit :vers :comp

# Prefix must be unambiguous:
buildkit :git         # Ambiguous: gitstatus, gitcommit, gitpull, ...
buildkit :gitstatus   # Exact match: OK
buildkit :gitst       # Unambiguous prefix: matches gitstatus
```

**Rules:**
- Exact matches (name or alias) always take priority over prefix matches
- If a prefix matches multiple commands, BuildKit reports the ambiguity and lists all matching commands
- Aliases are also checked for prefix matching (e.g., `:ex` matches `:execute` via the `exec` alias)

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

BuildKit provides comprehensive git repository management through both a low-level `:git` command and high-level specialized git tools.

### Git Traversal Modes

Git tools require explicit traversal order for correct operation with nested repositories:

| Flag | Short | Order |
|------|-------|-------|
| `--inner-first-git` | `-i` | Deepest (innermost) repositories first |
| `--outer-first-git` | `-o` | Shallowest (outermost) repositories first |

**Choosing traversal mode:**

| Operation | Mode | Reasoning |
|-----------|------|-----------|  
| Commit/Push | Inner-first (`-i`) | Commit submodules first so parent records updated hashes |
| Pull/Sync | Outer-first (`-o`) | Pull parent first to get correct submodule refs |
| Checkout/Reset | Outer-first (`-o`) | Parent determines which submodule versions to use |

### Specialized Git Tools

These standalone tools provide purpose-built git operations:

| Tool | Default Mode | Purpose |
|------|-------------|--------|
| `gitstatus` | Either | Show status for all repositories |
| `gitcommit` | Inner-first | Commit and push all repositories |
| `gitpull` | Outer-first | Pull latest from all repositories |
| `gitbranch` | Inner-first | Branch management |
| `gittag` | Inner-first | Tag management |
| `gitclean` | Inner-first | Clean untracked files |
| `gitcheckout` | Outer-first | Checkout branches/tags |
| `gitreset` | Outer-first | Reset to specific state |
| `gitsync` | Outer-first | Fetch + merge/rebase |

**Standalone binaries auto-inject the recommended traversal flag** when not specified.

**Examples:**

```bash
# Check status of all repos
gitstatus
buildkit :gitstatus -i

# Commit all repos
gitcommit -m "Fix bug"
buildkit :gitcommit -i -m "Fix bug"

# Pull all repos
gitpull
buildkit :gitpull -o

# Create feature branch everywhere
gitbranch --create feature/new-ui
```

> See [tools_user_guide.md — Git Tools](tools_user_guide.md#git-tools) for complete documentation.

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

**DCli --stdin mode:** You can also use stdin piping with `dcli --stdin` to execute inline Dart code without creating script files. DCli's `--stdin` mode auto-detects the input format (bare statements, main with no imports, or complete script):

```yaml
core:
  - commands:
      - |
        stdin dcli --stdin
        print("First line");
        print("Second line");
```

> **Note:** `stdin dcli --stdin` uses the **stdin piping mechanism** (shell command with piped input), while `:dcli` or `dcli` in pipeline commands uses the **built-in dcli command** with path resolution and file existence checking. They serve different purposes — stdin piping is for inline code, the built-in command is for script files.

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

Projects with `buildkit_skip.yaml` are automatically skipped. Master YAML `navigation.exclude-projects` patterns are merged automatically.

---

## Configuration Hierarchy

Configuration is loaded in priority order:

| Priority | Source | Merge Behavior |
|----------|--------|----------------|
| 1 (highest) | **Command-line arguments** | Overrides all |
| 2 | **Project `buildkit.yaml`** | **Replaces** workspace pipelines for matching names |
| 3 (lowest) | **Workspace `buildkit_master.yaml`** | Base pipeline definitions |

**Important:** Project-level pipeline definitions **completely replace** workspace-level definitions for the same pipeline name — there is no merging of pipeline steps across levels.

**Allowed binaries** are **additive** across internal defaults, workspace config, and project config.

---

## Command Security

BuildKit enforces strict command security:

1. **Built-in commands** — Always allowed (`versioner`, `compiler`, etc.)
2. **Configured pipelines** — Pipeline names from `buildkit.yaml` / `buildkit_master.yaml`
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

### DCli Script Execution

```bash
# Run a workspace-level script in every project (skips if file doesn't exist)
bk :dcli ~s/build_hook.dart

# Run a script from _scripts/bin/
bk :dcli ::poll_binaries

# Run per-project optional script
bk :dcli build_step.dart

# Run a Dart expression in every project
bk :dcli "print(DateTime.now())"

# Combine with other steps
bk :versioner :dcli ~s/pre_compile.dart :compiler
```

### DCli in Pipeline Configuration

```yaml
buildkit:
  pipelines:
    build:
      precore:
        - commands:
            - dcli ~s/build_hook.dart -no-init-source
      core:
        - commands:
            - versioner
            - compiler
      postcore:
        - commands:
            - dcli ~s/post_build.dart
```

### DCli via Stdin in Pipeline

```yaml
buildkit:
  pipelines:
    test-dcli:
      executable: true
      core:
        - commands:
            - |
              stdin dcli --stdin
              print("First line");
              print("Second line");
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
