# Test Tracking — Concept and Workflow

This document defines the test tracking concept supported by Tom Test Kit. It describes the test-code-fix cycle, test description conventions, and the CLI commands that support the workflow.

---

## Table of Contents

1. [Overview](#overview)
2. [Test Description Convention](#test-description-convention)
3. [The Test-Code-Fix Cycle](#the-test-code-fix-cycle)
4. [Command Reference](#command-reference)
5. [Tracking Principles](#tracking-principles)
6. [Command Details](#command-details)
   - [:baseline](#baseline)
   - [:test](#test)
   - [:status](#status)
   - [:diff](#diff)
   - [:reset](#reset)
   - [:report](#report)

---

## Overview

Tom Test Kit provides automated test result tracking across multiple runs of `dart test`. It captures structured test output, parses test descriptions for metadata (IDs, creation dates, expected outcomes), and maintains a persistent tracking file that shows how test results evolve over time.

The core idea is that test descriptions carry structured metadata that enables:

- **Identification** — Each test has a unique ID for cross-referencing
- **Expectation management** — Tests declare whether they are expected to pass or fail
- **Temporal tracking** — Creation dates enable sorting and age analysis
- **Regression detection** — Comparing runs reveals new failures vs. known issues

---

## Test Description Convention

Test descriptions follow a structured naming convention:

```dart
test('I-BUG-14a: Records with named fields should return native record [2026-02-10 08:00] (FAIL)', () {
  // test code
});
```

### Format

```
<ID>: <description> [<creation date>] (<expected result>)
```

| Component | Required | Format | Description |
|-----------|----------|--------|-------------|
| ID | Optional | `PREFIX-CATEGORY-number` | Unique test identifier |
| Description | Required | Free text | What the test validates |
| Creation date | Optional | `YYYY-MM-DD HH:MM` | When the test was created |
| Expected result | Optional | `PASS` or `FAIL` | Expected outcome; defaults to `PASS` if absent |

### ID Conventions

Projects define their own ID prefixes and categories. Common patterns:

- `I-BUG-n` — Interpreter bugs
- `G-CB-n` — Generator callback tests
- `T-REG-n` — Regression tests

The tool does not enforce ID formats — it extracts whatever text precedes the first colon as the ID.

### Expected Result

The expected result in parentheses at the end of the description tells the tracker whether a failure is expected:

- `(PASS)` or absent — Test is expected to succeed
- `(FAIL)` — Test is a known limitation or open bug; failure is expected

This distinction is critical for sorting and reporting: an unexpected failure (expected PASS but got FAIL) is a regression and ranks higher in the output than an expected failure.

---

## The Test-Code-Fix Cycle

The test-code-fix cycle is the core development workflow that Test Kit supports. It consists of these phases:

### Phase 1: Establish Baseline

Before starting work, capture the current state of all tests. This creates a reference point for measuring progress.

```bash
test_kit :baseline                  # Run dart test, create baseline file
```

### Phase 2: Write Code / Write Tests

Make changes to the codebase — implement features, fix bugs, add tests. New tests should follow the test description convention with creation dates and expected outcomes.

### Phase 3: Run Tests and Track

After changes, run tests and append results to the tracking file. Each run adds a column so you can see how results change over time.

```bash
test_kit :test                      # Run dart test, append results column
```

### Phase 4: Analyze Results

Review the tracking file to identify regressions (previously passing tests now failing), progress (previously failing tests now passing), and persistent failures.

```bash
test_kit :status                    # Show summary of current state
test_kit :diff                      # Show changes since baseline/last run
```

### Phase 5: Fix and Iterate

Fix regressions and bugs, then repeat Phase 3–4 until satisfied.

### Phase 6: New Baseline

When the current state is acceptable, create a new baseline that replaces the old tracking file. This archives the previous cycle and starts fresh.

```bash
test_kit :reset                     # Archive old tracking, create new baseline
```

### Phase 7: Report

Generate a summary report suitable for documentation or commit messages.

```bash
test_kit :report                    # Generate markdown report
```

---

## Command Reference

| Command | Description |
|---------|-------------|
| `:baseline` | Run `dart test`, create a new baseline tracking file with test IDs, descriptions, and initial results |
| `:test` | Run `dart test`, append a new result column to the existing tracking file |
| `:status` | Show summary: total tests, pass/fail counts, regressions, and progress since baseline |
| `:diff` | Show changes between the last two runs, or between baseline and latest run |
| `:reset` | Archive the current tracking file and create a fresh baseline |
| `:report` | Generate a markdown summary report of the current tracking state |

All commands support the standard `tom_build_base` navigation options (`-R`, `-s`, `-p`, `-r`, etc.) for multi-project operation.

---

## Tracking Principles

### File Format

The tracking file (`baseline_<timestamp>.md`) is a markdown table with the following structure:

```markdown
| ID / Description | Baseline [02-10 14:30] | [02-10 15:45] | [02-11 09:00] |
|------------------|------------------------|---------------|---------------|
| I-BUG-1: Some test [2026-02-10 08:00] | OK/OK | OK/OK | X/OK |
| I-LIM-3: Known limitation [2026-02-10 08:00] | X/FAIL | X/FAIL | X/FAIL |
```

### Result Format

Each cell uses the format: `<result>/<expectation>`

| Value | Meaning |
|-------|---------|
| `OK` | Test passed |
| `X` | Test failed |
| `SKIP` | Test was skipped |

| Expectation | Source | Meaning |
|-------------|--------|---------|
| `OK` | No annotation or `(PASS)` | Test is expected to pass |
| `FAIL` | `(FAIL)` in description | Test is a known failure |

### Result/Expectation Combinations

| Cell | Interpretation |
|------|----------------|
| `OK/OK` | Passed as expected — healthy |
| `X/OK` | Failed unexpectedly — **regression** |
| `X/FAIL` | Failed as expected — known issue |
| `OK/FAIL` | Passed unexpectedly — **progress** (bug may be fixed) |
| `SKIP/OK` | Skipped — needs attention |
| `SKIP/FAIL` | Skipped known failure — acceptable |

### Sorting Order

Rows in the tracking file are sorted by priority based on the **latest run**:

1. **Failed (unexpected)** — `X/OK` — Regressions come first
2. **Failed (expected)** — `X/FAIL` — Known issues
3. **Passed (unexpected)** — `OK/FAIL` — Potential fixes to verify
4. **Passed (expected)** — `OK/OK` — Healthy tests
5. **Skipped** — `SKIP/*` — Last

Within each group, tests are sorted by creation date (oldest first), extracted from the `[YYYY-MM-DD HH:MM]` annotation in the test description. Tests without a creation date sort after dated tests.

### Column Timestamps

Column headers use the compact format `MM-DD HH:MM` to keep tables readable:

```
| Baseline [02-10 14:30] | [02-10 15:45] | [02-11 09:00] |
```

### Multi-Project Support

When running across multiple projects (via `-R` or `-s`), each project gets its own tracking file in its own directory. The tracking file is placed in the project's `doc/` directory by default (configurable via `--output`).

---

## Command Details

### :baseline

Creates a new baseline tracking file by running `dart test` and capturing all test results.

**Workflow:**
1. Runs `dart test --reporter json` to capture structured output
2. Parses test descriptions for IDs, creation dates, and expected outcomes
3. Creates `doc/baseline_<MMDD_HHMM>.md` with two columns: ID/Description and Baseline result
4. Sorts tests by the standard sorting order

**Options:**
- `--output=<path>` — Custom output file path
- `--test-args=<args>` — Additional arguments passed to `dart test`

**Example:**
```bash
test_kit :baseline                     # Baseline current project
test_kit :baseline -R                  # Baseline all projects in workspace
test_kit :baseline --output results.md # Custom output path
```

### :test

Runs `dart test` and appends a new result column to the most recent tracking file.

**Workflow:**
1. Finds the most recent `baseline_*.md` file in the project's `doc/` directory
2. Runs `dart test --reporter json` to capture structured output
3. Parses results and appends a new column with timestamp header
4. Re-sorts rows by the standard sorting order based on the latest results
5. New tests (not in the tracking file) are added as new rows
6. Removed tests (in tracking file but not in run) are marked with `-` in the new column

**Options:**
- `--file=<path>` — Specify which tracking file to update (default: most recent baseline)
- `--test-args=<args>` — Additional arguments passed to `dart test`

**Example:**
```bash
test_kit :test                         # Test and track current project
test_kit :test -R                      # Test and track all workspace projects
test_kit :test --file doc/baseline_0210_1430.md
```

### :status

Shows a summary of the current tracking state without running tests.

**Output includes:**
- Total tests, pass/fail/skip counts from latest run
- Regressions since baseline (tests that were OK and are now X)
- Progress since baseline (tests that were X and are now OK)
- Persistent failures (tests failing in every run)

### :diff

Shows changes between the last two runs, or between baseline and the latest run.

**Output includes:**
- Newly failing tests (regression candidates)
- Newly passing tests (fix candidates)
- Tests with changed expected outcomes

### :reset

Archives the current tracking file and creates a fresh baseline. Used when the current state is accepted as the new normal.

### :report

Generates a markdown summary report of the tracking state, suitable for documentation or commit messages.

---

## Related Documentation

- [CLI Tools Navigation Guide](../../tom_build_base/doc/cli_tools_navigation.md) — Standard navigation options
- [Build Base User Guide](../../tom_build_base/doc/build_base_user_guide.md) — Configuration and project discovery
