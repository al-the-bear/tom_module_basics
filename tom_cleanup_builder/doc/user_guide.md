# Tom Cleanup Builder - User Guide

The `cleanup` tool provides automated cleanup of generated and temporary files in Dart projects with support for glob patterns and exclude lists.

## Overview

Tom Cleanup Builder enables:
- Automatic deletion of generated files (*.g.dart, *.freezed.dart, etc.)
- Glob pattern matching for flexible file selection
- Global and section-specific exclude patterns
- Project auto-discovery and scanning
- Dry-run mode for safe preview

## Configuration

The tool uses a two-tier configuration pattern:

### 1. Project Discovery - tom_build.yaml (Optional)

Create a `tom_build.yaml` file in your project root for CLI options:

```yaml
# tom_build.yaml
cleanup:
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

### 2. Cleanup Configuration - build.yaml

Define cleanup patterns in `build.yaml`:

```yaml
targets:
  $default:
    builders:
      tom_cleanup_builder:cleanup_builder:
        enabled: true
        options:
          cleanup:
            - '**/*.g.dart'
            - '**/*.freezed.dart'
            - globs:
                - 'lib/generated/**'
              excludes:
                - 'lib/generated/keep_me.dart'
          excludes:
            - '**/important.g.dart'
```

## Configuration Fields

### `cleanup` (list, required)

List of cleanup patterns. Each item can be:

#### Simple String Pattern

A glob pattern matching files to delete:

```yaml
cleanup:
  - '**/*.g.dart'           # All .g.dart files
  - '**/*.freezed.dart'     # All .freezed.dart files
  - 'lib/generated/**'      # Everything in lib/generated/
  - '*.tmp'                 # Temp files in root
```

#### Complex Pattern with Excludes

An object with `globs` and `excludes` fields:

```yaml
cleanup:
  - globs:
      - 'lib/generated/**'
      - 'lib/cache/**'
    excludes:
      - 'lib/generated/keep_this.dart'
      - 'lib/cache/important.json'
```

**Fields:**
- `globs` (list): Patterns matching files to delete
- `excludes` (list): Patterns for files to preserve (section-specific)

### `excludes` (list, optional)

Global exclude patterns applied to ALL cleanup sections:

```yaml
excludes:
  - '**/important.g.dart'
  - '**/manual_*.dart'
  - 'lib/src/version.g.dart'
```

**Use cases:**
- Project-wide files that should never be deleted
- Files that match cleanup patterns but are manually maintained
- Special generated files needed for builds

## Glob Patterns

### Supported Syntax

- `*` - Matches any characters except /
- `**` - Matches any characters including /
- `?` - Matches any single character
- `[abc]` - Matches any character in the set
- `{a,b}` - Matches either a or b

### Examples

```yaml
cleanup:
  # All .g.dart files anywhere
  - '**/*.g.dart'
  
  # Only in lib directory
  - 'lib/**/*.g.dart'
  
  # Multiple extensions
  - '**/*.{g,freezed}.dart'
  
  # Specific subdirectory
  - 'lib/generated/**'
  
  # Test files
  - 'test/**/*.mocks.dart'
  
  # Cache directories
  - '.dart_tool/build/**'
```

## Exclude Priority

When a file matches multiple patterns, excludes take precedence:

1. **Section-specific excludes** (highest priority)
2. **Global excludes**
3. **Cleanup globs**

### Example

```yaml
cleanup:
  - globs:
      - '**/*.g.dart'
    excludes:
      - 'lib/important.g.dart'  # Section exclude
excludes:
  - '**/manual.g.dart'          # Global exclude
```

**Result:**
- `lib/user.g.dart` → DELETED
- `lib/important.g.dart` → KEPT (section exclude)
- `lib/manual.g.dart` → KEPT (global exclude)
- `test/manual.g.dart` → KEPT (global exclude)

## Usage

### Command Line

```bash
# Clean current project (auto-detects configuration)
dart run tom_cleanup_builder:cleanup

# Clean specific project
dart run tom_cleanup_builder:cleanup --project=my_app

# Scan directory for projects
dart run tom_cleanup_builder:cleanup --scan=. --recursive

# Dry run (show what would be deleted)
dart run tom_cleanup_builder:cleanup --dry-run

# Verbose output
dart run tom_cleanup_builder:cleanup --verbose

# Exclude projects
dart run tom_cleanup_builder:cleanup --scan=. --exclude='**/node_modules/**'
```

### Options

```
-p, --project           Path to specific project to clean
-s, --scan             Directory to scan for projects
-r, --recursive        Process subprojects recursively
-e, --exclude          Glob patterns for projects to exclude
    --recursion-exclude Glob patterns to exclude from recursive traversal
-v, --verbose          Show detailed output
-d, --dry-run          Show what would be deleted without executing
-h, --help             Show help message
```

## Examples

### Example 1: Basic Generated Files

Clean standard generated files:

```yaml
# build.yaml
targets:
  $default:
    builders:
      tom_cleanup_builder:cleanup_builder:
        enabled: true
        options:
          cleanup:
            - '**/*.g.dart'
            - '**/*.freezed.dart'
```

### Example 2: Multiple Patterns with Global Excludes

```yaml
# build.yaml
targets:
  $default:
    builders:
      tom_cleanup_builder:cleanup_builder:
        enabled: true
        options:
          cleanup:
            - '**/*.g.dart'
            - '**/*.freezed.dart'
            - '**/*.mocks.dart'
            - 'lib/generated/**'
          excludes:
            - '**/important.g.dart'
            - 'lib/src/version.g.dart'
```

### Example 3: Section-Specific Excludes

Different exclude rules for different patterns:

```yaml
# build.yaml
targets:
  $default:
    builders:
      tom_cleanup_builder:cleanup_builder:
        enabled: true
        options:
          cleanup:
            # Clean all .g.dart except important ones
            - globs:
                - '**/*.g.dart'
              excludes:
                - 'lib/core/important.g.dart'
            
            # Clean generated directory but keep config
            - globs:
                - 'lib/generated/**'
              excludes:
                - 'lib/generated/config.dart'
                - 'lib/generated/constants.dart'
```

### Example 4: Test Files

Clean test-specific generated files:

```yaml
# build.yaml
targets:
  $default:
    builders:
      tom_cleanup_builder:cleanup_builder:
        enabled: true
        options:
          cleanup:
            - 'test/**/*.mocks.dart'
            - 'test/**/*.g.dart'
            - 'test/fixtures/generated/**'
```

### Example 5: Build Artifacts

Clean build directories and cache:

```yaml
# build.yaml
targets:
  $default:
    builders:
      tom_cleanup_builder:cleanup_builder:
        enabled: true
        options:
          cleanup:
            - '.dart_tool/build/**'
            - 'build/**'
            - '**/*.cache'
            - '**/*.tmp'
```

## Output Format

```
============================================================
Cleanup running
============================================================

Project: my_app
Processing: **/*.g.dart - Found 5, excluded 1, deleted 4
Processing: **/*.freezed.dart - Found 3, excluded 0, deleted 3
Processing: lib/generated/** - Found 10, excluded 2, deleted 8

Cleanup: Processed 1 project(s)
```

### Verbose Output

With `--verbose` flag:

```
============================================================
Cleanup running
============================================================

Project: my_app
  [DRY RUN] Would delete: lib/user.g.dart
  Excluding: lib/important.g.dart
  [DRY RUN] Would delete: lib/model.g.dart
Processing: **/*.g.dart - Found 3, excluded 1, deleted 2
  [DRY RUN] Would delete: lib/generated/auto.dart
  Excluding: lib/generated/keep_me.dart
Processing: lib/generated/** - Found 2, excluded 1, deleted 1

Cleanup: Processed 1 project(s)
```

## Integration with build_runner

You can add cleanup as the first builder in your build pipeline:

```yaml
# build.yaml
targets:
  $default:
    builders:
      # Clean first
      tom_cleanup_builder:cleanup_builder:
        enabled: true
        options:
          cleanup:
            - '**/*.g.dart'
            - '**/*.freezed.dart'
      
      # Then generate
      json_serializable:
        enabled: true
      
      freezed:
        enabled: true
```

Run with:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Project Discovery

A project is considered a "cleanup project" if it:
1. Contains a `pubspec.yaml` file
2. Contains a `build.yaml` file with `tom_cleanup_builder:cleanup_builder` configuration
3. Is not a builder definition project itself

## Best Practices

### 1. Always Use Dry-Run First

Test patterns before actual deletion:

```bash
dart run tom_cleanup_builder:cleanup --dry-run
```

### 2. Be Specific with Patterns

Avoid overly broad patterns that might delete important files:

```yaml
# ❌ Too broad - might delete manually maintained files
cleanup:
  - '**/*.dart'

# ✅ Specific to generated files
cleanup:
  - '**/*.g.dart'
  - '**/*.freezed.dart'
```

### 3. Use Global Excludes for Project-Wide Rules

```yaml
excludes:
  - '**/important.g.dart'      # Never delete this
  - 'lib/src/version.g.dart'   # Version info
  - '**/manual_*.dart'         # Manually maintained
```

### 4. Group Related Patterns

```yaml
cleanup:
  # Code generation
  - '**/*.g.dart'
  - '**/*.freezed.dart'
  
  # Test mocks
  - 'test/**/*.mocks.dart'
  
  # Build artifacts
  - '.dart_tool/build/**'
```

### 5. Document Special Excludes

```yaml
excludes:
  # Version file needed for build info
  - 'lib/src/version.g.dart'
  
  # Core types manually maintained despite .g.dart extension
  - 'lib/core/important.g.dart'
```

## Troubleshooting

### "No cleanup configuration found in project"

**Cause:** No `build.yaml` with cleanup configuration found.

**Solution:** Add cleanup configuration to `build.yaml` in your project.

### Files not being deleted

**Possible causes:**
1. File matches an exclude pattern
2. Pattern doesn't match the file path
3. File permissions prevent deletion

**Solutions:**
- Use `--verbose` to see what's being excluded
- Test patterns with `--dry-run`
- Check file paths relative to project root

### Pattern not matching expected files

**Common issues:**
- Missing `**` for recursive matching
- Wrong path separators (use `/` not `\`)
- Quotes needed for glob patterns in YAML

**Example:**
```yaml
# ❌ Wrong - only matches top level
cleanup:
  - '*.g.dart'

# ✅ Correct - matches recursively
cleanup:
  - '**/*.g.dart'
```

### Too many files being deleted

**Solution:** Add excludes or make patterns more specific:

```yaml
cleanup:
  - globs:
      - '**/*.g.dart'
    excludes:
      - 'lib/core/**'       # Exclude entire directory
      - '**/important_*'    # Exclude by name pattern
```

## See Also

- [Glob Pattern Syntax](https://pub.dev/packages/glob)
- [YAML Configuration](https://yaml.org/)
