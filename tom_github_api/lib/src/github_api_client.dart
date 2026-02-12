import 'dart:convert';

import 'package:http/http.dart' as http;

import 'http/github_http_client.dart';
import 'models/github_comment.dart';
import 'models/github_issue.dart';
import 'models/github_label.dart';
import 'models/github_rate_limit.dart';
import 'models/github_search_result.dart';

/// Main client for the GitHub REST API v3.
///
/// Provides typed access to Issues, Labels, Comments, Search, and
/// Workflow operations. All operations require authentication via
/// a Personal Access Token.
///
/// ```dart
/// final client = GitHubApiClient(token: 'ghp_...');
/// try {
///   final issue = await client.getIssue(
///     owner: 'al-the-bear', repo: 'tom_issues', number: 42);
///   print(issue.title);
/// } finally {
///   client.close();
/// }
/// ```
class GitHubApiClient {
  final GitHubHttpClient _http;

  GitHubApiClient({
    required String token,
    http.Client? httpClient,
    String baseUrl = 'https://api.github.com',
  }) : _http = GitHubHttpClient(
          token: token,
          httpClient: httpClient ?? http.Client(),
          baseUrl: baseUrl,
        );

  /// Rate limit info from the most recent API call.
  GitHubRateLimit? get lastRateLimit => _http.lastRateLimit;

  /// Release HTTP client resources.
  void close() => _http.close();

  // --- Helper ---

  (String, String) _parseSlug(String? repoSlug, String? owner, String? repo) {
    if (repoSlug != null) {
      final parts = repoSlug.split('/');
      if (parts.length != 2) {
        throw ArgumentError('repoSlug must be "owner/repo", got: $repoSlug');
      }
      return (parts[0], parts[1]);
    }
    if (owner != null && repo != null) return (owner, repo);
    throw ArgumentError('Either repoSlug or both owner and repo must be set');
  }

  // ===================================================================
  // ISSUE OPERATIONS
  // ===================================================================

  /// Create a new issue.
  Future<GitHubIssue> createIssue({
    String? repoSlug,
    String? owner,
    String? repo,
    required String title,
    String? body,
    List<String>? labels,
    String? assignee,
  }) async {
    final (o, r) = _parseSlug(repoSlug, owner, repo);
    final json = await _http.post(
      '/repos/$o/$r/issues',
      body: {
        'title': title,
        if (body != null) 'body': body,
        if (labels != null) 'labels': labels,
        if (assignee != null) 'assignee': assignee,
      },
    );
    return GitHubIssue.fromJson(json);
  }

  /// Get a single issue by number.
  Future<GitHubIssue> getIssue({
    String? repoSlug,
    String? owner,
    String? repo,
    required int number,
  }) async {
    final (o, r) = _parseSlug(repoSlug, owner, repo);
    final json = await _http.get('/repos/$o/$r/issues/$number');
    return GitHubIssue.fromJson(json);
  }

  /// Update an existing issue. Only non-null fields are sent.
  Future<GitHubIssue> updateIssue({
    String? repoSlug,
    String? owner,
    String? repo,
    required int number,
    String? title,
    String? body,
    String? state,
    List<String>? labels,
    String? assignee,
  }) async {
    final (o, r) = _parseSlug(repoSlug, owner, repo);
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (body != null) data['body'] = body;
    if (state != null) data['state'] = state;
    if (labels != null) data['labels'] = labels;
    if (assignee != null) data['assignee'] = assignee;

    final json = await _http.patch('/repos/$o/$r/issues/$number', body: data);
    return GitHubIssue.fromJson(json);
  }

  /// Close an issue (convenience for updateIssue with state: 'closed').
  Future<GitHubIssue> closeIssue({
    String? repoSlug,
    String? owner,
    String? repo,
    required int number,
  }) {
    return updateIssue(
      repoSlug: repoSlug,
      owner: owner,
      repo: repo,
      number: number,
      state: 'closed',
    );
  }

  /// Reopen an issue (convenience for updateIssue with state: 'open').
  Future<GitHubIssue> reopenIssue({
    String? repoSlug,
    String? owner,
    String? repo,
    required int number,
  }) {
    return updateIssue(
      repoSlug: repoSlug,
      owner: owner,
      repo: repo,
      number: number,
      state: 'open',
    );
  }

  /// List issues with optional filters. Returns a single page.
  Future<List<GitHubIssue>> listIssues({
    String? repoSlug,
    String? owner,
    String? repo,
    String? state,
    List<String>? labels,
    String? sort,
    String? direction,
    DateTime? since,
    int? perPage,
    int? page,
  }) async {
    final (o, r) = _parseSlug(repoSlug, owner, repo);
    final params = <String, String>{};
    if (state != null) params['state'] = state;
    if (labels != null && labels.isNotEmpty) {
      params['labels'] = labels.join(',');
    }
    if (sort != null) params['sort'] = sort;
    if (direction != null) params['direction'] = direction;
    if (since != null) params['since'] = since.toUtc().toIso8601String();
    if (perPage != null) params['per_page'] = perPage.toString();
    if (page != null) params['page'] = page.toString();

    final response =
        await _http.getRaw('/repos/$o/$r/issues', queryParams: params);
    final list = jsonDecode(response.body) as List<dynamic>;

    // Filter out pull requests (they have a 'pull_request' field)
    return list
        .cast<Map<String, dynamic>>()
        .where((j) => !j.containsKey('pull_request'))
        .map(GitHubIssue.fromJson)
        .toList();
  }

  /// Fetch ALL matching issues across all pages (handles pagination).
  Future<List<GitHubIssue>> listAllIssues({
    String? repoSlug,
    String? owner,
    String? repo,
    String? state,
    List<String>? labels,
    String? sort,
    String? direction,
    DateTime? since,
  }) async {
    final (o, r) = _parseSlug(repoSlug, owner, repo);
    final params = <String, String>{
      'per_page': '100',
    };
    if (state != null) params['state'] = state;
    if (labels != null && labels.isNotEmpty) {
      params['labels'] = labels.join(',');
    }
    if (sort != null) params['sort'] = sort;
    if (direction != null) params['direction'] = direction;
    if (since != null) params['since'] = since.toUtc().toIso8601String();

    final allIssues = <GitHubIssue>[];
    var response =
        await _http.getRaw('/repos/$o/$r/issues', queryParams: params);
    var list = jsonDecode(response.body) as List<dynamic>;

    allIssues.addAll(
      list
          .cast<Map<String, dynamic>>()
          .where((j) => !j.containsKey('pull_request'))
          .map(GitHubIssue.fromJson),
    );

    // Follow pagination
    var links = parseLinkHeader(response.headers['link']);
    while (links.containsKey('next')) {
      response = await _http.getUrl(links['next']!);
      list = jsonDecode(response.body) as List<dynamic>;
      allIssues.addAll(
        list
            .cast<Map<String, dynamic>>()
            .where((j) => !j.containsKey('pull_request'))
            .map(GitHubIssue.fromJson),
      );
      links = parseLinkHeader(response.headers['link']);
    }

    return allIssues;
  }

  // ===================================================================
  // LABEL OPERATIONS
  // ===================================================================

  /// Create a new label in the repository.
  Future<GitHubLabel> createLabel({
    String? repoSlug,
    String? owner,
    String? repo,
    required String name,
    required String color,
    String? description,
  }) async {
    final (o, r) = _parseSlug(repoSlug, owner, repo);
    final json = await _http.post(
      '/repos/$o/$r/labels',
      body: {
        'name': name,
        'color': color,
        if (description != null) 'description': description,
      },
    );
    return GitHubLabel.fromJson(json);
  }

  /// List all labels in the repository.
  Future<List<GitHubLabel>> listLabels({
    String? repoSlug,
    String? owner,
    String? repo,
  }) async {
    final (o, r) = _parseSlug(repoSlug, owner, repo);
    final response = await _http.getRaw(
      '/repos/$o/$r/labels',
      queryParams: {'per_page': '100'},
    );
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .cast<Map<String, dynamic>>()
        .map(GitHubLabel.fromJson)
        .toList();
  }

  /// Update an existing label.
  Future<GitHubLabel> updateLabel({
    String? repoSlug,
    String? owner,
    String? repo,
    required String name,
    String? newName,
    String? color,
    String? description,
  }) async {
    final (o, r) = _parseSlug(repoSlug, owner, repo);
    final data = <String, dynamic>{};
    if (newName != null) data['new_name'] = newName;
    if (color != null) data['color'] = color;
    if (description != null) data['description'] = description;

    final json = await _http.patch('/repos/$o/$r/labels/$name', body: data);
    return GitHubLabel.fromJson(json);
  }

  /// Delete a label from the repository.
  Future<void> deleteLabel({
    String? repoSlug,
    String? owner,
    String? repo,
    required String name,
  }) async {
    final (o, r) = _parseSlug(repoSlug, owner, repo);
    await _http.delete('/repos/$o/$r/labels/$name');
  }

  /// Add labels to an issue without removing existing ones.
  Future<List<GitHubLabel>> addLabelsToIssue({
    String? repoSlug,
    String? owner,
    String? repo,
    required int issueNumber,
    required List<String> labels,
  }) async {
    final (o, r) = _parseSlug(repoSlug, owner, repo);
    // POST /repos/{owner}/{repo}/issues/{number}/labels returns an array
    final response = await _http.postRaw(
      '/repos/$o/$r/issues/$issueNumber/labels',
      body: {'labels': labels},
    );
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .cast<Map<String, dynamic>>()
        .map(GitHubLabel.fromJson)
        .toList();
  }

  /// Remove a single label from an issue.
  Future<void> removeLabelFromIssue({
    String? repoSlug,
    String? owner,
    String? repo,
    required int issueNumber,
    required String label,
  }) async {
    final (o, r) = _parseSlug(repoSlug, owner, repo);
    await _http.delete('/repos/$o/$r/issues/$issueNumber/labels/$label');
  }

  // ===================================================================
  // COMMENT OPERATIONS
  // ===================================================================

  /// Add a comment to an issue.
  Future<GitHubComment> addComment({
    String? repoSlug,
    String? owner,
    String? repo,
    required int issueNumber,
    required String body,
  }) async {
    final (o, r) = _parseSlug(repoSlug, owner, repo);
    final json = await _http.post(
      '/repos/$o/$r/issues/$issueNumber/comments',
      body: {'body': body},
    );
    return GitHubComment.fromJson(json);
  }

  /// List comments for an issue (single page).
  Future<List<GitHubComment>> listComments({
    String? repoSlug,
    String? owner,
    String? repo,
    required int issueNumber,
    int? perPage,
    int? page,
  }) async {
    final (o, r) = _parseSlug(repoSlug, owner, repo);
    final params = <String, String>{};
    if (perPage != null) params['per_page'] = perPage.toString();
    if (page != null) params['page'] = page.toString();

    final response = await _http.getRaw(
      '/repos/$o/$r/issues/$issueNumber/comments',
      queryParams: params,
    );
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .cast<Map<String, dynamic>>()
        .map(GitHubComment.fromJson)
        .toList();
  }

  /// Fetch ALL comments for an issue across all pages.
  Future<List<GitHubComment>> listAllComments({
    String? repoSlug,
    String? owner,
    String? repo,
    required int issueNumber,
  }) async {
    final (o, r) = _parseSlug(repoSlug, owner, repo);
    final allComments = <GitHubComment>[];

    var response = await _http.getRaw(
      '/repos/$o/$r/issues/$issueNumber/comments',
      queryParams: {'per_page': '100'},
    );
    var list = jsonDecode(response.body) as List<dynamic>;
    allComments.addAll(
        list.cast<Map<String, dynamic>>().map(GitHubComment.fromJson));

    var links = parseLinkHeader(response.headers['link']);
    while (links.containsKey('next')) {
      response = await _http.getUrl(links['next']!);
      list = jsonDecode(response.body) as List<dynamic>;
      allComments.addAll(
          list.cast<Map<String, dynamic>>().map(GitHubComment.fromJson));
      links = parseLinkHeader(response.headers['link']);
    }

    return allComments;
  }

  // ===================================================================
  // SEARCH OPERATIONS
  // ===================================================================

  /// Search issues using GitHub's search syntax.
  Future<GitHubSearchResult> searchIssues({
    required String query,
    String? sort,
    String? order,
    int? perPage,
    int? page,
  }) async {
    final params = <String, String>{
      'q': query,
    };
    if (sort != null) params['sort'] = sort;
    if (order != null) params['order'] = order;
    if (perPage != null) params['per_page'] = perPage.toString();
    if (page != null) params['page'] = page.toString();

    final json = await _http.get('/search/issues', queryParams: params);
    return GitHubSearchResult.fromJson(json);
  }

  // ===================================================================
  // WORKFLOW OPERATIONS
  // ===================================================================

  /// Trigger a GitHub Actions workflow via workflow_dispatch.
  Future<void> dispatchWorkflow({
    String? repoSlug,
    String? owner,
    String? repo,
    required String workflowId,
    String ref = 'main',
    Map<String, String>? inputs,
  }) async {
    final (o, r) = _parseSlug(repoSlug, owner, repo);
    await _http.postNoContent(
      '/repos/$o/$r/actions/workflows/$workflowId/dispatches',
      body: {
        'ref': ref,
        if (inputs != null) 'inputs': inputs,
      },
    );
  }
}
