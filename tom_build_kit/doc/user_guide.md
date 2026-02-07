# Tom Build Kit User Guide

Tom Build Kit is a pipeline-based build orchestration tool for the Tom workspace. It provides a unified interface to run build pipelines and individual build tools in sequence.

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Command Line Usage](#command-line-usage)
- [Execution Steps](#execution-steps)
- [Pipeline Configuration](#pipeline-configuration)
- [Built-in Commands](#built-in-commands)
- [Shell Commands](#shell-commands)
- [Platform Filtering](#platform-filtering)
- [Project Scanning](#project-scanning)
- [Configuration Hierarchy](#configuration-hierarchy)
- [Examples](#examples)

## Installation

Build Kit is part of the Tom workspace build tools. To use it:

```bash
# Run directly with dart
dart run tom_build_kit:buildkit [options] <steps>

# Or compile to executable
dart compile exe bin/buildkit.dart -o buildkit
```

## Quick Start

```bash
# Run a single pipeline
buildkit build

# Run multiple pipelines in sequence
buildkit clean build

# Run tool commands directly
buildkit :versioner :compiler

# Mix pipelines and commands
buildkit build :cleanup --all

# Dry-run to see what would be executed
buildkit -n build :versioner
```

## Command Line Usage

```
Usage: buildkit [options] <pipeline|:command> [args...] [<pipeline|:command> [args...]]...

Steps can be:
  <pipeline>        Run a pipeline defined in tom_build.yaml
  :<command> [args] Run a tool command directly (versioner, compiler, etc.)

Options:
  -h, --help         Show help
  -V, --version      Show version
  -v, --verbose      Verbose output
  -n, --dry-run      Show what would be executed
  -l, --list         List available pipelines
  -R, --recursive    Scan directories recursively
  -s, --scan         Scan directory for projects to run pipeline in
  -r, --root         Root directory for configuration lookup
  -p, --project      Project directory (defaults to current directory)
```

## Execution Steps

Build Kit supports two types of execution steps:

### Pipelines

Pipelines are named sequences of commands defined in `tom_build.yaml`. They are invoked by name:

```bash
buildkit build         # Run the "build" pipeline
buildkit clean build   # Run "clean" then "build" pipelines
```

### Direct Commands

Tool commands can be invoked directly using the `:` prefix. This runs the tool without needing a pipeline definition:

```bash
buildkit :versioner                    # Run versioner
buildkit :compiler --target myapp      # Run compiler with arguments
buildkit :versioner :compiler :runner  # Run multiple tools in sequence
```

**Available commands:**
- `:versioner` - Generate version files from pubspec.yaml
- `:compiler` - Compile Dart projects to native executables
- `:runner` - Run build_runner for code generation
- `:astgen` - Generate AST files for D4rt
- `:d4rtgen` - Generate D4rt bridge code
- `:cleanup` - Clean build artifacts

### Mixed Execution

Pipelines and commands can be mixed freely:

```bash
buildkit build :cleanup --all :versioner
```

This runs:
1. The `build` pipeline
2. The `cleanup` command with `--all` argument
3. The `versioner` command

### Output Format

Each step is clearly separated in the output:

```
________ Running build

[pipeline output...]

________ Running :cleanup --all

[cleanup output...]

________ Running :versioner

[versioner output...]
```

## Pipeline Configuration

Pipelines are defined in `tom_build.yaml`:

```yaml
buildkit:
  pipelines:
    clean:
      executable: true
      core:
        - commands:
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

| Property | Type | Description |
|----------|------|-------------|
| `executable` | bool | Whether the pipeline can be invoked from command line (default: true) |
| `runBefore` | string/list | Pipeline(s) to run before this one |
| `runAfter` | string/list | Pipeline(s) to run after this one |
| `precore` | list | Steps to run before core (can be extended at project level) |
| `core` | list | Main pipeline steps |
| `postcore` | list | Steps to run after core (can be extended at project level) |

### Step Structure

Each step in precore/core/postcore is a map with:

```yaml
core:
  - commands:
      - versioner
      - compiler
    platforms:
      - darwin-arm64
      - linux-x64
```

| Property | Type | Description |
|----------|------|-------------|
| `commands` | list | Commands to execute in this step |
| `platforms` | list | Platforms this step applies to (empty = all platforms) |

## Built-in Commands

Built-in commands are Tom workspace tools that can be invoked within pipelines:

| Command | Description |
|---------|-------------|
| `versioner` | Generate version.g.dart from pubspec.yaml |
| `compiler` | Compile Dart to native executables |
| `runner` | Run build_runner for code generation |
| `astgen` | Generate AST files for D4rt |
| `d4rtgen` | Generate D4rt bridge code |
| `cleanup` | Clean build artifacts |

Commands can include arguments:

```yaml
core:
  - commands:
      - versioner --no-git
      - compiler --dry-run
      - runner --command build
```

## Shell Commands

Shell commands are prefixed with `shell`:

```yaml
core:
  - commands:
      - shell rm -rf build/
      - shell echo "Build complete"
      - shell rsync -av dist/ server:/app/
```

### Variable Expansion

Shell commands support variable expansion:

| Variable | Description |
|----------|-------------|
| `${project}` | Path to the current project directory |
| `${root}` | Path to the workspace root directory |
| `${current-platform-vs}` | VS Code platform format (e.g., `darwin-arm64`) |
| `${current-os}` | Operating system (e.g., `macos`, `linux`, `windows`) |

Example:

```yaml
core:
  - commands:
      - shell cp build/app ${root}/_bin/${current-platform-vs}/
```

## Platform Filtering

Steps can be filtered by platform:

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
| `*-arm64` | All ARM64 platforms (glob pattern) |

## Project Scanning

Build Kit can scan directories to find projects:

```bash
# Scan current directory for projects
buildkit build --scan .

# Scan recursively (into nested projects)
buildkit build --scan . --recursive

# Short form
buildkit build -s . -R
```

### Scan Behavior

**Always skips:**
- `.dart_tool`, `.git`, `.idea`, `.vscode`
- `build`, `node_modules`, `coverage`
- `.pub-cache`, `.pub`, `__pycache__`
- Hidden directories (starting with `.`)

**Inside projects (with `--recursive`):**
- Source dirs: `bin`, `lib`, `src`
- Build dirs: `build`, `out`, `dist`
- Asset dirs: `assets`, `fonts`, `images`
- Platform dirs: `android`, `ios`, `macos`, `windows`, `linux`, `web`

## Configuration Hierarchy

Configuration is loaded in priority order:

1. **Command-line arguments** (highest priority)
2. **Project-level `tom_build.yaml`** (in each project folder)
3. **Workspace-level `tom_build.yaml`** (at workspace root)
4. **Tool defaults** (lowest priority)

Project-level pipelines completely replace workspace-level definitions (no merging).

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

### Clean and Build

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
buildkit build  # Automatically runs clean first
```

### Cross-Platform Build

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
buildkit :versioner --no-git :compiler --dry-run
```

### Workspace-Wide Build

```bash
# Build all projects in workspace
buildkit build --scan . --recursive

# List projects that would be processed
buildkit build -s . -R --list
```

### Dry Run

```bash
# See what would be executed
buildkit -n build :versioner

# Output:
# ________ Running build
# [DRY RUN] Would run versioner with args: []
# [DRY RUN] Would run runner with args: []
# [DRY RUN] Would run compiler with args: []
#
# ________ Running :versioner
# [DRY RUN] Would run versioner with args: []
```
