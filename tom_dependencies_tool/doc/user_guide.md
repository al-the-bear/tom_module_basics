# Dependency Tree Tool (dependencies) - User Guide

The `dependencies` tool visualizes Dart project dependency trees, showing dependencies from `pubspec.yaml` with overrides from `pubspec_overrides.yaml`.

## Overview

- Display direct dependencies or full dependency trees
- Show normal dependencies, dev dependencies, or both
- Highlight dependency overrides with bracketed notation
- Detect and display circular dependencies
- Support glob patterns for analyzing multiple projects

## Installation

The tool is part of the `tom_dependencies_tool` package:

```bash
# Run directly with dart
dart run tom_dependencies_tool:dependencies [options]

# Or compile to executable
dart compile exe bin/dependencies.dart -o dependencies
```

## Quick Start

```bash
# Show dependencies for current project
dependencies

# Show only dev dependencies
dependencies --dev

# Show all dependencies (normal + dev)
dependencies --all

# Show full dependency tree (recursive)
dependencies --deep

# Analyze specific project
dependencies --project=my_app

# Show help
dependencies --help
```

## Command-Line Options

| Option | Short | Description |
|--------|-------|-------------|
| `--project=<pattern>` | `-p` | Project(s) to analyze (comma-separated, globs) |
| `--scan=<dir>` | `-s` | Directory to scan for projects |
| `--recursive` | `-r` | Process subprojects recursively |
| `--exclude=<glob>` | `-e` | Glob patterns for projects to exclude |
| `--recursion-exclude` | | Glob patterns to exclude from recursive traversal |
| `--dev` | `-d` | Show only dev dependencies |
| `--all` | `-a` | Show both normal and dev dependencies |
| `--deep` | `-D` | Show full dependency tree (recursive) |
| `--verbose` | `-v` | Show detailed output |
| `--list` | `-l` | List projects that would be processed (no action) |
| `--help` | `-h` | Show help message |
| `--version` | | Show version information |

### Project Selection (`--project`)

The `--project` option supports multiple ways to specify projects:

- **Single project**: `--project=my_app`
- **Comma-separated**: `--project='project1,project2,project3'`
- **Glob patterns**: `--project='tom_*'`
- **Path globs**: `--project='packages/*'`
- **Current directory children**: `--project='./*'`
- **Recursive from current directory**: `--project='./**/*'`

Multiple patterns can be combined: `--project='tom_*,my_app'`

## Output Format

### Dependency Prefixes

| Prefix | Meaning |
|--------|---------|
| `->` | Normal dependency |
| `+>` | Dev dependency |

### Override Notation

When a dependency has an override in `pubspec_overrides.yaml`, the override source is shown in square brackets:

```
tom_d4rt: ^1.4.0 [path: ../tom_d4rt]
```

This shows:
- Original source: `^1.4.0` (from `pubspec.yaml`)
- Override: `path: ../tom_d4rt` (from `pubspec_overrides.yaml`)

### Circular Dependencies

In deep mode, circular dependencies are detected and shown with `... (circular)`:

```
my_project:
   -> package_a: path: ../package_a
      -> package_b: path: ../package_b
         -> package_a: ... (circular)
```

## Dependency Display Modes

### Default Mode (Normal Dependencies Only)

```bash
dependencies
```

Shows only regular dependencies:

```
my_project:
   -> args: ^2.7.0
   -> path: ^1.9.0
   -> yaml: ^3.1.2
```

### Dev Dependencies Only (`--dev`)

```bash
dependencies --dev
```

Shows only development dependencies:

```
my_project:
   +> lints: ^6.0.0
   +> test: ^1.25.6
```

### All Dependencies (`--all`)

```bash
dependencies --all
```

Shows both normal and dev dependencies, sorted by category then name:

```
my_project:
   -> args: ^2.7.0
   -> path: ^1.9.0
   -> yaml: ^3.1.2
   +> lints: ^6.0.0
   +> test: ^1.25.6
```

### Deep Mode (`--deep`)

```bash
dependencies --deep
```

Shows the complete dependency tree by recursively resolving path dependencies:

```
my_project:
   -> tom_build_base: path: ../tom_build_base
      -> glob: ^2.1.3
      -> path: ^1.9.0
      -> yaml: ^3.1.3
   -> args: ^2.7.0
   -> yaml: ^3.1.2
```

**Note:** Deep mode only resolves path dependencies (local packages). Published packages from pub.dev show their version without sub-dependencies.

## Dependency Sources

The tool recognizes different dependency source types:

| Source Type | Display Format |
|-------------|----------------|
| Version constraint | `^1.0.0`, `>=1.0.0 <2.0.0` |
| Path | `path: ../my_package` |
| Git | `git: https://github.com/user/repo` |
| Git with ref | `git: https://github.com/user/repo @main` |
| Git with path | `git: https://github.com/user/repo (packages/sub)` |
| SDK | `sdk: flutter` |
| Hosted | `^1.0.0 (hosted: custom.pub.dev)` |
| Any | `any` (when no constraint specified) |

## Examples

### Basic Usage

```bash
# Analyze current project
dependencies

# Analyze specific project
dependencies --project=tom_build_base
```

### Multi-Project Analysis

```bash
# Analyze all tom_* projects
dependencies --project='tom_*'

# Analyze multiple specific projects
dependencies --project='tom_build_base,tom_build_kit'

# Scan workspace for all projects
dependencies --scan=. --recursive
```

### Deep Analysis with Filters

```bash
# Full tree with all dependencies
dependencies --deep --all

# Full tree of dev dependencies only
dependencies --deep --dev

# Deep analysis of specific projects
dependencies --project='tom_*_builder' --deep
```

### List Mode

```bash
# Preview which projects would be analyzed
dependencies --project='tom_*' --list

# Output:
# Dependencies projects (5):
#   xternal/tom_module_basics/tom_build_base
#   xternal/tom_module_basics/tom_build_kit
#   ...
```

## Practical Use Cases

### Check for Path Dependencies

Find which projects use local path dependencies (useful before publishing):

```bash
dependencies --all | grep "path:"
```

### Verify Override Configuration

Check that pubspec_overrides.yaml is correctly set up for development:

```bash
dependencies --all --verbose
```

### Audit Dev Dependencies

Review development dependencies across projects:

```bash
dependencies --project='./*' --dev
```

### Investigate Dependency Chains

Understand how dependencies are connected:

```bash
dependencies --deep --verbose
```

## Notes

### Path Dependency Resolution

In deep mode, only path dependencies can be recursively resolved. For published packages (version constraints), the tool shows the version but cannot traverse into their sub-dependencies.

For complete transitive dependency analysis of published packages, use:

```bash
dart pub deps
```

### Sorting

Dependencies are sorted by:
1. Category (normal dependencies first, then dev dependencies)
2. Alphabetically by package name

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Error (invalid arguments, file not found, etc.) |
