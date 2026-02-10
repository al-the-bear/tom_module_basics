# Tom Build Kit Project Guidelines - Index

This folder contains project-specific guidelines for the `tom_build_kit` package.

## Files

| File | Description |
|------|-------------|
| [build_base_projects.md](build_base_projects.md) | List of all projects depending on tom_build_base |
| [implementation_hints.md](implementation_hints.md) | tom_build_base integration and CLI infrastructure |
| [testing.md](testing.md) | Testing guidelines |

## Quick Reference

**Package:** `tom_build_kit`  
**Purpose:** Build tools for the Tom workspace

**Key Components:**
- **versioner** — Generate version.g.dart files with build metadata
- **bumpversion** — Bump pubspec.yaml versions across projects
- **cleanup** — Remove generated and temporary files
- **compiler** — Cross-platform Dart compilation
- **runner** — build_runner wrapper with builder filtering
- **dependencies** — Dependency tree visualization
- **buildsorter** — Build order sorting
- **buildkit** — Pipeline orchestrator

**Documentation:**
- [Tools User Guide](../doc/tools_user_guide.md) — Individual tool reference
- [BuildKit User Guide](../doc/buildkit_user_guide.md) — Pipeline orchestrator
- [README](../README.md) — Quick start guide

## Related Packages

- [tom_build_base](../../tom_build_base/) — Shared CLI infrastructure (navigation, project discovery)
- [tom_d4rt_astgen](../../tom_d4rt_astgen/) — AST generator tool
- [tom_analyzer](../../tom_analyzer/) — Code analysis tool

## Dependencies

This package depends on **tom_build_base** for:
- Workspace navigation options (`-s`, `-r`, `-R`, `-p`, `-x`, etc.)
- Project discovery and scanning
- Configuration loading (TomBuildConfig)
- CLI standardization (help/version commands)

See [implementation_hints.md](implementation_hints.md) for details.
