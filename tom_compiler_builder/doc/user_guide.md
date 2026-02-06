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
            - commandline: dart compile exe ${file} -o bin/${target_platform}/app
              files: [bin/app.dart, bin/tool.dart]
              targets: [darwin_arm64, linux_x64, win32_x64]
              platforms: [darwin_*, linux_*]
            - commandline: dart compile exe ${file} -o bin/${target_platform}/app.exe
              files: [bin/app.dart]
              targets: [win32_x64, win32_arm64]
              platforms: [win32_*]
```

## Configuration Fields

### `compiles` (list, required)

List of compilation configurations, each with:

#### `commandline` (string, required)

Command template with placeholders:

**File placeholders:**
- `${file}` or `[file]` - Source file being compiled

**Platform placeholders:**
- `${target}` or `[target]` - Dart compiler target format (e.g., `macos-arm64`, `linux-x64`)
- `${target_platform}` or `[target_platform]` - VS Code format (e.g., `darwin_arm64`, `linux_x64`)
- `${current_platform}` or `[current_platform]` - Current platform in VS Code format

**Environment variables:**
- `$VAR` or `[VAR]` - Environment variable value (e.g., `$OUTPUT`, `[BUILD_DIR]`)

**Example:**
```yaml
commandline: dart compile exe ${file} -o $OUTPUT/${target_platform}/${file}
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
- **VS Code format**: `darwin_arm64`, `linux_x64`, `win32_x64`, `linux_arm64`
- **Generic OS**: `linux` (all Linux architectures), `macos`, `windows`
- **Wildcards**: `linux_*` (matches `linux_x64`, `linux_arm64`, `linux_arm`)

**Default behavior:** If omitted, compiles only for current platform.

**Examples:**
```yaml
# Single target
targets: darwin_arm64

# Multiple specific targets
targets: [darwin_arm64, linux_x64, win32_x64]

# All Linux architectures
targets: linux

# Wildcard match
targets: [darwin_*, linux_*]
```

#### `platforms` (string or list, optional)

Platforms where this compilation section should RUN (host platform filter).

**Use case:** Platform-specific compilation commands (e.g., different file extensions)

**Default behavior:** If omitted, runs on all platforms.

**Examples:**
```yaml
# Only run on macOS
platforms: darwin_*

# Only run on Windows
platforms: [win32_x64, win32_arm64]

# Run on macOS and Linux
platforms: [darwin_*, linux_*]
```

## Platform Names

### Supported Formats

The tool uses VS Code platform naming (with dashes):

#### VS Code Platform Names (Standard)
- `darwin-arm64` - macOS ARM64 (Apple Silicon)
- `darwin-x64` - macOS x64 (Intel)
- `linux-x64` - Linux x64
- `linux-arm64` - Linux ARM64
- `linux-armhf` - Linux ARM32
- `win32-x64` - Windows x64
- `win32-arm64` - Windows ARM64

#### Generic OS Names
- `linux` - All Linux architectures
- `macos` or `darwin` - All macOS architectures
- `windows` or `win32` - All Windows architectures

#### Dart Compiler Targets (automatic conversion)
- `macos-arm64` - macOS ARM64
- `macos-x64` - macOS x64
- `linux-x64` - Linux x64
- `linux-arm64` - Linux ARM64
- `windows-x64` - Windows x64
- `windows-arm64` - Windows ARM64

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
-p, --project           Path to specific project to compile
-s, --scan             Directory to scan for projects
-r, --recursive        Process subprojects recursively
-e, --exclude          Glob patterns for projects to exclude
    --recursion-exclude Glob patterns to exclude from recursive traversal
-v, --verbose          Show detailed output
-d, --dry-run          Show what would be compiled without executing
-h, --help             Show help message

Commands:
    version            Show version information
```

**Note:** Unknown options will display usage information with an error message.

## Examples

### Example 1: Single Platform

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

### Example 2: Cross-Platform Compilation

Compile for multiple platforms:

```yaml
# build.yaml
targets:
  $default:
    builders:
      tom_compiler_builder:compiler_builder:
        enabled: true
        options:
          compiles:
            - commandline: dart compile exe ${file} -o $OUTPUT/${target_platform}/${file}
              files: [bin/app.dart, bin/cli.dart]
              targets: [darwin_arm64, darwin_x64, linux_x64, linux_arm64]
```

### Example 3: Platform-Specific Commands

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
            - commandline: dart compile exe ${file} -o bin/output/${target_platform}/app
              files: bin/app.dart
              targets: [darwin_arm64, darwin_x64, linux_x64]
              platforms: [darwin_*, linux_*]
            
            # Windows systems
            - commandline: dart compile exe ${file} -o bin\\output\\${target_platform}\\app.exe
              files: bin/app.dart
              targets: [win32_x64, win32_arm64]
              platforms: [win32_*]
```

### Example 4: Using Environment Variables

```yaml
# build.yaml
targets:
  $default:
    builders:
      tom_compiler_builder:compiler_builder:
        enabled: true
        options:
          compiles:
            - commandline: dart compile exe ${file} -o $BUILD_DIR/${target_platform}/app
              files: bin/app.dart
              targets: linux
```

Set environment variable before running:

```bash
export BUILD_DIR=/path/to/output
dart run tom_compiler_builder:compiler
```

### Example 5: Multiple Files and Targets

```yaml
# build.yaml
targets:
  $default:
    builders:
      tom_compiler_builder:compiler_builder:
        enabled: true
        options:
          compiles:
            - commandline: dart compile exe ${file} -o bin/${target_platform}/$(basename ${file} .dart)
              files:
                - bin/app.dart
                - bin/cli.dart
                - bin/server.dart
              targets: [darwin_arm64, linux_x64, win32_x64]
```

This will compile 3 files × 3 targets = 9 executables.

## Output Format

```
============================================================
Compiler running
============================================================

Project: my_app
Compiling: bin/app.dart -> darwin_arm64
  Success
Compiling: bin/app.dart -> linux_x64
  Failed (exit code 254)
  Error: AOT compilation failed
Completed 1 compilation(s)

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
