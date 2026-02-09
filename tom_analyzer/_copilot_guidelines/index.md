# Tom Analyzer Project Guidelines - Index

This folder contains project-specific guidelines for the `tom_analyzer` package.

## Files

| File | Description |
|------|-------------|
| [implementation_hints.md](implementation_hints.md) | tom_build_base integration and CLI infrastructure |

## Quick Reference

**Package:** `tom_analyzer`  
**Purpose:** Dart code analysis tooling

**Key Components:**
- **analyzer** CLI — Code analysis with AST introspection
- **reflector** CLI — Reflection metadata generation
- Integration with Dart analyzer package

**Documentation:**
- [Analyzer Usage Guide](../doc/analyzer_usage_guide.md) — Analyzer CLI reference
- [Reflector Usage Guide](../doc/reflector_usage_guide.md) — Reflector CLI reference
- [README](../README.md) — Quick start guide

## Related Packages

- [tom_build_base](../../tom_build_base/) — Shared CLI infrastructure (navigation, project discovery)
- [tom_analyzer_model](../../tom_analyzer_model/) — Analyzer data models

## Dependencies

This package depends on **tom_build_base** for:
- Workspace navigation options (`-s`, `-r`, `-R`, `-p`, `-x`, etc.)
- Project discovery and scanning
- Configuration loading (TomBuildConfig)
- CLI standardization (help/version commands)

See [implementation_hints.md](implementation_hints.md) for details.
