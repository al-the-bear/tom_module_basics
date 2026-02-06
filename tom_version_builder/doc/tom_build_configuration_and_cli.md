# Tom Version Builder - Configuration and CLI Reference

This document covers both the `tom_build.yaml` configuration file and command-line interface options for the Tom Version Builder tool.

## Configuration File: tom_build.yaml

The `tom_build.yaml` file is an optional configuration file placed in the project root that controls project discovery, default CLI options, and version generation settings for the versioner tool.

### Location

```
my_project/
├── tom_build.yaml    # Optional configuration
├── build.yaml        # Optional: builder configuration
└── pubspec.yaml      # Required: source of version info
```

### Structure

```yaml
# tom_build.yaml
versioner:
  project: .
  scan: ../
  recursive: true
  exclude:
    - '**/node_modules/**'
    - '**/build/**'
  recursion-exclude:
    - '**/.git/**'
  verbose: false
  output: lib/src/version.g.dart
  includeGitCommit: true
```

### Configuration Fields

#### `project` (string, optional)

Path to a specific project to generate version files for. Relative to the tom_build.yaml location.

**Default:** `.` (current directory)

**Examples:**
```yaml
project: .                    # Current directory
project: ../my_app            # Parent directory
project: packages/core        # Subdirectory
```

**CLI equivalent:** `--project` or `-p`

#### `scan` (string, optional)

Directory to scan for projects needing version file generation.

**Default:** Not set (no scanning)

**Examples:**
```yaml
scan: .                       # Scan current directory
scan: ../                     # Scan parent directory
scan: packages/               # Scan packages directory
```

**CLI equivalent:** `--scan` or `-s`

**Note:** When `scan` is set, the tool will search for all projects with `pubspec.yaml` files.

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
  - '**/example/**'           # Skip example projects
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

Enable detailed output showing generation progress and file contents.

**Default:** `false`

**Examples:**
```yaml
verbose: true                 # Show detailed output
verbose: false                # Show summary only
```

**CLI equivalent:** `--verbose` or `-v`

#### `output` (string, optional)

Path for the generated version file, relative to project root.

**Default:** `lib/src/version.g.dart`

**Examples:**
```yaml
output: lib/src/version.g.dart    # Default location
output: lib/version.dart          # Custom location
output: lib/src/app_version.g.dart # Custom name
```

**CLI equivalent:** `--output`

**Note:** This can also be configured in `build.yaml` if using the builder integration.

#### `includeGitCommit` (boolean, optional)

Whether to include git commit hash in the generated version file.

**Default:** `true`

**Examples:**
```yaml
includeGitCommit: true        # Include git commit hash
includeGitCommit: false       # Skip git operations
```

**CLI equivalent:** `--no-git` (to disable)

**Note:** If set to `false` or git is not available, the git commit field will be set to `"unknown"`.

### Complete Example

```yaml
# tom_build.yaml
versioner:
  # Scan the workspace for projects
  scan: ../
  recursive: true
  
  # Exclude unnecessary directories
  exclude:
    - '**/node_modules/**'
    - '**/build/**'
    - '**/.dart_tool/**'
    - '**/test/**'
    - '**/example/**'
  
  # Don't even look inside these directories
  recursion-exclude:
    - '**/.git/**'
    - '**/node_modules/**'
  
  # Version file settings
  output: lib/src/version.g.dart
  includeGitCommit: true
  
  # Show detailed output
  verbose: true
```

## Command-Line Interface

### Basic Usage

```bash
# Run with tom_build.yaml configuration
dart run tom_version_builder:versioner

# Override configuration with CLI options
dart run tom_version_builder:versioner --project=my_app --verbose

# Scan for projects
dart run tom_version_builder:versioner --scan=. --recursive
```

### CLI Options

#### `-p, --project <path>`

Path to a specific project to generate version file for.

**Examples:**
```bash
dart run tom_version_builder:versioner --project=.
dart run tom_version_builder:versioner -p ../my_app
dart run tom_version_builder:versioner --project=packages/core
```

**Overrides:** `versioner.project` in tom_build.yaml

#### `--projects <pattern>`

Glob patterns for projects to process. Can be specified multiple times.

**Examples:**
```bash
dart run tom_version_builder:versioner --projects='packages/*'
dart run tom_version_builder:versioner --projects='packages/core' --projects='packages/utils'
```

**Use case:** Process specific subset of projects when scanning.

#### `-s, --scan <path>`

Directory to scan for projects needing version files.

**Examples:**
```bash
dart run tom_version_builder:versioner --scan=.
dart run tom_version_builder:versioner -s ../
dart run tom_version_builder:versioner --scan=packages/
```

**Overrides:** `versioner.scan` in tom_build.yaml

#### `-r, --recursive`

Process subprojects recursively.

**Examples:**
```bash
dart run tom_version_builder:versioner --scan=. --recursive
dart run tom_version_builder:versioner -s ../ -r
```

**Overrides:** `versioner.recursive` in tom_build.yaml

#### `-e, --exclude <pattern>`

Glob pattern for projects to exclude. Can be specified multiple times.

**Examples:**
```bash
dart run tom_version_builder:versioner --scan=. --exclude='**/test/**'
dart run tom_version_builder:versioner -e '**/node_modules/**' -e '**/build/**'
```

**Overrides:** `versioner.exclude` in tom_build.yaml

#### `--recursion-exclude <pattern>`

Glob pattern to exclude from recursive traversal. Can be specified multiple times.

**Examples:**
```bash
dart run tom_version_builder:versioner --scan=. --recursion-exclude='**/.git/**'
dart run tom_version_builder:versioner --recursion-exclude='**/node_modules/**'
```

**Overrides:** `versioner.recursion-exclude` in tom_build.yaml

#### `--output <path>`

Path for the generated version file (relative to project root).

**Examples:**
```bash
dart run tom_version_builder:versioner --output=lib/version.dart
dart run tom_version_builder:versioner --output=lib/src/app_version.g.dart
```

**Overrides:** `versioner.output` in tom_build.yaml

#### `--no-git`

Exclude git commit hash from generated version file.

**Examples:**
```bash
dart run tom_version_builder:versioner --no-git
dart run tom_version_builder:versioner --project=my_app --no-git
```

**Overrides:** `versioner.includeGitCommit` in tom_build.yaml (sets to `false`)

**Use case:** Projects not in git repositories or when git is not available.

#### `--version <version>`

Override version from pubspec.yaml.

**Examples:**
```bash
dart run tom_version_builder:versioner --version=1.2.3
dart run tom_version_builder:versioner --version=2.0.0-beta.1
```

**Use case:** CI/CD builds where version is determined by release tags.

#### `-v, --verbose`

Show detailed output including file contents and git operations.

**Examples:**
```bash
dart run tom_version_builder:versioner --verbose
dart run tom_version_builder:versioner -v --scan=.
```

**Overrides:** `versioner.verbose` in tom_build.yaml

**Verbose output includes:**
- Projects being processed
- Version information extracted
- Git operations (if enabled)
- Generated file paths
- Build number increments

#### `-h, --help`

Display help message with all available options.

**Example:**
```bash
dart run tom_version_builder:versioner --help
```

## Configuration Priority

When the same option is specified in multiple places, the priority order is:

1. **CLI arguments** (highest priority)
2. **tom_build.yaml file**
3. **build.yaml file** (for `output` only)
4. **Default values** (lowest priority)

**Example:**
```yaml
# tom_build.yaml
versioner:
  output: lib/src/version.g.dart
  includeGitCommit: true
```

```bash
# CLI overrides output, uses includeGitCommit from config
dart run tom_version_builder:versioner --output=lib/version.dart
# Result: output=lib/version.dart, includeGitCommit=true
```

## Usage Patterns

### Pattern 1: Single Project

Generate version file for a specific project:

```bash
dart run tom_version_builder:versioner --project=my_app
```

Or with configuration:
```yaml
# tom_build.yaml
versioner:
  project: .
  output: lib/src/version.g.dart
```

```bash
dart run tom_version_builder:versioner
```

### Pattern 2: Workspace Scanning

Generate version files for all projects in a workspace:

```bash
dart run tom_version_builder:versioner --scan=. --recursive --exclude='**/test/**'
```

Or with configuration:
```yaml
# tom_build.yaml (in workspace root)
versioner:
  scan: .
  recursive: true
  exclude:
    - '**/test/**'
    - '**/example/**'
```

```bash
dart run tom_version_builder:versioner
```

### Pattern 3: Pre-Build Version Generation

Generate version files before building:

```bash
#!/bin/bash
# build.sh
dart run tom_version_builder:versioner --scan=packages --recursive
dart run build_runner build
dart compile exe bin/app.dart
```

### Pattern 4: CI/CD with Version Override

In CI/CD scripts with release tags:

```bash
#!/bin/bash
# release.sh
VERSION=$(git describe --tags --abbrev=0)
dart run tom_version_builder:versioner \
  --scan=packages \
  --recursive \
  --version=$VERSION \
  --verbose
```

### Pattern 5: Non-Git Projects

For projects not in git repositories:

```yaml
# tom_build.yaml
versioner:
  project: .
  includeGitCommit: false
```

Or via CLI:

```bash
dart run tom_version_builder:versioner --no-git
```

### Pattern 6: Selective Projects

Generate version files only for specific projects:

```bash
dart run tom_version_builder:versioner \
  --scan=packages \
  --projects='packages/core' \
  --projects='packages/utils'
```

## Build State Management

The tool maintains build state in `tom_build_state.json` in each project root:

```json
{
  "buildNumber": 42,
  "lastBuildTime": "2026-02-06T10:30:45.123Z"
}
```

### Build Number Behavior

- Starts at 1 for new projects
- Increments by 1 with each version generation
- Persists across builds
- Independent per project
- Can be reset by deleting `tom_build_state.json`

### Resetting Build Numbers

```bash
# Delete state file to reset build number
rm tom_build_state.json

# Next run will start from build number 1
dart run tom_version_builder:versioner
```

## Integration with build_runner

The versioner can be integrated into your build_runner pipeline:

```yaml
# build.yaml
targets:
  $default:
    builders:
      tom_version_builder:version_builder:
        enabled: true
        options:
          output: lib/src/version.g.dart
          includeGitCommit: true
```

**Note:** This is in addition to the standalone CLI tool. The builder runs automatically with `build_runner`, while the CLI tool is run manually or in scripts.

## Troubleshooting

### "No projects found to process"

**Cause:** No projects with `pubspec.yaml` found.

**Solutions:**
1. Verify `pubspec.yaml` exists in project(s)
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

### Git commit shows "unknown"

**Possible causes:**
1. Project not in a git repository
2. Git not installed or not in PATH
3. No commits in repository yet
4. `includeGitCommit` is `false` or `--no-git` flag used

**Solutions:**
- Initialize git repository: `git init && git add . && git commit -m "Initial commit"`
- Install git if missing
- Verify git is in PATH: `git --version`
- Remove `--no-git` flag if accidentally set

### Build number not incrementing

**Possible causes:**
1. `tom_build_state.json` file was deleted
2. File permissions prevent writing
3. Multiple parallel builds writing simultaneously

**Solutions:**
- Build number will restart from 1 if state file is missing (expected behavior)
- Check file permissions in project directory
- Avoid parallel version generation for the same project

### Version not updating

**Cause:** Version comes from pubspec.yaml, not version file.

**Solution:**
- Update version in `pubspec.yaml`
- Or use `--version` CLI option to override
- Generated file reflects pubspec.yaml version + incremented build number

### Wrong Dart SDK version

**Cause:** SDK version is captured at generation time, not runtime.

**Solution:** This is expected behavior. The SDK version reflects the build environment.

## Best Practices

1. **Generate before building releases**
   ```bash
   dart run tom_version_builder:versioner
   dart compile exe bin/app.dart
   ```

2. **Add generated files to .gitignore**
   ```gitignore
   **/version.g.dart
   tom_build_state.json
   ```

3. **Use consistent output paths**
   ```yaml
   output: lib/src/version.g.dart
   ```

4. **Display version in your app**
   ```dart
   print('App ${TomVersionInfo.versionMedium}');
   ```

5. **Log version at startup**
   ```dart
   void main() {
     print('Starting ${TomVersionInfo.versionLong}');
     runApp(MyApp());
   }
   ```

6. **Use version override in CI/CD**
   ```bash
   VERSION=$(git describe --tags)
   dart run tom_version_builder:versioner --version=$VERSION
   ```

## See Also

- [User Guide](user_guide.md) - Complete usage documentation
- [build.yaml Configuration](user_guide.md#configuration) - Builder configuration
- [Semantic Versioning](https://semver.org/)
