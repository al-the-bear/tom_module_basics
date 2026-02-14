# Tom Build Base Project Guidelines

**Project:** `tom_build_base`  
**Type:** Dart Package

## Global Guidelines

| Document | Purpose |
|----------|---------|
| [Documentation Guidelines](/_copilot_guidelines/documentation_guidelines.md) | Where to place user docs vs development docs |

## Dart Guidelines

| Document | Purpose |
|----------|---------|
| [Coding Guidelines](/_copilot_guidelines/dart/coding_guidelines.md) | Naming conventions, error handling, patterns |
| [Unit Tests](/_copilot_guidelines/dart/unit_tests.md) | Test structure, matchers, mocking patterns |
| [Examples](/_copilot_guidelines/dart/examples.md) | Example file creation guidelines |

## Project-Specific Guidelines

| File | Description |
|------|-------------|
| [build_base_projects.md](build_base_projects.md) | List of all projects depending on tom_build_base |
| [cli_v2_design.md](cli_v2_design.md) | V2 CLI framework architecture and design specification |
| [implementation_guidelines.md](implementation_guidelines.md) | Development workflow, test-first approach, naming conventions |

## Quick Reference

**Purpose:** Shared CLI infrastructure for Tom build tools

**Key Components:**
- **Workspace navigation** — `-s`, `-r`, `-R`, `-p`, `-x` options for directory targeting
- **Project discovery** — Scanning for pubspec.yaml, tom_project.yaml files
- **Configuration loading** — TomBuildConfig, TomProjectConfig classes
- **CLI helpers** — `isHelpCommand()`, `isVersionCommand()`, help text generation

**Documentation:**
- [Build Base User Guide](../doc/build_base_user_guide.md) — Full API documentation
- [CLI Tools Navigation](../doc/cli_tools_navigation.md) — Navigation options reference
- [Modes and Placeholders](../doc/modes_and_placeholders.md) — Mode system and placeholder resolution
- [README](../README.md) — Quick start guide

## Dependent Projects

See [build_base_projects.md](build_base_projects.md) for the full list of projects that depend on this package.
