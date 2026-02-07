# Tom Build Base

Shared infrastructure for Tom build tools — configuration loading, project scanning, path validation, and `build.yaml` utilities.

This package provides the common foundation that Tom CLI build tools (like `tom_d4rt_generator`, `tom_version_builder`, etc.) use to discover projects, load configuration, and traverse directory structures.

## Features

- **Configuration loading** — Load tool-specific config from `tom_build.yaml` files
- **Project scanning** — Find projects in a directory tree with glob patterns and exclusions
- **Project discovery** — Advanced scan-vs-recursive semantics for workspace traversal
- **build.yaml utilities** — Detect builder definitions vs consumer configurations
- **Path validation** — Ensure paths stay within the workspace root (security)
- **Result tracking** — Track success/failure counts across batch operations

## Installation

```yaml
dependencies:
  tom_build_base: ^1.0.0
```

## Usage

### Loading Configuration

```dart
import 'package:tom_build_base/tom_build_base.dart';

// Load tool-specific config from tom_build.yaml
final config = TomBuildConfig.load(
  dir: '/path/to/project',
  toolKey: 'dartgen',
);

if (config != null) {
  print('Project: ${config.project}');
  print('Recursive: ${config.recursive}');
  print('Verbose: ${config.verbose}');
  // Access tool-specific options
  final custom = config.toolOptions['myOption'];
}
```

### Scanning for Projects

```dart
final scanner = ProjectScanner(
  toolKey: 'dartgen',
  basePath: workspacePath,
);

// Scan directory for projects
final projects = scanner.scanForProjects(workspacePath, []);

// Find subprojects within a project
final subprojects = scanner.findSubprojects(projectPath, ['test_*']);

// Glob-based project matching
final matched = scanner.findProjectsByGlob(['tom_*_builder'], []);
```

### Detecting Builder Definitions

```dart
// Skip packages that define builders (they shouldn't be processed as consumers)
if (isBuildYamlBuilderDefinition(projectPath)) {
  print('Skipping builder package');
  return;
}

// Check if a package uses a specific builder
if (hasBuildYamlConsumerConfig(projectPath, 'my_package:my_builder')) {
  print('This project uses my_builder');
}
```

### Path Validation

```dart
// Ensure a path stays within the workspace
if (isPathContained(targetPath, workspaceRoot)) {
  // Safe to process
}

// Validate multiple paths at once
final error = validatePathContainment(
  project: config.project,
  scan: config.scan,
  basePath: workspaceRoot,
);
if (error != null) print('Path error: $error');
```

## Configuration Format

Tom build tools use a two-tier configuration pattern:

### tom_build.yaml (tool-specific)

```yaml
dartgen:
  project: .
  recursive: true
  verbose: false
  modules:
    - name: core
      barrelFiles: [lib/core.dart]

versioner:
  output: lib/src/version.g.dart
```

### build.yaml (build_runner format)

```yaml
targets:
  $default:
    builders:
      tom_d4rt_generator|bridge_builder:
        enabled: true
        options:
          modules: [...]
```

## Documentation

See [build_base_user_guide.md](doc/build_base_user_guide.md) for the complete user guide.

## License

BSD 3-Clause License — see [LICENSE](LICENSE) for details.

Author: Alexis Kyaw ([LinkedIn](https://www.linkedin.com/in/nickmeinhold/))

