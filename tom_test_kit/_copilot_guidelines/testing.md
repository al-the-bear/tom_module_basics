# Tom Test Kit — Testing Guidelines

## Overview

Tom Test Kit uses standard `dart test` unit tests. Tests validate the parsing, formatting, and model logic that underpins the tracking workflow. Integration tests that run `dart test` as a subprocess are not included here — they belong in end-to-end test suites.

## Test Strategy

- **Unit tests only** — All tests run in-process with no external dependencies
- **No file-system access** in model/parser/util tests — use string fixtures
- **File-system tests** (file_helpers) use temporary directories
- **Arrange-Act-Assert** structure in every test
- **One concept per test** — each test validates a single behavior

## Test File Location

Test files mirror the source structure under `test/`:

| Test File | Source File | What It Tests |
|-----------|------------|---------------|
| `test/model/test_entry_test.dart` | `lib/src/model/test_entry.dart` | TestEntry construction, displayLabel, sortDate |
| `test/model/test_run_test.dart` | `lib/src/model/test_run.dart` | TestRun, TestResult, resultSortPriority, formatResultCell, SortableTestEntry |
| `test/model/tracking_file_test.dart` | `lib/src/model/tracking_file.dart` | TrackingFile round-trip (write → load), addRun, sortedEntries |
| `test/parser/test_description_parser_test.dart` | `lib/src/parser/test_description_parser.dart` | Parsing IDs, dates, expectations from descriptions |
| `test/parser/dart_test_parser_test.dart` | `lib/src/parser/dart_test_parser.dart` | Parsing JSON output from dart test |
| `test/tui/tui_command_test.dart` | `lib/src/tui/tui_command.dart` | TuiCommandSink event delivery, TuiCommandResult |
| `test/tui/tui_command_registry_test.dart` | `lib/src/tui/tui_command_registry.dart` | Command/module registration, lookup, menu labels |
| `test/tui/tui_output_parser_test.dart` | `lib/src/tui/tui_output_parser.dart` | Protocol and passthrough line parsing |
| `test/util/format_helpers_test.dart` | `lib/src/util/format_helpers.dart` | padTwo, escapeMarkdownCell, baselineTimestamp |
| `test/util/markdown_table_test.dart` | `lib/src/util/markdown_table.dart` | splitTableRow, parseColumnTimestamp, parseResultCell, parseEntryFromLabel |
| `test/util/file_helpers_test.dart` | `lib/src/util/file_helpers.dart` | defaultBaselinePath, findLatestTrackingFile |

## Test ID Convention

Test IDs use the format: `TK-<CATEGORY>-<number>`

- **TK** — Tom Test Kit project prefix
- **CATEGORY** — 2–3 letter category code (see table below)
- **number** — Sequential number, optionally with letter suffix for variants (e.g., `1a`, `1b`)

### Categories

| Category | Code | Description |
|----------|------|-------------|
| Format helpers | `FMT` | `padTwo`, `escapeMarkdownCell`, `baselineTimestamp` |
| Markdown table | `MDT` | `splitTableRow`, `parseColumnTimestamp`, `parseResultCell`, `parseEntryFromLabel` |
| File helpers | `FIL` | `defaultBaselinePath`, `findLatestTrackingFile` |
| Test entry model | `ENT` | `TestEntry` construction, display, sorting |
| Test run model | `RUN` | `TestRun`, `TestResult`, sort priority, formatting |
| Tracking file | `TRK` | `TrackingFile` round-trip, merge, sort |
| Description parser | `TDP` | `TestDescriptionParser.parse` |
| Dart test parser | `DTP` | `DartTestParser.parseJsonOutput` |
| TUI command | `TCD` | `TuiCommand`, `TuiCommandSink`, `TuiCommandEvent`, `TuiCommandResult` |
| TUI registry | `TRG` | `TuiCommandRegistry` registration, lookup, menu labels |
| TUI output parser | `TOP` | `TuiProtocolParser`, `PassthroughParser` line parsing |
| TUI adapter | `TAD` | `ExternalToolAdapter` process wrapping |
| TUI app | `TAP` | `TestKitTuiApp` keyboard handling, layout, focus |
| TUI panels | `TPN` | `TuiOutputPanel`, `TuiMenuPanel` state, rendering |

> **Note:** Add new categories as new commands and modules are added to the tool.

### Example Test Names

```dart
test('TK-FMT-1: padTwo should zero-pad single digit', () { ... });
test('TK-MDT-3: parseResultCell should return fail for X/OK cell', () { ... });
test('TK-TDP-2: parse should extract creation date [2026-02-10 08:00]', () { ... });
test('TK-TRK-1: fromBaseline should create tracking file with one run (FAIL)', () { ... });
```

## Running Tests

```bash
# Run all tests
cd tom_test_kit
dart test

# Run a specific test file
dart test test/util/format_helpers_test.dart

# Run tests matching a name pattern
dart test --name "TK-FMT"

# Run with verbose output
dart test -r expanded
```

## Writing New Tests

1. Create the test file mirroring the source path under `test/`
2. Use the `TK-<CATEGORY>-<number>` naming convention
3. Group tests by class or function name
4. Add `(FAIL)` to tests for known limitations
5. Run `dart test` to verify
6. Update this document if adding a new category

### Template

```dart
import 'package:test/test.dart';
import 'package:tom_test_kit/tom_test_kit.dart';

/// Test IDs: TK-XXX-1, TK-XXX-2, ...
void main() {
  group('ClassName', () {
    group('methodName', () {
      test('TK-XXX-1: should do the expected thing', () {
        // Arrange
        final input = ...;

        // Act
        final result = method(input);

        // Assert
        expect(result, equals(expected));
      });
    });
  });
}
```

## Related Documentation

- [Global Test Guidelines](../../../_copilot_guidelines/tests.md) — Workspace-wide test file rules
- [Global Unit Test Guidelines](../../../_copilot_guidelines/unit_tests.md) — Unit test structure and patterns
- [Test Tracking Concept](../doc/test_tracking.md) — The tracking workflow this tool implements
