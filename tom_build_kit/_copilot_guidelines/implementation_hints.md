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
