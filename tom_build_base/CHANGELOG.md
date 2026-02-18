## 1.11.0

### Features

- **WorkspaceScanner** — Unified scanning API combining FolderScanner + NatureDetector.
  - `scan()` returns `ScanResults` with type-safe `byNature<T>()` filtering.
  - `findGitRepos()`, `findDartProjects()`, `findPublishable()` — Nature-based queries.
  - `findGitRepoPaths()`, `findDartProjectPaths()`, `findPublishablePaths()` — Path convenience methods.
  - `FolderContext` provides folder + natures together with `hasNature<T>()`, `getNature<T>()`.

- **DartProjectFolder.isPublishable** — New getter to check if package can be published to pub.dev.

### Exports

- V2 traversal API now exported from main barrel: `WorkspaceScanner`, `GitFolder`, `DartProjectFolder`, etc.

---

## 1.10.0

### Features

- **Top repository navigation** (`-T, --top-repo`) — New git traversal option.
  - Traverses UP the directory tree to find the topmost (outermost) git repository.
  - Uses that repository as the root for subsequent traversal.
  - Can be combined with `-i` (inner-first-git) or `-o` (outer-first-git).
  - Added `GitRepoFinder.findTopRepo()` method for upward git repo discovery.
  - Example: `buildkit -T -i :compile` — finds top repo, then processes inner repos first.

### Classes Modified

- `CliArgs` — Added `topRepo` field.
- `WorkspaceNavigationArgs` — Added `topRepo` field and updated execution mode detection.
- `GitRepoFinder` — Added `findTopRepo(String startPath)` method.
- `ProjectNavigator` — Integrated `topRepo` option in navigation.
- `CliArgParser` — Added parsing for `-T` and `--top-repo` flags.
- `OptionDefinition` — Added `top-repo` to `gitTraversalOptions`.

---

## 1.9.0

### Features

- **DCli integration** — Refactored file operations to use DCli library for improved code readability.
  - `File(path).existsSync()` → `exists(path)`
  - `File(path).readAsStringSync()` → `read(path).toParagraph()`
  - `Directory(path).listSync()` → `find('*', types: [Find.directory])`
  - Improved directory filtering with DCli's `find()` type filtering.

### Dependencies

- Added `dcli` package as dependency for file and directory operations.

### Files Refactored

- `build_config.dart` — Config file loading
- `build_yaml_utils.dart` — Build.yaml utilities
- `config_loader.dart` — Configuration loading with placeholders
- `project_discovery.dart` — Project discovery and scanning
- `project_scanner.dart` — Project validation and scanning
- `show_versions.dart` — Version display functionality
- `workspace_mode.dart` — Workspace navigation utilities

---

## 1.8.0

### Features

- **`ConfigLoader` class** — New unified configuration loader with mode processing and placeholder resolution.
  - Loads `{basename}_master.yaml` (workspace) and `{basename}.yaml` (project) configuration files.
  - Processes mode-prefixed keys (e.g., `DEV-target`, `CI-enabled`) with merging behavior.
  - Resolves `@[...]` define placeholders from the `defines:` section.
  - Resolves `@{...}` tool placeholders (project-path, project-name, workspace-root, etc.).
  - Custom tool placeholders via `PlaceholderDefinition`.

- **Mode system** — Workspace-wide configuration dimensions.
  - `--modes` CLI option to override active modes (e.g., `--modes=DEV,CI`).
  - Mode sources: CLI option (highest) → `tom_workspace.yaml` default.
  - UPPERCASE mode prefixes merge in order, later modes override earlier.

- **Skip file system** — Directory-level skip markers.
  - `tom_skip.yaml` — Skips directory for ALL tools.
  - `{basename}_skip.yaml` — Skips directory for specific tool only.
  - Skip reason readable from YAML `reason:` field.

- **`resolvePlaceholders()` function** — Standalone placeholder resolution utility.
  - Supports `@[...]` defines, `@{...}` tool placeholders.
  - Environment variable resolution with `$VAR` and `$[VAR]` syntax.
  - Recursive resolution (max depth 10).

### API Changes

- New `config_loader.dart` exported from `tom_build_base.dart`.
- `WorkspaceNavigationArgs.modes` — New field for active modes.
- `addNavigationOptions()` registers `--modes` option.
- `parseNavigationArgs()` parses modes as comma-separated, uppercased values.
- `ProjectNavigator` accepts optional `toolBasename` parameter for tool-specific skip files.
- `ProjectDiscovery.hasSkipFile(basename)` — Updated signature with basename parameter.
- `ProjectDiscovery.getSkipFileName(basename)` — Returns tool-specific skip filename.
- `ProjectDiscovery.globalSkipFileName` — Constant for `tom_skip.yaml`.
- **v2 `FolderScanner`** — Now supports tool-specific skip files:
  - Constructor accepts `toolBasename` parameter (defaults to 'buildkit').
  - Checks for `tom_skip.yaml` (global skip for all tools).
  - Checks for `{toolBasename}_skip.yaml` (tool-specific skip).
  - New `skipFilename` getter returns tool-specific skip filename.
  - New `kTomSkipYaml` constant exported.

## 1.7.1

- Changelog update for 1.7.0 features.

## 1.7.0

### Features

- **`ProjectNavigator` class** — New unified project navigation and discovery class that can be shared across CLI tools. Supports all navigation modes: project patterns, directory scanning, git-based traversal.
- **`NavigationConfig` class** — Configurable opt-in/opt-out for navigation features (path exclude, name exclude, modules filter, skip files, master config defaults, build order, git traversal).
- **`NavigationDefaults` class** — Navigation defaults loaded from master config.
- **`NavigationResult` class** — Result container with discovered paths and metadata.
- **Build order sorting** — `ProjectNavigator.sortByBuildOrder()` uses Kahn's algorithm for dependency-based topological sorting.
- **Git repository discovery** — `ProjectNavigator.findGitRepositories()` recursively scans for `.git` folders.
- **Static filter methods** — `filterByPath()`, `filterByName()`, `filterSkippedProjects()`, `hasSkipFile()`.
- **Master config loading** — `loadNavigationDefaults()` and `loadMasterExcludeProjects()` static methods.

### API Changes

- New `project_navigator.dart` exported from `tom_build_base.dart`.
- `kBuildkitSkipYaml` constant now exported from `workspace_mode.dart`.
- `toStringList()` utility added to `yaml_utils.dart`.

## 1.6.0

### Features

- **`--no-recursive` support** — The `--recursive` flag is now negatable. Pass `--no-recursive` to suppress recursion when applied via `buildkit.yaml` or parent directories.
- **`--no-build-order` support** — The `--build-order` flag is now negatable. Pass `--no-build-order` to skip dependency-based sorting.
- **`recursiveExplicitlySet` field** — `WorkspaceNavigationArgs` now tracks whether the `-r, --recursive` flag was explicitly set by the user, allowing downstream tools to distinguish between defaulted and explicit values.

### API Changes

- `WorkspaceNavigationArgs.recursiveExplicitlySet` — New boolean field indicating explicit user setting.
- `parseNavigationArgs()` now uses `wasParsed('recursive')` to detect explicit usage.
- `withDefaults()` and `withProjectModeDefaults()` respect explicit settings and don't override them.

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
