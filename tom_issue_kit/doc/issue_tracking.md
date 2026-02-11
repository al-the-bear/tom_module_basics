# Issue Tracking — Concept and Workflow

This document defines the issue tracking process supported by Tom Issue Kit's `issuekit` CLI. It describes the lifecycle of an issue from discovery through verified resolution, the ID conventions that link issues to reproduction tests via the codebase, and the commands needed to support each step.

---

## Table of Contents

1. [Overview](#overview)
2. [The Problem](#the-problem)
3. [Design Principles](#design-principles)
4. [ID Scheme](#id-scheme)
5. [Issue Lifecycle](#issue-lifecycle)
6. [The Issue-to-Resolution Pipeline](#the-issue-to-resolution-pipeline)
7. [Convention-Based Test Linking](#convention-based-test-linking)
8. [Issue Record Format](#issue-record-format)
9. [Command Reference (Quick)](#command-reference-quick)
10. [Full Command Reference](#full-command-reference)
11. [Integration with Testkit and Buildkit](#integration-with-testkit-and-buildkit)
12. [Storage and File Format](#storage-and-file-format)
13. [Project Traversal](#project-traversal)

---

## Overview

`issuekit` bridges the gap between **discovering a problem** and **confirming it is fixed**. When a consumer of a component experiences a problem, the root cause is often unclear — it might be in the component itself, in a dependency, or in the integration between components. The issue needs to be recorded immediately so it doesn't get lost, then tracked through analysis, project assignment, reproduction test creation, bug fix, and verified resolution.

Tom Issue Kit fills the space that neither `testkit` nor `buildkit` covers:

| Tool | Scope |
|------|-------|
| **testkit** | Runs tests, tracks test results over time, detects regressions |
| **buildkit** | Builds, analyzes, and manages projects |
| **issuekit** | Records discovered problems, tracks them from discovery through verified resolution |

`testkit` tells you _what_ failed. `issuekit` tells you _why_ it matters, _where_ it belongs, _what_ to do about it, and — critically — **whether the fix actually resolved the original problem**.

---

## The Problem

In a multi-project workspace, problems surface in many ways:

- A test fails during development and the cause isn't immediately clear
- A consumer of a component reports unexpected behavior
- A developer notices incorrect output while working on something else
- A code review reveals a latent bug
- An edge case is discovered that no test covers

In all these cases, the person who discovers the problem may not have time to fix it right now, may not know which project owns the bug, or may not be the right person to fix it. Without a lightweight way to record the issue, it gets lost — mentioned in a chat message, a mental note, or a TODO comment buried in code.

**The core requirement:** Record the issue immediately with enough context to act on it later, then track it through a defined pipeline until resolution is **verified** — not just "fixed" but confirmed that the original problem no longer occurs.

---

## Design Principles

### 1. Codebase as Source of Truth

The primary linking mechanism between issues and reproduction tests is the **test description in source code**, not a database. By embedding the issue ID in the test's ID using a naming convention, we can **scan the codebase** to discover all tests related to any issue — across all projects in the workspace.

This eliminates synchronization problems: there is no link record that can get out of date. The test code IS the link.

### 2. Convention Over Configuration

Issue-to-test linking works through ID conventions, not explicit registration. When a developer writes a reproduction test with the correct ID format, the issuekit can discover it automatically. No exceptions or overrides.

### 3. Verified Resolution

An issue is not resolved just because someone says "I fixed it." Resolution requires **proof**: the reproduction test must pass. And the issue is not closed until the original reporter or a reviewer confirms that the fix addresses the **original symptom**, not just the test case.

### 4. Workspace-Level Tracking

Issues live at the workspace level because they don't belong to a project when first discovered. Once analyzed and assigned, they link to one or more projects through the test ID convention.

---

## ID Scheme

The ID scheme creates a globally unique, scannable connection between issues, projects, and tests.

### Project ID

Each project in the workspace has a short unique prefix, defined in the project's `tom_project.yaml` or derived from the project name:

| Project | Project ID |
|---------|-----------|
| `tom_d4rt` | `D4RT` |
| `tom_d4rt_generator` | `D4GN` |
| `tom_build_kit` | `BKIT` |
| `tom_test_kit` | `TKIT` |
| `tom_crypto` | `CRYP` |
| `tom_basics` | `BASC` |

Project IDs are uppercase, 2–5 characters. They must be unique within the workspace. Each project declares its ID:

```yaml
# tom_project.yaml
project_id: D4RT
```

### Issue ID

Issues use the format `ISS-<number>`, auto-incremented at the workspace level:

```
ISS-0001, ISS-0002, ..., ISS-0042
```

The number is zero-padded to 4 digits for consistent sorting.

### Test ID for Issue Reproduction

When creating a reproduction test for an issue, the test ID **embeds the issue number** using the convention:

```
<PROJECT_ID>-ISS-<issue_number><suffix>
```

| Component | Description |
|-----------|-------------|
| `<PROJECT_ID>` | Project prefix — makes the test ID globally unique |
| `ISS` | Literal marker — indicates this test is linked to an issue |
| `<issue_number>` | The issue number (without padding) — links back to the issue |
| `<suffix>` | Optional letter — allows multiple tests per issue per project (a, b, c...) |

**Examples:**

```
D4RT-ISS-42a     → tom_d4rt, issue ISS-0042, first test
D4RT-ISS-42b     → tom_d4rt, issue ISS-0042, second test
BKIT-ISS-42a     → tom_build_kit, issue ISS-0042, first test (same issue, different project)
```

**Full test description:**

```dart
test('D4RT-ISS-42a: Array parser crashes on empty arrays [2026-02-10 14:00] (FAIL)', () {
  final result = parseArray('[]');
  expect(result, isEmpty);
});
```

### Regular Test IDs (Non-Issue)

Tests that are not linked to issues use the existing convention:

```
<PROJECT_ID>-<CATEGORY>-<number>
```

**Examples:**

```dart
test('D4RT-PAR-15: Parser handles nested objects [2026-01-15 10:00]', () { ... });
test('BKIT-BLD-3: Build with missing pubspec fails gracefully [2026-01-20 09:00]', () { ... });
```

### Why This Matters

Given issue `ISS-0042`, we can find **every reproduction test in the entire workspace** by scanning test files for the pattern `ISS-42` in test descriptions. This works across projects:

```
tom_d4rt/test/parser/array_test.dart       → D4RT-ISS-42a
tom_d4rt/test/parser/null_test.dart        → D4RT-ISS-42b
tom_build_kit/test/build/edge_test.dart    → BKIT-ISS-42a
```

No database. No link records. The codebase is the source of truth.

---

## Issue Lifecycle

An issue moves through the following lifecycle:

```
  ┌───────┐     ┌──────────┐     ┌──────────┐     ┌─────────┐     ┌───────────┐     ┌──────────┐     ┌────────┐
  │  NEW  │────▶│ ANALYZED │────▶│ ASSIGNED │────▶│ TESTING │────▶│ VERIFYING │────▶│ RESOLVED │────▶│ CLOSED │
  └───────┘     └──────────┘     └──────────┘     └─────────┘     └───────────┘     └──────────┘     └────────┘
      │              │                │                │                │                 │
      ▼              ▼                ▼                ▼                ▼                 ▼
   Issue          Root cause      Assigned to     Reproduction     Tests pass,       Fix confirmed,
   recorded       identified      a project       test created     fix applied       issue closed
                                                   (FAIL)          (OK/X → OK/OK)    after review
```

### States

| State | Meaning | Entry Condition | Exit Criteria |
|-------|---------|-----------------|---------------|
| **NEW** | Issue discovered and recorded | `:new` command | Symptom and context provided |
| **ANALYZED** | Root cause identified or narrowed down | Root cause determined | Affected project identified |
| **ASSIGNED** | Ownership clear — belongs to a specific project | Project identified | Developer can act on it |
| **TESTING** | Reproduction test exists in the target project | Test created with `ISS-<n>` ID and `(FAIL)` expectation | Developer works on fix |
| **VERIFYING** | Fix applied — reproduction test now passes | All linked tests pass (`OK/X` or `OK/OK` in testkit) | Original reporter confirms fix addresses the symptom |
| **RESOLVED** | Original issue confirmed fixed by the reporter/reviewer | Reporter confirms the original symptom is gone | Awaiting archival |
| **CLOSED** | Archived | Issue archived after resolution | N/A |

**Key distinction between VERIFYING and RESOLVED:**

- **VERIFYING** = "The test passes" — the code fix works. But does it actually solve the original problem as the reporter experienced it? The reproduction test may be too narrow, or the fix may only address part of the issue.
- **RESOLVED** = "The original problem is gone" — confirmed by the reporter, reviewer, or by passing a broader acceptance test.

### Additional States

| State | Meaning |
|-------|---------|
| **BLOCKED** | Cannot proceed — waiting on external factor (dependency, information, decision) |
| **DUPLICATE** | Same root cause as another issue — linked to original |
| **WONTFIX** | Intentional behavior or out of scope — documented and closed |

### State Transitions

```
NEW ──────────▶ ANALYZED ──▶ ASSIGNED ──▶ TESTING ──▶ VERIFYING ──▶ RESOLVED ──▶ CLOSED
  │                 │            │            │            │             │
  │                 │            │            │            │             ├──▶ REOPEN → NEW
  │                 │            │            │            │             │
  │                 │            │            │            ├─ test fails ─▶ back to TESTING
  │                 │            │            │            │               (regression)
  │                 │            │            │            │
  │                 │            │            ├────────────┤
  │                 │            │            │ (shortcut: if project known and test created immediately)
  │                 │            │            │
  │                 │ (shortcut: analyze + assign in one step if project is clear)
  │                 │
  ├─────────────────┘
  │ (shortcut: NEW → ASSIGNED if project is known at creation time)
  │
  ├──▶ DUPLICATE (linked to original issue)
  ├──▶ WONTFIX (documented and closed)
  └──▶ BLOCKED (waiting on external factor)
```

---

## The Issue-to-Resolution Pipeline

This is the complete workflow from problem discovery to confirmed, verified resolution.

### Step 1: Record the Issue (→ NEW)

Someone discovers a problem. They immediately record it:

```bash
issuekit :new "JSON parser crashes on empty arrays"
```

This creates a new issue in `NEW` state with an auto-generated ID (e.g., `ISS-0042`). Context can be added immediately:

```bash
issuekit :new "JSON parser crashes on empty arrays" \
  --severity high \
  --context "Discovered while running tom_d4rt tests, test D4RT-PAR-12 fails with RangeError" \
  --expected "Empty arrays should parse to an empty list" \
  --tags "parser,json,crash"
```

The issue is now recorded and won't be lost.

### Step 2: Analyze the Issue (→ ANALYZED)

Later (or immediately), someone analyzes the issue to determine the root cause and identify which project owns it:

```bash
issuekit :analyze ISS-0042 \
  --root-cause "Array parser does not handle length-0 case in _parseArrayElements()" \
  --project tom_d4rt \
  --module parser
```

If the project is identified, the tool can move directly to `ASSIGNED`:

```bash
issuekit :assign ISS-0042 --project tom_d4rt --module parser
```

### Step 3: Create a Reproduction Test (→ TESTING)

A reproduction test is created in the target project's test suite. The test uses the **issue-linked ID convention**:

```dart
test('D4RT-ISS-42a: Array parser crashes on empty arrays [2026-02-10 14:00] (FAIL)', () {
  final result = parseArray('[]');
  expect(result, isEmpty);
});
```

Key elements:
- **`D4RT-ISS-42a`** — Project prefix + issue link + suffix. This makes the test scannable and globally unique.
- **`(FAIL)`** — Expected to fail because the bug hasn't been fixed yet.
- **`[2026-02-10 14:00]`** — When the test was created.

The issue transitions to `TESTING` when issuekit detects a test matching `ISS-42` in the codebase (via `:scan`), or explicitly:

```bash
issuekit :testing ISS-0042
```

At this point, `testkit :test` tracks this test as an expected failure (`X/X`).

**Multiple tests per issue:** One issue can spawn multiple reproduction tests, potentially across different projects:

```dart
// In tom_d4rt — tests the parser directly
test('D4RT-ISS-42a: Array parser crashes on empty arrays [2026-02-10 14:00] (FAIL)', ...);

// In tom_d4rt — tests a related edge case
test('D4RT-ISS-42b: Array parser crashes on null elements [2026-02-10 14:00] (FAIL)', ...);

// In tom_build_kit — tests that build handles the parser error gracefully
test('BKIT-ISS-42a: Build recovers from parser crash on empty arrays [2026-02-10 15:00] (FAIL)', ...);
```

All three are discoverable by scanning for `ISS-42`.

### Step 4: Fix the Bug

The developer fixes the bug in the target project. After the fix, run the tests:

```bash
# In the target project
testkit :test -c "fixed empty array parsing"
```

If the reproduction test now passes, `testkit` shows it as `OK/X` (passed unexpectedly — progress!).

### Step 5: Verify the Fix (→ VERIFYING)

This is the critical step that was often missed. **Passing the test is necessary but not sufficient.** The fix must be verified:

```bash
issuekit :verify ISS-0042
```

The `:verify` command:
1. **Scans the workspace** for all tests matching `ISS-42` in their test IDs
2. **Checks testkit baselines** in each relevant project to see if the tests pass
3. **Reports the verification status** for each linked test:
   - `PASS` — Test exists and passes in the latest testkit run
   - `FAIL` — Test exists but still fails
   - `NOT RUN` — Test exists but hasn't been run since the fix
4. If **all linked tests pass**, the issue transitions to `VERIFYING`

In `VERIFYING` state, the issue awaits **human confirmation** that the original symptom is gone. This might mean:
- The original reporter retests the scenario
- A broader integration test is run
- A manual check of the reported behavior

If the verification fails (tests pass but the original problem persists), the issue stays in `TESTING` — the reproduction test was incomplete and needs to be improved.

### Step 6: Confirm Resolution (→ RESOLVED)

Once the original reporter or reviewer confirms the fix:

```bash
issuekit :resolve ISS-0042 --fix "Added empty check in ArrayParser._parseArrayElements()"
```

The developer also updates the test expectation from `(FAIL)` to `(PASS)`:

```dart
// Before: (FAIL) — bug not yet fixed
test('D4RT-ISS-42a: Array parser crashes on empty arrays [2026-02-10 14:00] (FAIL)', ...);

// After: removed (FAIL) or changed to (PASS) — bug is fixed, test should pass permanently
test('D4RT-ISS-42a: Array parser crashes on empty arrays [2026-02-10 14:00]', ...);
```

Now `testkit` tracks it as `OK/OK` — a healthy test. Any future regression will show as `X/OK` and immediately flag a problem.

### Step 7: Close the Issue (→ CLOSED)

After the fix is stable (e.g., passes in the next baseline too):

```bash
issuekit :close ISS-0042
```

The issue moves to `CLOSED` and is archived. The reproduction test **remains in the codebase permanently** as a regression guard.

### What If the Fix Doesn't Hold?

If a resolved issue regresses later:

1. `testkit` detects the regression (`X/OK` in the baseline — test was expected to pass but failed)
2. `issuekit :sync` cross-references failing tests with closed issues and alerts:
   ```
   REGRESSION: ISS-0042 — Test D4RT-ISS-42a now fails (was passing since 02-10)
   ```
3. The issue can be reopened:
   ```bash
   issuekit :reopen ISS-0042 --note "Regression detected in testkit baseline 02-15"
   ```

---

## Convention-Based Test Linking

This is the key mechanism that connects issues to tests without maintaining a database of links.

### How It Works

1. **Write the test** with an issue-linked ID: `<PROJECT>-ISS-<number><suffix>`
2. **issuekit discovers it** by scanning `test/` directories across the workspace for `ISS-<number>` patterns in test descriptions
3. **testkit tracks it** as a normal test — the ID format is transparent to testkit
4. **issuekit reads testkit baselines** to check if linked tests pass or fail

### Scanning

The `:scan` command discovers all tests for an issue:

```bash
issuekit :scan ISS-0042
```

Output:
```
Tests for ISS-0042:

Project       Test ID         File                                    Line  Status
-----------   -------------   ------------------------------------    ----  ------
tom_d4rt      D4RT-ISS-42a    test/parser/array_parser_test.dart      45    FAIL
tom_d4rt      D4RT-ISS-42b    test/parser/array_null_test.dart        12    FAIL
tom_build_kit BKIT-ISS-42a    test/build/edge_cases_test.dart         88    PASS
```

Scanning without an issue ID shows all issue-linked tests across the workspace:

```bash
issuekit :scan              # All issue-linked tests
issuekit :scan --project tom_d4rt   # Only in tom_d4rt
issuekit :scan --state testing      # Only for issues in TESTING state
```

### Why Not a Database?

A database approach (`:link` with stored references) has synchronization problems:

| Problem | Database approach | Convention approach |
|---------|-------------------|---------------------|
| Test renamed/moved | Database out of date | Scan finds it wherever it is |
| Test deleted | Stale reference | Scan finds nothing — clear signal |
| New test added | Must run `:link` again | Scan discovers it automatically |
| Test in wrong project | Reference to wrong location | ID prefix makes project clear |
| Multiple tests per issue | Must register each one | All discovered automatically |

The `:link` command still exists as an **explicit override** for cases where the convention doesn't apply (e.g., linking to a test with a non-standard ID), but it is not the primary mechanism.

---

## Issue Record Format

Each issue is a structured record with the following fields:

### Required Fields

| Field | Description |
|-------|-------------|
| **ID** | Auto-generated unique identifier (e.g., `ISS-0042`) |
| **Title** | Short summary of the problem (one line) |
| **State** | Current lifecycle state |
| **Reporter** | Who discovered the issue |
| **Created** | Timestamp of initial report |

### Context Fields

| Field | Description |
|-------|-------------|
| **Symptom** | Observable behavior — what goes wrong |
| **Context** | Where / how the problem was discovered (test name, user scenario, code path) |
| **Expected** | What should happen instead |
| **Severity** | `critical`, `high`, `normal`, `low` |
| **Tags** | Free-form labels for categorization |

### Assignment Fields (populated during analysis/assignment)

| Field | Description |
|-------|-------------|
| **Project** | Target project that owns the bug |
| **Module** | Specific module within the project (optional) |
| **Root cause** | Brief explanation of why it happens |
| **Assignee** | Who is responsible for the fix (optional) |

### Resolution Fields (populated during verification/resolution)

| Field | Description |
|-------|-------------|
| **Fix description** | What was changed to fix it |
| **Verified** | Timestamp when all linked tests passed |
| **Resolved** | Timestamp when the reporter confirmed resolution |

Note: Test IDs and test files are **not stored** in the issue record — they are **discovered** by scanning the codebase for the `ISS-<number>` pattern. The issue record only stores metadata about the issue itself.

---

## Command Reference (Quick)

### Issue Management

| Command | Description |
|---------|-------------|
| `:new` | Create a new issue |
| `:edit` | Edit an existing issue's fields |
| `:analyze` | Record analysis results (root cause, affected project) |
| `:assign` | Assign an issue to a project |
| `:testing` | Mark that a reproduction test has been created |
| `:verify` | Check if linked tests pass — move to VERIFYING if all pass |
| `:resolve` | Confirm the original issue is fixed after verification |
| `:close` | Close and archive a resolved issue |
| `:reopen` | Reopen a closed or resolved issue |

### Discovery and Querying

| Command | Description |
|---------|-------------|
| `:list` | List issues with filtering and sorting |
| `:show` | Show full details of one issue |
| `:search` | Full-text search across all issues |
| `:scan` | Scan workspace for tests linked to issues via ID convention |
| `:summary` | Dashboard: counts by state, severity, project |

### Workflow Integration

| Command | Description |
|---------|-------------|
| `:sync` | Sync issue states with testkit results — detect fixes and regressions |
| `:link` | Explicitly link a test to an issue (override for non-standard IDs) |
| `:export` | Export issues as CSV, JSON, or Markdown |
| `:import` | Import issues from a file |

---

## Full Command Reference

### :new

Creates a new issue and assigns it a unique ID.

**Usage:**
```
issuekit :new "<title>" [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--severity=<level>` | Severity: `critical`, `high`, `normal` (default), `low` |
| `--context=<text>` | Where/how the problem was discovered |
| `--expected=<text>` | Expected behavior |
| `--symptom=<text>` | Observable symptoms (defaults to title if not set) |
| `--tags=<t1,t2,...>` | Comma-separated tags for categorization |
| `--project=<name>` | Pre-assign to a project (skips NEW → goes to ASSIGNED) |

**Examples:**
```bash
issuekit :new "Memory leak in long-running server"
issuekit :new "Incorrect UTF-8 decoding" --severity high --tags "encoding,parser"
issuekit :new "Timeout on large files" --project tom_d4rt --context "Seen during stress test"
```

---

### :edit

Modifies fields on an existing issue.

**Usage:**
```
issuekit :edit <issue-id> [field options]
```

Any field can be updated: `--title`, `--severity`, `--context`, `--expected`, `--symptom`, `--tags`, `--project`, `--module`, `--assignee`.

**Examples:**
```bash
issuekit :edit ISS-0042 --severity critical
issuekit :edit ISS-0042 --tags "parser,json,regression"
issuekit :edit ISS-0042 --title "Array parser crashes on empty and null arrays"
```

---

### :analyze

Records analysis findings for an issue — narrows down the root cause and affected area.

**Usage:**
```
issuekit :analyze <issue-id> [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--root-cause=<text>` | Explanation of the root cause |
| `--project=<name>` | Identified target project |
| `--module=<name>` | Identified target module |
| `--note=<text>` | Additional analysis notes |

Moves the issue from `NEW` → `ANALYZED`. If `--project` is provided, also moves to `ASSIGNED`.

---

### :assign

Assigns an issue to a specific project and optional module.

**Usage:**
```
issuekit :assign <issue-id> --project=<name> [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--project=<name>` | Target project (required) |
| `--module=<name>` | Target module within the project |
| `--assignee=<name>` | Person responsible for the fix |

Moves the issue to `ASSIGNED` state.

---

### :testing

Marks that a reproduction test has been created for the issue. This is typically done after writing the test with the `<PROJECT>-ISS-<number>` convention.

**Usage:**
```
issuekit :testing <issue-id>
```

The tool verifies that at least one test matching `ISS-<number>` exists in the workspace before transitioning. If no test is found, it warns but still allows the transition (the test might not be committed yet).

Moves the issue to `TESTING` state.

---

### :verify

Checks whether the reproduction tests for an issue now pass, indicating the fix works.

**Usage:**
```
issuekit :verify <issue-id>
```

**Process:**
1. Scans the workspace for all tests matching `ISS-<number>`
2. For each test found, checks the latest testkit baseline in that project
3. Reports pass/fail status for each linked test
4. If **all linked tests pass**, moves the issue to `VERIFYING` state
5. If any test still fails, reports which ones and does not transition

The `VERIFYING` state means "the code fix works — awaiting human confirmation that the original problem is resolved."

**Options:**

| Option | Description |
|--------|-------------|
| `--note=<text>` | Verification notes |

---

### :resolve

Confirms that the fix addresses the original issue after verification.

**Usage:**
```
issuekit :resolve <issue-id> [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--fix=<text>` | Short description of the fix |
| `--note=<text>` | Additional notes |

Requires the issue to be in `VERIFYING` state (use `--force` to override). Moves to `RESOLVED`.

---

### :close

Closes a resolved issue and moves it to the archive.

**Usage:**
```
issuekit :close <issue-id>
```

Moves the issue to `CLOSED` state. Closed issues are retained in the archive file.

---

### :reopen

Reopens a closed or resolved issue.

**Usage:**
```
issuekit :reopen <issue-id> [--note="<reason>"]
```

Moves the issue back to the appropriate active state. Common reasons: regression detected, fix was incomplete, original problem recurred.

---

### :list

Lists issues matching filter criteria. By default, shows all active (non-closed) issues.

**Usage:**
```
issuekit :list [filters]
```

**Filters:**

| Option | Description |
|--------|-------------|
| `--state=<state>` | Filter by state (e.g., `new`, `assigned`, `testing`, `verifying`) |
| `--severity=<level>` | Filter by severity |
| `--project=<name>` | Filter by assigned project |
| `--tags=<t1,t2>` | Filter by tags (any match) |
| `--reporter=<name>` | Filter by reporter |
| `--all` | Include closed/archived issues |
| `--sort=<field>` | Sort by: `created`, `severity`, `state`, `project` (default: `severity,created`) |
| `--output=<spec>` | Output format: `plain`, `csv`, `json`, `md` or `<format>:<file>` |

**Examples:**
```bash
issuekit :list                                 # All active issues
issuekit :list --state testing                 # Issues awaiting fix
issuekit :list --state verifying               # Issues awaiting confirmation
issuekit :list --project tom_d4rt              # Issues assigned to tom_d4rt
issuekit :list --severity critical,high        # High-priority issues
issuekit :list --all --output csv:issues.csv   # Export everything
```

---

### :show

Displays the full details of a single issue, including discovered tests.

**Usage:**
```
issuekit :show <issue-id>
```

Shows all fields, state change history, and the results of scanning the workspace for linked tests.

**Options:**

| Option | Description |
|--------|-------------|
| `--output=<spec>` | Output format: `plain`, `json`, `md` |

---

### :search

Full-text search across all issue fields.

**Usage:**
```
issuekit :search "<query>"
```

Searches title, symptom, context, root cause, fix description, tags, and notes.

**Options:**

| Option | Description |
|--------|-------------|
| `--all` | Include closed/archived issues |
| `--output=<spec>` | Output format |

---

### :scan

Scans the workspace for tests linked to issues via the ID convention.

**Usage:**
```
issuekit :scan [<issue-id>]
```

Without an issue ID, scans for all issue-linked tests (`*-ISS-*` pattern). With an issue ID, scans only for that issue's tests.

**Process:**
1. Traverses `test/` directories across workspace projects
2. Searches test file contents for test descriptions matching the issue ID pattern
3. Cross-references with testkit baselines to report pass/fail status
4. Reports file path and line number for each discovered test

**Options:**

| Option | Description |
|--------|-------------|
| `--project=<name>` | Only scan within a specific project |
| `--state=<state>` | Only scan for issues in a specific state |
| `--output=<spec>` | Output format |

**Examples:**
```bash
issuekit :scan ISS-0042                  # Find all tests for issue 42
issuekit :scan                           # Find all issue-linked tests
issuekit :scan --project tom_d4rt        # Only in tom_d4rt
issuekit :scan --state testing           # Only for issues in TESTING state
```

---

### :summary

Displays a dashboard overview of issues grouped by various dimensions.

**Usage:**
```
issuekit :summary
```

**Output includes:**
- Total issues by state (with emphasis on TESTING and VERIFYING counts)
- Issues by severity
- Issues by project
- Unassigned issues count
- Issues awaiting verification
- Recently resolved/closed issues

**Options:**

| Option | Description |
|--------|-------------|
| `--output=<spec>` | Output format |

---

### :sync

Synchronizes issue states with testkit results across the workspace. This is the primary automated workflow command.

**Usage:**
```
issuekit :sync
```

**Process:**
1. For each issue in `ASSIGNED` state: scans for tests matching the issue ID. If found, suggests moving to `TESTING`.
2. For each issue in `TESTING` state: checks if linked tests now pass. If all pass, suggests moving to `VERIFYING`.
3. For each issue in `VERIFYING` or `RESOLVED` state: checks if any linked test has regressed. If so, alerts and suggests reopening.
4. For closed issues: checks if linked tests regress. If so, alerts about potential regression.

**Output:**
```
Sync results:

  ISS-0042 [TESTING → VERIFYING suggested]
    All 3 linked tests now pass (D4RT-ISS-42a, D4RT-ISS-42b, BKIT-ISS-42a)

  ISS-0038 [TESTING — still failing]
    1/2 tests pass (D4RT-ISS-38a: PASS, D4RT-ISS-38b: FAIL)

  ISS-0015 [CLOSED — REGRESSION DETECTED]
    Test D4RT-ISS-15a now fails (was passing since 01-28)
```

**Options:**

| Option | Description |
|--------|-------------|
| `--auto` | Automatically apply suggested state transitions |
| `--project=<name>` | Only sync issues for a specific project |

---

### :link

Explicitly links a test to an issue. This is an **override** for cases where the convention-based approach doesn't apply (e.g., the test has a non-standard ID, or the test predates the convention).

**Usage:**
```
issuekit :link <issue-id> --test-id=<id> [--test-file=<path>]
```

Explicit links are stored in the issue record and are checked alongside convention-based discoveries during `:scan` and `:verify`.

---

### :export

Exports issues in structured formats for reporting.

**Usage:**
```
issuekit :export [filters] --output=<spec>
```

Supports the same filters as `:list`. Output formats: `csv`, `json`, `md`, `yaml`.

---

### :import

Imports issues from an external file.

**Usage:**
```
issuekit :import <file>
```

Accepts CSV, JSON, or YAML files. New IDs are auto-assigned; existing IDs are updated.

---

## Integration with Testkit and Buildkit

### The Complete Chain

Issue Kit and Test Kit form a closed-loop verification cycle through the ID convention:

```
1. Issue ISS-0042 created
         │
2. Reproduction test written: D4RT-ISS-42a ... (FAIL)
         │
3. testkit :test → tracks D4RT-ISS-42a as X/X (expected failure)
         │
4. Developer fixes the bug
         │
5. testkit :test → tracks D4RT-ISS-42a as OK/X (unexpected pass!)
         │
6. issuekit :verify ISS-0042 → scans workspace, finds D4RT-ISS-42a passes
         │                      → moves to VERIFYING
7. Reporter confirms fix
         │
8. issuekit :resolve ISS-0042 → moves to RESOLVED
         │
9. Developer updates test: (FAIL) → remove/change to (PASS)
         │
10. testkit :test → tracks D4RT-ISS-42a as OK/OK (expected pass — healthy)
          │
11. issuekit :close ISS-0042 → archived
          │
    Future: if D4RT-ISS-42a ever becomes X/OK → issuekit :sync detects regression
```

### How Scanning Connects the Dots

The workspace scan is what makes the integration work without synchronization:

| Question | Answer from scanning |
|----------|---------------------|
| "What tests exist for ISS-0042?" | Scan `test/` dirs for `ISS-42` in test descriptions |
| "Do those tests pass?" | Check testkit baselines in the corresponding projects |
| "Which project has tests for this issue?" | The project ID prefix in the test ID (e.g., `D4RT-`) |
| "Is this issue still a problem?" | Run `:verify` — if all tests pass, the fix works |
| "Did a fix regress?" | `:sync` checks closed issues against current test results |

### Testkit Baseline Cross-Reference

`:verify` and `:sync` read testkit's `doc/baseline_*.csv` files to check test status. They look for the test ID in the baseline's ID column and read the latest result.

If testkit hasn't been run recently, `:verify` will report `NOT RUN` — the developer should run `testkit :test` first.

### Buildkit Integration

- **Project discovery:** Uses the same detection as buildkit (`pubspec.yaml`)
- **Project IDs:** Defined in `tom_project.yaml`, used by both buildkit and issuekit
- **Workspace navigation:** Shares the standard tom_build_base navigation options

---

## Storage and File Format

### Issue Storage Location

Issues are stored at the **workspace level** because they aren't assigned to a project when first created:

```
<workspace-root>/.issues/
├── issues.yaml          # Active issues
├── archive.yaml         # Closed issues
└── config.yaml          # Configuration (ID counter, defaults)
```

### YAML Format

```yaml
issues:
  - id: ISS-0042
    title: "Array parser crashes on empty arrays"
    state: verifying
    severity: high
    reporter: alexis
    created: 2026-02-10T14:00:00
    symptom: "parseArray('[]') throws RangeError"
    context: "Discovered while running tom_d4rt tests, test D4RT-PAR-12 fails"
    expected: "Empty arrays should parse to an empty list"
    tags: [parser, json, crash]
    project: tom_d4rt
    module: parser
    root_cause: "Array parser does not handle length-0 case"
    fix: "Added empty check in ArrayParser._parseArrayElements()"
    verified: 2026-02-11T10:00:00
    explicit_links: []          # Only populated by :link override
    history:
      - date: 2026-02-10T14:00:00
        to: new
        note: "Initial report"
      - date: 2026-02-10T14:30:00
        to: analyzed
        note: "Root cause identified in ArrayParser"
      - date: 2026-02-10T15:00:00
        to: assigned
        note: "Assigned to tom_d4rt/parser"
      - date: 2026-02-10T16:00:00
        to: testing
        note: "Reproduction tests D4RT-ISS-42a, D4RT-ISS-42b created"
      - date: 2026-02-11T10:00:00
        to: verifying
        note: "All 2 linked tests pass (verified by :verify)"
```

Note: The `explicit_links` field is only used for tests linked via the `:link` override command. Convention-based tests are discovered dynamically by scanning.

### Configuration

```yaml
next_id: 43
default_severity: normal
default_reporter: alexis
```

---

## Project Traversal

issuekit uses the same navigation system as testkit and buildkit for workspace scanning:

| Option | Description |
|--------|-------------|
| `-R, --root[=<path>]` | Workspace mode: detect or specify workspace root |
| `-s, --scan=<path>` | Scan a specific directory for projects |
| `-r, --recursive` | Recurse into subdirectories |
| `-p, --project=<pattern>` | Filter by project name pattern |
| `-i, --include=<pattern>` | Include only matching projects |
| `-o, --exclude=<pattern>` | Exclude matching projects |
| `-l, --list` | List projects that would be processed |

These options apply primarily to `:scan`, `:verify`, and `:sync` commands, which need to traverse projects to find tests and read testkit baselines.

Issue management commands (`:new`, `:edit`, `:list`, etc.) operate on the workspace-level issue store and don't need project traversal.

---

## Related Documentation

- [Test Tracking — Concept and Workflow](../../tom_test_kit/doc/test_tracking.md) — Testkit workflow and commands
- [CLI Tools Navigation Guide](../../tom_build_base/doc/cli_tools_navigation.md) — Standard navigation options
- [Build Base User Guide](../../tom_build_base/doc/build_base_user_guide.md) — Configuration and project discovery
