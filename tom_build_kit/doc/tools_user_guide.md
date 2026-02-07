# Tom Build Kit — Tools User Guide

Comprehensive guide for all tools in the `tom_build_kit` package.

---

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Common CLI Options](#common-cli-options)
- [Configuration Files](#configuration-files)
  - [tom_build.yaml](#tom_buildyaml)
  - [build.yaml](#buildyaml)
- [Config Precedence](#config-precedence)
- [Tools](#tools)
  - [Cleanup](#cleanup)
  - [Compiler](#compiler)
  - [Dependencies](#dependencies)
  - [Runner](#runner)
  - [Versioner](#versioner)
- [BuildKit Orchestrator](#buildkit-orchestrator)
  - [Pipelines](#pipelines)
  - [Per-Tool Option Override](#per-tool-option-override)
  - [Direct Commands](#direct-commands)

---

## Overview

Tom Build Kit consolidates five build tools into a single package:

| Tool | Purpose |
|------|---------|
| **cleanup** | Remove generated and temporary files |
| **compiler** | Cross-platform Dart compilation with pre/post-compile commands |
| **dependencies** | Dependency tree visualization |
| **runner** | `build_runner` wrapper with project scanning and builder filtering |
| **versioner** | Generate `version.g.dart` files with build metadata |

All tools share a common base (project discovery, argument parsing, config loading) and can be invoked either standalone or through the **buildkit** orchestrator.

---

## Installation

Each tool has a standalone executable and can also be invoked via buildkit:

```bash
# Standalone
dart run tom_build_kit:versioner [options]
dart run tom_build_kit:cleanup [options]
dart run tom_build_kit:compiler [options]
dart run tom_build_kit:runner [options]
dart run tom_build_kit:dependencies [options]

# Via buildkit orchestrator
dart run tom_build_kit:buildkit :versioner [options]
dart run tom_build_kit:buildkit :cleanup [options]
```

---

## Common CLI Options

All tools share these options:

| Flag | Short | Description |
|------|-------|-------------|
| `--help` | `-h` | Show help text |
| `--verbose` | `-v` | Verbose output |
| `--project <path>` | `-p` | Project directory or glob pattern |
| `--scan <dir>` | `-s` | Scan directory for projects |
| `--recursive` | `-R` | Scan recursively |
| `--exclude <pattern>` | `-x` | Exclude patterns (multi-option) |
| `--recursion-exclude <pattern>` | | Exclude patterns during recursive scan |
| `--list` | `-l` | List matching projects |
| `--show` | | Show configuration for projects |
| `--dry-run` | `-n` | Show what would be done |

### Version Flag

All tools support `--version`, `-version`, or `version` as the first argument:

```bash
versioner --version
# Output: versioner 1.0.0+4.b54e489 (2026-02-07T09:54:50.320327Z) [Dart 3.10.4]
```

### Project Discovery

**Single project:**
```bash
versioner --project ./my_package
```

**Glob pattern:**
```bash
versioner --project "tom_*"
```

**Scan directory:**
```bash
versioner --scan . --recursive
```

**Exclude patterns (glob-based):**
```bash
versioner --scan . -R --exclude "zom_*" --exclude "xternal/**"
```

---

## Configuration Files

### tom_build.yaml

The primary configuration file, placed at the workspace root or in individual project directories. Each tool reads its section by key:

```yaml
# Versioner config
versioner:
  output: lib/src/version.g.dart
  includeGitCommit: true
  scan: .
  recursive: true
  exclude:
    - zom_*

# Cleanup config
cleanup:
  cleanup:
    - build
    - .dart_tool/build
    - "**/*.g.dart"
  excludes:
    - lib/src/version.g.dart

# Compiler config
compiler:
  scan: .
  recursive: true

# Build runner config
build_runner:
  command: build
  delete-conflicting: true
  scan: .
  recursive: true
  include-builders:
    - tom_build_kit

# Builder filter config (for runner)
tom_build_kit:
  build_runner:
    include-builders:
      - json_serializable
    exclude-builders:
      - source_gen
```

### build.yaml

Standard `build_runner` configuration file. Used by the builder variants and also read by CLI tools for per-project config:

```yaml
targets:
  $default:
    builders:
      tom_build_kit:version_builder:
        enabled: true
        options:
          output: lib/src/version.g.dart
          includeGitCommit: true

      tom_build_kit:compiler_builder:
        enabled: true
        options:
          compiles:
            - files: [bin/my_tool.dart]
              targets: [linux-x64, darwin-arm64]
              commandlines:
                - dart compile exe ${file} -o build/${file.name}_${target-platform-vs} --target=${target-platform}

      tom_build_kit:cleanup_builder:
        enabled: true
        options:
          cleanup:
            - build
            - .dart_tool/build
          excludes:
            - lib/src/version.g.dart
```

---

## Config Precedence

Configuration is loaded in layers, with later layers overriding earlier ones:

1. **Workspace root** `tom_build.yaml` — base defaults
2. **Per-project** `tom_build.yaml` — project-specific overrides
3. **Per-project** `build.yaml` — builder-specific options
4. **CLI arguments** — highest priority

---

## Tools

### Cleanup

Removes generated and temporary files from Dart projects with two-pass safety checking.

**Usage:**
```bash
cleanup [options]
buildkit :cleanup [options]
```

**Tool-specific options:**

| Flag | Short | Description |
|------|-------|-------------|
| `--force` | `-f` | Skip safety check on file count |
| `--max-files <n>` | `-m` | Maximum files to delete without `--force` (default: 10) |

**tom_build.yaml:**
```yaml
cleanup:
  cleanup:
    - build
    - .dart_tool/build
    - "**/*.freezed.dart"
    - globs: ["**/*.g.dart"]
      excludes: ["lib/src/version.g.dart"]
  excludes:
    - lib/src/version.g.dart
```

Cleanup sections can be:
- A simple string (glob pattern)
- A map with `globs` and optional `excludes` keys
- A direct YAML list under `cleanup:` key

**Safety features:**
- Two-pass: first collects files, then deletes
- `--max-files` limit (default: 10) prevents accidental mass deletion
- `--force` to override the safety check
- `--dry-run` to preview what would be deleted

**build.yaml:**
```yaml
targets:
  $default:
    builders:
      tom_build_kit:cleanup_builder:
        options:
          cleanup:
            - build
          excludes:
            - lib/src/version.g.dart
```

---

### Compiler

Cross-platform Dart compilation with configurable pre-compile and post-compile command sequences.

**Usage:**
```bash
compiler [options]
buildkit :compiler [options]
```

**Tool-specific options:**

| Flag | Short | Description |
|------|-------|-------------|
| `--targets <list>` | `-t` | Target platforms (comma-separated) |

**build.yaml:**
```yaml
targets:
  $default:
    builders:
      tom_build_kit:compiler_builder:
        options:
          precompile:
            - platforms: [darwin-arm64]
              commandlines:
                - echo "Pre-compile for macOS ARM64"
          compiles:
            - files:
                - bin/my_tool.dart
              targets:
                - linux-x64
                - darwin-arm64
                - windows-x64
              commandlines:
                - dart compile exe ${file} -o build/${file.name}_${target-platform-vs} --target=${target-platform}
          postcompile:
            - commandlines:
                - echo "Build complete"
```

**Placeholders in command lines:**

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `${file}` | Source file path | `bin/my_tool.dart` |
| `${file.path}` | Same as `${file}` | `bin/my_tool.dart` |
| `${file.name}` | File name without extension | `my_tool` |
| `${file.basename}` | File name with extension | `my_tool.dart` |
| `${file.extension}` | File extension | `.dart` |
| `${file.dir}` | File directory | `bin` |
| `${target-os}` | Target OS | `macos`, `linux`, `windows` |
| `${target-arch}` | Target architecture | `x64`, `arm64` |
| `${target-platform}` | Dart target format | `macos-arm64` |
| `${target-platform-vs}` | VS Code format | `darwin-arm64` |
| `${current-os}` | Current OS | `macos` |
| `${current-arch}` | Current architecture | `arm64` |
| `${current-platform}` | Current platform (Dart format) | `macos-arm64` |
| `${current-platform-vs}` | Current platform (VS Code format) | `darwin-arm64` |

Bracket format `[placeholder]` is also supported: `[file]`, `[target-os]`, etc.

**Environment variables** are replaced in commands:
- `$HOME`, `$USER`, `$PATH` — standard `$VAR` format
- `[HOME]`, `[USER]` — bracket `[VAR]` format

**Platform filtering:**

Each compile/precompile/postcompile section can have a `platforms:` list to restrict execution:
```yaml
precompile:
  - platforms: [darwin-arm64, darwin-x64]
    commandlines:
      - codesign --remove-signature build/my_tool
```

---

### Dependencies

Dependency tree visualization for Dart projects. Reads `pubspec.yaml` and `pubspec_overrides.yaml`.

**Usage:**
```bash
dependencies [options]
buildkit :dependencies [options]
```

**Tool-specific options:**

| Flag | Short | Description |
|------|-------|-------------|
| `--dev` | `-d` | Show only dev dependencies |
| `--all` | `-a` | Show all dependency types |
| `--deep` | `-D` | Show recursive dependency tree |

**Output format:**
```
my_package (my_package):
  -> path: ^1.9.0
  -> yaml: ^3.1.0
  +> test: ^1.25.0
  +> lints: ^4.0.0
```

Legend:
- `->` normal dependency
- `+>` dev dependency
- `[override: ...]` shows dependency overrides

**Deep mode** (`--deep`) resolves path dependencies recursively, showing the full transitive dependency tree with circular dependency detection.

---

### Runner

`build_runner` wrapper with multi-project scanning and 4-level builder include/exclude filtering.

**Usage:**
```bash
runner [options]
buildkit :runner [options]
```

**Tool-specific options:**

| Flag | Short | Description |
|------|-------|-------------|
| `--command <cmd>` | `-c` | Build runner command: `build`, `watch`, `clean` (default: `build`) |
| `--include-builders <list>` | `-i` | Include specific builders |
| `--exclude-builders <list>` | | Exclude specific builders |
| `--config <name>` | | Build runner config name |
| `--release` | | Build in release mode |
| `--delete-conflicting` | | Delete conflicting outputs (default: true) |

**tom_build.yaml:**
```yaml
build_runner:
  command: build
  delete-conflicting: true
  scan: .
  recursive: true
```

**Builder filter precedence (4 levels):**

1. **CLI args** — `--include-builders` / `--exclude-builders`
2. **build.yaml** — `tom_build_kit.build_runner` section
3. **Project tom_build.yaml** — `build_runner` section
4. **Root tom_build.yaml** — `build_runner` section

**build.yaml filter config:**
```yaml
tom_build_kit:
  build_runner:
    include-builders:
      - json_serializable
      - freezed
```

**Builder matching** uses fuzzy substring matching: `json_serializable` matches `json_serializable:json_serializable` and vice versa.

---

### Versioner

Generates `version.g.dart` files with build metadata from `pubspec.yaml`.

**Usage:**
```bash
versioner [options]
buildkit :versioner [options]
```

**Tool-specific options:**

| Flag | Short | Description |
|------|-------|-------------|
| `--output <path>` | `-o` | Output file path (default: `lib/src/version.g.dart`) |
| `--no-git` | | Skip git commit hash |
| `--version <ver>` | | Override version string |

**tom_build.yaml:**
```yaml
versioner:
  output: lib/src/version.g.dart
  includeGitCommit: true
  scan: .
  recursive: true
```

**Generated file format:**

```dart
// GENERATED FILE - DO NOT EDIT
// Generated by versioner at 2026-02-07T09:54:50.320327Z

class TomVersionInfo {
  TomVersionInfo._();

  static const String version = '1.0.0';
  static const String buildTime = '2026-02-07T09:54:50.320327Z';
  static const String gitCommit = 'b54e489';
  static const int buildNumber = 4;
  static const String dartSdkVersion = '3.10.4';

  static String get versionShort => '$version+$buildNumber';
  static String get versionMedium => '$version+$buildNumber.$gitCommit ($buildTime)';
  static String get versionLong => '$version+$buildNumber.$gitCommit ($buildTime) [Dart $dartSdkVersion]';
}
```

**Build state:** The build number is tracked in `tom_build_state.json` in each project directory and increments with each build.

---

## BuildKit Orchestrator

The `buildkit` command orchestrates multi-step build pipelines.

**Usage:**
```bash
buildkit [options] <pipeline|:command> [args...]
```

**Options:**

| Flag | Short | Description |
|------|-------|-------------|
| `--help` | `-h` | Show help |
| `--version` | `-V` | Show version |
| `--verbose` | `-v` | Verbose output |
| `--dry-run` | `-n` | Show what would be executed |
| `--list` | `-l` | List available pipelines |
| `--scan <dir>` | `-s` | Scan directory for projects |
| `--project <path>` | `-p` | Project(s) to run on |
| `--recursive` | `-R` | Scan recursively |
| `--root <dir>` | `-r` | Root directory for config lookup |

### Pipelines

Define pipelines in `tom_build.yaml`:

```yaml
buildkit:
  pipelines:
    clean:
      executable: true
      core:
        - commands:
            - cleanup
    build:
      executable: true
      runBefore: clean
      core:
        - commands:
            - versioner
            - compiler
    deploy:
      executable: true
      runAfter: build
      precore:
        - commands:
            - shell echo "Preparing..."
      core:
        - commands:
            - shell rsync -av build/ server:/app/
```

**Pipeline sections:**
- `precore:` — runs before the main commands
- `core:` — main command sequence
- `postcore:` — runs after the main commands
- `runBefore:` — pipeline to run before this one
- `runAfter:` — pipeline to run after this one
- `executable: true` — makes pipeline visible in `--list`

**Command types in pipelines:**
- `versioner` — run the versioner tool
- `compiler` — run the compiler tool
- `runner` — run the build runner tool
- `cleanup` — run the cleanup tool
- `dependencies` — run the dependencies tool
- `shell <command>` — run a shell command
- `<pipeline-name>` — call another pipeline

### Direct Commands

Use `:` prefix to invoke tools directly:

```bash
buildkit :versioner --project my_package
buildkit :cleanup --scan . -R :compiler --project my_tool
```

### Per-Tool Option Override

When chaining commands, global options (like `--scan`) are inherited. Use `-X-` syntax to suppress a specific option for one command:

```bash
# Scan with cleanup but NOT with compiler
buildkit -s . :cleanup -s- --project tom_* :compiler

# Verbose for versioner but not for runner
buildkit -v :versioner :runner -v-
```

The `-X-` syntax works for any single-letter option:
- `-s-` suppresses `--scan`
- `-v-` suppresses `--verbose`
- `-n-` suppresses `--dry-run`
