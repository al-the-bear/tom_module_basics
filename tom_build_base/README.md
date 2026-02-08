# Tom Build Base

Shared infrastructure for Tom build tools — configuration loading, project scanning, path validation, and `build.yaml` utilities.

This package provides the common foundation that Tom CLI build tools (like `tom_d4rt_generator`, `tom_version_builder`, etc.) use to discover projects, load configuration, and traverse directory structures.

## Features

- **Configuration loading** — Two-tier config from `tom_build_master.yaml` (workspace) and `tom_build.yaml` (project), with automatic merging
- **Configuration merging** — `ConfigMerger` with additive, scalar, nullable, section, and map merge strategies
- **Project scanning** — `ProjectScanner` for directory traversal with custom validators, glob matching, and exclusions
- **Project discovery** — `ProjectDiscovery` for workspace-wide scanning with proper scan-vs-recursive semantics
- **build.yaml utilities** — Detect builder definitions vs consumers, read options and enabled flags
- **Path validation** — `isPathContained` and `validatePathContainment` for directory-traversal protection
- **Result tracking** — `ProcessingResult` for batch success/failure/file counting

## Installation

```yaml
dependencies:
  tom_build_base: ^1.1.0
```

## Usage

### Loading and Merging Configuration

```dart
import 'package:tom_build_base/tom_build_base.dart';

const toolKey = 'show_versions';

// Load workspace-level master config
final master = TomBuildConfig.loadMaster(dir: basePath, toolKey: toolKey);

// Load project-level config
final project = TomBuildConfig.load(dir: basePath, toolKey: toolKey);

// Merge (project overrides master)
final config = (master != null && project != null)
    ? master.merge(project)
    : project ?? master ?? const TomBuildConfig();
```

### Merging Custom Options

```dart
// Additive — union of both lists (deduped)
final excludes = ConfigMerger.mergeAdditive(workspaceExcludes, projectExcludes);

// Scalar — project overrides workspace
final verbose = ConfigMerger.mergeScalar(false, true);

// Map — project keys override, workspace keys preserved
final opts = ConfigMerger.mergeMaps({'a': 1}, {'b': 2});
```

### Scanning for Projects

```dart
final scanner = ProjectScanner(
  toolKey: toolKey,
  basePath: workspacePath,
  projectValidator: (dir, key) => File('$dir/pubspec.yaml').existsSync(),
);

// Recursive scan
final projects = scanner.scanForProjects(workspacePath, config.exclude);

// Glob-based matching
final matched = scanner.findProjectsByGlob(['tom_*', 'xternal/**'], []);

// Apply exclusions to an existing list
final filtered = scanner.applyExclusions(projects, ['zom_*']);
```

### Project Discovery (Glob Patterns)

```dart
final discovery = ProjectDiscovery(verbose: true);

// Resolve comma-separated glob patterns
final found = await discovery.resolveProjectPatterns(
  'tom_*,xternal/tom_module_*/*',
  basePath: workspacePath,
);
```

### Detecting Builder Definitions

```dart
// Skip packages that define builders
if (isBuildYamlBuilderDefinition(projectPath)) return;

// Check consumer configuration and options
if (hasBuildYamlConsumerConfig(projectPath, 'my_package:my_builder')) {
  final enabled = isBuildYamlBuilderEnabled(projectPath, 'my_package:my_builder');
  final options = getBuildYamlBuilderOptions(projectPath, 'my_package:my_builder');
}
```

### Path Validation

```dart
final error = validatePathContainment(
  project: config.project,
  projects: config.projects,
  scan: config.scan,
  config: config.config,
  basePath: workspaceRoot,
);
if (error != null) exit(1);
```

### Result Tracking

```dart
final result = ProcessingResult();
result.addSuccess(3);   // 3 files processed
result.addFailure();
print('Total: ${result.totalCount}, Files: ${result.fileCount}');
exit(result.hasFailures ? 1 : 0);
```

## Configuration Format

Tom build tools use a two-tier configuration pattern:

### tom_build_master.yaml (workspace root)

```yaml
navigation:                   # shared defaults for all tools
  scan: .
  recursive: true
  exclude: [.git, build]

show_versions:                # tool-specific workspace defaults
  verbose: false
```

### tom_build.yaml (inside a project)

```yaml
show_versions:
  verbose: true               # overrides workspace default
```

## Documentation

See [build_base_user_guide.md](doc/build_base_user_guide.md) for the complete user guide with API reference.

## License

BSD 3-Clause License — see [LICENSE](LICENSE) for details.

Author: Alexis Kyaw ([LinkedIn](https://www.linkedin.com/in/nickmeinhold/))

