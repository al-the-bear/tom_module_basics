# Issue Tracking — Concept and Workflow

This document defines the issue tracking process supported by Tom Issue Tracker's `issuekit` CLI. It describes the lifecycle of an issue from discovery to resolution, the integration with `testkit` and `buildkit`, and the commands needed to support each step.

---

## Table of Contents

1. [Overview](#overview)
2. [The Problem](#the-problem)
3. [Issue Lifecycle](#issue-lifecycle)
4. [Issue States](#issue-states)
5. [Issue Record Format](#issue-record-format)
6. [The Issue-to-Resolution Pipeline](#the-issue-to-resolution-pipeline)
7. [Command Reference (Quick)](#command-reference-quick)
8. [Full Command Reference](#full-command-reference)
9. [Integration with Testkit and Buildkit](#integration-with-testkit-and-buildkit)
10. [Project Traversal](#project-traversal)
11. [Storage and File Format](#storage-and-file-format)

---

## Overview

`issuekit` bridges the gap between **discovering a problem** and **fixing it in code**. When a consumer of a component experiences a problem, the root cause is often unclear — it might be in the component itself, in a dependency, or in the integration between components. The issue needs to be recorded immediately so it doesn't get lost, then tracked through analysis, assignment, test creation, and resolution.

Tom Issue Tracker fills the space that neither `testkit` nor `buildkit` covers:

| Tool | Scope |
|------|-------|
| **testkit** | Runs tests, tracks test results over time, detects regressions |
| **buildkit** | Builds, analyzes, and manages projects |
| **issuekit** | Records discovered problems, tracks them from discovery to resolution |

`testkit` tells you _what_ failed. `issuekit` tells you _why_ it matters, _where_ it belongs, and _what_ to do about it.

---

## The Problem

In a multi-project workspace, problems surface in many ways:

- A test fails during development and the cause isn't immediately clear
- A consumer of a component reports unexpected behavior
- A developer notices incorrect output while working on something else
- A code review reveals a latent bug
- An edge case is discovered that no test covers

In all these cases, the person who discovers the problem may not have time to fix it right now, may not know which project owns the bug, or may not be the right person to fix it. Without a lightweight way to record the issue, it gets lost — mentioned in a chat message, a mental note, or a TODO comment buried in code.

**The core requirement:** Record the issue immediately with enough context to act on it later, then track it through a defined pipeline until resolution is confirmed.

---

## Issue Lifecycle

An issue moves through the following lifecycle:

```
  ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
  │   NEW    │────▶│ ANALYZED │────▶│ ASSIGNED │────▶│ TESTING  │────▶│ RESOLVED │
  └──────────┘     └──────────┘     └──────────┘     └──────────┘     └──────────┘
       │                │                │                │                │
       │                │                │                │                │
       ▼                ▼                ▼                ▼                ▼
  Issue first      Root cause       Assigned to      Reproduction     Fix verified
  recorded         identified       a project        test created     by retest
```

### States

| State | Meaning | Exit Criteria |
|-------|---------|---------------|
| **NEW** | Issue discovered and recorded | Symptom description and reproduction context provided |
| **ANALYZED** | Root cause identified or narrowed down | The affected project/module is known |
| **ASSIGNED** | Ownership is clear — issue belongs to a specific project | A developer or the project maintainer can act on it |
| **TESTING** | A reproduction test exists in the target project | Test is tracked by `testkit` with `(FAIL)` expectation |
| **RESOLVED** | The bug is fixed and the reproduction test passes | Test expectation changed to `(PASS)`, test passes |
| **CLOSED** | Issue confirmed resolved and archived | Issue removed from active tracking |

Additional states for special cases:

| State | Meaning |
|-------|---------|
| **BLOCKED** | Cannot proceed — waiting on external factor (dependency, information, decision) |
| **DUPLICATE** | Same root cause as another issue — linked to original |
| **WONTFIX** | Intentional behavior or out of scope — documented and closed |

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

### Resolution Fields (populated during testing/resolution)

| Field | Description |
|-------|-------------|
| **Test ID** | ID of the reproduction test in `testkit` (e.g., `I-BUG-42`) |
| **Test file** | Path to the test file |
| **Fix description** | What was changed to fix it |
| **Resolved** | Timestamp of resolution |

---

## The Issue-to-Resolution Pipeline

This is the complete workflow from problem discovery to confirmed fix.

### Step 1: Record the Issue

Someone discovers a problem. They immediately record it:

```bash
issuekit :new "JSON parser crashes on empty arrays"
```

This creates a new issue in `NEW` state with an auto-generated ID. The reporter can add context interactively or via options:

```bash
issuekit :new "JSON parser crashes on empty arrays" \
  --severity high \
  --context "Discovered while running tom_d4rt tests, test I-PAR-12 fails" \
  --expected "Empty arrays should parse to an empty list" \
  --tags "parser,json,crash"
```

The issue is now recorded and won't be lost.

### Step 2: Analyze the Issue

Later (or immediately), someone analyzes the issue to determine the root cause:

```bash
issuekit :analyze ISS-0042 \
  --root-cause "Array parser does not handle length-0 case" \
  --project tom_d4rt
```

This moves the issue to `ANALYZED` state and records the findings. If the project is identified, the issue can also be assigned in the same step:

```bash
issuekit :assign ISS-0042 --project tom_d4rt --module parser
```

This moves the issue to `ASSIGNED` state.

### Step 3: Create a Reproduction Test

Once assigned to a project, a reproduction test is created in that project's test suite. The test follows the `testkit` naming convention:

```dart
test('I-BUG-42: Array parser crashes on empty arrays [2026-02-10 14:00] (FAIL)', () {
  final result = parseArray('[]');
  expect(result, isEmpty);
});
```

The test is expected to `(FAIL)` because the bug hasn't been fixed yet. Register the test link:

```bash
issuekit :link ISS-0042 \
  --test-id I-BUG-42 \
  --test-file test/parser/array_parser_test.dart
```

This moves the issue to `TESTING` state. At this point, `testkit :test` will track this test as an expected failure (`X/X`).

### Step 4: Fix the Bug

The developer fixes the bug in the target project. After the fix:

```bash
# In the target project
testkit :test -c "fixed empty array parsing"
```

If the reproduction test now passes, `testkit` will show it as `OK/X` (passed unexpectedly — progress!). The developer updates the test expectation from `(FAIL)` to `(PASS)`.

### Step 5: Resolve the Issue

Confirm the fix resolved the issue:

```bash
issuekit :resolve ISS-0042 --fix "Added empty check in ArrayParser.parse()"
```

This moves the issue to `RESOLVED` state. The resolution is timestamped.

### Step 6: Close the Issue

After verification (e.g., the next baseline confirms the test passes consistently):

```bash
issuekit :close ISS-0042
```

This moves the issue to `CLOSED` state and archives it.

---

## Command Reference (Quick)

### Issue Management

| Command | Description |
|---------|-------------|
| `:new` | Create a new issue |
| `:edit` | Edit an existing issue's fields |
| `:analyze` | Record analysis results (root cause, affected project) |
| `:assign` | Assign an issue to a project |
| `:link` | Link an issue to a reproduction test |
| `:resolve` | Mark an issue as resolved |
| `:close` | Close and archive a resolved issue |
| `:reopen` | Reopen a closed or resolved issue |

### Viewing and Querying

| Command | Description |
|---------|-------------|
| `:list` | List issues with filtering and sorting |
| `:show` | Show full details of one issue |
| `:search` | Full-text search across all issues |
| `:summary` | Dashboard: counts by state, severity, project |

### Workflow Integration

| Command | Description |
|---------|-------------|
| `:sync` | Sync issue states with testkit results (auto-detect resolved tests) |
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
| `--project=<name>` | Pre-assign to a project (skips `NEW` → goes to `ASSIGNED`) |

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

### :link

Links an issue to a reproduction test in `testkit`.

**Usage:**
```
issuekit :link <issue-id> [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--test-id=<id>` | Test ID in the testkit naming convention (e.g., `I-BUG-42`) |
| `--test-file=<path>` | Path to the test file |

Moves the issue to `TESTING` state. The issue is now tracked alongside the test result.

---

### :resolve

Marks an issue as resolved after the bug has been fixed and the test passes.

**Usage:**
```
issuekit :resolve <issue-id> [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--fix=<text>` | Short description of the fix |
| `--note=<text>` | Additional notes |

Moves the issue to `RESOLVED` state with a timestamp.

---

### :close

Closes a resolved issue and moves it to the archive.

**Usage:**
```
issuekit :close <issue-id>
```

Moves the issue to `CLOSED` state. Closed issues are retained in the archive file for historical reference.

---

### :reopen

Reopens a closed or resolved issue (e.g., if the fix didn't hold or the problem recurred).

**Usage:**
```
issuekit :reopen <issue-id> [--note="<reason>"]
```

Moves the issue back to its previous active state (before resolution).

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
| `--state=<state>` | Filter by state (e.g., `new`, `assigned`, `testing`) |
| `--severity=<level>` | Filter by severity |
| `--project=<name>` | Filter by assigned project |
| `--tags=<t1,t2>` | Filter by tags (any match) |
| `--reporter=<name>` | Filter by reporter |
| `--all` | Include closed/archived issues |
| `--sort=<field>` | Sort by field: `created`, `severity`, `state`, `project` (default: `severity,created`) |
| `--output=<spec>` | Output format: `plain`, `csv`, `json`, `md` or `<format>:<file>` |

**Examples:**
```bash
issuekit :list                                 # All active issues
issuekit :list --state new                     # Only new/unanalyzed issues
issuekit :list --project tom_d4rt              # Issues assigned to tom_d4rt
issuekit :list --severity critical,high        # High-priority issues
issuekit :list --all --output csv:issues.csv   # Export all issues
```

---

### :show

Displays the full details of a single issue.

**Usage:**
```
issuekit :show <issue-id>
```

Shows all fields including history of state changes, analysis notes, and linked test results.

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

Searches title, symptom, context, root cause, fix description, tags, and notes. Returns matching issues sorted by relevance.

**Options:**

| Option | Description |
|--------|-------------|
| `--all` | Include closed/archived issues |
| `--output=<spec>` | Output format |

---

### :summary

Displays a dashboard-style overview of issue counts grouped by various dimensions.

**Usage:**
```
issuekit :summary
```

**Output includes:**
- Total issues by state
- Issues by severity
- Issues by project
- Unassigned issues count
- Issues in testing (awaiting retest)
- Recently resolved issues

**Options:**

| Option | Description |
|--------|-------------|
| `--output=<spec>` | Output format |

---

### :sync

Synchronizes issue states with `testkit` test results. Checks linked reproduction tests and auto-detects when a test that was expected to fail now passes, suggesting the issue may be resolved.

**Usage:**
```
issuekit :sync
```

**Behavior:**
- For issues in `TESTING` state: checks if the linked test ID now passes in the latest testkit baseline
- Reports issues that may be resolved (test now passes)
- Reports issues where the test regressed (was passing, now fails again)
- Does **not** auto-transition states — only reports findings for human review

**Options:**

| Option | Description |
|--------|-------------|
| `--auto-resolve` | Automatically move issues to `RESOLVED` when their linked test passes |
| `--project=<name>` | Only sync issues for a specific project |

---

### :export

Exports issues in structured formats for reporting or integration.

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

### Testkit Integration

Issue Tracker and Test Kit work together through the test ID convention:

1. **Issue links to test:** When a reproduction test is created, the issue records the test ID (e.g., `I-BUG-42`)
2. **Test describes the issue:** The test description follows testkit convention: `I-BUG-42: <description> [<date>] (FAIL)`
3. **Sync detects resolution:** `issuekit :sync` reads testkit baselines to detect when linked tests start passing

This creates a complete chain:

```
Issue ISS-0042 → links to test I-BUG-42 → tracked in testkit baseline
                                         → testkit shows X/X (expected failure)
After fix:                               → testkit shows OK/X (unexpected pass!)
                                         → issuekit :sync detects this
                                         → developer resolves the issue
```

### Test ID Convention

Issue IDs and test IDs are related but distinct:

| ID Type | Format | Where | Example |
|---------|--------|-------|---------|
| **Issue ID** | `ISS-<number>` | Issue tracker | `ISS-0042` |
| **Test ID** | `<prefix>-<category>-<number>` | Test description | `I-BUG-42` |

The mapping is recorded in the issue record via `:link`.

### Buildkit Integration

Issue Tracker can work alongside buildkit for project-level operations:

- **Project discovery:** Uses the same project detection as buildkit (pubspec.yaml)
- **Project names:** Issue assignment uses the same project names as buildkit
- **Workspace navigation:** Shares the standard tom_build_base navigation options

---

## Project Traversal

issuekit uses the same navigation system as testkit and buildkit:

### Issue Storage Location

Issues are stored at the **workspace level**, not per project, because issues are not yet assigned to a project when first created. The issue database is located at:

```
<workspace-root>/.issues/
├── issues.yaml          # Active issues
├── archive.yaml         # Closed issues
└── config.yaml          # Issue tracker configuration (ID counter, defaults)
```

### Multi-Project Context

When operating on issues related to specific projects, the standard navigation options apply:

| Option | Description |
|--------|-------------|
| `-R, --root[=<path>]` | Workspace mode: detect or specify workspace root |
| `-p, --project=<pattern>` | Filter issues by project name pattern |

For `:sync`, which needs to read testkit baselines, it traverses into each project's `doc/` directory.

---

## Storage and File Format

### YAML Format

Issues are stored as YAML for human readability and easy editing:

```yaml
issues:
  - id: ISS-0042
    title: "Array parser crashes on empty arrays"
    state: testing
    severity: high
    reporter: alexis
    created: 2026-02-10T14:00:00
    symptom: "parseArray('[]') throws RangeError"
    context: "Discovered while running tom_d4rt tests, test I-PAR-12 fails"
    expected: "Empty arrays should parse to an empty list"
    tags: [parser, json, crash]
    project: tom_d4rt
    module: parser
    root_cause: "Array parser does not handle length-0 case"
    test_id: I-BUG-42
    test_file: test/parser/array_parser_test.dart
    history:
      - date: 2026-02-10T14:00:00
        from: null
        to: new
        note: "Initial report"
      - date: 2026-02-10T14:30:00
        from: new
        to: analyzed
        note: "Root cause identified in ArrayParser"
      - date: 2026-02-10T15:00:00
        from: analyzed
        to: assigned
        note: "Assigned to tom_d4rt/parser"
      - date: 2026-02-10T16:00:00
        from: assigned
        to: testing
        note: "Reproduction test I-BUG-42 created"
```

### Configuration

The `config.yaml` file stores tracker settings:

```yaml
next_id: 43
default_severity: normal
default_reporter: alexis
```

---

## Related Documentation

- [Test Tracking — Concept and Workflow](../../tom_test_kit/doc/test_tracking.md) — Testkit workflow and commands
- [CLI Tools Navigation Guide](../../tom_build_base/doc/cli_tools_navigation.md) — Standard navigation options
- [Build Base User Guide](../../tom_build_base/doc/build_base_user_guide.md) — Configuration and project discovery
