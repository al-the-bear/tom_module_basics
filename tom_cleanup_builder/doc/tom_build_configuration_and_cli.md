# Tom Cleanup Builder - Configuration and CLI Reference

This document covers both the `tom_build.yaml` configuration file and command-line interface options for the Tom Cleanup Builder tool.

## Configuration File: tom_build.yaml

The `tom_build.yaml` file is an optional configuration file placed in the project root that controls project discovery and default CLI options for the cleanup tool.

### Location

```
my_project/
├── tom_build.yaml    # Optional configuration
├── build.yaml        # Required: cleanup configuration
└── pubspec.yaml
```

### Structure

```yaml
# tom_build.yaml
cleanup:
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

Path to a specific project to clean. Relative to the tom_build.yaml location.

**Default:** `.` (current directory)

**Examples:**
```yaml
project: .                    # Current directory
project: ../my_app            # Parent directory
project: packages/core        # Subdirectory
```

**CLI equivalent:** `--project` or `-p`

#### `scan` (string, optional)

Directory to scan for projects containing cleanup configurations.

**Default:** Not set (no scanning)

**Examples:**
```yaml
scan: .                       # Scan current directory
scan: ../                     # Scan parent directory
scan: packages/               # Scan packages directory
```

**CLI equivalent:** `--scan` or `-s`

**Note:** When `scan` is set, the tool will search for all projects with `build.yaml` files containing `tom_cleanup_builder:cleanup_builder` configuration.

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

Enable detailed output showing which files are being deleted or excluded.

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
cleanup:
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
dart run tom_cleanup_builder:cleanup

# Override configuration with CLI options
dart run tom_cleanup_builder:cleanup --project=my_app --verbose

# Scan for projects
dart run tom_cleanup_builder:cleanup --scan=. --recursive
```

### CLI Options

#### `-p, --project <path>`

Path to a specific project to clean.

**Examples:**
```bash
dart run tom_cleanup_builder:cleanup --project=.
dart run tom_cleanup_builder:cleanup -p ../my_app
dart run tom_cleanup_builder:cleanup --project=packages/core
```

**Overrides:** `cleanup.project` in tom_build.yaml

#### `-s, --scan <path>`

Directory to scan for projects with cleanup configurations.

**Examples:**
```bash
dart run tom_cleanup_builder:cleanup --scan=.
dart run tom_cleanup_builder:cleanup -s ../
dart run tom_cleanup_builder:cleanup --scan=packages/
```

**Overrides:** `cleanup.scan` in tom_build.yaml

#### `-r, --recursive`

Process subprojects recursively.

**Examples:**
```bash
dart run tom_cleanup_builder:cleanup --scan=. --recursive
dart run tom_cleanup_builder:cleanup -s ../ -r
```

**Overrides:** `cleanup.recursive` in tom_build.yaml

#### `-e, --exclude <pattern>`

Glob pattern for projects to exclude. Can be specified multiple times.

**Examples:**
```bash
dart run tom_cleanup_builder:cleanup --scan=. --exclude='**/test/**'
dart run tom_cleanup_builder:cleanup -e '**/node_modules/**' -e '**/build/**'
```

**Overrides:** `cleanup.exclude` in tom_build.yaml

#### `--recursion-exclude <pattern>`

Glob pattern to exclude from recursive traversal. Can be specified multiple times.

**Examples:**
```bash
dart run tom_cleanup_builder:cleanup --scan=. --recursion-exclude='**/.git/**'
dart run tom_cleanup_builder:cleanup --recursion-exclude='**/node_modules/**'
```

**Overrides:** `cleanup.recursion-exclude` in tom_build.yaml

#### `-v, --verbose`

Show detailed output including which files are deleted or excluded.

**Examples:**
```bash
dart run tom_cleanup_builder:cleanup --verbose
dart run tom_cleanup_builder:cleanup -v --scan=.
```

**Overrides:** `cleanup.verbose` in tom_build.yaml

**Verbose output includes:**
- Each file being deleted
- Each file being excluded (with reason)
- Detailed statistics per pattern

#### `-d, --dry-run`

Show what would be deleted without actually deleting files.

**Examples:**
```bash
dart run tom_cleanup_builder:cleanup --dry-run
dart run tom_cleanup_builder:cleanup -d --verbose
```

**Note:** Not configurable in tom_build.yaml (runtime-only option)

**Best practice:** Always use `--dry-run` first to preview deletions before running actual cleanup.

#### `-h, --help`

Display help message with all available options.

**Example:**
```bash
dart run tom_cleanup_builder:cleanup --help
```

## Configuration Priority

When the same option is specified in multiple places, the priority order is:

1. **CLI arguments** (highest priority)
2. **tom_build.yaml file**
3. **Default values** (lowest priority)

**Example:**
```yaml
# tom_build.yaml
cleanup:
  verbose: false
  project: .
```

```bash
# CLI overrides verbose, uses project from config
dart run tom_cleanup_builder:cleanup --verbose
# Result: verbose=true, project=.
```

## Usage Patterns

### Pattern 1: Single Project

Clean a specific project:

```bash
dart run tom_cleanup_builder:cleanup --project=my_app
```

Or with configuration:
```yaml
# tom_build.yaml
cleanup:
  project: .
```

```bash
dart run tom_cleanup_builder:cleanup
```

### Pattern 2: Workspace Scanning

Clean all projects in a workspace:

```bash
dart run tom_cleanup_builder:cleanup --scan=. --recursive --exclude='**/test/**'
```

Or with configuration:
```yaml
# tom_build.yaml (in workspace root)
cleanup:
  scan: .
  recursive: true
  exclude:
    - '**/test/**'
    - '**/example/**'
```

```bash
dart run tom_cleanup_builder:cleanup
```

### Pattern 3: Dry Run Testing

**Always test cleanup before executing:**

```bash
# Preview what would be deleted
dart run tom_cleanup_builder:cleanup --dry-run --verbose

# If results look good, run actual cleanup
dart run tom_cleanup_builder:cleanup
```

### Pattern 4: Pre-Build Cleanup

Clean before running build_runner:

```bash
#!/bin/bash
# build.sh
dart run tom_cleanup_builder:cleanup
dart run build_runner build --delete-conflicting-outputs
```

### Pattern 5: CI/CD Integration

In CI/CD scripts:

```bash
#!/bin/bash
# ci_build.sh
dart run tom_cleanup_builder:cleanup \
  --scan=packages \
  --recursive \
  --exclude='**/test/**' \
  --verbose
```

### Pattern 6: Selective Cleanup

Clean only specific projects:

```yaml
# tom_build.yaml
cleanup:
  scan: packages/
  exclude:
    - '**/example/**'
    - '**/test/**'
    - '**/packages/experimental/**'
```

## Integration with build_runner

The cleanup builder can be integrated into your build_runner pipeline:

```yaml
# build.yaml
targets:
  $default:
    builders:
      # Run cleanup first
      tom_cleanup_builder:cleanup_builder:
        enabled: true
        options:
          cleanup:
            - '**/*.g.dart'
            - '**/*.freezed.dart'
      
      # Then generate files
      json_serializable:
        enabled: true
```

**Note:** This is in addition to the standalone CLI tool. The builder runs automatically with `build_runner`, while the CLI tool is run manually.

## Troubleshooting

### "No projects found to process"

**Cause:** No projects with cleanup configuration found.

**Solutions:**
1. Verify `build.yaml` contains `tom_cleanup_builder:cleanup_builder` configuration
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

### Files not being deleted

**Possible causes:**
1. Files match an exclude pattern (global or section-specific)
2. Glob pattern doesn't match the file path
3. File permissions prevent deletion
4. Dry-run mode is active

**Solutions:**
1. Use `--verbose` to see why files are excluded
2. Use `--dry-run --verbose` to see what patterns match
3. Test patterns: `**/file.dart` not `*/file.dart` for recursive matching
4. Verify no `--dry-run` flag is set

### Too many files being deleted

**Immediate action:** Use `--dry-run` to preview before confirming.

**Solutions:**
1. Make patterns more specific: `**/*.g.dart` not `**/*.dart`
2. Add section-specific excludes:
   ```yaml
   cleanup:
     - globs:
         - '**/*.dart'
       excludes:
         - '**/important/**'
   ```
3. Add global excludes for protection:
   ```yaml
   excludes:
     - '**/manual_*.dart'
     - '**/important.dart'
   ```

### Patterns not matching expected files

**Cause:** Glob pattern syntax issues.

**Solutions:**
1. Use `**` for recursive matching: `**/test/**` not `*/test/**`
2. Always use forward slashes `/` even on Windows
3. Quote patterns in shell: `--exclude='**/test/**'`
4. Test patterns with `--dry-run --verbose`
5. Remember patterns are relative to project root

## Safety Best Practices

1. **Always use --dry-run first**
   ```bash
   dart run tom_cleanup_builder:cleanup --dry-run --verbose
   ```

2. **Use version control**
   - Commit before cleanup
   - Easy to recover accidentally deleted files

3. **Test patterns on small projects first**
   ```bash
   dart run tom_cleanup_builder:cleanup --project=test_project --dry-run
   ```

4. **Use specific patterns**
   ```yaml
   # ❌ Dangerous - too broad
   cleanup:
     - '**/*.dart'
   
   # ✅ Safe - specific to generated files
   cleanup:
     - '**/*.g.dart'
     - '**/*.freezed.dart'
   ```

5. **Add protective excludes**
   ```yaml
   excludes:
     - '**/manual_*.g.dart'
     - '**/important.dart'
     - 'lib/src/version.g.dart'
   ```

## See Also

- [User Guide](user_guide.md) - Complete usage documentation
- [build.yaml Configuration](user_guide.md#configuration) - Cleanup configuration
- [Glob Pattern Syntax](https://pub.dev/packages/glob)
