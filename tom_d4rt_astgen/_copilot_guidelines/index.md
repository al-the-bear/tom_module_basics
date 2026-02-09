# Tom D4rt AST Generator Project Guidelines - Index

This folder contains project-specific guidelines for the `tom_d4rt_astgen` package.

## Files

| File | Description |
|------|-------------|
| [implementation_hints.md](implementation_hints.md) | tom_build_base integration and CLI infrastructure |

## Quick Reference

**Package:** `tom_d4rt_astgen`  
**Purpose:** Convert Dart source files to serialized AST YAML files

**Key Components:**
- **astgen** CLI — Command-line AST generation tool
- AST serialization to YAML format
- Integration with D4rt runtime

**Documentation:**
- [AST Build Configuration](../doc/astgen_build_yaml.md) — build.yaml configuration
- [CLI Reference](../doc/tom_build_configuration_and_cli.md) — CLI options and tom_build.yaml
- [README](../README.md) — Quick start guide

## Related Packages

- [tom_build_base](../../tom_build_base/) — Shared CLI infrastructure (navigation, project discovery)
- [tom_d4rt](../../../tom_module_d4rt/tom_d4rt/) — D4rt interpreter that uses AST files
- [tom_d4rt_generator](../../../tom_module_d4rt/tom_d4rt_generator/) — Bridge generator

## Dependencies

This package depends on **tom_build_base** for:
- Workspace navigation options (`-s`, `-r`, `-R`, `-p`, `-x`, etc.)
- Project discovery and scanning
- Configuration loading (TomBuildConfig)
- CLI standardization (help/version commands)

See [implementation_hints.md](implementation_hints.md) for details.
