# CLI Tools and Workspace Navigation

This document describes the standard CLI patterns and workspace navigation options used by all Tom build tools.

## Overview

Tom build tools share a consistent set of command-line options for workspace traversal. This is provided by the `workspace_mode.dart` module in `tom_build_base`.

## Standard Commands

All Tom build tools support these command patterns:

### Help Command

```bash
<tool> help           # Show help
<tool> --help         # Show help
<tool> -h             # Show help (short form)
```

### Version Command

```bash
<tool> version        # Show version
<tool> --version      # Show version
<tool> -version       # Show version (legacy)
```

## Execution Modes

Tom tools operate in two execution modes:

### Project Mode (Default)

When run without explicit navigation options, tools operate in **project mode**:

- Works from the current directory
- Automatically applies: `--scan . --recursive --build-order`
- Processes the current project and its subprojects

```bash
# These are equivalent in project mode:
astgen
astgen --scan . --recursive --build-order
```

### Workspace Mode

When navigation options are provided, tools operate in **workspace mode**:

- Triggered by: `-R`, `-s <path>` (where path ≠ "."), `-i`, or `-o`
- Does NOT auto-apply defaults
- Processes exactly what you specify

```bash
# Workspace mode examples:
astgen -R                    # From detected workspace root
astgen -R /path/to/workspace # From specified workspace
astgen -s packages/          # Scan specific directory
astgen -i                    # Inner-first git mode
```

## Navigation Options

### Scanning and Traversal

| Option | Abbr | Description |
|--------|------|-------------|
| `--scan=<path>` | `-s` | Scan directory for projects |
| `--recursive` | `-r` | Scan directories recursively |
| `--build-order` | `-b` | Sort projects in dependency build order |
| `--project=<pattern>` | `-p` | Project(s) to run (comma-separated, globs supported) |

### Workspace Root

| Option | Abbr | Description |
|--------|------|-------------|
| `--root` | `-R` | Bare: auto-detect workspace root |
| `--root=<path>` | `-R` | Use specified path as workspace root |
| `--workspace-recursion` | `-w` | Shell out to sub-workspaces instead of skipping |

**Workspace detection** looks for these files (in order):
- `buildkit_master.yaml`
- `tom_workspace.yaml`
- `tom.code-workspace`

### Git Repository Traversal

| Option | Abbr | Description |
|--------|------|-------------|
| `--inner-first-git` | `-i` | Scan git repos, process innermost (deepest) first |
| `--outer-first-git` | `-o` | Scan git repos, process outermost (shallowest) first |

**Use cases:**
- `-i`: For commit/push operations (leaf repos first)
- `-o`: For pull/fetch operations (parent repos first)

### Exclusion Patterns

| Option | Abbr | Description |
|--------|------|-------------|
| `--exclude=<glob>` | `-x` | Exclude patterns (path-based globs) |
| `--exclude-projects=<pattern>` | | Exclude projects by name or path |
| `--recursion-exclude=<glob>` | | Exclude patterns during recursive scan |

**Pattern syntax:**
- `*` matches any characters except `/`
- `**` matches any characters including `/`
- Can be specified multiple times

```bash
# Examples:
astgen -R -x '**/test/**' -x '**/example/**'
astgen --exclude-projects='zom_*,test_*'
astgen --recursion-exclude='**/.git/**,**/node_modules/**'
```

## Implementation Guide

### Adding Navigation to Your Tool

```dart
import 'package:args/args.dart';
import 'package:tom_build_base/tom_build_base.dart';

void main(List<String> args) async {
  // 1. Check for help/version commands first
  if (isHelpCommand(args)) {
    _printUsage();
    return;
  }
  if (isVersionCommand(args)) {
    print('MyTool $version');
    return;
  }

  // 2. Preprocess args for bare -R detection
  final (processedArgs, bareRoot) = preprocessRootFlag(args);

  // 3. Create parser with tool-specific options
  final parser = ArgParser()
    ..addOption('config', abbr: 'c', help: 'Config file path')
    ..addFlag('verbose', abbr: 'v', help: 'Verbose output')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');
  
  // 4. Add standard navigation options
  addNavigationOptions(parser);

  // 5. Parse arguments
  final results = parser.parse(processedArgs);
  
  if (results['help'] as bool) {
    _printUsage();
    return;
  }

  // 6. Parse navigation options
  final navArgs = parseNavigationArgs(results, bareRoot: bareRoot);
  
  // 7. Resolve execution root
  final executionRoot = resolveExecutionRoot(
    navArgs,
    currentDir: Directory.current.path,
  );

  // 8. Apply defaults if needed
  final effectiveNavArgs = navArgs.withDefaults();

  // 9. Find projects using navigation args
  final discovery = ProjectDiscovery(verbose: results['verbose'] as bool);
  final projects = await discovery.findProjects(effectiveNavArgs, executionRoot);

  // 10. Process projects...
}

void _printUsage() {
  // Print tool-specific header
  print('MyTool - Does something useful');
  print('');
  print('Usage:');
  print('  mytool [options]');
  print('  mytool help');
  print('  mytool version');
  print('');
  
  // Print tool-specific options
  print('Tool Options:');
  print('  -c, --config=<path>  Config file path');
  print('  -v, --verbose        Verbose output');
  print('  -h, --help           Show help');
  print('');
  
  // Print standard navigation options
  printNavigationOptionsHelp();
}
```

### Generating Consistent Help Output

Use the helper functions to ensure consistent help text:

```dart
void _printUsage(ArgParser parser) {
  // Print header
  for (final line in getToolHelpHeader(
    toolName: 'Astgen',
    toolDescription: 'Converts Dart source files to serialized AST YAML files',
    usagePatterns: [
      'astgen [options]',
      'astgen help',
      'astgen version',
    ],
  )) {
    print(line);
  }

  // Print tool-specific options
  print('Tool Options:');
  print(parser.usage);  // ArgParser's built-in usage
  print('');

  // Print navigation options
  printNavigationOptionsHelp();

  // Print footer with examples
  for (final line in getToolHelpFooter(toolName: 'astgen')) {
    print(line);
  }
}
```

## API Reference

### Functions

| Function | Description |
|----------|-------------|
| `isHelpCommand(args)` | Check if first arg is a help command |
| `isVersionCommand(args)` | Check if first arg is a version command |
| `addNavigationOptions(parser)` | Add standard navigation options to ArgParser |
| `preprocessRootFlag(args)` | Detect bare `-R` and preprocess for parsing |
| `parseNavigationArgs(results, bareRoot)` | Parse navigation options from ArgResults |
| `resolveExecutionRoot(navArgs, currentDir)` | Resolve workspace root based on nav args |
| `findWorkspaceRoot(startPath)` | Find workspace root by traversing up |
| `isWorkspaceBoundary(dirPath)` | Check if directory has buildkit_master.yaml |
| `printNavigationOptionsHelp()` | Print navigation options help to stdout |
| `getNavigationOptionsHelpLines()` | Get navigation options help as list of strings |
| `getToolHelpHeader(...)` | Generate standard tool help header |
| `getToolHelpFooter(toolName)` | Generate standard tool help footer |

### Classes

| Class | Description |
|-------|-------------|
| `WorkspaceNavigationArgs` | Parsed navigation options container |
| `ExecutionMode` | Enum: `project` or `workspace` |

### WorkspaceNavigationArgs Properties

| Property | Type | Description |
|----------|------|-------------|
| `scan` | `String?` | Scan directory path |
| `recursive` | `bool` | Recursive scanning enabled |
| `buildOrder` | `bool` | Sort by dependency order |
| `project` | `String?` | Project pattern(s) |
| `root` | `String?` | Explicit workspace root path |
| `bareRoot` | `bool` | True if bare `-R` was used |
| `workspaceRecursion` | `bool` | Shell out to sub-workspaces |
| `innerFirstGit` | `bool` | Inner-first git traversal |
| `outerFirstGit` | `bool` | Outer-first git traversal |
| `exclude` | `List<String>` | Exclude patterns |
| `excludeProjects` | `List<String>` | Excluded project names/paths |
| `recursionExclude` | `List<String>` | Recursion exclude patterns |
| `executionMode` | `ExecutionMode` | Computed: project or workspace |
| `isWorkspaceMode` | `bool` | True if in workspace mode |
| `isProjectMode` | `bool` | True if in project mode |

### WorkspaceNavigationArgs Methods

| Method | Description |
|--------|-------------|
| `withDefaults()` | Apply default scan/recursive/build-order if no explicit nav |
| `copyWith(...)` | Create modified copy |

## Tools Using This System

All these tools share identical navigation options:

| Tool | Package | Purpose |
|------|---------|---------|
| `buildkit` | tom_build_kit | Pipeline orchestration |
| `versioner` | tom_build_kit | Version file generation |
| `compiler` | tom_build_kit | Cross-platform compilation |
| `cleanup` | tom_build_kit | Clean generated files |
| `runner` | tom_build_kit | Build_runner wrapper |
| `bumpversion` | tom_build_kit | Bump pubspec versions |
| `dependencies` | tom_build_kit | Dependency tree visualization |
| `buildsorter` | tom_build_kit | Build order sorting |
| `astgen` | tom_d4rt_astgen | AST serialization |
| `d4rtgen` | tom_d4rt_generator | D4rt bridge generation |
