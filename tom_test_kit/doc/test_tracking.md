# Test Tracking — Concept and Workflow

This document defines the test tracking concept supported by Tom Test Kit's `testkit` CLI. It describes the test-code-fix cycle, test description conventions, and how each command supports the workflow.

---

## Table of Contents

1. [Overview](#overview)
2. [Test Description Convention](#test-description-convention)
3. [The Test-Code-Fix Cycle](#the-test-code-fix-cycle)
4. [Tracking File](#tracking-file)
5. [Command Reference (Quick)](#command-reference-quick)
6. [Full Command Reference](#full-command-reference)

---

## Overview

`testkit` provides automated test result tracking across multiple runs of `dart test`. It captures structured JSON test output, parses test descriptions for metadata (IDs, creation dates, expected outcomes), and maintains a persistent CSV tracking file that shows how test results evolve over time.

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

This distinction is critical for sorting and reporting: an unexpected failure (expected PASS but got FAIL) is a **regression** and ranks higher in the output than an expected failure.

---

## The Test-Code-Fix Cycle

The test-code-fix cycle is the core development workflow that testkit supports.

### Phase 1: Establish Baseline

Before starting work, capture the current state of all tests. This creates a reference point for measuring progress.

```bash
testkit :baseline                       # Run dart test, create baseline file
testkit :baseline -c "before refactor"  # With a comment label
```

### Phase 2: Write Code / Write Tests

Make changes to the codebase — implement features, fix bugs, add tests. New tests should follow the test description convention with creation dates and expected outcomes.

### Phase 3: Run Tests and Track

After changes, run tests and append results to the tracking file. Each run adds a column so you can see how results change over time.

```bash
testkit :test                           # Run dart test, append results column
testkit :test -c "fixed parser bug"     # Run with comment label
```

### Phase 4: Analyze Results

Use the analysis commands to understand what changed:

```bash
testkit :status                         # Quick summary: counts, regressions, fixes
testkit :basediff                       # What changed since baseline?
testkit :lastdiff                       # What changed since the previous run?
testkit :history TK-RUN-5               # How did a specific test evolve?
testkit :flaky                          # Which tests are non-deterministic?
```

### Phase 5: Fix and Iterate

Fix regressions and bugs, then repeat Phase 3–4 until satisfied.

### Phase 6: Manage Tracking Files

When the tracking file grows too large, trim old runs. When starting a new development cycle, reset and create a fresh baseline.

```bash
testkit :trim 5                         # Keep only last 5 runs + baseline
testkit :reset                          # Delete all tracking files, start fresh
```

### Phase 7: Generate Reports

Generate reports for documentation or code review:

```bash
testkit :basediff --report=progress.md           # Markdown report (baseline → latest)
testkit :lastdiff --full --report=lastdiff.md    # With error details
testkit :basediff --output csv:results.csv       # Export as CSV
```

---

## Tracking File

### File Location and Naming

Tracking files are stored in the project's `doc/` directory:

- **Baseline CSV:** `doc/baseline_<MMDD_HHMM>.csv`
- **Raw JSON output:** `doc/last_testrun.json` (overwritten each run)

When multiple baseline files exist, testkit automatically uses the most recent one (sorted alphabetically by filename, which orders by timestamp). You can override this with `--baseline-file=<path>`.

### CSV Format

The tracking file is a CSV with metadata rows and a data grid:

```
ID,Groups,Description,Creation Date,Suite,Expectation,Baseline [02-10 14:30],[02-10 15:45],[02-11 09:00]
TK-1,parser,parses JSON,2026-02-10 08:00,test/parser_test.dart,OK,OK/OK,OK/OK,X/OK
TK-2,,known limitation,2026-02-10 08:00,test/edge_test.dart,X,X/X,X/X,X/X
```

Each column after the metadata columns represents a test run. The first run column is the baseline.

### Result Format

Each result cell uses the format: `<result>/<expectation>`

| Value | Meaning |
|-------|---------|
| `OK` | Test passed |
| `X` | Test failed |
| `-` | Test was skipped |
| `--` | Test was not present in this run |

| Expectation | Source | Meaning |
|-------------|--------|---------|
| `OK` | No annotation or `(PASS)` | Test is expected to pass |
| `X` | `(FAIL)` in description | Test is a known failure |

### Result/Expectation Combinations

| Cell | Interpretation |
|------|----------------|
| `OK/OK` | Passed as expected — healthy |
| `X/OK` | Failed unexpectedly — **regression** |
| `X/X` | Failed as expected — known issue |
| `OK/X` | Passed unexpectedly — **progress** (bug may be fixed) |
| `-/OK` | Skipped — needs attention |
| `-/X` | Skipped known failure — acceptable |
| `--/OK` | Not present in this run |

### Sorting Order

Rows in the tracking file are sorted by priority based on the **latest run**:

1. **Failed (unexpected)** — `X/OK` — Regressions come first
2. **Failed (expected)** — `X/X` — Known issues
3. **Passed (unexpected)** — `OK/X` — Potential fixes to verify
4. **Passed (expected)** — `OK/OK` — Healthy tests
5. **Skipped** — `-/*` — Last
6. **Absent** — `--/*` — Not present

Within each group, tests are sorted by creation date (oldest first). Tests without a creation date sort after dated tests.

### Column Timestamps

Run column headers use the compact format `MM-DD HH:MM`:

```
Baseline [02-10 14:30],[02-10 15:45],[02-11 09:00]
```

Comments, if provided via `-c`, appear in the column header.

---

## Command Reference (Quick)

| Command | Description |
|---------|-------------|
| `:baseline` | Run `dart test`, create a new baseline tracking file |
| `:test` | Run `dart test`, append results to the existing tracking file |
| `:runs` | List all run timestamps in the tracking file |
| `:status` | Quick summary: pass/fail counts, regressions, fixes |
| `:basediff` | Diff baseline vs latest run |
| `:lastdiff` | Diff previous run vs latest run |
| `:diff <ts> [<ts2>]` | Diff two arbitrary runs by timestamp |
| `:history <search>` | Show all results for a test across runs |
| `:flaky` | List tests with inconsistent results across runs |
| `:crossreference` | Map tests to source files (aliases: `:crossref`, `:xref`) |
| `:trim <n>` | Remove old runs, keeping last N (baseline always preserved) |
| `:reset` | Delete all tracking files in doc/ |

All commands support project traversal options for multi-project operation. Run `testkit help` for the overview or `testkit help <command>` for per-command details.

---

## Full Command Reference

### :baseline

Creates a new baseline tracking file by running `dart test` and capturing all test results. This becomes the reference point for comparing future test runs.

**Process:**
1. Runs `dart test --reporter json` to capture structured output
2. Saves raw JSON to `doc/last_testrun.json`
3. Parses test descriptions for IDs, creation dates, and expected outcomes
4. Creates `doc/baseline_<MMDD_HHMM>.csv` with metadata columns and one result column
5. Sorts tests by the standard sorting order

**Options:**

| Option | Description |
|--------|-------------|
| `-c, --comment=<text>` | Short label shown in the baseline column header |
| `--file=<path>` | Output file path (overrides default `doc/baseline_<ts>.csv`) |
| `--test-args=<args>` | Additional arguments passed to `dart test` |

**Examples:**
```bash
testkit :baseline                            # Baseline current project
testkit :baseline -c "v2.0 release"          # Baseline with comment
testkit :baseline --test-args="--tags e2e"   # Only include e2e tests
testkit :baseline -r                         # Baseline all subprojects
```

---

### :test

Runs `dart test` and appends a new result column to the most recent tracking file.

**Process:**
1. Finds the most recent `baseline_*.csv` file in the project's `doc/` directory
2. Runs `dart test --reporter json` to capture structured output
3. Saves raw JSON to `doc/last_testrun.json`
4. Parses results and appends a new column with timestamp header
5. New tests (not in the tracking file) are added as new rows
6. Missing tests (in tracking file but not in run) are marked as absent (`--`)
7. Re-sorts rows by the standard sorting order based on the latest results

**Options:**

| Option | Description |
|--------|-------------|
| `-c, --comment=<text>` | Short label shown in the run column header |
| `--file=<path>` | Tracking file to update (instead of most recent) |
| `--baseline` | Create baseline if no tracking file exists |
| `--no-update` | Run tests and print summary without updating baseline |
| `--test-args=<args>` | Additional arguments passed to `dart test` |

**Test args:** Arguments are passed through to `dart test`. testkit always adds `--reporter json` internally. Forbidden args (will be rejected): `--reporter`, `--file-reporter`, `--pause-after-load`, `--debug`.

Common dart test options:

| dart test option | Description |
|------------------|-------------|
| `-n, --name=<regex>` | Filter tests by name (regex) |
| `-N, --plain-name=<text>` | Filter tests by plain-text name |
| `-t, --tags=<tags>` | Run only tests with specified tags |
| `-x, --exclude-tags=<tags>` | Exclude tests with specified tags |
| `--fail-fast` | Stop after first failure |
| `--timeout=<duration>` | Test timeout (e.g. `15s`, `2x`, `none`) |

**Examples:**
```bash
testkit :test                                # Append run to latest baseline
testkit :test -c "after refactor"            # Run with comment
testkit :test --baseline                     # Create baseline if missing
testkit :test --test-args="--name parser"    # Only run parser tests
testkit :test --no-update                    # Run tests, show summary without updating
```

---

### :runs

Lists all run timestamps in the tracking file. Use these timestamps with `:diff`.

**Output columns:** `#` (index), Timestamp, Type (baseline/run), Comment

**Options:**

| Option | Description |
|--------|-------------|
| `--output=<spec>` | Output format: `plain`, `csv`, `json`, `md` or `<format>:<filename>` |

**Example output:**
```
Runs in baseline_0210_1430.csv

#  Timestamp    Type      Comment
-  -----------  --------  ----------------
1  02-10 14:30  baseline  initial
2  02-10 15:45  run       after refactor
3  02-11 09:00  run       fixed parser bug
```

---

### :status

Shows a quick summary of the current tracking state without running tests.

**Output includes:**
- File path and number of runs
- Total tests, pass/fail/skip/absent counts from the latest run
- Regressions and fixes since baseline (if ≥2 runs exist)
- Regressions and fixes since the previous run (if ≥2 runs exist)

A regression is a test that was OK in the older run but X in the newer run. A fix is the reverse.

**Example output:**
```
  File: doc/baseline_0210_1430.csv
  Runs: 3
  Tests: 87 (82 passed, 3 failed, 2 skipped)

  Since baseline:
    Regressions: 1
    Fixes:       4

  Since last run:
    Regressions: 0
    Fixes:       2
```

---

### :basediff

Shows all tests that changed between the baseline (first run) and the latest run. Useful for seeing overall progress since tracking began.

**Process:**
1. Loads the tracking file
2. Computes differences between the first and last run columns
3. Sorts by priority: regressions first, then other changes, then fixes
4. Outputs a table with change labels

**Options:**

| Option | Description |
|--------|-------------|
| `--output=<spec>` | Output format: `plain`, `csv`, `json`, `md` or `<format>:<filename>` |
| `--full` | Include error messages and stack traces from `last_testrun.json` |
| `--report=<file>` | Generate a detailed Markdown report (mutually exclusive with `--output`) |

**Change labels:**

| Label | Meaning |
|-------|---------|
| `REGRESSION` | Was passing, now failing |
| `FIXED` | Was failing, now passing |
| `REMOVED` | Test no longer present |
| `NEW` | Test appeared since baseline |
| `- → OK`, `OK → -`, etc. | Other status changes |

**Examples:**
```bash
testkit :basediff                            # Show changes since baseline
testkit :basediff --full                     # Include error details
testkit :basediff --report=progress.md       # Write Markdown report
testkit :basediff --output csv:changes.csv   # Export as CSV
```

---

### :lastdiff

Shows all tests that changed between the second-to-last run and the most recent run. Useful for seeing what changed in the last test cycle.

Same options and output format as `:basediff`. Requires at least 2 runs.

**Examples:**
```bash
testkit :lastdiff                        # Changes since previous run
testkit :lastdiff --full                 # Include error details
testkit :lastdiff --output md            # Output as Markdown
```

---

### :diff

Compares two arbitrary runs by timestamp. Use `:runs` to see available timestamps.

**Usage:**
```
testkit :diff <timestamp>              # Compare that run vs latest
testkit :diff <timestamp1> <timestamp2>  # Compare two specific runs
```

**Timestamp formats:** `MM-DD_HHMM`, `MM-DD HH:MM`. These match the timestamps shown by `:runs`.

Same options as `:basediff` (`--output`, `--full`, `--report`).

**Examples:**
```bash
testkit :diff 02-10_1430                     # Compare 02-10 14:30 vs latest
testkit :diff 02-10_1430 02-11_0900          # Compare two specific runs
testkit :diff "02-10 14:30" --full           # With error details
```

---

### :history

Shows all results for one or more tests across all runs, making it easy to track regressions and fixes over time.

**Usage:**
```
testkit :history <search>
```

The search term is matched case-insensitively against:
- **Test ID** (e.g., `TK-RUN-5`) — an exact ID match returns only that test
- **Test description** text
- **Group path**
- **Full test path** (groups + description combined)

If multiple tests match, all are shown in the same table.

**Options:**

| Option | Description |
|--------|-------------|
| `--output=<spec>` | Output format: `plain`, `csv`, `json`, `md` or `<format>:<filename>` |

**Example output:**
```
History: test A

Test          B 02-10 14:30  02-11 10:00  02-12 16:45
------------  -------------  -----------  -----------
TK-A: test A  OK/OK          X/OK         OK/OK
```

**Examples:**
```bash
testkit :history TK-RUN-5                # By exact test ID
testkit :history "parse JSON"            # By description substring
testkit :history parser                  # All tests matching "parser"
testkit :history TK-RUN --output csv     # Export as CSV
```

---

### :flaky

Lists tests with inconsistent results across runs — tests that sometimes pass and sometimes fail. Useful for identifying non-deterministic or environment-sensitive tests.

Requires at least 2 runs. Only considers OK and X results (skip and absent are ignored for flakiness).

**Output columns:** ID, Description, Pass count, Fail count, Flips, Fail Rate%

A **flip** is a transition between OK and X in consecutive runs (e.g., OK→X or X→OK). More flips indicate higher flakiness. Tests are sorted by flip count (most flaky first).

**Options:**

| Option | Description |
|--------|-------------|
| `--output=<spec>` | Output format: `plain`, `csv`, `json`, `md` or `<format>:<filename>` |

**Examples:**
```bash
testkit :flaky                           # Show flaky tests
testkit :flaky --output json             # Export as JSON
testkit :flaky -r                        # Check all subprojects
```

---

### :crossreference

Maps each test in the tracking file to its source file and line number. Useful for navigating from tracking results back to code.

**Aliases:** `:crossref`, `:xref`

**Process:** Searches the source file (recorded during test execution as the test suite path) for the test description string to find the line number.

**Output columns:** ID, Group, Description, Source File, Line, Link

**Options:**

| Option | Description |
|--------|-------------|
| `--output=<spec>` | Output format: `plain`, `csv`, `json`, `md` or `<format>:<filename>` |

**Examples:**
```bash
testkit :crossreference                  # Map tests to source
testkit :xref --output csv:xref.csv      # Export as CSV
testkit :crossref --output md:xref.md    # Export as Markdown
```

---

### :trim

Removes old run columns from the tracking file, keeping only the last N runs. The baseline (first run) is **always preserved** regardless of N.

**Usage:**
```
testkit :trim <n>
```

Where `<n>` is the number of most recent runs to keep. The baseline is always included, so the file will contain baseline + last N-1 non-baseline runs (= N total columns). Runs in between are removed. Prompts for confirmation unless `--force` is used.

**Options:**

| Option | Description |
|--------|-------------|
| `--force` | Skip the confirmation prompt |

**Examples:**
```bash
testkit :trim 5                          # Keep baseline + last 4 runs
testkit :trim 3 --force                  # Trim without confirmation
testkit :trim 10 -r                      # Trim all subprojects
```

---

### :reset

Deletes all tracking files from the project's `doc/` directory. This removes all `baseline_*.csv` files and `last_testrun.json`. Other files in `doc/` are preserved. Prompts for confirmation unless `--force` is used.

**Options:**

| Option | Description |
|--------|-------------|
| `--force` | Skip the confirmation prompt |

**Examples:**
```bash
testkit :reset                           # Delete with confirmation
testkit :reset --force                   # Delete without prompt
testkit :reset -r                        # Reset all subprojects
```

---

## Common Options

These options are available on every command:

| Option | Description |
|--------|-------------|
| `-v, --verbose` | Enable verbose output (shows file paths, extra details) |
| `-l, --list` | List projects that would be processed, without running the command |
| `-h, --help` | Show help for this command |
| `--baseline-file=<path>` | Use a specific baseline file instead of the most recent |

---

## Output Formats

Several commands accept `--output=<spec>` to control the output format and destination:

```
--output=plain               # Plain text table to stdout (default)
--output=csv                 # CSV to stdout
--output=json                # JSON to stdout
--output=md                  # Markdown to stdout
--output=csv:results.csv     # CSV to file
--output=json:data.json      # JSON to file
--output=md:report.md        # Markdown to file
```

The `--report=<file>` option (on diff commands) generates a detailed Markdown report with error messages and stack traces, which is different from `--output=md` (which outputs just the diff table).

---

## Project Traversal

testkit supports multi-project operation through the standard tom_build_base navigation system. This lets you run any command across multiple Dart projects in a workspace.

### Default Behavior

By default, testkit operates on **the current directory only** (non-recursive). It checks if the current directory is a testable project (has both `pubspec.yaml` and a `test/` directory). If so, the command runs on that project.

### Traversal Options

| Option | Description |
|--------|-------------|
| `-s, --scan=<path>` | Scan a directory for projects (default: `.`) |
| `-r, --recursive` | Recurse into subdirectories when scanning |
| `-R, --root[=<path>]` | Workspace mode: detect or specify workspace root, scan recursively |
| `-p, --project=<pattern>` | Process projects matching a glob pattern |
| `-b, --build-order` | Process in dependency order (default: on) |
| `-i, --include=<pattern>` | Include only projects matching pattern |
| `-o, --exclude=<pattern>` | Exclude projects matching pattern |

### Inside a Project

When running inside a project directory (the most common case), testkit:

1. Verifies the directory has `pubspec.yaml` and `test/`
2. Looks for the tracking file in `doc/` (the most recent `baseline_*.csv`)
3. Runs the command on that single project

```bash
cd my_package
testkit :status          # Status for my_package only
```

### Workspace Tree Traversal

Use `-R` to scan an entire workspace, or `-r` to recurse from the current location:

```bash
# From the workspace root — process ALL projects with test/ directories
testkit :status -R

# From a subdirectory — recurse into child projects
cd packages/
testkit :status -r

# Scan a specific directory
testkit :status -s packages/core

# Only specific projects
testkit :status -p "tom_*"

# Exclude projects
testkit :status -R --exclude="*_example"
```

A project is considered **testable** if it has both:
- A `pubspec.yaml` file
- A `test/` directory

Projects with a `.skip` file are always skipped during traversal.

### Listing Projects

Use `-l` to preview which projects would be processed without running the command:

```bash
testkit :test -R -l      # List all workspace projects that would be tested
```

### Multi-Project Output

When processing multiple projects, testkit prints each project path as a header, followed by the command output. A summary is printed at the end:

```
packages/core:
  File: doc/baseline_0210_1430.csv
  Runs: 3
  Tests: 45 (42 passed, 3 failed)

packages/utils:
  File: doc/baseline_0210_1430.csv
  Runs: 2
  Tests: 23 (23 passed, 0 failed)

testkit: Processed 2 project(s)
```

Each project has its own independent tracking file in its own `doc/` directory.

---

## TUI Mode

testkit includes an interactive TUI (terminal user interface) mode:

```bash
testkit --tui                    # Launch TUI for current project
testkit --tui -R                 # Launch with workspace root
```

The TUI provides a full-screen dashboard for running baselines and tests interactively.

---

## Help System

```bash
testkit help                     # Overview of all commands
testkit help <command>           # Detailed help for a specific command
testkit help baseline            # Example: detailed :baseline help
testkit help crossreference      # Aliases work too: crossref, xref
testkit --help                   # Same as testkit help
testkit version                  # Show version information
```

---

## Related Documentation

- [CLI Tools Navigation Guide](../../tom_build_base/doc/cli_tools_navigation.md) — Standard navigation options
- [Build Base User Guide](../../tom_build_base/doc/build_base_user_guide.md) — Configuration and project discovery
