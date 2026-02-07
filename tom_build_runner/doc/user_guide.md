# Build Runner Tool - User Guide

The Build Runner Tool is a CLI wrapper for `build_runner` that adds workspace scanning and project discovery capabilities. It allows you to run code generators across multiple projects in a workspace with a single command.

## Installation

### From Source

```bash
# Navigate to the project directory
cd tom_build_runner

# Get dependencies
dart pub get

# Run directly
dart run bin/build_runner.dart --help

# Or compile to binary
dart compile exe bin/build_runner.dart -o build_runner
```

### Using Pre-compiled Binary

Place the `build_runner` binary in a directory on your PATH:

```bash
# macOS/Linux
cp build_runner ~/.tom/bin/darwin-arm64/
chmod +x ~/.tom/bin/darwin-arm64/build_runner

# Add to PATH in ~/.zshrc or ~/.bashrc
export PATH="$HOME/.tom/bin/darwin-arm64:$PATH"
```

## Basic Usage

```bash
# Show help
build_runner --help

# Show version
build_runner version

# Run on current project (must have build.yaml)
build_runner

# Run in watch mode
build_runner --command=watch

# Clean generated files
build_runner --command=clean
```

## Project Discovery

The tool can automatically discover projects that need code generation.

### Single Project

```bash
# Run on a specific project
build_runner --project=path/to/project

# Short form
build_runner -p path/to/project
```

### Workspace Scanning

```bash
# Scan current directory for projects
build_runner --scan=.

# Scan with recursion for nested projects
build_runner --scan=. --recursive

# Scan and exclude certain patterns
build_runner --scan=. --exclude="**/test/**" --exclude="**/example/**"
```

A project is considered a build_runner project if it contains both:
- `pubspec.yaml` - Dart package definition
- `build.yaml` - Build runner configuration

## Builder Filtering

The tool supports include/exclude filtering of builders. Configuration is loaded from multiple sources with no merging - the first source with configuration wins.

### Configuration Priority (no merging)

1. **Command-line arguments** (highest priority)
2. **build.yaml** (`tom_build_runner:build_runner` section) in project
3. **tom_build.yaml** in project directory
4. **tom_build.yaml** in root directory (fallback for all projects)

### Excluding Builders

Exclude specific builders from running:

```bash
# Exclude a specific builder
build_runner --exclude-builders=json_serializable:json_serializable

# Exclude multiple builders
build_runner -x some_package:builder1 -x other_package:builder2
```

### Including Builders

Only run specified builders (all others are disabled):

```bash
# Only run the version builder
build_runner --include-builders=tom_version_builder:version_builder

# Multiple include filters
build_runner -i tom_version_builder:version_builder -i json_serializable:json_serializable
```

## Configuration Files

### Per-Project Configuration (build.yaml)

Add a `tom_build_runner` section to your project's `build.yaml`:

```yaml
targets:
  $default:
    builders:
      tom_version_builder:version_builder:
        enabled: true
        # ... builder config

# Builder filtering for this project
tom_build_runner:
  build_runner:
    include-builders:
      - tom_version_builder:version_builder
    exclude-builders:
      - json_serializable:json_serializable
```

### Per-Project Configuration (tom_build.yaml)

Add a `build_runner` section to your project's `tom_build.yaml`:

```yaml
build_runner:
  include-builders:
    - tom_version_builder:version_builder
  exclude-builders:
    - some_package:unwanted_builder
```

### Root Configuration (tom_build.yaml)

Set default builder filtering for all projects in your workspace root:

```yaml
build_runner:
  # Scan settings
  scan: .
  recursive: true
  exclude:
    - "**/test/**"
    - "**/example/**"
  
  # Build settings
  command: build
  verbose: false
  release: false
  delete-conflicting: true
  
  # Builder filtering (fallback for projects without their own config)
  include-builders:
    - tom_version_builder:version_builder
  exclude-builders:
    - some_package:unwanted_builder
```

### Using Alternative build.yaml

Build runner supports named configuration files (build.<name>.yaml):

```bash
# Use build.prod.yaml instead of build.yaml
build_runner --config=prod
```

## Command Options

### Core Options

| Option | Short | Description |
|--------|-------|-------------|
| `--project` | `-p` | Path to specific project to process |
| `--scan` | `-s` | Directory to scan for projects |
| `--recursive` | `-r` | Process subprojects recursively |
| `--exclude` | `-e` | Glob patterns for projects to exclude |
| `--help` | `-h` | Show help message |

### Build Options

| Option | Short | Description |
|--------|-------|-------------|
| `--command` | `-c` | Build command: build, watch, clean |
| `--config` | | Use build.<name>.yaml instead of build.yaml |
| `--release` | | Build with release mode defaults |
| `--delete-conflicting` | | Delete conflicting outputs (default: true) |

### Builder Options

| Option | Short | Description |
|--------|-------|-------------|
| `--include-builders` | `-i` | Builder patterns to include (only these run) |
| `--exclude-builders` | `-x` | Builder patterns to exclude |

### Output Options

| Option | Short | Description |
|--------|-------|-------------|
| `--verbose` | `-v` | Show detailed output |
| `--dry-run` | `-d` | Show what would be run without executing |

## Examples

### Basic Workflow

```bash
# Navigate to your workspace root
cd ~/code/my_workspace

# Run build_runner on all projects
build_runner --scan=. --recursive

# Check what would be run first
build_runner --scan=. --recursive --dry-run
```

### CI/CD Integration

```bash
#!/bin/bash
# Build script for CI

# Run all code generators in release mode
build_runner --scan=. --recursive --release

# Or with specific projects excluded
build_runner --scan=. --recursive --exclude="**/zom_*/**"
```

### Watch Mode Development

```bash
# Watch a specific project
build_runner --project=packages/my_package --command=watch

# Watch current project with verbose output
build_runner --command=watch --verbose
```

### Clean Generated Files

```bash
# Clean all projects in workspace
build_runner --scan=. --recursive --command=clean
```

## Exit Codes

| Code | Description |
|------|-------------|
| 0 | Success - all projects processed |
| 1 | Failure - one or more projects failed |

## Troubleshooting

### Project Not Found

If your project isn't being discovered:

1. Verify it has a `pubspec.yaml` file
2. Verify it has a `build.yaml` file
3. Check exclude patterns aren't filtering it out
4. Use `--verbose` to see what's being scanned

### Builder Not Running

If a builder isn't generating code:

1. Check the builder is properly configured in `build.yaml`
2. Verify `--exclude-builders` isn't filtering it
3. Run with `--verbose` to see detailed output
4. Try running `dart run build_runner build` directly in the project

### Permission Issues

On macOS/Linux, ensure the binary is executable:

```bash
chmod +x build_runner
```

## Related Tools

- **compiler** - Compile tom_build projects to binaries
- **versioner** - Version management and version.g.dart generation
- **cleanup** - Clean generated and cached files
