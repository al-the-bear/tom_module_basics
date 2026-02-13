# tom_issue_kit Testing Guidelines

This document describes the testing strategy for `tom_issue_kit`, covering unit tests and integration tests.

## Test Architecture Overview

```
tom_issue_kit/
├── test/                           # Unit tests (mocked GitHubApiClient)
│   ├── helpers/
│   │   ├── fixtures.dart           # Test data fixtures
│   │   └── mock_github_api.dart    # Mock GitHubApiClient
│   ├── v2/
│   │   └── issuekit_tool_test.dart # Tool definition tests
│   ├── config/
│   │   └── issuekit_config_test.dart # Configuration loading tests
│   ├── util/
│   │   └── output_formatter_test.dart # Output formatting tests
│   └── commands/
│       ├── new_test.dart           # :new command tests
│       ├── edit_test.dart          # :edit command tests
│       ├── show_test.dart          # :show command tests
│       ├── list_test.dart          # :list command tests
│       ├── search_test.dart        # :search command tests
│       ├── close_test.dart         # :close command tests
│       ├── analyze_test.dart       # :analyze command tests
│       └── ...                     # Other command tests
└── tool/
    └── integration_test.dart       # End-to-end CLI tests
```

## Unit Testing Strategy

Unit tests use a **mocked GitHubApiClient** — no real API calls. This allows:

- Fast execution
- No network or GitHub token dependency
- Deterministic, repeatable results
- Testing edge cases and error conditions

### Mock GitHubApiClient

Use `mocktail` to create mock implementations:

```dart
import 'package:mocktail/mocktail.dart';
import 'package:tom_github_api/tom_github_api.dart';

class MockGitHubApiClient extends Mock implements GitHubApiClient {}

// In tests:
final mockApi = MockGitHubApiClient();
when(() => mockApi.getIssue(
  repoSlug: any(named: 'repoSlug'),
  issueNumber: any(named: 'issueNumber'),
)).thenAnswer((_) async => GitHubIssue(
  number: 42,
  title: 'Test issue',
  state: 'open',
  labels: [],
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
));
```

### Fixtures

The `fixtures.dart` file provides factory functions for test data:

| Function | Purpose |
|----------|---------|
| `createTestIssue()` | GitHubIssue with configurable fields |
| `createTestLabel()` | GitHubLabel for label operations |
| `createTestConfig()` | IssueKitConfig for testing |
| `createTestWorkspaceYaml()` | Sample tom_workspace.yaml content |
| `createTestProjectYaml()` | Sample tom_project.yaml content |

### Test Naming Convention

Tests follow the `IK-<CAT>-<num>: description [date] (expectation)` pattern:

| Category | Code | Description |
|----------|------|-------------|
| :new command | NEW | Issue creation |
| :edit command | EDT | Issue editing |
| :show command | SHW | Single issue display |
| :list command | LST | Issue listing |
| :search command | SRC | Issue search |
| :close command | CLS | Close issues |
| :reopen command | ROP | Reopen issues |
| :analyze command | ANL | Issue analysis |
| :assign command | ASN | Issue assignment |
| :testing command | TST | Test tracking |
| :verify command | VRF | Issue verification |
| :resolve command | RSL | Resolution |
| :scan command | SCN | Workspace scanning |
| :sync command | SYN | GitHub sync |
| :validate command | VLD | Validation |
| :promote command | PRO | State promotion |
| :link command | LNK | Issue linking |
| :export command | EXP | Data export |
| :import command | IMP | Data import |
| :snapshot command | SNP | Snapshots |
| :aggregate command | AGG | Multi-repo aggregation |
| :summary command | SUM | Summary reports |
| :init command | INI | Initialization |
| :run-tests command | RUN | Test execution |
| Configuration | CFG | Config loading |
| CLI infrastructure | CLI | Tool/command definitions |
| Integration | INT | End-to-end tests |

Example:
```dart
test('IK-NEW-1: creates issue with title and body [2026-02-13]', () async {
  // ...
});
```

### Running Unit Tests

```bash
# All unit tests
dart test

# With baseline tracking (via testkit)
testkit :test

# Specific test file
dart test test/commands/new_test.dart

# By category
dart test --name "IK-NEW"
```

## Integration Testing Strategy

Integration tests run the CLI against **real GitHub repositories** to verify end-to-end functionality.

### Configuration

| Environment Variable | Purpose | Default |
|---------------------|---------|---------|
| `GITHUB_TOKEN` | Personal access token | (required) |
| `ISSUEKIT_TEST_REPO` | Test repository for issues | `al-the-bear/tom_issues_test` |
| `ISSUEKIT_TEST_TESTS_REPO` | Test repository for test tracking | `al-the-bear/tom_tests_test` |

**Usage examples:**

```bash
# Run integration tests with default repos
dart run tool/integration_test.dart

# With custom repositories
ISSUEKIT_TEST_REPO=myuser/myrepo dart run tool/integration_test.dart
```

The test token needs these permissions:
- **Issues**: Read and write
- **Metadata**: Read (usually auto-granted)

### Test Repositories

| Repository | Purpose |
|------------|---------|
| `al-the-bear/tom_issues_test` | Issue operations testing |
| `al-the-bear/tom_tests_test` | Test tracking operations |

These are dedicated repositories for testing — integration tests create/modify/close issues here.

### What Integration Tests Cover

1. **Issue Management**
   - `:new` — Create issues with various options
   - `:edit` — Update title, body, labels, state
   - `:show` — Display issue details
   - `:list` — List with filters
   - `:search` — Search across repos
   - `:close` / `:reopen` — State transitions

2. **Lifecycle Commands**
   - `:analyze` — Analysis transitions
   - `:assign` — Assignment workflow
   - `:testing` / `:verify` — Test tracking
   - `:resolve` — Resolution workflow

3. **Output Formats**
   - Plain text
   - CSV
   - JSON
   - Markdown

4. **Configuration**
   - Reading `tom_workspace.yaml`
   - Reading `tom_project.yaml`
   - GitHub token resolution

### Test Cleanup

Integration tests create and then clean up:
- Issues are closed (GitHub doesn't allow deleting issues)
- Labels prefixed with `ik-test-` are deleted

## CI Considerations

Unit tests can run in CI without credentials. Integration tests require:

```yaml
env:
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  ISSUEKIT_TEST_REPO: al-the-bear/tom_issues_test
  ISSUEKIT_TEST_TESTS_REPO: al-the-bear/tom_tests_test
```

Consider rate limits when running integration tests frequently (5000 requests/hour for authenticated users).

## Adding New Tests

### Unit Test Template

```dart
test('IK-XXX-N: description [YYYY-MM-DD]', () async {
  final mockApi = MockGitHubApiClient();
  when(() => mockApi.someMethod(...)).thenAnswer((_) async => result);
  
  final executor = SomeCommandExecutor(api: mockApi);
  final result = await executor.execute(args);
  
  expect(result.exitCode, 0);
  verify(() => mockApi.someMethod(...)).called(1);
});
```

### Integration Test Template

Add to `tool/integration_test.dart`:

```dart
await _test('N.M: description', () async {
  final result = await _runIssueKit([':command', '--option', 'value']);
  _assert(result.exitCode == 0, 'command should succeed');
  _assert(result.stdout.contains('expected'), 'output should contain expected');
});
```

## Test Coverage Summary

| Area | Unit Tests | Integration Tests |
|------|------------|-------------------|
| Tool definition | 11 | — |
| Configuration | 19 | — |
| Output formatting | 23 | — |
| :new command | — | TBD |
| :edit command | — | TBD |
| :show command | — | TBD |
| :list command | — | TBD |
| :search command | — | TBD |
| Other commands | — | TBD |
| **Total** | **53** | **TBD** |

## Related Documents

- [implementation_guidelines.md](implementation_guidelines.md) — Development workflow
- [issue_tracking.md](../doc/issue_tracking.md) — Design specification
- [issuekit_command_reference.md](../doc/issuekit_command_reference.md) — Command specifications
