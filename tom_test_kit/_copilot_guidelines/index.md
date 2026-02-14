# Tom Test Kit Project Guidelines

**Project:** `tom_test_kit`  
**Type:** CLI Tool

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
| [testing.md](testing.md) | Test strategy, naming conventions, categories, and running tests |

## Quick Reference

**Purpose:** CLI tool for tracking `dart test` results across runs

**Key Components:**

- `TestEntry` — Parsed test metadata (ID, description, date, expectation)
- `TestRun` — Single run with timestamp and result map
- `TrackingFile` — Markdown tracking file read/write/append
- `TestDescriptionParser` — Extracts structured metadata from test description strings
- `DartTestParser` — Runs `dart test --reporter json` and parses output
- `BaselineCommand` / `TestCommand` — CLI subcommand implementations
- `format_helpers` — Shared formatting utilities (`padTwo`, `escapeMarkdownCell`, `baselineTimestamp`)
- `markdown_table` — Markdown table parsing (`splitTableRow`, `parseColumnTimestamp`, `parseResultCell`, `parseEntryFromLabel`)
- `file_helpers` — File discovery (`defaultBaselinePath`, `findLatestTrackingFile`)

**Documentation:**

- [Test Tracking Concept](../doc/test_tracking.md) — Full concept, workflow, and command reference
- [README](../README.md) — Quick start guide

## Related Packages

- [`tom_build_base`](../../tom_build_base/_copilot_guidelines/) — Provides CLI navigation infrastructure
