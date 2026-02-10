## 1.5.0

### Features

- **`--modules` / `-m` navigation option** — New include filter to limit project discovery to specific git modules (repositories). Comma-separated list of module names (e.g., `--modules tom_module_d4rt,tom_module_basics`). Use "root" or "tom" to reference the main repository.
- **`ProjectDiscovery.findGitRepositories()`** — Static method to discover all git repositories in a workspace.
- **`ProjectDiscovery.resolveModulePaths()`** — Resolve module names to absolute paths.
- **`ProjectDiscovery.filterByModules()`** — Filter project list to only those within specified modules.
- **`ProjectDiscovery.applyModulesFilter()`** — Convenience method combining resolution and filtering.

### API Changes

- `WorkspaceNavigationArgs` now includes a `modules` field (List<String>).
- `addNavigationOptions()` registers the `-m, --modules` option.
- `parseNavigationArgs()` parses the modules option as comma-separated values.
- Help text updated with modules documentation.

## 1.3.2

### Internal

- **Config filename standardization** — Updated all code references from `tom_build.yaml` to `buildkit.yaml`. The `TomBuildConfig.projectFilename` constant was already correct; this release ensures `hasTomBuildConfig()` and `ProjectDiscovery.getProjectRecursiveSetting()` use the constant instead of hardcoded strings.

## 1.3.0

### Features

- **`yamlToMap()` utility** — Public function to recursively convert `YamlMap` to plain `Map<String, dynamic>`. Eliminates private YAML-to-Map conversion duplicated across build tools.
- **`yamlListToList()` utility** — Companion function to recursively convert `YamlList` to plain `List<dynamic>`.

### Internal

- Replaced private `_convertYamlToMap` in `build_config.dart` and `_yamlToMap`/`_yamlListToList` in `build_yaml_utils.dart` with the shared public utilities.

## 1.2.0

### Features

- **`show_versions` CLI tool** — New executable in `bin/show_versions.dart`. Run via `dart run tom_build_base:show_versions [workspace-path]` or install globally with `dart pub global activate tom_build_base`.
- **`showVersions()` library function** — Importable API in `lib/src/show_versions.dart` that discovers projects and reads their pubspec versions. Returns a structured `ShowVersionsResult`.
- **`readPubspecVersion()` helper** — Reusable function to read the `version:` field from any project's `pubspec.yaml`.

### Improvements

- Example file now delegates to the library function instead of reimplementing the logic.

## 1.1.0

### Improvements

- **Comprehensive example** — Rewrote the example as a `show_versions` CLI tool that exercises every library feature: config loading & merging, project scanning & discovery, build.yaml utilities, path validation, and result tracking.
- **Updated user guide** — Complete rewrite of `doc/build_base_user_guide.md` with accurate API signatures, `ConfigMerger` documentation, `ProjectDiscovery` section, and an API quick-reference table.
- **Updated README** — Refreshed usage examples to cover `ConfigMerger`, `ProjectDiscovery`, and all `build.yaml` utility functions.

## 1.0.0

### Features

- **TomBuildConfig**: Unified configuration loading from `tom_build.yaml` files with support for project paths, glob patterns, scan directories, recursive traversal, exclusion patterns, and tool-specific options.
- **ProjectScanner**: Directory traversal with configurable project validation. Finds subprojects, scans directories recursively, supports glob-based project matching, and applies exclusion patterns.
- **ProjectDiscovery**: Advanced project discovery with proper scan vs recursive semantics. Scans until it hits a project boundary; recursive mode also looks inside found projects for nested projects. Supports comma-separated glob patterns with brace group handling.
- **build.yaml utilities**: Detect builder definitions (`isBuildYamlBuilderDefinition`) vs consumer configurations (`hasBuildYamlConsumerConfig`) — so CLI tools can skip packages that define builders and only process consumer packages.
- **Path utilities**: Path containment validation (`isPathContained`) and multi-path validation (`validatePathContainment`) for security.
- **ProcessingResult**: Simple success/failure/file-count tracking for batch operations.
- **Multi-project support**: `--project` option accepts comma-separated lists and glob patterns (e.g., `tom_*`, `xternal/tom_module_*/*`).
- **`--list` flag support**: Tools can list discovered projects without processing.
