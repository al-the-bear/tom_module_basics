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

  /// Analyze an issue — record root cause and optionally assign to a project.
  ///
  /// Posts a structured analysis comment. If [project] is provided, also
  /// assigns the issue (state → ASSIGNED) and creates a stub test entry.
  /// Without [project], moves the issue to ANALYZED state.
  Future<AnalyzeResult> analyzeIssue({
    required int issueNumber,
    String? rootCause,
    String? project,
    String? module,
    String? note,
  }) async {
    // Build analysis comment
    final comment = StringBuffer('## Analysis\n\n');
    if (rootCause != null) {
      comment.writeln('**Root Cause:** $rootCause\n');
    }
    if (project != null) {
      comment.writeln('**Target Project:** $project');
      if (module != null) {
        comment.writeln('**Target Module:** $module');
      }
      comment.writeln();
    }
    if (note != null) {
      comment.writeln('**Notes:** $note\n');
    }

    // Post the analysis comment
    await _client.addComment(
      repoSlug: _issuesRepo,
      issueNumber: issueNumber,
      body: comment.toString().trim(),
    );

    // Determine target state
    final targetState = project != null ? 'assigned' : 'analyzed';

    // Get current issue and update labels
    final current = await _client.getIssue(
      repoSlug: _issuesRepo,
      number: issueNumber,
    );

    final newLabels = _updateLabels(
      current: current.labels.map((l) => l.name).toList(),
      newState: targetState,
      newProject: project,
    );

    final updated = await _client.updateIssue(
      repoSlug: _issuesRepo,
      number: issueNumber,
      labels: newLabels,
    );

    // If project provided, create stub test entry
    GitHubIssue? testEntry;
    if (project != null) {
      testEntry = await _createTestEntry(
        issueNumber: issueNumber,
        title: current.title,
        project: project,
        module: module,
      );
    }

    return AnalyzeResult(
      issue: updated,
      testEntry: testEntry,
    );
  }

  /// Assign an issue to a project.
  ///
  /// Creates a stub test entry in tom_tests and transitions the issue
  /// to ASSIGNED state with the project label.
  Future<AssignResult> assignIssue({
    required int issueNumber,
    required String project,
    String? module,
    String? assignee,
  }) async {
    // Get current issue
    final current = await _client.getIssue(
      repoSlug: _issuesRepo,
      number: issueNumber,
    );

    // Update labels to ASSIGNED state with project
    final newLabels = _updateLabels(
      current: current.labels.map((l) => l.name).toList(),
      newState: 'assigned',
      newProject: project,
    );

    final updated = await _client.updateIssue(
      repoSlug: _issuesRepo,
      number: issueNumber,
      labels: newLabels,
      assignee: assignee,
    );

    // Create stub test entry in tom_tests
    final testEntry = await _createTestEntry(
      issueNumber: issueNumber,
      title: current.title,
      project: project,
      module: module,
    );

    // Post assignment comment
    await _client.addComment(
      repoSlug: _issuesRepo,
      issueNumber: issueNumber,
      body: '**Assigned** to project `$project`'
          '${module != null ? ' (module: `$module`)' : ''}'
          '${assignee != null ? ' — assignee: @$assignee' : ''}',
    );

    return AssignResult(
      issue: updated,
      testEntry: testEntry,
    );
  }

  /// Resolve an issue — human confirmation that the fix works.
  ///
  /// The issue must be in VERIFYING state (has 'verifying' label).
  /// Transitions to RESOLVED state with optional fix description.
  Future<GitHubIssue> resolveIssue({
    required int issueNumber,
    String? fix,
    String? note,
  }) async {
    final issue = await getIssue(issueNumber);

    // Verify it's in VERIFYING state
    final hasVerifying = issue.labels.any((l) => l.name == 'verifying');
    if (!hasVerifying) {
      throw IssueServiceException(
        'Cannot resolve issue #$issueNumber: must be in VERIFYING state',
        code: 'NOT_VERIFYING',
      );
    }

    // Update labels to RESOLVED
    final newLabels = _updateLabels(
      current: issue.labels.map((l) => l.name).toList(),
      newState: 'resolved',
    );

    final updated = await _client.updateIssue(
      repoSlug: _issuesRepo,
      number: issueNumber,
      labels: newLabels,
    );

    // Post resolution comment
    final comment = StringBuffer('## Resolved\n\n');
    if (fix != null) {
      comment.writeln('**Fix:** $fix\n');
    }
    if (note != null) {
      comment.writeln('**Notes:** $note\n');
    }
    comment.writeln('Issue confirmed fixed.');

    await _client.addComment(
      repoSlug: _issuesRepo,
      issueNumber: issueNumber,
      body: comment.toString().trim(),
    );

    return updated;
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

  /// Get a summary of all issues by state, severity, and project.
  ///
  /// Returns counts aggregated from all open issues in tom_issues.
  Future<IssueSummary> getSummary() async {
    final issues = await _client.listAllIssues(
      repoSlug: _issuesRepo,
      state: 'all',
    );

    final byState = <String, int>{};
    final bySeverity = <String, int>{};
    final byProject = <String, int>{};
    var missingTests = 0;
    var awaitingVerify = 0;

    for (final issue in issues) {
      final labels = issue.labels.map((l) => l.name).toList();

      // Count by state
      const stateLabels = ['new', 'analyzed', 'assigned', 'testing', 'verifying', 'resolved'];
      for (final state in stateLabels) {
        if (labels.contains(state)) {
          byState[state] = (byState[state] ?? 0) + 1;
        }
      }

      // Count by severity
      for (final label in labels) {
        if (label.startsWith('severity:')) {
          final sev = label.replaceFirst('severity:', '');
          bySeverity[sev] = (bySeverity[sev] ?? 0) + 1;
        }
      }

      // Count by project
      for (final label in labels) {
        if (label.startsWith('project:')) {
          final proj = label.replaceFirst('project:', '');
          byProject[proj] = (byProject[proj] ?? 0) + 1;
        }
      }

      // Count attention items
      if (labels.contains('assigned') && !labels.contains('testing')) {
        missingTests++;
      }
      if (labels.contains('verifying')) {
        awaitingVerify++;
      }
    }

    return IssueSummary(
      totalCount: issues.length,
      byState: byState,
      bySeverity: bySeverity,
      byProject: byProject,
      missingTests: missingTests,
      awaitingVerify: awaitingVerify,
    );
  }

  /// Initialize labels in the issue/test repositories.
  ///
  /// Creates standard state and severity labels in tom_issues,
  /// and project/status labels in tom_tests.
  Future<InitResult> initLabels({
    String repo = 'both',
    bool force = false,
  }) async {
    var issuesCreated = 0;
    var testsCreated = 0;

    if (repo == 'issues' || repo == 'both') {
      // Create state labels in tom_issues
      const issueLabels = {
        'new': '5319e7',
        'analyzed': '0052cc',
        'assigned': '006b75',
        'testing': '1d76db',
        'verifying': '0e8a16',
        'resolved': '2cbe4e',
        'blocked': 'b60205',
        'duplicate': 'cccccc',
        'wontfix': 'cccccc',
        'severity:critical': 'd93f0b',
        'severity:high': 'e99695',
        'severity:normal': 'fef2c0',
        'severity:low': 'c5def5',
        'reporter:copilot': '5319e7',
      };

      for (final entry in issueLabels.entries) {
        try {
          await _client.createLabel(
            repoSlug: _issuesRepo,
            name: entry.key,
            color: entry.value,
          );
          issuesCreated++;
        } on Exception {
          if (force) {
            try {
              await _client.updateLabel(
                repoSlug: _issuesRepo,
                name: entry.key,
                color: entry.value,
              );
              issuesCreated++;
            } on Exception {
              // Label update failed, skip
            }
          }
        }
      }
    }

    if (repo == 'tests' || repo == 'both') {
      // Create standard test labels in tom_tests
      const testLabels = {
        'stub': 'fbca04',
        'has-tests': '0e8a16',
        'all-pass': '0e8a16',
        'some-fail': 'b60205',
      };

      for (final entry in testLabels.entries) {
        try {
          await _client.createLabel(
            repoSlug: _testsRepo,
            name: entry.key,
            color: entry.value,
          );
          testsCreated++;
        } on Exception {
          if (force) {
            try {
              await _client.updateLabel(
                repoSlug: _testsRepo,
                name: entry.key,
                color: entry.value,
              );
              testsCreated++;
            } on Exception {
              // Label update failed, skip
            }
          }
        }
      }
    }

    return InitResult(
      issuesLabelsCreated: issuesCreated,
      testsLabelsCreated: testsCreated,
    );
  }

  /// Explicitly link a test to an issue via a comment.
  ///
  /// Posts a structured comment on the issue with the test link info.
  Future<GitHubComment> linkTest({
    required int issueNumber,
    required String testId,
    String? testFile,
    String? note,
  }) async {
    final comment = StringBuffer('## Test Link\n\n');
    comment.writeln('**Test ID:** `$testId`');
    if (testFile != null) {
      comment.writeln('**File:** `$testFile`');
    }
    if (note != null) {
      comment.writeln('**Note:** $note');
    }

    return _client.addComment(
      repoSlug: _issuesRepo,
      issueNumber: issueNumber,
      body: comment.toString().trim(),
    );
  }

  /// Export issues from the specified repository.
  ///
  /// Returns all issues matching the given filters.
  Future<List<GitHubIssue>> exportIssues({
    String repo = 'issues',
    String? state,
    String? severity,
    String? project,
    List<String>? tags,
    bool includeAll = false,
  }) {
    final targetRepo = repo == 'tests' ? _testsRepo : _issuesRepo;
    final labels = <String>[
      ?state,
      if (severity != null) 'severity:$severity',
      if (project != null) 'project:$project',
      ...?tags,
    ];

    return _client.listAllIssues(
      repoSlug: targetRepo,
      state: includeAll ? 'all' : 'open',
      labels: labels.isEmpty ? null : labels,
    );
  }

  /// Import issues from parsed data.
  ///
  /// Creates issues in bulk from a list of maps with title, body, labels.
  Future<List<GitHubIssue>> importIssues({
    required List<Map<String, dynamic>> entries,
    String repo = 'issues',
    bool dryRun = false,
  }) async {
    if (dryRun) return [];
    final targetRepo = repo == 'tests' ? _testsRepo : _issuesRepo;
    final created = <GitHubIssue>[];

    for (final entry in entries) {
      final issue = await _client.createIssue(
        repoSlug: targetRepo,
        title: entry['title'] as String,
        body: entry['body'] as String?,
        labels: (entry['labels'] as List<dynamic>?)?.cast<String>(),
      );
      created.add(issue);
    }

    return created;
  }

  /// Create a snapshot of all issues and/or tests.
  ///
  /// Returns maps suitable for JSON serialization.
  Future<SnapshotResult> createSnapshot({
    bool issuesOnly = false,
    bool testsOnly = false,
  }) async {
    List<GitHubIssue>? issues;
    List<GitHubIssue>? tests;

    if (!testsOnly) {
      issues = await _client.listAllIssues(
        repoSlug: _issuesRepo,
        state: 'all',
      );
    }

    if (!issuesOnly) {
      tests = await _client.listAllIssues(
        repoSlug: _testsRepo,
        state: 'all',
      );
    }

    return SnapshotResult(
      issues: issues,
      tests: tests,
      snapshotDate: DateTime.now(),
    );
  }

  /// Trigger the nightly test workflow via GitHub Actions.
  Future<void> triggerTestWorkflow({bool wait = false}) async {
    await _client.dispatchWorkflow(
      repoSlug: _testsRepo,
      workflowId: 'nightly_tests.yml',
      ref: 'main',
    );
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
    String? module,
  }) {
    // Test entry ID format: PROJECT-ISSUE (e.g., D4-42)
    final testId = '$project-$issueNumber';
    final labels = <String>[
      'stub',
      'project:$project',
      if (module != null) 'module:$module',
    ];
    
    return _client.createIssue(
      repoSlug: _testsRepo,
      title: '[$testId] $title',
      body: '''
## Test Entry

- **Issue**: #$issueNumber
- **Project**: $project
${module != null ? '- **Module**: $module\n' : ''}- **Status**: Stub (no dart test yet)

## Linked Tests

_No dart tests linked yet. Create a test with ID `$testId-XXX-N` to link it._
''',
      labels: labels,
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

/// Result of analyzing an issue.
class AnalyzeResult {
  final GitHubIssue issue;
  final GitHubIssue? testEntry;

  const AnalyzeResult({
    required this.issue,
    this.testEntry,
  });
}

/// Result of assigning an issue.
class AssignResult {
  final GitHubIssue issue;
  final GitHubIssue testEntry;

  const AssignResult({
    required this.issue,
    required this.testEntry,
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

/// Summary of issues aggregated by state, severity, and project.
class IssueSummary {
  final int totalCount;
  final Map<String, int> byState;
  final Map<String, int> bySeverity;
  final Map<String, int> byProject;
  final int missingTests;
  final int awaitingVerify;

  const IssueSummary({
    required this.totalCount,
    required this.byState,
    required this.bySeverity,
    required this.byProject,
    required this.missingTests,
    required this.awaitingVerify,
  });
}

/// Result of initializing labels.
class InitResult {
  final int issuesLabelsCreated;
  final int testsLabelsCreated;

  const InitResult({
    required this.issuesLabelsCreated,
    required this.testsLabelsCreated,
  });

  int get totalCreated => issuesLabelsCreated + testsLabelsCreated;
}

/// Result of creating a snapshot.
class SnapshotResult {
  final List<GitHubIssue>? issues;
  final List<GitHubIssue>? tests;
  final DateTime snapshotDate;

  const SnapshotResult({
    this.issues,
    this.tests,
    required this.snapshotDate,
  });
}
