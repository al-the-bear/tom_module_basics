# Tom Compiler Builder - User Guide

The `compiler` tool provides cross-platform compilation support for Dart projects with configurable build targets and platform filtering.

## Overview

Tom Compiler Builder enables:
- Cross-compilation to multiple target platforms
- Platform-specific compilation commands
- Command template system with placeholders
- Environment variable substitution
- Project auto-discovery and scanning
- Multiple commands per compilation (e.g., compile + chmod)

## Quick Start

```bash
# Check version
compiler version

# Compile current project
compiler

# Compile specific project
compiler --project=my_app

# Compile multiple projects (comma-separated, globs)
compiler --project='tom_*_builder,my_app'

# Compile only for current platform (faster dev builds)
compiler --targets=darwin-arm64

# Compile for specific platforms
compiler --targets=darwin-arm64,linux-x64

# Scan and compile all projects
compiler --scan=. --recursive

# Show help
compiler --help
```

## Configuration

The tool uses a two-tier configuration pattern:

### 1. Project Discovery - tom_build.yaml (Optional)

Create a `tom_build.yaml` file in your project root for CLI options:

```yaml
# tom_build.yaml
compiler:
  project: .
  scan: ../
  recursive: true
  verbose: false
```

**CLI Options:**
- `project`: Path to specific project
- `scan`: Directory to scan for projects
- `recursive`: Process subprojects recursively
- `exclude`: Glob patterns for projects to exclude
- `recursion-exclude`: Patterns to exclude from recursive traversal
- `verbose`: Show detailed output

### 2. Compilation Configuration - build.yaml

Define compilation targets in `build.yaml`:

```yaml
targets:
  $default:
    builders:
      tom_compiler_builder:compiler_builder:
        enabled: true
        options:
          compiles:
            - commandline:
                - mkdir -p $HOME/.tom/bin/${target-platform-vs}
                - dart compile exe ${file} --target-os=${target-os} -o $HOME/.tom/bin/${target-platform-vs}/${file.name}
              files: [bin/app.dart, bin/tool.dart]
              targets: [darwin-arm64, linux-x64, win32-x64]
              platforms: [darwin-*, linux-*]

          postcompile:
            - commandline:
                - chmod -R +x $HOME/.tom/bin/${current-platform-vs}/
              platforms: [macos, linux]
```

## Configuration Fields

### `precompile` (list, optional)

Commands to run BEFORE compilation starts. Runs once per project.

```yaml
precompile:
  - commandline:
      - echo "Starting compilation..."
    platforms: [macos, linux]
```

**Fields:**
- `commandline` (string or list, required): Commands to execute
- `platforms` (string or list, optional): Host platforms where this runs

**Available placeholders:** `${current-os}`, `${current-arch}`, `${current-platform}`, `${current-platform-vs}`

### `compiles` (list, required)

List of compilation configurations, each with:

#### `commandline` (string or list, required)

Command template with placeholders. Can be a single string or a list for multiple commands (executed sequentially with fail-fast):

**File placeholders:**
- `${file}` - Full source file path
- `${file.path}` - Normalized file path
- `${file.name}` - Filename without extension (e.g., `app` from `bin/app.dart`)
- `${file.basename}` - Filename with extension (e.g., `app.dart`)
- `${file.extension}` - File extension (e.g., `.dart`)
- `${file.dir}` - Directory containing the file (e.g., `bin`)

**Target platform placeholders (for dart compile options):**
- `${target-os}` - Target OS for `--target-os` option: `linux`, `macos`, `windows`
- `${target-arch}` - Target architecture for `--target-arch` option: `arm`, `arm64`, `x64`
- `${target-platform}` - Combined target: `macos-arm64`, `linux-x64`, `windows-x64`, etc.
- `${target-platform-vs}` - VS Code format: `darwin-arm64`, `linux-x64`, `win32-x64`

**Current platform placeholders:**
- `${current-os}` - Current OS (where compilation runs): `linux`, `macos`, `windows`
- `${current-arch}` - Current architecture: `arm`, `arm64`, `x64`
- `${current-platform}` - Current platform in dart target format: `macos-arm64`, `linux-x64`
- `${current-platform-vs}` - Current platform in VS Code format: `darwin-arm64`, `linux-x64`

**Environment variables:**
- `$VAR` - Environment variable value (e.g., `$HOME`, `$USER`)
- `[VAR]` - Alternative syntax for environment variables

**Example - Single command:**
```yaml
commandline: dart compile exe ${file} --target-os=${target-os} -o $HOME/.tom/bin/${target-platform-vs}/${file.name}
```

**Example - Multiple commands:**
```yaml
commandline:
  - mkdir -p $HOME/.tom/bin/${target-platform-vs}
  - dart compile exe ${file} --target-os=${target-os} -o $HOME/.tom/bin/${target-platform-vs}/${file.name}
```

#### `files` (string or list, required)

Source files to compile. Can be a single string or list:

```yaml
# Single file
files: bin/app.dart

# Multiple files
files: [bin/app.dart, bin/tool.dart, bin/helper.dart]
```

Each file will be compiled separately for each target.

#### `targets` (string or list, optional)

Target platforms to compile FOR (cross-compilation targets).

**Platform name formats:**
- **Specific platforms**: `darwin-arm64`, `linux-x64`, `win32-x64`, `linux-arm64`
- **Short forms**: `linux`, `macos`, `windows` - expands to all architectures for that OS
- **Wildcards**: `linux-*` (matches `linux-x64`, `linux-arm64`, `linux-armhf`)

**Short form expansion:**
- `linux` → `linux-x64`, `linux-arm64`, `linux-armhf`
- `macos` or `darwin` → `darwin-arm64`, `darwin-x64`
- `windows` or `win32` → `win32-x64`, `win32-arm64`

**Default behavior:** If omitted, compiles only for current platform.

**Examples:**
```yaml
# Single target
targets: darwin-arm64

# Multiple specific targets
targets: [darwin-arm64, linux-x64, win32-x64]

# All Linux architectures (short form)
targets: linux

# All macOS + all Linux (short forms)
targets: [macos, linux]

# Wildcard match
targets: [darwin-*, linux-*]
```

#### `platforms` (string or list, optional)

Platforms where this compilation section should RUN (host platform filter).

**Platform name formats:** Same as `targets` - supports specific platforms, short forms, and wildcards.

**Short form expansion:**
- `linux` → `linux-x64`, `linux-arm64`, `linux-armhf`
- `macos` or `darwin` → `darwin-arm64`, `darwin-x64`
- `windows` or `win32` → `win32-x64`, `win32-arm64`

**Use case:** Platform-specific compilation commands (e.g., different file extensions)

**Default behavior:** If omitted, runs on all platforms.

**Examples:**
```yaml
# Only run on any macOS
platforms: darwin-*

# Only run on macOS (short form - all variants)
platforms: macos

# Only run on Windows
platforms: [win32-x64, win32-arm64]

# Run on macOS and Linux (short forms)
platforms: [macos, linux]

# Run on macOS and Linux (wildcards)
platforms: [darwin-*, linux-*]
```

### `postcompile` (list, optional)

Commands to run AFTER all compilations complete. Runs once per project.

```yaml
postcompile:
  - commandline:
      - chmod -R +x $HOME/.tom/bin/${current-platform-vs}/
    platforms: [macos, linux]
```

**Fields:**
- `commandline` (string or list, required): Commands to execute
- `platforms` (string or list, optional): Host platforms where this runs

**Available placeholders:** `${current-os}`, `${current-arch}`, `${current-platform}`, `${current-platform-vs}`

**Use case:** Make compiled binaries executable, run post-processing, cleanup temporary files.

## Platform Names

### Supported Formats

The tool uses VS Code platform naming (with dashes) for `targets` and `platforms` settings:

#### VS Code Platform Names (for targets/platforms settings)
| Platform | Description |
|----------|-------------|
| `darwin-arm64` | macOS ARM64 (Apple Silicon) |
| `darwin-x64` | macOS x64 (Intel) |
| `linux-x64` | Linux x64 |
| `linux-arm64` | Linux ARM64 |
| `linux-armhf` | Linux ARM32 |
| `win32-x64` | Windows x64 |
| `win32-arm64` | Windows ARM64 |

#### Short Forms (for both targets and platforms)
| Short Form | Expands To |
|------------|------------|
| `linux` | `linux-x64`, `linux-arm64`, `linux-armhf` |
| `macos` or `darwin` | `darwin-arm64`, `darwin-x64` |
| `windows` or `win32` | `win32-x64`, `win32-arm64` |

#### Dart Compile Target Platform (`${target-platform}` placeholder)
| OS | Architecture | Target Name |
|----|--------------|-------------|
| Windows | x64 | `windows-x64` |
| Windows | ARM64 | `windows-arm64` |
| Linux | x64 | `linux-x64` |
| Linux | ARM64 | `linux-arm64` |
| macOS | x64 (Intel) | `macos-x64` |
| macOS | ARM64 (Apple Silicon) | `macos-arm64` |

#### Dart Compile Options
| Placeholder | Values | Usage |
|-------------|--------|-------|
| `${target-os}` | `linux`, `macos`, `windows` | For `--target-os` option |
| `${target-arch}` | `arm`, `arm64`, `x64` | For `--target-arch` option |

**The tool automatically converts between formats as needed.**

**Note:** For backward compatibility, underscore variants (e.g., `darwin_arm64`) are accepted and normalized to dashes.

## Usage

### Command Line

```bash
# Check version
compiler version
compiler --version
compiler -version

# Compile current project (auto-detects configuration)
compiler

# Compile specific project
compiler --project=my_app

# Scan directory for projects
compiler --scan=. --recursive

# Dry run (show what would be compiled)
compiler --dry-run

# Verbose output
compiler --verbose

# Exclude projects
compiler --scan=. --exclude='**/node_modules/**'

# Show help
compiler --help
```

### Options

```
-p, --project           Project(s) to compile (comma-separated, globs: tom_*_builder, ./*)
-s, --scan             Directory to scan for projects
-r, --recursive        Process subprojects recursively
-e, --exclude          Glob patterns for projects to exclude
    --recursion-exclude Glob patterns to exclude from recursive traversal
-t, --targets          Target platform(s) to compile for (comma-separated, globs: darwin-*, linux-x64)
-v, --verbose          Show detailed output
-d, --dry-run          Show what would be compiled without executing
-l, --list             List projects that would be processed (no action)
-h, --help             Show help message

Commands:
    version            Show version information
```

#### Project Selection (`--project`)

The `--project` option supports multiple ways to specify projects:

- **Single project**: `--project=my_app`
- **Comma-separated**: `--project='project1,project2,project3'`
- **Glob patterns**: `--project='tom_*_builder'` (matches any project starting with `tom_` and ending with `_builder`)
- **Path globs**: `--project='xternal/tom_module_d4rt/*'`
- **Current directory children**: `--project='./*'`
- **Recursive from current directory**: `--project='./**/*'`

Multiple patterns can be combined: `--project='tom_*_builder,tom_build_*,./*'`

#### Target Filtering (`--targets`)

The `--targets` option filters which target platforms to compile for. This is useful during development to reduce compile times:

- **Single target**: `--targets=darwin-arm64`
- **Comma-separated**: `--targets='darwin-arm64,linux-x64'`
- **Glob patterns**: `--targets='linux-*'` (matches all Linux architectures)
- **Platform aliases**: `--targets=macos` or `--targets=linux`

**Examples:**
```bash
# Compile only for current Mac (fast dev build)
compiler --targets=darwin-arm64

# Compile for Mac and Linux x64 only
compiler --targets='darwin-arm64,linux-x64'

# Compile for all Linux platforms
compiler --targets='linux-*'

# Compile for macOS only (both arm64 and x64)
compiler --targets=macos
```

**Note:** Unknown options will display usage information with an error message.

## Examples

### Example 1: Fast Development Build

Use `--targets` to compile only for your current platform during development:

```bash
# Quick build for Mac ARM64 only (skip other platforms)
compiler --targets=darwin-arm64

# Build for Mac + Linux x64 (common deployment)
compiler --targets='darwin-arm64,linux-x64'
```

### Example 2: Single Platform Config

Compile for current platform only:

```yaml
# build.yaml
targets:
  $default:
    builders:
      tom_compiler_builder:compiler_builder:
        enabled: true
        options:
          compiles:
            - commandline: dart compile exe ${file} -o bin/app
              files: bin/app.dart
              # No targets = current platform only
```

### Example 3: Cross-Platform Compilation

Compile for multiple platforms with cross-compilation:

```yaml
# build.yaml
targets:
  $default:
    builders:
      tom_compiler_builder:compiler_builder:
        enabled: true
        options:
          compiles:
            - commandline:
                - mkdir -p $HOME/.tom/bin/${target-platform-vs}
                - dart compile exe ${file} --target-os=${target-os} -o $HOME/.tom/bin/${target-platform-vs}/${file.name}
              files: [bin/app.dart, bin/cli.dart]
              targets: [darwin-arm64, linux-x64, linux-arm64]
              platforms: [darwin-arm64]  # Only run on macOS ARM64

          postcompile:
            - commandline:
                - chmod -R +x $HOME/.tom/bin/${current-platform-vs}/
              platforms: [macos, linux]
```

### Example 4: Platform-Specific Commands

Different commands for different host platforms:

```yaml
# build.yaml
targets:
  $default:
    builders:
      tom_compiler_builder:compiler_builder:
        enabled: true
        options:
          compiles:
            # Unix-like systems (macOS, Linux)
            - commandline:
                - mkdir -p $HOME/.tom/bin/${target-platform-vs}
                - dart compile exe ${file} --target-os=${target-os} -o $HOME/.tom/bin/${target-platform-vs}/${file.name}
              files: bin/app.dart
              targets: [macos, linux]
              platforms: [macos, linux]
            
            # Windows systems
            - commandline: dart compile exe ${file} -o bin\\output\\${target-platform-vs}\\${file.name}.exe
              files: bin/app.dart
              targets: windows
              platforms: windows

          postcompile:
            - commandline:
                - chmod -R +x $HOME/.tom/bin/${current-platform-vs}/
              platforms: [macos, linux]
```

### Example 5: Using Environment Variables

```yaml
# build.yaml
targets:
  $default:
    builders:
      tom_compiler_builder:compiler_builder:
        enabled: true
        options:
          compiles:
            - commandline:
                - mkdir -p $BUILD_DIR/${target-platform-vs}
                - dart compile exe ${file} --target-os=${target-os} -o $BUILD_DIR/${target-platform-vs}/${file.name}
              files: bin/app.dart
              targets: linux
```

Set environment variable before running:

```bash
export BUILD_DIR=/path/to/output
compiler --project=.
```

### Example 6: Multiple Files and Targets

```yaml
# build.yaml
targets:
  $default:
    builders:
      tom_compiler_builder:compiler_builder:
        enabled: true
        options:
          compiles:
            - commandline:
                - mkdir -p $HOME/.tom/bin/${target-platform-vs}
                - dart compile exe ${file} --target-os=${target-os} -o $HOME/.tom/bin/${target-platform-vs}/${file.name}
              files:
                - bin/app.dart
                - bin/cli.dart
                - bin/server.dart
              targets: [darwin-arm64, linux-x64, win32-x64]

          postcompile:
            - commandline:
                - chmod -R +x $HOME/.tom/bin/${current-platform-vs}/
              platforms: [macos, linux]
```

This will compile 3 files × 3 targets = 9 executables.

### Example 7: Full Cross-Compilation Setup

Compile from macOS ARM64 to multiple platforms:

```yaml
# build.yaml
targets:
  $default:
    builders:
      tom_compiler_builder:compiler_builder:
        enabled: true
        options:
          compiles:
            # macOS ARM64 host - cross-compile to self + all Linux targets
            - commandline:
                - mkdir -p $HOME/.tom/bin/${target-platform-vs}
                - dart compile exe ${file} --target-os=${target-os} -o $HOME/.tom/bin/${target-platform-vs}/${file.name}
              files: bin/my_tool.dart
              targets: [darwin-arm64, linux-x64, linux-arm64, linux-armhf]
              platforms: [darwin-arm64]
            
            # Other platforms - compile for self only
            - commandline:
                - mkdir -p $HOME/.tom/bin/${target-platform-vs}
                - dart compile exe ${file} -o $HOME/.tom/bin/${target-platform-vs}/${file.name}
              files: bin/my_tool.dart
              platforms: [darwin-x64, linux-*, win32-*]

          postcompile:
            - commandline:
                - chmod -R +x $HOME/.tom/bin/${current-platform-vs}/
              platforms: [macos, linux]
```

## Output Format

```
============================================================
Compiler running
============================================================

Project: my_app
Compiling: bin/app.dart -> darwin-arm64
  Executing (1/2): mkdir -p /Users/me/.tom/bin/darwin-arm64
  Executing (2/2): dart compile exe bin/app.dart --target-os=macos -o /Users/me/.tom/bin/darwin-arm64/app
  Success
Compiling: bin/app.dart -> linux-x64
  Executing (1/2): mkdir -p /Users/me/.tom/bin/linux-x64
  Executing (2/2): dart compile exe bin/app.dart --target-os=linux -o /Users/me/.tom/bin/linux-x64/app
  Success
Running postcompile...
  Executing: chmod -R +x /Users/me/.tom/bin/darwin-arm64/
Completed 2 compilation(s)

Compiler: Processed 1 project(s)
```

## Project Discovery

A project is considered a "compiler project" if it:
1. Contains a `pubspec.yaml` file
2. Contains a `build.yaml` file with `tom_compiler_builder:compiler_builder` configuration
3. Is not a builder definition project itself

## Notes

### Cross-Compilation Limitations

Dart's native compilation has limited cross-compilation support:
- macOS can compile for macOS targets
- Linux can compile for Linux targets
- Windows can compile for Windows targets

Cross-OS compilation (e.g., compiling for Linux on macOS) requires the target platform's toolchain.

### Best Practices

1. **Use environment variables** for output paths to make builds flexible
2. **Filter by platforms** when commands differ between operating systems
3. **Use wildcards** (`linux_*`) for flexibility across architectures
4. **Test with --dry-run** before actual compilation
5. **Keep separate sections** for platform-specific needs (file extensions, path separators)

## Troubleshooting

### "No projects found to process"

**Cause:** No `build.yaml` with compiler configuration found.

**Solution:** Add compiler configuration to `build.yaml` in your project.

### "Skipping section - current platform not in platforms"

**Cause:** Compilation section's `platforms:` doesn't match current platform.

**Solution:** This is expected behavior for platform-filtered sections. No action needed unless the filter is incorrect.

### "Failed (exit code 254)"

**Cause:** Cross-compilation failed or target toolchain missing.

**Solution:** 
- Verify target platform supports cross-compilation from current platform
- Check that output directory exists
- Ensure Dart SDK supports the target platform

### Command not executing

**Cause:** Environment variable not set or placeholder not resolved.

**Solution:**
- Use `--verbose` to see the exact command being executed
- Verify environment variables are set before running
- Check placeholder syntax (`${var}` or `[var]`)
