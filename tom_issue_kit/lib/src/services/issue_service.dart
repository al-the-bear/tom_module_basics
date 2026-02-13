/// GitHub Issue service for tom_issue_kit.
///
/// Provides high-level operations on GitHub issues using tom_github_api.
/// Handles label management, issue body formatting, and state transitions.
library;

import 'package:tom_github_api/tom_github_api.dart';

/// Service for managing issues in tom_issues repository.
class IssueService {
  final GitHubApiClient _client;
  final String _issuesRepo;
  final String _testsRepo;

  IssueService({
    required GitHubApiClient client,
    required String issuesRepo,
    required String testsRepo,
  })  : _client = client,
        _issuesRepo = issuesRepo,
        _testsRepo = testsRepo;

  /// Create a new issue in tom_issues.
  ///
  /// Creates an issue with the NEW state label and severity label.
  /// If [project] is provided, creates the issue in ASSIGNED state and
  /// creates a stub test entry in tom_tests.
  Future<CreateIssueResult> createIssue({
    required String title,
    String? symptom,
    String? context,
    String? expected,
    String severity = 'normal',
    List<String> tags = const [],
    String? project,
    String? reporter,
  }) async {
    // Build issue body
    final body = _buildIssueBody(
      title: title,
      symptom: symptom,
      context: context,
      expected: expected,
    );

    // Build labels
    final labels = <String>[
      if (project == null) 'new' else 'assigned',
      'severity:$severity',
      if (reporter != null) 'reporter:$reporter',
      if (project != null) 'project:$project',
      ...tags,
    ];

    // Create the issue
    final issue = await _client.createIssue(
      repoSlug: _issuesRepo,
      title: title,
      body: body,
      labels: labels,
    );

    // If project is specified, create a stub test entry in tom_tests
    GitHubIssue? testEntry;
    if (project != null) {
      testEntry = await _createTestEntry(
        issueNumber: issue.number,
        title: title,
        project: project,
      );
    }

    return CreateIssueResult(
      issue: issue,
      testEntry: testEntry,
    );
  }

  /// Update an existing issue.
  Future<GitHubIssue> updateIssue({
    required int issueNumber,
    String? title,
    String? severity,
    String? context,
    String? expected,
    String? symptom,
    List<String>? tags,
    String? project,
    String? assignee,
  }) async {
    // First get the current issue to preserve existing labels
    final current = await _client.getIssue(
      repoSlug: _issuesRepo,
      number: issueNumber,
    );

    // Build new labels if needed
    List<String>? labels;
    if (severity != null || tags != null || project != null) {
      labels = _updateLabels(
        current: current.labels.map((l) => l.name).toList(),
        newSeverity: severity,
        newTags: tags,
        newProject: project,
      );
    }

    // Update the issue
    return _client.updateIssue(
      repoSlug: _issuesRepo,
      number: issueNumber,
      title: title,
      labels: labels,
      assignee: assignee,
    );
  }

  /// Get a single issue by number.
  Future<GitHubIssue> getIssue(int issueNumber) {
    return _client.getIssue(
      repoSlug: _issuesRepo,
      number: issueNumber,
    );
  }

  /// List issues with optional filters.
  Future<List<GitHubIssue>> listIssues({
    String? state,
    String? severity,
    String? project,
    List<String>? tags,
    String? reporter,
    bool includeAll = false,
    String? sort,
  }) async {
    // Build label filters
    final labels = <String>[
      ?state,
      if (severity != null) 'severity:$severity',
      if (project != null) 'project:$project',
      if (reporter != null) 'reporter:$reporter',
      ...?tags,
    ];

    return _client.listAllIssues(
      repoSlug: _issuesRepo,
      state: includeAll ? 'all' : 'open',
      labels: labels.isEmpty ? null : labels,
      sort: sort,
    );
  }

  /// Search issues by query text.
  Future<GitHubSearchResult> searchIssues({
    required String query,
    String repo = 'issues',
  }) {
    final targetRepo = repo == 'tests' ? _testsRepo : _issuesRepo;
    // Build search query: "query repo:owner/repo is:issue"
    final fullQuery = '$query repo:$targetRepo is:issue';
    return _client.searchIssues(query: fullQuery);
  }

  /// Close an issue.
  ///
  /// The issue must be in RESOLVED state (has 'resolved' label).
  Future<GitHubIssue> closeIssue(int issueNumber) async {
    final issue = await getIssue(issueNumber);
    
    // Verify it's in RESOLVED state
    final hasResolved = issue.labels.any((l) => l.name == 'resolved');
    if (!hasResolved) {
      throw IssueServiceException(
        'Cannot close issue #$issueNumber: must be in RESOLVED state',
        code: 'NOT_RESOLVED',
      );
    }

    return _client.closeIssue(
      repoSlug: _issuesRepo,
      number: issueNumber,
    );
  }

  /// Reopen an issue.
  ///
  /// Sets the issue state back to NEW.
  Future<GitHubIssue> reopenIssue(int issueNumber, {String? note}) async {
    // Reopen the issue
    final reopened = await _client.reopenIssue(
      repoSlug: _issuesRepo,
      number: issueNumber,
    );

    // Update labels to NEW state
    final newLabels = _updateLabels(
      current: reopened.labels.map((l) => l.name).toList(),
      newState: 'new',
    );

    final updated = await _client.updateIssue(
      repoSlug: _issuesRepo,
      number: issueNumber,
      labels: newLabels,
    );

    // Add a comment if note is provided
    if (note != null) {
      await _client.addComment(
        repoSlug: _issuesRepo,
        issueNumber: issueNumber,
        body: '**Reopened**: $note',
      );
    }

    return updated;
  }

  /// Release client resources.
  void close() => _client.close();

  // ===========================================================================
  // Private Helpers
  // ===========================================================================

  String _buildIssueBody({
    required String title,
    String? symptom,
    String? context,
    String? expected,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('## Symptom');
    buffer.writeln(symptom ?? title);
    buffer.writeln();

    if (context != null) {
      buffer.writeln('## Context');
      buffer.writeln(context);
      buffer.writeln();
    }

    if (expected != null) {
      buffer.writeln('## Expected');
      buffer.writeln(expected);
      buffer.writeln();
    }

    return buffer.toString().trim();
  }

  List<String> _updateLabels({
    required List<String> current,
    String? newSeverity,
    String? newState,
    List<String>? newTags,
    String? newProject,
  }) {
    final result = <String>[];

    // State labels (only one allowed)
    const stateLabels = ['new', 'analyzed', 'assigned', 'testing', 'verifying', 'resolved'];
    
    for (final label in current) {
      // Skip if it's a severity label and we're updating severity
      if (newSeverity != null && label.startsWith('severity:')) {
        continue;
      }
      // Skip if it's a state label and we're updating state
      if (newState != null && stateLabels.contains(label)) {
        continue;
      }
      // Skip if it's a project label and we're updating project
      if (newProject != null && label.startsWith('project:')) {
        continue;
      }
      // Skip if we're replacing all tags
      if (newTags != null && !label.startsWith('severity:') && 
          !label.startsWith('project:') && !label.startsWith('reporter:') &&
          !stateLabels.contains(label)) {
        continue;
      }
      result.add(label);
    }

    // Add new values
    if (newSeverity != null) {
      result.add('severity:$newSeverity');
    }
    if (newState != null) {
      result.add(newState);
    }
    if (newProject != null) {
      result.add('project:$newProject');
    }
    if (newTags != null) {
      result.addAll(newTags);
    }

    return result;
  }

  Future<GitHubIssue> _createTestEntry({
    required int issueNumber,
    required String title,
    required String project,
  }) {
    // Test entry ID format: PROJECT-ISSUE (e.g., D4-42)
    final testId = '$project-$issueNumber';
    
    return _client.createIssue(
      repoSlug: _testsRepo,
      title: '[$testId] $title',
      body: '''
## Test Entry

- **Issue**: #$issueNumber
- **Project**: $project
- **Status**: Stub (no dart test yet)

## Linked Tests

_No dart tests linked yet. Create a test with ID `$testId-XXX-N` to link it._
''',
      labels: ['stub', 'project:$project'],
    );
  }
}

/// Result of creating a new issue.
class CreateIssueResult {
  final GitHubIssue issue;
  final GitHubIssue? testEntry;

  const CreateIssueResult({
    required this.issue,
    this.testEntry,
  });
}

/// Exception thrown by IssueService operations.
class IssueServiceException implements Exception {
  final String message;
  final String? code;

  IssueServiceException(this.message, {this.code});

  @override
  String toString() => 'IssueServiceException: $message';
}
