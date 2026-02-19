# Implementation Hints — tom_build_base Integration

This document describes the relationship between `tom_build_kit` and the shared CLI infrastructure from `tom_build_base`.

## Overview

`tom_build_kit` provides the build tools for the Tom workspace:
- **versioner** — Generate version.versioner.dart files
- **bumpversion** — Bump pubspec.yaml versions
- **cleanup** — Remove generated files
- **compiler** — Cross-platform compilation
- **runner** — build_runner wrapper
- **dependencies** — Dependency visualization
- **buildsorter** — Build order sorting

All tools inherit from `ToolBase` (in `lib/src/commands/tool_base.dart`), which uses the shared infrastructure from `tom_build_base`.

## Dependencies on tom_build_base

### Workspace Navigation

All navigation options are provided by `tom_build_base`:

```dart
import 'package:tom_build_base/tom_build_base.dart';

// In createParser():
addNavigationOptions(parser);  // Adds -s, -r, -p, -R, -x, etc.

// In run():
final navArgs = parseNavigationArgs(results);
```

### CLI Commands

The base package provides standardized help/version detection:

```dart
// Delegates to tom_build_base
bool checkVersionArg(List<String> args) => isVersionCommand(args);
bool checkHelpArg(List<String> args) => isHelpCommand(args);
```

### Help Output

Standardized help output is generated using:

```dart
printUsageHeader();              // Tool name, usage patterns
printExecutionModesExplanation(); // Project/Workspace mode explanation
printUsageFooter();              // Common examples
```

### Project Discovery

```dart
final projects = await findProjectsFromNavArgs(navArgs, basePath: executionRoot);
```

## Tom Build Base Reference

See the following documentation in `tom_build_base`:

| Document | Description |
|----------|-------------|
| [cli_tools_navigation.md](../../tom_build_base/doc/cli_tools_navigation.md) | Standard CLI commands, execution modes, navigation options |
| [build_base_user_guide.md](../../tom_build_base/doc/build_base_user_guide.md) | Configuration loading, project discovery, workspace mode |

### Key Files in tom_build_base

| File | Purpose |
|------|---------|
| `lib/src/workspace_mode.dart` | Navigation args, execution modes, CLI helpers |
| `lib/src/project_discovery.dart` | Project scanning and pattern matching |
| `lib/src/build_config.dart` | TomBuildConfig loading |

## Adding a New Tool

When creating a new tool:

1. **Extend ToolBase** — Inherit common functionality
2. **Override `toolKey`** — Used in buildkit.yaml configuration
3. **Override `toolDescription`** — Shown in help output
4. **Override `addToolOptions`** — Add tool-specific CLI options
5. **Override `isToolProject`** — Define project detection criteria
6. **Use `checkVersionArg/checkHelpArg`** — Handle version/help commands early
7. **Use `parseArgsWithExecutionMode`** — Parse args with navigation handling
8. **Use `printUsageHeader/printExecutionModesExplanation`** — Standardized help

Example template:

```dart
class MyTool extends ToolBase {
  @override
  String get toolKey => 'mytool';

  @override
  String get toolDescription => 'My tool description';

  @override
  Future<bool> run(List<String> args) async {
    if (checkVersionArg(args)) return true;
    if (checkHelpArg(args)) {
      _printUsage(createParser());
      return true;
    }
    // ... implementation
  }

  void _printUsage(ArgParser parser) {
    printUsageHeader();
    print('Options:');
    print(parser.usage);
    printExecutionModesExplanation();
    // ... tool-specific help
  }
}
```

## Version History

- **2026-02**: Added standardized CLI help/version support via tom_build_base
## Debugging Traversal with :execute

The `:execute` command is a powerful tool for testing and debugging navigation options before running actual commands. It executes arbitrary shell commands in each discovered project, showing you exactly which projects are selected and in what order.

### Placeholder-Based Diagnostics

The `:execute` command supports placeholders that provide detailed information about each traversed folder. Use these for diagnostic output:

#### Git Traversal Diagnostic

Shows all git repository information:

```bash
# Full git diagnostic with -i (inner-first) traversal
buildkit -T -i :execute 'echo "📂 ${folder.name} | Path: ${folder.relative} | Git: ${git.exists} | Branch: ${git.branch} | Changes: ${git.hasChanges} | Submodule: ${git.isSubmodule}"'

# Compact git info
buildkit -T -o :execute 'echo "${folder.name}: ${git.branch} [${git.hasChanges?(dirty):(clean)}]"'
```

#### Project Traversal Diagnostic

Shows Dart/Flutter project information:

```bash
# Full Dart project diagnostic with --condition to filter
buildkit -R --scan . -r :execute --condition dart.exists 'echo "📦 ${folder.name} | Name: ${dart.name} | Ver: ${dart.version} | Pub: ${dart.publishable}"'

# Flutter projects only
buildkit -R --scan . -r :execute --condition flutter.exists 'echo "${folder.name}: ${flutter.platforms} [${flutter.isPlugin?(plugin):(app)}]"'
```

### Available Placeholders

| Placeholder | Description |
|-------------|-------------|
| `${folder.name}` | Folder basename |
| `${folder.relative}` | Relative path from workspace root |
| `${folder}` | Absolute folder path |
| `${root}` | Workspace root path |
| `${git.exists}` | Boolean: is git repository |
| `${git.branch}` | Current git branch |
| `${git.hasChanges}` | Boolean: has uncommitted changes |
| `${git.isSubmodule}` | Boolean: is git submodule |
| `${dart.exists}` | Boolean: is Dart project |
| `${dart.name}` | Package name from pubspec.yaml |
| `${dart.version}` | Version from pubspec.yaml |
| `${dart.publishable}` | Boolean: publish_to not set to none |
| `${flutter.exists}` | Boolean: is Flutter project |
| `${flutter.platforms}` | Comma-separated platform list |
| `${flutter.isPlugin}` | Boolean: is Flutter plugin |
| `${current-os}` | Current OS (macos, linux, windows) |
| `${current-arch}` | Current architecture (arm64, x64) |
| `${current-platform}` | Platform string (darwin-arm64, linux-x64) |

### Ternary Placeholder Syntax

Use ternary syntax for conditional output:

```bash
# Show (dirty) or (clean) based on git.hasChanges
buildkit -T -i :execute 'echo "${folder.name}: ${git.hasChanges?(dirty):(clean)}"'

# Show (Pub) or (Internal) based on dart.publishable
buildkit -R -s . -r :execute --condition dart.exists 'echo "${dart.name}: ${dart.publishable?(Pub):(Internal)}"'
```

### Basic Usage

```bash
# Test which projects would be affected
buildkit -T -i :execute echo "Test"

# Show project paths
buildkit -s . -r :execute pwd

# Verify git traversal order
buildkit -T -o :execute echo "Repo: $(basename $(git rev-parse --show-toplevel 2>/dev/null || pwd))"
```

### Examples

```bash
# Debug -T (top-repo) with inner-first traversal
buildkit -T -i :execute echo "Project: ${PWD##*/}"

# Test --project filter
buildkit --project tom_build_* :execute echo "Found"

# Verify --exclude-projects filtering
buildkit -s . -r --exclude-projects "zom_*" :execute ls -la

# Test modules filter
buildkit -m tom_module_basics :execute echo "In basics"
```

### Key Points

- `:execute` respects all navigation options (`-T`, `-i`, `-o`, `-s`, `-r`, `-p`, etc.)
- Output shows project name before command output for each project
- Use `--dry-run` with other commands first, then `:execute` to verify traversal
- Combine with `echo` for quick visibility checks

## Architecture Issue: Option Duplication

### Current Problem

`buildkit.dart` duplicates navigation options instead of using `addNavigationOptions()` from tom_build_base:

**buildkit.dart:**
```dart
ArgParser _createGlobalParser() {
  return ArgParser(allowTrailingOptions: false)
    ..addFlag('inner-first-git', abbr: 'i', ...)  // Duplicated!
    ..addFlag('outer-first-git', abbr: 'o', ...)  // Duplicated!
    ..addFlag('top-repo', abbr: 'T', ...)         // Duplicated!
    // ... all manually defined
}
```

**Standalone tools (via ToolBase):**
```dart
ArgParser createParser() {
  final parser = ArgParser(allowTrailingOptions: false);
  addNavigationOptions(parser);  // Uses tom_build_base
  // ...
}
```

### Missing Options in buildkit.dart

When tom_build_base adds new options, buildkit.dart must be manually updated in THREE places:
1. `_createGlobalParser()` — Parse the option
2. `_executeCommand()` — Pass option to underlying commands
3. `_generateCommandHelp()` — Document the option

Currently missing from buildkit.dart:
- `--recursion-exclude` — Exclude patterns during recursive scan
- `--modes` — Active modes for config processing

### Proposed Solution

Refactor buildkit.dart to use tom_build_base's `addNavigationOptions()`:

```dart
ArgParser _createGlobalParser() {
  final parser = ArgParser(allowTrailingOptions: false)
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help')
    ..addFlag('version', abbr: 'V', negatable: false, help: 'Show version')
    ..addFlag('verbose', abbr: 'v', negatable: false, help: 'Verbose output')
    ..addFlag('dry-run', abbr: 'n', negatable: false, help: 'Show what would be executed')
    ..addFlag('list', abbr: 'l', negatable: false, help: 'List available pipelines');
  
  // Delegate navigation options to tom_build_base
  addNavigationOptions(parser);
  
  return parser;
}
```

Then use `WorkspaceNavigationArgs` for passing options:

```dart
Future<bool> _executeCommand(...) async {
  // Parse navigation args once, pass them directly
  final navArgs = parseNavigationArgs(globalResults, bareRoot: bareRootFlag);
  final execArgs = navArgs.toArgs();  // Convert back to arg list
  // ...
}
```

### Benefits of Unified Architecture

1. **Single source of truth** — Options defined only in tom_build_base
2. **Automatic updates** — New options automatically available in buildkit
3. **Consistent behavior** — Same parsing logic in kit-mode and standalone-mode
4. **Reduced maintenance** — No more manual option synchronization

### Implementation Priority

- **High**: Add missing `--recursion-exclude` and `--modes` options to buildkit.dart
- **Medium**: Refactor to use `addNavigationOptions()`
- **Long-term**: Add `WorkspaceNavigationArgs.toArgs()` helper to tom_build_base