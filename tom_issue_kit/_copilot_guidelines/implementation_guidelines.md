# Tom Issue Kit — Implementation Guidelines

This document defines the development workflow for `tom_issue_kit`, emphasizing specification-driven development and test-first implementation.

---

## Core Principle: Test the Specification, Not the Implementation

**Tests verify that the code meets its design specification — not that the current implementation works.**

| Approach | What It Tests | Problem |
|----------|---------------|---------|
| Testing implementation | "Does the code do what it currently does?" | Tests pass even when the code is wrong |
| Testing specification | "Does the code do what it should do?" | Tests fail when the code deviates from design |

Always write tests from the specification. If a test fails, the implementation is wrong — not the test.

---

## Development Sequence

```
1. Specification    → What should the code do?
2. Tests            → How do we verify it does that?
3. Implementation   → Make the tests pass
4. Verification     → Run tests, fix any failures
```

### 1. Specification First

Before writing any code, understand **what** the code should do:

- Read the design documents (`doc/issue_tracking.md`, `doc/issuekit_command_reference.md`)
- Identify the specific behavior being implemented
- Note edge cases and error conditions

### 2. Tests First (TDD)

Write the test **before** implementing the feature or fix.

### 3. Implementation

Implement the minimum code needed to make tests pass.

### 4. Verification

1. Run `dart analyze` — fix all errors and warnings
2. Run `dart test` — verify new tests pass
3. Run full test suite — ensure no regressions
4. Update test expectation from `(FAIL)` to `(PASS)` or remove it

---

## Test Naming Convention

All tests use a structured naming format:

```
<ID>: <description> [<creation-timestamp>] (<expectation>)
```

### Components

| Component | Format | Description |
|-----------|--------|-------------|
| **ID** | `IK-<CAT>-<num>` | Unique identifier (IK = Issue Kit) |
| **Description** | Free text | What the test verifies |
| **Timestamp** | `YYYY-MM-DD HH:MM` | When the test was created |
| **Expectation** | `PASS` or `FAIL` | Expected result (optional) |

### ID Categories

| Prefix | Category | Examples |
|--------|----------|----------|
| `IK-NEW-n` | :new command | IK-NEW-1 |
| `IK-EDT-n` | :edit command | IK-EDT-1 |
| `IK-SHW-n` | :show command | IK-SHW-1 |
| `IK-LST-n` | :list command | IK-LST-1 |
| `IK-SRC-n` | :search command | IK-SRC-1 |
| `IK-CLS-n` | :close command | IK-CLS-1 |
| `IK-ROP-n` | :reopen command | IK-ROP-1 |
| `IK-ANL-n` | :analyze command | IK-ANL-1 |
| `IK-ASN-n` | :assign command | IK-ASN-1 |
| `IK-TST-n` | :testing command | IK-TST-1 |
| `IK-VRF-n` | :verify command | IK-VRF-1 |
| `IK-RSL-n` | :resolve command | IK-RSL-1 |
| `IK-SCN-n` | :scan command | IK-SCN-1 |
| `IK-SYN-n` | :sync command | IK-SYN-1 |
| `IK-VLD-n` | :validate command | IK-VLD-1 |
| `IK-PRO-n` | :promote command | IK-PRO-1 |
| `IK-LNK-n` | :link command | IK-LNK-1 |
| `IK-EXP-n` | :export command | IK-EXP-1 |
| `IK-IMP-n` | :import command | IK-IMP-1 |
| `IK-SNP-n` | :snapshot command | IK-SNP-1 |
| `IK-AGG-n` | :aggregate command | IK-AGG-1 |
| `IK-SUM-n` | :summary command | IK-SUM-1 |
| `IK-INI-n` | :init command | IK-INI-1 |
| `IK-RUN-n` | :run-tests command | IK-RUN-1 |
| `IK-CFG-n` | Configuration | IK-CFG-1 |
| `IK-CLI-n` | CLI infrastructure | IK-CLI-1 |
| `IK-INT-n` | Integration tests | IK-INT-1 |

### Issue-Linked Tests

Tests linked to a `tom_issues` issue embed the issue number:

```
IK-<issue-number>-<CAT>-<num>
```

---

## Bug Fixing Workflow

1. **Understand the specification** — What does the design document say?
2. **Write a failing test** — Proves the bug exists
3. **Run the test** — Verify it fails (if it passes, test is wrong)
4. **Fix the implementation** — Match the specification
5. **Verify the fix** — Run the test, run full suite
6. **Update test expectation** — Remove `(FAIL)`

---

## Quality Checklist

Before marking any task complete:

- [ ] Tests written based on **specification**, not implementation
- [ ] Failing test written **before** fix (for bugs)
- [ ] `dart analyze` shows no errors or warnings
- [ ] All related tests pass
- [ ] Full test suite passes (no regressions)
- [ ] Test expectations updated

---

## Related Documents

- [issue_tracking.md](../doc/issue_tracking.md) — Design specification
- [issuekit_command_reference.md](../doc/issuekit_command_reference.md) — Command specifications
- [issuekit_implementation_todos.md](../doc/issuekit_implementation_todos.md) — Phased implementation plan
