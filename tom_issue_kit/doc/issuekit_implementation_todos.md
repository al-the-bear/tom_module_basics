# Issuekit Implementation — Phased Plan

This document breaks the issuekit implementation into phased steps following the development methodology: **Specification → Stub → Tests → Implementation**.

---

## Phase 1: tom_github_api (Foundation Library)

The reusable GitHub Issues API library that both issuekit and testkit depend on.

### Deliverables

| Step | Type | Description | Status |
|------|------|-------------|--------|
| 1.1 | Spec | `github_api_specification.md` — API surface, models, error handling | TODO |
| 1.2 | Guidelines | Copy implementation guidelines, create index.md | TODO |
| 1.3 | Stub | Stub classes and methods matching specification | TODO |
| 1.4 | Tests | Unit tests for all API operations (GH- prefix) | TODO |
| 1.5 | Impl | Complete implementation to pass all tests | TODO |
| 1.6 | QA | dart analyze, full test suite, baseline | TODO |

### Scope

- GitHub Issues CRUD (create, get, update, close, reopen)
- Label management (create, add, remove, list)
- Comment operations (add, list)
- Issue listing with filters (state, labels, sort)
- Full-text search via GitHub Search API
- Pagination handling (100 items/page)
- Authentication (PAT from env/file)
- Rate limiting (detect, retry, report)
- Workflow dispatch (trigger GitHub Actions)
- Cross-repo support (tom_issues, tom_tests)

### Dependencies

- `http` package for HTTP requests
- No dependency on tom_build_base or tom_issue_kit

---

## Phase 2: tom_issue_kit Core Infrastructure

The CLI framework and configuration layer.

### Deliverables

| Step | Type | Description | Status |
|------|------|-------------|--------|
| 2.1 | Spec | CLI architecture, command registration, config loading | TODO |
| 2.2 | Stub | Command base classes, config reader, CLI entry point | TODO |
| 2.3 | Tests | Command parsing, config loading, project traversal | TODO |
| 2.4 | Impl | Complete infrastructure (uses tom_build_base for traversal) | TODO |
| 2.5 | QA | dart analyze, full test suite | TODO |

### Scope

- CLI entry point (`bin/issuekit.dart`)
- Command registration and dispatch
- Configuration loading (`tom_workspace.yaml`, `tom_project.yaml`)
- GitHub authentication resolution (env → file → keychain)
- Output formatting (plain, csv, json, md)

### Dependencies

- tom_build_base (project traversal, CLI infrastructure)
- tom_github_api (GitHub API access)

---

## Phase 3: Issue Management Commands

The commands that manage issues in tom_issues.

### Deliverables

| Step | Type | Description | Status |
|------|------|-------------|--------|
| 3.1 | Stub | Command stubs: :new, :edit, :show, :list, :search, :close, :reopen | TODO |
| 3.2 | Tests | Tests for each command | TODO |
| 3.3 | Impl | Complete command implementations | TODO |
| 3.4 | QA | dart analyze, full test suite | TODO |

### Commands

- `:new` — Create issue in tom_issues
- `:edit` — Update issue fields
- `:show` — Display full issue details
- `:list` — List/filter issues
- `:search` — Full-text search
- `:close` — Close resolved issue
- `:reopen` — Reopen issue (manual)

---

## Phase 4: Issue Lifecycle Commands

State transition and project assignment commands.

### Deliverables

| Step | Type | Description | Status |
|------|------|-------------|--------|
| 4.1 | Stub | Command stubs: :analyze, :assign, :testing, :verify, :resolve | TODO |
| 4.2 | Tests | Tests for state transitions and cross-repo operations | TODO |
| 4.3 | Impl | Complete implementations | TODO |
| 4.4 | QA | dart analyze, full test suite | TODO |

### Commands

- `:analyze` — Record root cause analysis
- `:assign` — Assign to project, create stub test entry in tom_tests
- `:testing` — Confirm reproduction test exists
- `:verify` — Machine verification (all tests pass)
- `:resolve` — Human confirmation of fix

---

## Phase 5: Workspace Integration Commands

Commands that bridge GitHub Issues and the local codebase.

### Deliverables

| Step | Type | Description | Status |
|------|------|-------------|--------|
| 5.1 | Stub | Command stubs: :scan, :sync, :validate, :promote, :link | TODO |
| 5.2 | Tests | Tests for scanning, sync, validation | TODO |
| 5.3 | Impl | Complete implementations (uses tom_build_base traversal) | TODO |
| 5.4 | QA | dart analyze, full test suite | TODO |

### Commands

- `:scan` — Discover issue-linked tests in workspace
- `:sync` — Synchronize issue states with test results
- `:validate` — Check test ID uniqueness
- `:promote` — Promote regular test to issue-linked
- `:link` — Explicitly link non-standard test to issue

---

## Phase 6: Data Management Commands

Export, import, snapshot, and aggregation.

### Deliverables

| Step | Type | Description | Status |
|------|------|-------------|--------|
| 6.1 | Stub | Command stubs: :export, :import, :snapshot, :aggregate, :summary | TODO |
| 6.2 | Tests | Tests for data operations | TODO |
| 6.3 | Impl | Complete implementations | TODO |
| 6.4 | QA | dart analyze, full test suite | TODO |

### Commands

- `:export` — Export issues/tests to file (csv, json, md)
- `:import` — Import entries from file
- `:snapshot` — Full backup to timestamped JSON
- `:aggregate` — Merge per-project baselines into consolidated
- `:summary` — Dashboard overview

---

## Phase 7: Automation

GitHub Actions integration and initialization.

### Deliverables

| Step | Type | Description | Status |
|------|------|-------------|--------|
| 7.1 | Stub | Command stubs: :init, :run-tests | TODO |
| 7.2 | Tests | Tests for label creation, workflow dispatch | TODO |
| 7.3 | Impl | Complete implementations | TODO |
| 7.4 | GitHub | Nightly workflow YAML for tom_tests | TODO |
| 7.5 | QA | dart analyze, full test suite, end-to-end test | TODO |

### Commands

- `:init` — Initialize repos with labels and templates
- `:run-tests` — Trigger nightly test workflow

---

## Dependency Graph

```
Phase 1: tom_github_api        ← No dependencies (standalone)
    ↓
Phase 2: Core Infrastructure   ← tom_build_base, tom_github_api
    ↓
Phase 3: Issue Management       ← Phase 2
    ↓
Phase 4: Lifecycle Commands     ← Phase 3 (cross-repo: tom_issues + tom_tests)
    ↓
Phase 5: Workspace Integration  ← Phase 4, tom_build_base traversal
    ↓
Phase 6: Data Management        ← Phase 3, 4
    ↓
Phase 7: Automation             ← Phase 1 (workflow dispatch), Phase 3-6
```

---

## Current Focus

**Phase 1: tom_github_api** — See [github_api_specification.md](../../tom_github_api/doc/github_api_specification.md) for the detailed API specification.

---

## Implementation Gaps (2026-02-15)

Gaps discovered during spec-driven test implementation:

| Area | Gap | Priority | Notes |
|------|-----|----------|-------|
| ValidateExecutor | `--fix` option not implemented | Medium | Spec defines auto-fix for simple conflicts |
| Post-traversal | No `afterTraversal` hook in framework | Low | Would enable workspace-wide consolidation of results |
| AggregateExecutor | Limited output formats | Low | Consider JSON/YAML output in addition to CSV |
| SyncExecutor | Auto-verifying logic incomplete | Medium | Should auto-update issue states based on test results |
| Integration tests | No end-to-end workflow tests | Medium | Would test actual GitHub API calls with mocks |

### Test Coverage Summary

- **283 tests** passing as of 2026-02-15
- **24 executors** fully stubbed and tested
- **5 traversal executors** enhanced with service interactions
- **Generic test infrastructure** created for file I/O testing
