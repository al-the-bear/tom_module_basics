# Tom Build Base User Guide

This guide explains how to use `tom_build_base` to create CLI tools that integrate with the `tom_build.yaml` and `build.yaml` configuration patterns used in the Tom workspace.

## Overview

`tom_build_base` provides shared infrastructure for Tom build tools:

- **Configuration loading** from `tom_build.yaml` files
- **Build.yaml utilities** for detecting builder definitions vs consumer configurations
- **Project scanning** for finding and validating projects in a directory structure
- **Path validation** for security (ensuring paths stay within the workspace)
- **Result tracking** for reporting success/failure counts

## Installation

Add `tom_build_base` as a dependency:

```yaml
dependencies:
  tom_build_base: ^1.0.0
```

Import the library:

```dart
import 'package:tom_build_base/tom_build_base.dart';
```

## Configuration Pattern

Tom build tools follow a two-tier configuration pattern:

### 1. tom_build.yaml (Primary - Tool-Specific)

A `tom_build.yaml` file in a project root provides tool-specific configuration:

```yaml
# tom_build.yaml
dartgen:
  project: .
  recursive: true
  verbose: false
  # Tool-specific options
  modules:
    - name: core
      barrelFiles:
        - lib/core.dart

versioner:
  output: lib/src/version.g.dart
  includeGitCommit: true
```

Each top-level key is a tool name, containing that tool's configuration.

### 2. build.yaml (Secondary - build_runner Format)

A `build.yaml` file uses the standard build_runner format:

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

## Loading Configuration

Use `TomBuildConfig` to load tool-specific configuration:

```dart
import 'package:tom_build_base/tom_build_base.dart';

const toolKey = 'mytool';

// Load from tom_build.yaml
final config = TomBuildConfig.load(
  dir: '/path/to/project',
  toolKey: toolKey,
);

if (config != null) {
  print('Project: ${config.project}');
  print('Recursive: ${config.recursive}');
  print('Verbose: ${config.verbose}');
  
  // Access tool-specific options
  final customOption = config.toolOptions['myCustomOption'];
}
```

### TomBuildConfig Properties

| Property | Type | Description |
|----------|------|-------------|
| `project` | `String?` | Path to a single project directory |
| `projects` | `List<String>` | Glob patterns for projects to process |
| `scan` | `String?` | Directory to scan for projects |
| `config` | `String?` | Path to a specific config file |
| `recursive` | `bool` | Whether to process subprojects recursively |
| `exclude` | `List<String>` | Glob patterns for projects to exclude |
| `recursionExclude` | `List<String>` | Glob patterns to exclude from recursion |
| `verbose` | `bool` | Whether to show detailed output |
| `toolOptions` | `Map<String, dynamic>` | All options from the tool section (for custom options) |

### Checking for Configuration

```dart
// Check if tom_build.yaml exists with a specific tool section
if (hasTomBuildConfig(projectPath, 'mytool')) {
  print('Project has mytool configuration');
}
```

## Detecting Builder Definitions vs Consumers

When scanning for projects, CLI tools should distinguish between:

- **Builder definition packages**: Contain `builders:` section (e.g., `tom_d4rt_generator`)
- **Consumer packages**: Contain `targets:` with builder configuration

### Skip Builder Definitions

Builder packages define builders for build_runner but shouldn't be processed as consumers:

```dart
// In your project detection logic
bool isMyToolProject(String dirPath) {
  // Skip packages that DEFINE builders
  if (isBuildYamlBuilderDefinition(dirPath)) {
    return false;
  }
  
  // Check for consumer configuration
  if (hasBuildYamlConsumerConfig(dirPath, 'my_package:my_builder')) {
    return true;
  }
  
  // Check for tom_build.yaml configuration
  if (hasTomBuildConfig(dirPath, 'mytool')) {
    return true;
  }
  
  return false;
}
```

### Build.yaml Utility Functions

| Function | Purpose |
|----------|---------|
| `isBuildYamlBuilderDefinition(dirPath)` | Returns `true` if build.yaml has `builders:` section |
| `hasBuildYamlConsumerConfig(dirPath, builderName)` | Returns `true` if build.yaml has consumer config for the builder |
| `getBuildYamlBuilderOptions(dirPath, builderName)` | Extracts the `options` map for a builder |
| `isBuildYamlBuilderEnabled(dirPath, builderName)` | Checks if builder is enabled (default: `true`) |

### Example: Loading Builder Options

```dart
final options = getBuildYamlBuilderOptions(
  projectPath,
  'tom_version_builder:version_builder',
);

if (options != null) {
  final output = options['output'] as String? ?? 'lib/src/version.g.dart';
  final includeGit = options['includeGitCommit'] as bool? ?? true;
}
```

## Path Validation

For security, validate that user-provided paths stay within the workspace:

```dart
final error = validatePathContainment(
  project: config.project,
  projects: config.projects,
  scan: config.scan,
  basePath: Directory.current.path,
);

if (error != null) {
  print('Error: $error');
  exit(1);
}
```

### Path Utility Functions

| Function | Purpose |
|----------|---------|
| `isPathContained(targetPath, basePath)` | Returns `true` if target is within base |
| `validatePathContainment(...)` | Validates multiple paths, returns error message or `null` |

## Project Scanning

Use `ProjectScanner` for directory traversal:

```dart
final scanner = ProjectScanner(
  toolKey: 'mytool',
  basePath: Directory.current.path,
  verbose: true,
);

// Find immediate subprojects
final subprojects = scanner.findSubprojects(
  '/path/to/project',
  ['**/node_modules/**'],  // exclusions
);

// Find all projects recursively
final allProjects = await scanner.findProjectsRecursive(
  '/path/to/workspace',
  exclude: ['**/test/**'],
  recursionExclude: ['**/build/**'],
);
```

### Custom Project Validation

Provide a custom validator for project detection:

```dart
bool myValidator(String dirPath, String toolKey) {
  // Must have pubspec.yaml
  if (!File('$dirPath/pubspec.yaml').existsSync()) {
    return false;
  }
  
  // Skip builder definitions
  if (isBuildYamlBuilderDefinition(dirPath)) {
    return false;
  }
  
  // Must have my tool's config file
  return File('$dirPath/mytool.json').existsSync();
}

final scanner = ProjectScanner(
  toolKey: 'mytool',
  basePath: Directory.current.path,
  projectValidator: myValidator,
);
```

## Result Tracking

Use `ProcessingResult` to track operation outcomes:

```dart
final result = ProcessingResult();

for (final project in projects) {
  try {
    final fileCount = await processProject(project);
    result.addSuccess(fileCount);
  } catch (e) {
    print('Error processing $project: $e');
    result.addFailure();
  }
}

// Print summary
print('Success: ${result.successCount}');
print('Failed: ${result.failureCount}');
print('Files: ${result.fileCount}');

// Exit with appropriate code
exit(result.hasFailures ? 1 : 0);
```

## Complete CLI Example

Here's a minimal CLI tool using `tom_build_base`:

```dart
#!/usr/bin/env dart
import 'dart:io';

import 'package:args/args.dart';
import 'package:tom_build_base/tom_build_base.dart';

const toolKey = 'mytool';
const builderName = 'my_package:my_builder';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('project', abbr: 'p')
    ..addOption('scan', abbr: 's')
    ..addFlag('recursive', abbr: 'r', defaultsTo: false)
    ..addFlag('verbose', abbr: 'v', defaultsTo: false);

  final args = parser.parse(arguments);
  final basePath = Directory.current.path;

  // Load config from tom_build.yaml
  var config = TomBuildConfig.load(dir: basePath, toolKey: toolKey);
  
  // Override with command-line args
  config = (config ?? const TomBuildConfig()).copyWith(
    project: args['project'] as String?,
    scan: args['scan'] as String?,
    recursive: args['recursive'] as bool,
    verbose: args['verbose'] as bool,
  );

  // Validate paths
  final error = validatePathContainment(
    project: config.project,
    scan: config.scan,
    basePath: basePath,
  );
  if (error != null) {
    print('Error: $error');
    exit(1);
  }

  // Find projects
  final projects = await findProjects(config, basePath);
  
  // Process projects
  final result = ProcessingResult();
  for (final project in projects) {
    if (await processProject(project, config.verbose)) {
      result.addSuccess();
    } else {
      result.addFailure();
    }
  }

  // Report results
  print('Success: ${result.successCount}');
  if (result.hasFailures) {
    print('Failed: ${result.failureCount}');
    exit(1);
  }
}

Future<List<String>> findProjects(TomBuildConfig config, String basePath) async {
  if (config.project != null) {
    return [config.project!];
  }
  
  if (config.scan != null) {
    final scanner = ProjectScanner(
      toolKey: toolKey,
      basePath: basePath,
      projectValidator: isMyToolProject,
    );
    return scanner.findProjectsRecursive(
      config.scan!,
      exclude: config.exclude,
      recursionExclude: config.recursionExclude,
    );
  }
  
  return [basePath];
}

bool isMyToolProject(String dirPath, String toolKey) {
  if (!File('$dirPath/pubspec.yaml').existsSync()) return false;
  if (isBuildYamlBuilderDefinition(dirPath)) return false;
  
  return hasBuildYamlConsumerConfig(dirPath, builderName) ||
         hasTomBuildConfig(dirPath, toolKey);
}

Future<bool> processProject(String projectPath, bool verbose) async {
  if (verbose) print('Processing: $projectPath');
  
  // Your tool logic here
  
  return true;
}
```

## Best Practices

1. **Always skip builder definitions** - Use `isBuildYamlBuilderDefinition()` to avoid processing packages that define builders

2. **Support both config formats** - Check `tom_build.yaml` first, fall back to `build.yaml`

3. **Validate paths** - Use `validatePathContainment()` to prevent directory traversal attacks

4. **Use verbose mode** - Honor the `verbose` flag for debugging output

5. **Track results** - Use `ProcessingResult` for consistent reporting

6. **Exit codes** - Return non-zero exit code on failures for CI/CD integration

## See Also

- [tom_version_builder](../../tom_version_builder/) - Version file generator using this pattern
- [tom_d4rt_generator](../../../tom_module_d4rt/tom_d4rt_generator/) - Bridge generator using this pattern
