/// Test fixtures and mock helpers for tom_issue_kit tests.
library;

import 'package:mocktail/mocktail.dart';
import 'package:tom_github_api/tom_github_api.dart';
import 'package:tom_issue_kit/src/config/issuekit_config.dart';
import 'package:tom_issue_kit/src/services/issue_service.dart';
import 'package:tom_issue_kit/src/services/test_scanner.dart';

// =============================================================================
// Mock Classes
// =============================================================================

/// Mock GitHubApiClient for unit testing.
class MockGitHubApiClient extends Mock implements GitHubApiClient {}

/// Mock IssueService for executor unit testing.
class MockIssueService extends Mock implements IssueService {}

/// Mock TestScanner for traversal executor unit testing.
class MockTestScanner extends Mock implements TestScanner {}

// =============================================================================
// Fixture Factories
// =============================================================================

/// Create a test GitHubUser with configurable fields.
GitHubUser createTestUser({
  String login = 'testuser',
  int id = 12345,
  String? avatarUrl,
}) {
  return GitHubUser(
    login: login,
    id: id,
    avatarUrl: avatarUrl ?? 'https://avatars.githubusercontent.com/u/$id',
  );
}

/// Create a test GitHubLabel with configurable fields.
GitHubLabel createTestLabel({
  String name = 'bug',
  String color = 'fc2929',
  String? description,
}) {
  return GitHubLabel(
    name: name,
    color: color,
    description: description,
  );
}

/// Create a test GitHubIssue with configurable fields.
GitHubIssue createTestIssue({
  int number = 42,
  String title = 'Test issue',
  String? body,
  String state = 'open',
  List<GitHubLabel>? labels,
  GitHubUser? user,
  GitHubUser? assignee,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? closedAt,
  int commentsCount = 0,
  String? htmlUrl,
}) {
  return GitHubIssue(
    number: number,
    title: title,
    body: body,
    state: state,
    labels: labels ?? [],
    user: user ?? createTestUser(),
    assignee: assignee,
    createdAt: createdAt ?? DateTime(2026, 2, 13, 10, 0),
    updatedAt: updatedAt ?? DateTime(2026, 2, 13, 10, 0),
    closedAt: closedAt,
    commentsCount: commentsCount,
    htmlUrl: htmlUrl ?? 'https://github.com/al-the-bear/tom_issues/issues/$number',
  );
}

/// Create a test GitHubComment with configurable fields.
GitHubComment createTestComment({
  int id = 1,
  String body = 'Test comment',
  GitHubUser? user,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return GitHubComment(
    id: id,
    body: body,
    user: user ?? createTestUser(),
    createdAt: createdAt ?? DateTime(2026, 2, 13, 10, 0),
    updatedAt: updatedAt ?? DateTime(2026, 2, 13, 10, 0),
  );
}

/// Create a test GitHubSearchResult with configurable fields.
GitHubSearchResult createTestSearchResult({
  int totalCount = 1,
  bool incompleteResults = false,
  List<GitHubIssue>? items,
}) {
  return GitHubSearchResult(
    totalCount: totalCount,
    incompleteResults: incompleteResults,
    items: items ?? [createTestIssue()],
  );
}

// =============================================================================
// Configuration Fixtures
// =============================================================================

/// Create a test IssueKitConfig with configurable fields.
IssueKitConfig createTestConfig({
  String? issuesRepo,
  String? testsRepo,
  String? projectId,
  String? token,
}) {
  return IssueKitConfig(
    issueTracking: IssueTrackingConfig(
      issuesRepo: issuesRepo ?? 'al-the-bear/tom_issues',
      testsRepo: testsRepo ?? 'al-the-bear/tom_tests',
    ),
    auth: GitHubAuthConfig(token: token),
    projectConfigs: projectId != null 
        ? {'test_project': ProjectConfig(projectId: projectId)}
        : {},
  );
}

/// Sample tom_workspace.yaml content for testing.
const String sampleWorkspaceYaml = '''
name: test_workspace
version: 1.0.0

issue_tracking:
  issues_repo: al-the-bear/tom_issues
  tests_repo: al-the-bear/tom_tests
  auth:
    token_file: ~/.tom/github_token
''';

/// Sample tom_project.yaml content for testing.
const String sampleProjectYaml = '''
name: test_project
project_id: TP
module: core
''';

// =============================================================================
// Label Fixtures
// =============================================================================

/// Standard state labels used in issue tracking.
final List<GitHubLabel> stateLabels = [
  createTestLabel(name: 'new', color: '5319e7', description: 'Newly created'),
  createTestLabel(name: 'analyzed', color: '0052cc', description: 'Analysis done'),
  createTestLabel(name: 'assigned', color: '006b75', description: 'Assigned to project'),
  createTestLabel(name: 'testing', color: '1d76db', description: 'Tests being written'),
  createTestLabel(name: 'verifying', color: '0e8a16', description: 'Awaiting verification'),
  createTestLabel(name: 'resolved', color: '2cbe4e', description: 'Fix verified'),
];

/// Standard severity labels used in issue tracking.
final List<GitHubLabel> severityLabels = [
  createTestLabel(name: 'severity:critical', color: 'd93f0b'),
  createTestLabel(name: 'severity:high', color: 'e99695'),
  createTestLabel(name: 'severity:normal', color: 'fef2c0'),
  createTestLabel(name: 'severity:low', color: 'c5def5'),
];

// =============================================================================
// Issue Fixtures
// =============================================================================

/// Create a NEW state issue fixture.
GitHubIssue createNewIssue({
  int number = 42,
  String title = 'Array parser crashes on empty arrays',
  String? body,
  String severity = 'high',
}) {
  return createTestIssue(
    number: number,
    title: title,
    body: body ?? '''
## Symptom
$title

## Context
Discovered during testing

## Expected
Should handle empty arrays gracefully
''',
    labels: [
      createTestLabel(name: 'new', color: '5319e7'),
      createTestLabel(name: 'severity:$severity', color: 'e99695'),
    ],
  );
}

/// Create an ASSIGNED state issue fixture.
GitHubIssue createAssignedIssue({
  int number = 42,
  String title = 'Array parser crashes on empty arrays',
  String project = 'D4',
}) {
  return createTestIssue(
    number: number,
    title: title,
    labels: [
      createTestLabel(name: 'assigned', color: '006b75'),
      createTestLabel(name: 'severity:high', color: 'e99695'),
      createTestLabel(name: 'project:$project', color: 'ededed'),
    ],
  );
}

/// Create a TESTING state issue fixture.
GitHubIssue createTestingIssue({
  int number = 42,
  String title = 'Array parser crashes on empty arrays',
  String project = 'D4',
}) {
  return createTestIssue(
    number: number,
    title: title,
    labels: [
      createTestLabel(name: 'testing', color: '1d76db'),
      createTestLabel(name: 'severity:high', color: 'e99695'),
      createTestLabel(name: 'project:$project', color: 'ededed'),
    ],
  );
}

/// Create a RESOLVED/closed issue fixture.
GitHubIssue createClosedIssue({
  int number = 42,
  String title = 'Array parser crashes on empty arrays',
}) {
  return createTestIssue(
    number: number,
    title: title,
    state: 'closed',
    closedAt: DateTime(2026, 2, 13, 15, 0),
    labels: [
      createTestLabel(name: 'resolved', color: '2cbe4e'),
      createTestLabel(name: 'severity:high', color: 'e99695'),
    ],
  );
}
