# Tom Build Base Project Guidelines - Index

This folder contains project-specific guidelines for the `tom_build_base` package.

## Files

| File | Description |
|------|-------------|
| [build_base_projects.md](build_base_projects.md) | List of all projects depending on tom_build_base |
| [implementation_guidelines.md](implementation_guidelines.md) | Development workflow, test-first approach, naming conventions |

## Quick Reference

**Package:** `tom_build_base`  
**Purpose:** Shared CLI infrastructure for Tom build tools

**Key Components:**
- **Workspace navigation** — `-s`, `-r`, `-R`, `-p`, `-x` options for directory targeting
- **Project discovery** — Scanning for pubspec.yaml, tom_project.yaml files
- **Configuration loading** — TomBuildConfig, TomProjectConfig classes
- **CLI helpers** — `isHelpCommand()`, `isVersionCommand()`, help text generation

**Documentation:**
- [Build Base User Guide](../doc/build_base_user_guide.md) — Full API documentation
- [CLI Tools Navigation](../doc/cli_tools_navigation.md) — Navigation options reference
- [README](../README.md) — Quick start guide

## Dependent Projects

See [build_base_projects.md](build_base_projects.md) for the full list of projects that depend on this package.
