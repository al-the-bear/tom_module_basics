# Tom Compiler Builder - Configuration and CLI Reference

This document covers both the `tom_build.yaml` configuration file and command-line interface options for the Tom Compiler Builder tool.

## Configuration File: tom_build.yaml

The `tom_build.yaml` file is an optional configuration file placed in the project root that controls project discovery and default CLI options for the compiler tool.

### Location

```
my_project/
├── tom_build.yaml    # Optional configuration
├── build.yaml        # Required: compilation configuration
└── pubspec.yaml
```

### Structure

```yaml
# tom_build.yaml
compiler:
  project: .
  scan: ../
  recursive: true
  exclude:
    - '**/node_modules/**'
    - '**/build/**'
  recursion-exclude:
    - '**/.git/**'
  verbose: false
```

### Configuration Fields

#### `project` (string, optional)

Path to a specific project to compile. Relative to the tom_build.yaml location.

**Default:** `.` (current directory)

**Examples:**
```yaml
project: .                    # Current directory
project: ../my_app            # Parent directory
project: packages/core        # Subdirectory
```

**CLI equivalent:** `--project` or `-p`

#### `scan` (string, optional)

Directory to scan for projects containing compiler configurations.

**Default:** Not set (no scanning)

**Examples:**
```yaml
scan: .                       # Scan current directory
scan: ../                     # Scan parent directory
scan: packages/               # Scan packages directory
```

**CLI equivalent:** `--scan` or `-s`

**Note:** When `scan` is set, the tool will search for all projects with `build.yaml` files containing `tom_compiler_builder:compiler_builder` configuration.

#### `recursive` (boolean, optional)

Whether to recursively process subprojects found during scanning.

**Default:** `false`

**Examples:**
```yaml
recursive: true               # Process subprojects
recursive: false              # Only top-level projects
```

**CLI equivalent:** `--recursive` or `-r`

#### `exclude` (list, optional)

Glob patterns for projects to exclude from processing.

**Default:** `[]` (no exclusions)

**Examples:**
```yaml
exclude:
  - '**/node_modules/**'      # Skip node_modules
  - '**/build/**'             # Skip build directories
  - '**/.dart_tool/**'        # Skip Dart tool cache
  - '**/test/**'              # Skip test directories
```

**CLI equivalent:** `--exclude` or `-e`

**Pattern syntax:** Uses glob patterns with `*` (any characters except /) and `**` (any characters including /)

#### `recursion-exclude` (list, optional)

Glob patterns to exclude from recursive directory traversal. Unlike `exclude`, these patterns prevent the tool from even looking inside matching directories.

**Default:** `[]` (no recursion exclusions)

**Examples:**
```yaml
recursion-exclude:
  - '**/.git/**'              # Don't traverse .git directories
  - '**/node_modules/**'      # Don't traverse node_modules
  - '**/.dart_tool/**'        # Don't traverse Dart cache
```

**CLI equivalent:** `--recursion-exclude`

**Use case:** Performance optimization - skip directories that definitely don't contain projects.

#### `verbose` (boolean, optional)

Enable detailed output showing compilation commands and results.

**Default:** `false`

**Examples:**
```yaml
verbose: true                 # Show detailed output
verbose: false                # Show summary only
```

**CLI equivalent:** `--verbose` or `-v`

### Complete Example

```yaml
# tom_build.yaml
compiler:
  # Scan the workspace for projects
  scan: ../
  recursive: true
  
  # Exclude unnecessary directories
  exclude:
    - '**/node_modules/**'
    - '**/build/**'
    - '**/.dart_tool/**'
    - '**/test/**'
  
  # Don't even look inside these directories
  recursion-exclude:
    - '**/.git/**'
    - '**/node_modules/**'
  
  # Show detailed output
  verbose: true
```

## Command-Line Interface

### Basic Usage

```bash
# Run with tom_build.yaml configuration
dart run tom_compiler_builder:compiler

# Override configuration with CLI options
dart run tom_compiler_builder:compiler --project=my_app --verbose

# Scan for projects
dart run tom_compiler_builder:compiler --scan=. --recursive
```

### CLI Options

#### `-p, --project <path>`

Path to a specific project to compile.

**Examples:**
```bash
dart run tom_compiler_builder:compiler --project=.
dart run tom_compiler_builder:compiler -p ../my_app
dart run tom_compiler_builder:compiler --project=packages/core
```

**Overrides:** `compiler.project` in tom_build.yaml

#### `-s, --scan <path>`

Directory to scan for projects with compiler configurations.

**Examples:**
```bash
dart run tom_compiler_builder:compiler --scan=.
dart run tom_compiler_builder:compiler -s ../
dart run tom_compiler_builder:compiler --scan=packages/
```

**Overrides:** `compiler.scan` in tom_build.yaml

#### `-r, --recursive`

Process subprojects recursively.

**Examples:**
```bash
dart run tom_compiler_builder:compiler --scan=. --recursive
dart run tom_compiler_builder:compiler -s ../ -r
```

**Overrides:** `compiler.recursive` in tom_build.yaml

#### `-e, --exclude <pattern>`

Glob pattern for projects to exclude. Can be specified multiple times.

**Examples:**
```bash
dart run tom_compiler_builder:compiler --scan=. --exclude='**/test/**'
dart run tom_compiler_builder:compiler -e '**/node_modules/**' -e '**/build/**'
```

**Overrides:** `compiler.exclude` in tom_build.yaml

#### `--recursion-exclude <pattern>`

Glob pattern to exclude from recursive traversal. Can be specified multiple times.

**Examples:**
```bash
dart run tom_compiler_builder:compiler --scan=. --recursion-exclude='**/.git/**'
dart run tom_compiler_builder:compiler --recursion-exclude='**/node_modules/**'
```

**Overrides:** `compiler.recursion-exclude` in tom_build.yaml

#### `-v, --verbose`

Show detailed output including compilation commands and results.

**Examples:**
```bash
dart run tom_compiler_builder:compiler --verbose
dart run tom_compiler_builder:compiler -v --scan=.
```

**Overrides:** `compiler.verbose` in tom_build.yaml

#### `-d, --dry-run`

Show what would be compiled without executing commands.

**Examples:**
```bash
dart run tom_compiler_builder:compiler --dry-run
dart run tom_compiler_builder:compiler -d --verbose
```

**Note:** Not configurable in tom_build.yaml (runtime-only option)

#### `-h, --help`

Display help message with all available options.

**Example:**
```bash
dart run tom_compiler_builder:compiler --help
```

## Configuration Priority

When the same option is specified in multiple places, the priority order is:

1. **CLI arguments** (highest priority)
2. **tom_build.yaml file**
3. **Default values** (lowest priority)

**Example:**
```yaml
# tom_build.yaml
compiler:
  verbose: false
  project: .
```

```bash
# CLI overrides verbose, uses project from config
dart run tom_compiler_builder:compiler --verbose
# Result: verbose=true, project=.
```

## Usage Patterns

### Pattern 1: Single Project

Compile a specific project:

```bash
dart run tom_compiler_builder:compiler --project=my_app
```

Or with configuration:
```yaml
# tom_build.yaml
compiler:
  project: .
```

```bash
dart run tom_compiler_builder:compiler
```

### Pattern 2: Workspace Scanning

Compile all projects in a workspace:

```bash
dart run tom_compiler_builder:compiler --scan=. --recursive --exclude='**/test/**'
```

Or with configuration:
```yaml
# tom_build.yaml (in workspace root)
compiler:
  scan: .
  recursive: true
  exclude:
    - '**/test/**'
    - '**/example/**'
```

```bash
dart run tom_compiler_builder:compiler
```

### Pattern 3: Dry Run Testing

Test configuration before actual compilation:

```bash
dart run tom_compiler_builder:compiler --dry-run --verbose
```

### Pattern 4: CI/CD Integration

In CI/CD scripts, use verbose output for debugging:

```bash
#!/bin/bash
# build.sh
dart run tom_compiler_builder:compiler \
  --scan=packages \
  --recursive \
  --exclude='**/test/**' \
  --verbose
```

### Pattern 5: Selective Compilation

Compile only specific projects:

```yaml
# tom_build.yaml
compiler:
  scan: packages/
  exclude:
    - '**/example/**'
    - '**/test/**'
    - '**/packages/experimental/**'
```

## Environment Variables

The compiler tool supports environment variable expansion in compilation commands (configured in `build.yaml`, not `tom_build.yaml`).

**Syntax:** `$VAR` or `[VAR]`

**Example:**
```yaml
# build.yaml
targets:
  $default:
    builders:
      tom_compiler_builder:compiler_builder:
        options:
          compiles:
            - commandline: dart compile exe ${file} -o $OUTPUT/${target_platform}/app
              files: bin/app.dart
              targets: [darwin_arm64, linux_x64]
```

```bash
export OUTPUT=/path/to/output
dart run tom_compiler_builder:compiler
```

## Troubleshooting

### "No projects found to process"

**Cause:** No projects with compiler configuration found.

**Solutions:**
1. Verify `build.yaml` contains `tom_compiler_builder:compiler_builder` configuration
2. Check `scan` path is correct
3. Verify projects aren't excluded by `exclude` patterns
4. Use `--verbose` to see which directories are being scanned

### Configuration not loading

**Cause:** tom_build.yaml not found or has syntax errors.

**Solutions:**
1. Verify file is named exactly `tom_build.yaml` (not `tom-build.yaml` or `tom_build.yml`)
2. Check YAML syntax with a validator
3. Ensure file is in the project root or working directory
4. Use `--verbose` to see which configuration is loaded

### Patterns not matching expected projects

**Cause:** Glob pattern syntax issues.

**Solutions:**
1. Use `**` for recursive matching: `**/test/**` not `*/test/**`
2. Always use forward slashes `/` even on Windows
3. Quote patterns in shell: `--exclude='**/test/**'`
4. Test patterns with `--dry-run --verbose`

### CLI options not overriding config

**Cause:** Using wrong option name or syntax.

**Solutions:**
1. Check option names: `--project` not `--path`
2. Use `=` or space: `--project=my_app` or `--project my_app`
3. For lists, repeat option: `-e 'pattern1' -e 'pattern2'`

## See Also

- [User Guide](user_guide.md) - Complete usage documentation
- [build.yaml Configuration](user_guide.md#configuration) - Compilation configuration
- [Glob Pattern Syntax](https://pub.dev/packages/glob)
