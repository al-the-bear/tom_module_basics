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
