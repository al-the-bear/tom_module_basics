/// Issuekit v2 command executors.
///
/// These executors implement the issuekit commands using the v2 ToolRunner
/// framework. Core commands (:new, :edit, :show, :list, :search, :close,
/// :reopen) are wired to [IssueService]. Remaining commands are stubs.
library;

import 'dart:convert';
import 'dart:io';

import 'package:tom_build_base/tom_build_base_v2.dart';

import '../services/issue_service.dart';
import '../services/test_scanner.dart';

// =============================================================================
// Helper Functions
// =============================================================================

/// Parse an issue number from the first positional argument.
///
/// Returns null if the arg is missing or not a valid integer.
int? _parseIssueNumber(CliArgs args) {
  if (args.positionalArgs.isEmpty) return null;
  return int.tryParse(args.positionalArgs.first);
}

/// Split a comma-separated option value into a list of trimmed strings.
List<String> _splitTags(String? value) {
  if (value == null || value.isEmpty) return [];
  return value
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Parse an import file (JSON format) into a list of entry maps.
///
/// Expected format: JSON array of objects with 'title', 'body', 'labels' fields.
/// Falls back to treating each non-empty line as a title if JSON parsing fails.
List<Map<String, dynamic>> _parseImportFile(String content) {
  try {
    final decoded = jsonDecode(content);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    return [];
  } on FormatException {
    // Fall back to line-based parsing (each line = a title)
    return content
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) => <String, dynamic>{'title': l})
        .toList();
  }
}

// =============================================================================
// Issue Management Executors
// =============================================================================

/// Executor for :new command.
///
/// Creates a new issue in tom_issues via IssueService.
/// Title is the first positional arg. Options: --severity, --context,
/// --expected, --symptom, --tags, --project, --reporter.
class NewIssueExecutor extends CommandExecutor {
  final IssueService service;

  NewIssueExecutor(this.service);

  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return ItemResult.failure(
      path: context.path,
      name: context.name,
      error: ':new is a non-traversal command',
    );
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    // Title is the first positional argument
    if (args.positionalArgs.isEmpty) {
      return const ToolResult.failure('Missing required argument: title');
    }
    final title = args.positionalArgs.first;
    final opts = args.extraOptions;

    if (args.dryRun) {
      final severity = opts['severity'] as String? ?? 'normal';
      final project = opts['project'] as String? ?? '(none)';
      return ToolResult(
        success: true,
        processedCount: 0,
        itemResults: [
          ItemResult.success(
            path: 'tom_issues',
            name: ':new',
            message:
                '[DRY RUN] Would create issue: "$title" '
                '(severity: $severity, project: $project)',
          ),
        ],
      );
    }

    try {
      final result = await service.createIssue(
        title: title,
        severity: opts['severity'] as String? ?? 'normal',
        context: opts['context'] as String?,
        expected: opts['expected'] as String?,
        symptom: opts['symptom'] as String?,
        tags: _splitTags(opts['tags'] as String?),
        project: opts['project'] as String?,
        reporter: opts['reporter'] as String?,
      );

      final issue = result.issue;
      final msg = StringBuffer(
        'Created issue #${issue.number}: ${issue.title}',
      );
      if (result.testEntry != null) {
        msg.write('\nTest entry created: #${result.testEntry!.number}');
      }

      return ToolResult(
        success: true,
        processedCount: 1,
        itemResults: [
          ItemResult.success(
            path: 'tom_issues',
            name: '#${issue.number}',
            message: msg.toString(),
          ),
        ],
      );
    } on IssueServiceException catch (e) {
      return ToolResult.failure(e.message);
    } on Exception catch (e) {
      return ToolResult.failure('Failed to create issue: $e');
    }
  }
}

/// Executor for :edit command.
///
/// Updates an existing issue's fields via IssueService.
/// Issue number is the first positional arg. Options: --title, --severity,
/// --context, --expected, --symptom, --tags, --project, --assignee.
class EditIssueExecutor extends CommandExecutor {
  final IssueService service;

  EditIssueExecutor(this.service);

  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return ItemResult.failure(
      path: context.path,
      name: context.name,
      error: ':edit is a non-traversal command',
    );
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    final issueNumber = _parseIssueNumber(args);
    if (issueNumber == null) {
      return const ToolResult.failure(
        'Missing required argument: issue number',
      );
    }
    final opts = args.extraOptions;

    if (args.dryRun) {
      final fields = <String>[];
      if (opts['title'] != null) fields.add('title');
      if (opts['severity'] != null) fields.add('severity');
      if (opts['context'] != null) fields.add('context');
      if (opts['tags'] != null) fields.add('tags');
      if (opts['project'] != null) fields.add('project');
      if (opts['assignee'] != null) fields.add('assignee');
      return ToolResult(
        success: true,
        processedCount: 0,
        itemResults: [
          ItemResult.success(
            path: 'tom_issues',
            name: '#$issueNumber',
            message:
                '[DRY RUN] Would update issue #$issueNumber '
                'fields: ${fields.isEmpty ? '(none)' : fields.join(', ')}',
          ),
        ],
      );
    }

    try {
      final updated = await service.updateIssue(
        issueNumber: issueNumber,
        title: opts['title'] as String?,
        severity: opts['severity'] as String?,
        context: opts['context'] as String?,
        expected: opts['expected'] as String?,
        symptom: opts['symptom'] as String?,
        tags: opts.containsKey('tags')
            ? _splitTags(opts['tags'] as String?)
            : null,
        project: opts['project'] as String?,
        assignee: opts['assignee'] as String?,
      );

      return ToolResult(
        success: true,
        processedCount: 1,
        itemResults: [
          ItemResult.success(
            path: 'tom_issues',
            name: '#${updated.number}',
            message: 'Updated issue #${updated.number}: ${updated.title}',
          ),
        ],
      );
    } on IssueServiceException catch (e) {
      return ToolResult.failure(e.message);
    } on Exception catch (e) {
      return ToolResult.failure('Failed to update issue: $e');
    }
  }
}

/// Executor for :analyze command.
///
/// Records analysis findings for an issue. If --project is provided, also
/// assigns the issue and creates a stub test entry.
/// Issue number is the first positional arg. Options: --root-cause, --project,
/// --module, --note.
class AnalyzeExecutor extends CommandExecutor {
  final IssueService service;

  AnalyzeExecutor(this.service);

  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return ItemResult.failure(
      path: context.path,
      name: context.name,
      error: ':analyze is a non-traversal command',
    );
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    final issueNumber = _parseIssueNumber(args);
    if (issueNumber == null) {
      return const ToolResult.failure(
        'Missing required argument: issue number',
      );
    }
    final opts = args.extraOptions;

    if (args.dryRun) {
      final project = opts['project'] as String?;
      return ToolResult(
        success: true,
        processedCount: 0,
        itemResults: [
          ItemResult.success(
            path: 'tom_issues',
            name: '#$issueNumber',
            message:
                '[DRY RUN] Would analyze issue #$issueNumber'
                '${project != null ? ' and assign to $project' : ''}',
          ),
        ],
      );
    }

    try {
      final result = await service.analyzeIssue(
        issueNumber: issueNumber,
        rootCause: opts['root-cause'] as String?,
        project: opts['project'] as String?,
        module: opts['module'] as String?,
        note: opts['note'] as String?,
      );

      final issue = result.issue;
      final state = result.testEntry != null ? 'ASSIGNED' : 'ANALYZED';
      final msg = StringBuffer(
        'Analyzed issue #${issue.number}: ${issue.title} → $state',
      );
      if (result.testEntry != null) {
        msg.write('\nTest entry created: #${result.testEntry!.number}');
      }

      return ToolResult(
        success: true,
        processedCount: 1,
        itemResults: [
          ItemResult.success(
            path: 'tom_issues',
            name: '#${issue.number}',
            message: msg.toString(),
          ),
        ],
      );
    } on IssueServiceException catch (e) {
      return ToolResult.failure(e.message);
    } on Exception catch (e) {
      return ToolResult.failure('Failed to analyze issue: $e');
    }
  }
}

/// Executor for :assign command.
///
/// Assigns an issue to a project and creates a stub test entry.
/// Issue number is the first positional arg. Options: --project (required),
/// --module, --assignee.
class AssignExecutor extends CommandExecutor {
  final IssueService service;

  AssignExecutor(this.service);

  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return ItemResult.failure(
      path: context.path,
      name: context.name,
      error: ':assign is a non-traversal command',
    );
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    final issueNumber = _parseIssueNumber(args);
    if (issueNumber == null) {
      return const ToolResult.failure(
        'Missing required argument: issue number',
      );
    }
    final opts = args.extraOptions;
    final project = opts['project'] as String?;
    if (project == null) {
      return const ToolResult.failure('Missing required option: --project');
    }

    if (args.dryRun) {
      return ToolResult(
        success: true,
        processedCount: 0,
        itemResults: [
          ItemResult.success(
            path: 'tom_issues',
            name: '#$issueNumber',
            message:
                '[DRY RUN] Would assign issue #$issueNumber '
                'to project $project',
          ),
        ],
      );
    }

    try {
      final result = await service.assignIssue(
        issueNumber: issueNumber,
        project: project,
        module: opts['module'] as String?,
        assignee: opts['assignee'] as String?,
      );

      return ToolResult(
        success: true,
        processedCount: 1,
        itemResults: [
          ItemResult.success(
            path: 'tom_issues',
            name: '#${result.issue.number}',
            message:
                'Assigned issue #${result.issue.number} to project $project\n'
                'Test entry created: #${result.testEntry.number}',
          ),
        ],
      );
    } on IssueServiceException catch (e) {
      return ToolResult.failure(e.message);
    } on Exception catch (e) {
      return ToolResult.failure('Failed to assign issue: $e');
    }
  }
}

/// Executor for :testing command.
///
/// Scans the project's test directory for full test IDs matching an issue.
/// Per spec, only **full** test IDs (with project-specific part) are accepted
/// — stubs like `D4-42` are reported separately. The issue number is the
/// first positional arg.
class TestingExecutor extends CommandExecutor {
  final TestScanner scanner;
  final IssueService service;

  TestingExecutor(this.scanner, this.service);

  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    final issueNumber = _parseIssueNumber(args);
    if (issueNumber == null) {
      return ItemResult.failure(
        path: context.path,
        name: context.name,
        error: 'Missing required argument: issue number',
      );
    }

    final matches = scanner.scanForIssue(context.path, issueNumber);
    if (matches.isEmpty) {
      return ItemResult.success(
        path: context.path,
        name: context.name,
        message: 'No tests for issue #$issueNumber',
      );
    }

    // Per spec: only full test IDs count (not stubs)
    final fullTests = matches.where((m) => !m.isStub).toList();
    final stubs = matches.where((m) => m.isStub).toList();

    if (fullTests.isEmpty) {
      final stubIds = stubs.map((m) => m.testId).join(', ');
      return ItemResult.failure(
        path: context.path,
        name: context.name,
        error:
            'Only stub(s) found for #$issueNumber: $stubIds '
            '— create a full dart test with project-specific ID',
      );
    }

    final ids = fullTests.map((m) => m.testId).join(', ');
    final stubNote = stubs.isNotEmpty
        ? ' (${stubs.length} stub(s) also present)'
        : '';

    // Per spec: update issue labels to TESTING and test entry to has-tests
    if (!args.dryRun) {
      try {
        await service.updateIssue(issueNumber: issueNumber, tags: ['testing']);
      } on Exception {
        // API call may fail — scan result is still valid
      }
    }

    return ItemResult.success(
      path: context.path,
      name: context.name,
      message:
          'Found ${fullTests.length} full test(s) for #$issueNumber: '
          '$ids$stubNote',
    );
  }
}

/// Executor for :verify command.
///
/// Checks whether all reproduction tests for an issue now pass by reading
/// testkit baselines. Reports per-project test status.
class VerifyExecutor extends CommandExecutor {
  final TestScanner scanner;
  final IssueService service;

  VerifyExecutor(this.scanner, this.service);

  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    final issueNumber = _parseIssueNumber(args);
    if (issueNumber == null) {
      return ItemResult.failure(
        path: context.path,
        name: context.name,
        error: 'Missing required argument: issue number',
      );
    }

    final matches = scanner.scanForIssue(context.path, issueNumber);
    if (matches.isEmpty) {
      return ItemResult.success(
        path: context.path,
        name: context.name,
        message: 'No tests for issue #$issueNumber',
      );
    }

    // Read baseline and check status
    final baselineContent = scanner.readLatestBaseline(context.path);
    if (baselineContent == null) {
      return ItemResult.failure(
        path: context.path,
        name: context.name,
        error: 'No testkit baseline found — run testkit :test first',
      );
    }

    final statuses = scanner.parseBaseline(baselineContent);
    final results = <String>[];
    var allPass = true;

    for (final match in matches) {
      final status = statuses[match.testId];
      if (status == null) {
        results.add('${match.testId}: NOT RUN');
        allPass = false;
      } else if (status.startsWith('OK')) {
        results.add('${match.testId}: OK');
      } else {
        results.add('${match.testId}: $status');
        allPass = false;
      }
    }

    final statusLine = allPass ? 'ALL PASS' : 'SOME FAIL';

    // Per spec: if all pass, update issue to VERIFYING and test entry to all-pass
    if (allPass && !args.dryRun) {
      try {
        await service.updateIssue(
          issueNumber: issueNumber,
          tags: ['verifying'],
        );
      } on Exception {
        // API call may fail — verification result is still valid
      }
    }

    return ItemResult(
      path: context.path,
      name: context.name,
      success: allPass,
      message: '$statusLine — ${results.join(', ')}',
    );
  }
}

/// Executor for :resolve command.
///
/// Confirms that a fix addresses the original issue (human verification).
/// Issue number is the first positional arg. Options: --fix, --note.
class ResolveExecutor extends CommandExecutor {
  final IssueService service;

  ResolveExecutor(this.service);

  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return ItemResult.failure(
      path: context.path,
      name: context.name,
      error: ':resolve is a non-traversal command',
    );
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    final issueNumber = _parseIssueNumber(args);
    if (issueNumber == null) {
      return const ToolResult.failure(
        'Missing required argument: issue number',
      );
    }
    final opts = args.extraOptions;

    if (args.dryRun) {
      return ToolResult(
        success: true,
        processedCount: 0,
        itemResults: [
          ItemResult.success(
            path: 'tom_issues',
            name: '#$issueNumber',
            message: '[DRY RUN] Would resolve issue #$issueNumber',
          ),
        ],
      );
    }

    try {
      final resolved = await service.resolveIssue(
        issueNumber: issueNumber,
        fix: opts['fix'] as String?,
        note: opts['note'] as String?,
      );

      return ToolResult(
        success: true,
        processedCount: 1,
        itemResults: [
          ItemResult.success(
            path: 'tom_issues',
            name: '#${resolved.number}',
            message:
                'Resolved issue #${resolved.number}: ${resolved.title} → RESOLVED',
          ),
        ],
      );
    } on IssueServiceException catch (e) {
      return ToolResult.failure(e.message);
    } on Exception catch (e) {
      return ToolResult.failure('Failed to resolve issue: $e');
    }
  }
}

/// Executor for :close command.
///
/// Closes a resolved issue via IssueService.
/// Issue number is the first positional arg.
class CloseExecutor extends CommandExecutor {
  final IssueService service;

  CloseExecutor(this.service);

  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return ItemResult.failure(
      path: context.path,
      name: context.name,
      error: ':close is a non-traversal command',
    );
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    final issueNumber = _parseIssueNumber(args);
    if (issueNumber == null) {
      return const ToolResult.failure(
        'Missing required argument: issue number',
      );
    }

    if (args.dryRun) {
      return ToolResult(
        success: true,
        processedCount: 0,
        itemResults: [
          ItemResult.success(
            path: 'tom_issues',
            name: '#$issueNumber',
            message: '[DRY RUN] Would close issue #$issueNumber',
          ),
        ],
      );
    }

    try {
      final closed = await service.closeIssue(issueNumber);
      return ToolResult(
        success: true,
        processedCount: 1,
        itemResults: [
          ItemResult.success(
            path: 'tom_issues',
            name: '#${closed.number}',
            message: 'Closed issue #${closed.number}: ${closed.title}',
          ),
        ],
      );
    } on IssueServiceException catch (e) {
      return ToolResult.failure(e.message);
    } on Exception catch (e) {
      return ToolResult.failure('Failed to close issue: $e');
    }
  }
}

/// Executor for :reopen command.
///
/// Reopens a closed or resolved issue via IssueService.
/// Issue number is the first positional arg. Options: --note.
class ReopenExecutor extends CommandExecutor {
  final IssueService service;

  ReopenExecutor(this.service);

  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return ItemResult.failure(
      path: context.path,
      name: context.name,
      error: ':reopen is a non-traversal command',
    );
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    final issueNumber = _parseIssueNumber(args);
    if (issueNumber == null) {
      return const ToolResult.failure(
        'Missing required argument: issue number',
      );
    }

    if (args.dryRun) {
      return ToolResult(
        success: true,
        processedCount: 0,
        itemResults: [
          ItemResult.success(
            path: 'tom_issues',
            name: '#$issueNumber',
            message: '[DRY RUN] Would reopen issue #$issueNumber',
          ),
        ],
      );
    }

    try {
      final reopened = await service.reopenIssue(
        issueNumber,
        note: args.extraOptions['note'] as String?,
      );
      return ToolResult(
        success: true,
        processedCount: 1,
        itemResults: [
          ItemResult.success(
            path: 'tom_issues',
            name: '#${reopened.number}',
            message: 'Reopened issue #${reopened.number}: ${reopened.title}',
          ),
        ],
      );
    } on IssueServiceException catch (e) {
      return ToolResult.failure(e.message);
    } on Exception catch (e) {
      return ToolResult.failure('Failed to reopen issue: $e');
    }
  }
}

// =============================================================================
// Discovery and Querying Executors
// =============================================================================

/// Executor for :list command.
///
/// Lists issues with optional filters via IssueService.
/// Options: --state, --severity, --project, --tags, --reporter,
/// --all, --sort, --repo.
class ListExecutor extends CommandExecutor {
  final IssueService service;

  ListExecutor(this.service);

  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return ItemResult.failure(
      path: context.path,
      name: context.name,
      error: ':list is a non-traversal command',
    );
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    final opts = args.extraOptions;

    try {
      final issues = await service.listIssues(
        state: opts['state'] as String?,
        severity: opts['severity'] as String?,
        project: opts['project'] as String?,
        tags: opts.containsKey('tags')
            ? _splitTags(opts['tags'] as String?)
            : null,
        reporter: opts['reporter'] as String?,
        includeAll: opts['all'] == true,
        sort: opts['sort'] as String?,
      );

      final items = issues.map((issue) {
        final stateLabel =
            issue.labels
                .map((l) => l.name)
                .where(
                  (n) => const [
                    'new',
                    'analyzed',
                    'assigned',
                    'testing',
                    'verifying',
                    'resolved',
                  ].contains(n),
                )
                .firstOrNull ??
            '';
        final severityLabel =
            issue.labels
                .map((l) => l.name)
                .where((n) => n.startsWith('severity:'))
                .firstOrNull ??
            '';
        final projectLabel =
            issue.labels
                .map((l) => l.name)
                .where((n) => n.startsWith('project:'))
                .firstOrNull ??
            '';

        return ItemResult.success(
          path: 'tom_issues',
          name: '#${issue.number}',
          message:
              '#${issue.number}  '
              '[${severityLabel.replaceFirst('severity:', '').toUpperCase()}]  '
              '${projectLabel.replaceFirst('project:', '')}  '
              '${stateLabel.toUpperCase()}  '
              '${issue.title}',
        );
      }).toList();

      return ToolResult(
        success: true,
        processedCount: issues.length,
        itemResults: items,
      );
    } on IssueServiceException catch (e) {
      return ToolResult.failure(e.message);
    } on Exception catch (e) {
      return ToolResult.failure('Failed to list issues: $e');
    }
  }
}

/// Executor for :show command.
///
/// Shows full details of a single issue via IssueService.
/// Issue number is the first positional arg.
class ShowExecutor extends CommandExecutor {
  final IssueService service;
  final TestScanner scanner;

  ShowExecutor(this.service, this.scanner);

  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    // Per spec: when called with traversal, scan workspace for linked tests
    // and include test file locations and baseline status.
    final issueNumber = _parseIssueNumber(args);
    if (issueNumber == null) {
      return ItemResult.failure(
        path: context.path,
        name: context.name,
        error: 'Missing required argument: issue number',
      );
    }

    final matches = scanner.scanForIssue(context.path, issueNumber);
    if (matches.isEmpty) {
      return ItemResult.success(
        path: context.path,
        name: context.name,
        message: 'No tests for issue #$issueNumber in this project',
      );
    }

    // Read baseline for status info
    final baselineContent = scanner.readLatestBaseline(context.path);
    final statuses = baselineContent != null
        ? scanner.parseBaseline(baselineContent)
        : <String, String>{};

    final lines = matches
        .map((m) {
          final file = m.filePath.replaceFirst('${context.path}/', '');
          final status = statuses[m.testId] ?? 'NOT RUN';
          return '${m.testId.padRight(16)} ${status.padRight(8)} $file:${m.line}';
        })
        .join('\n');

    return ItemResult.success(
      path: context.path,
      name: context.name,
      message: 'Issue #$issueNumber tests in project:\n$lines',
    );
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    final issueNumber = _parseIssueNumber(args);
    if (issueNumber == null) {
      return const ToolResult.failure(
        'Missing required argument: issue number',
      );
    }

    try {
      final issue = await service.getIssue(issueNumber);

      final labels = issue.labels.map((l) => l.name).join(', ');
      final body = issue.body ?? '(no description)';
      final assignee = issue.assignee?.login ?? 'unassigned';

      final detail = StringBuffer()
        ..writeln('Issue #${issue.number}: ${issue.title}')
        ..writeln('State: ${issue.state}')
        ..writeln('Labels: $labels')
        ..writeln('Assignee: $assignee')
        ..writeln('Created: ${issue.createdAt}')
        ..writeln('Updated: ${issue.updatedAt}')
        ..writeln()
        ..writeln(body);

      return ToolResult(
        success: true,
        processedCount: 1,
        itemResults: [
          ItemResult.success(
            path: 'tom_issues',
            name: '#${issue.number}',
            message: detail.toString(),
          ),
        ],
      );
    } on IssueServiceException catch (e) {
      return ToolResult.failure(e.message);
    } on Exception catch (e) {
      return ToolResult.failure('Failed to show issue: $e');
    }
  }
}

/// Executor for :search command.
///
/// Full-text search across issues via IssueService.
/// Query text is the first positional arg. Options: --repo.
class SearchExecutor extends CommandExecutor {
  final IssueService service;

  SearchExecutor(this.service);

  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return ItemResult.failure(
      path: context.path,
      name: context.name,
      error: ':search is a non-traversal command',
    );
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    if (args.positionalArgs.isEmpty) {
      return const ToolResult.failure('Missing required argument: query');
    }
    final query = args.positionalArgs.first;
    final repo = args.extraOptions['repo'] as String? ?? 'issues';

    try {
      final result = await service.searchIssues(query: query, repo: repo);

      final items = result.items.map((issue) {
        return ItemResult.success(
          path: 'tom_issues',
          name: '#${issue.number}',
          message: '#${issue.number}: ${issue.title}',
        );
      }).toList();

      return ToolResult(
        success: true,
        processedCount: result.totalCount,
        itemResults: items,
      );
    } on IssueServiceException catch (e) {
      return ToolResult.failure(e.message);
    } on Exception catch (e) {
      return ToolResult.failure('Failed to search issues: $e');
    }
  }
}

/// Executor for :scan command.
///
/// Scans the project's test directory for issue-linked test IDs.
/// Optionally filters to a specific issue number or reports stubs only.
class ScanExecutor extends CommandExecutor {
  final TestScanner scanner;

  ScanExecutor(this.scanner);

  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    final issueNumber = _parseIssueNumber(args);
    final opts = args.extraOptions;
    final missingTests = opts['missing-tests'] == true;

    List<TestIdMatch> matches;
    if (issueNumber != null) {
      matches = scanner.scanForIssue(context.path, issueNumber);
    } else {
      matches = scanner
          .scanProject(context.path)
          .where((m) => m.isIssueLinked)
          .toList();
    }

    if (missingTests) {
      // Only report issue-linked stubs (no full test ID found)
      matches = matches.where((m) => m.isStub).toList();
    }

    if (matches.isEmpty) {
      return ItemResult.success(
        path: context.path,
        name: context.name,
        message: issueNumber != null
            ? 'No tests for issue #$issueNumber'
            : 'No issue-linked tests found',
      );
    }

    final lines = matches
        .map((m) {
          final file = m.filePath.replaceFirst('${context.path}/', '');
          return '${m.testId.padRight(16)} $file:${m.line}';
        })
        .join('\n');

    return ItemResult.success(
      path: context.path,
      name: context.name,
      message: 'Found ${matches.length} test(s):\n$lines',
    );
  }
}

/// Executor for :summary command.
///
/// Displays a dashboard overview of all issues aggregated by state,
/// severity, and project.
class SummaryExecutor extends CommandExecutor {
  final IssueService service;

  SummaryExecutor(this.service);

  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return ItemResult.failure(
      path: context.path,
      name: context.name,
      error: ':summary is a non-traversal command',
    );
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    try {
      final summary = await service.getSummary();

      final msg = StringBuffer('Issue Tracking Summary\n')
        ..writeln('=' * 22)
        ..writeln()
        ..writeln('Total: ${summary.totalCount} issues')
        ..writeln();

      if (summary.byState.isNotEmpty) {
        msg.writeln('By State:');
        for (final entry in summary.byState.entries) {
          msg.writeln(
            '  ${entry.key.toUpperCase().padRight(14)} ${entry.value}',
          );
        }
        msg.writeln();
      }

      if (summary.bySeverity.isNotEmpty) {
        msg.writeln('By Severity:');
        for (final entry in summary.bySeverity.entries) {
          msg.writeln(
            '  ${entry.key.toUpperCase().padRight(14)} ${entry.value}',
          );
        }
        msg.writeln();
      }

      if (summary.byProject.isNotEmpty) {
        msg.writeln('By Project:');
        for (final entry in summary.byProject.entries) {
          msg.writeln('  ${entry.key.padRight(14)} ${entry.value}');
        }
        msg.writeln();
      }

      if (summary.missingTests > 0 || summary.awaitingVerify > 0) {
        msg.writeln('Attention:');
        if (summary.missingTests > 0) {
          msg.writeln('  Missing tests:       ${summary.missingTests}');
        }
        if (summary.awaitingVerify > 0) {
          msg.writeln('  Awaiting verify:     ${summary.awaitingVerify}');
        }
      }

      return ToolResult(
        success: true,
        processedCount: summary.totalCount,
        itemResults: [
          ItemResult.success(
            path: 'tom_issues',
            name: 'summary',
            message: msg.toString(),
          ),
        ],
      );
    } on Exception catch (e) {
      return ToolResult.failure('Failed to get summary: $e');
    }
  }
}

// =============================================================================
// Test Management Executors
// =============================================================================

/// Executor for :promote command.
///
/// Promotes a regular test to an issue-linked test by inserting the issue
/// number into the test ID. The first positional arg is the current test ID,
/// --issue is the issue number.
class PromoteExecutor extends CommandExecutor {
  final TestScanner scanner;

  PromoteExecutor(this.scanner);

  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    if (args.positionalArgs.isEmpty) {
      return ItemResult.failure(
        path: context.path,
        name: context.name,
        error: 'Missing required argument: test-id',
      );
    }
    final testId = args.positionalArgs.first;
    final issueNumber = args.extraOptions['issue'] as int?;
    if (issueNumber == null) {
      return ItemResult.failure(
        path: context.path,
        name: context.name,
        error: 'Missing required option: --issue',
      );
    }
    final dryRun = args.dryRun;

    // Search for the test ID in this project
    final allTests = scanner.scanProject(context.path);
    final match = allTests.where((m) => m.testId == testId).toList();

    if (match.isEmpty) {
      return ItemResult.success(
        path: context.path,
        name: context.name,
        message: 'Test $testId not found in project',
      );
    }

    // Build new ID: insert issue number after project ID
    // D4-PAR-15 → D4-42-PAR-15
    final m = match.first;
    final newId = '${m.projectId}-$issueNumber-${m.projectSpecific}';

    if (dryRun) {
      return ItemResult.success(
        path: context.path,
        name: context.name,
        message: 'Would rename $testId → $newId in ${m.filePath}:${m.line}',
      );
    }

    // Apply the rename in the source file
    final file = File(m.filePath);
    final content = file.readAsStringSync();
    final updated = content.replaceAll(testId, newId);
    file.writeAsStringSync(updated);

    return ItemResult.success(
      path: context.path,
      name: context.name,
      message: 'Promoted $testId → $newId in ${m.filePath}:${m.line}',
    );
  }
}

/// Executor for :validate command.
///
/// Checks test ID uniqueness within a project: no duplicate project-specific
/// IDs, no regular+promoted conflicts, and that all issue numbers in test IDs
/// reference existing issues in tom_issues.
///
/// With --fix option, automatically removes regular IDs when a promoted version
/// exists (e.g., removes D4-PAR-15 when D4-42-PAR-15 exists).
class ValidateExecutor extends CommandExecutor {
  final TestScanner scanner;
  final IssueService service;

  ValidateExecutor(this.scanner, this.service);

  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    final allTests = scanner.scanProject(context.path);
    if (allTests.isEmpty) {
      return ItemResult.success(
        path: context.path,
        name: context.name,
        message: 'No tests found',
      );
    }

    final fix = args.extraOptions['fix'] == true;
    final dryRun = args.dryRun;
    final errors = <String>[];
    final warnings = <String>[];
    final fixed = <String>[];

    // Identify regular + promoted conflicts first (for Check 2)
    // These should not be reported as duplicates in Check 1 when --fix is used
    final regularIds = allTests.where((t) => !t.isIssueLinked).toList();
    final issueLinkedIds = allTests.where((t) => t.isIssueLinked).toSet();
    final conflictPairs = <String, (TestIdMatch, TestIdMatch)>{};

    for (final regular in regularIds) {
      for (final linked in issueLinkedIds) {
        if (regular.projectId == linked.projectId &&
            regular.projectSpecific == linked.projectSpecific) {
          final key = '${regular.projectId}-${regular.projectSpecific}';
          conflictPairs[key] = (regular, linked);
        }
      }
    }

    // Check 1: Duplicate project-specific IDs within a project
    // Skip pairs that are regular+promoted conflicts (handled in Check 2)
    final byProjectSpecific = <String, List<TestIdMatch>>{};
    for (final test in allTests) {
      final key = '${test.projectId}-${test.projectSpecific}';
      byProjectSpecific.putIfAbsent(key, () => []).add(test);
    }
    for (final entry in byProjectSpecific.entries) {
      if (entry.value.length > 1) {
        // Skip if this is a regular+promoted conflict pair (handled in Check 2)
        if (conflictPairs.containsKey(entry.key) && entry.value.length == 2) {
          continue;
        }
        final locations = entry.value
            .map((m) => '${m.filePath}:${m.line}')
            .join(' AND ');
        errors.add('Duplicate ${entry.key}: $locations');
      }
    }

    // Check 2: Regular + promoted conflict
    // If D4-PAR-15 and D4-42-PAR-15 both exist, that's a conflict
    // With --fix, remove the regular ID from source
    for (final pair in conflictPairs.values) {
      final (regular, linked) = pair;
      if (fix) {
        // Auto-fix: remove regular ID, keep promoted
        if (dryRun) {
          fixed.add(
            'Would remove ${regular.testId} (promoted ${linked.testId} '
            'exists) from ${regular.filePath}:${regular.line}',
          );
        } else {
          final result = _removeTestId(regular);
          if (result != null) {
            fixed.add(
              'Removed ${regular.testId} from ${regular.filePath}:${regular.line}',
            );
          } else {
            errors.add(
              'Failed to fix: ${regular.testId} at ${regular.filePath}:${regular.line}',
            );
          }
        }
      } else {
        errors.add(
          'Conflict: regular ${regular.testId} AND promoted ${linked.testId}',
        );
      }
    }

    // Check 3: Invalid issue references
    // Collect unique issue numbers and verify they exist
    final issueNumbers = <int>{};
    for (final test in allTests) {
      if (test.issueNumber != null) {
        issueNumbers.add(test.issueNumber!);
      }
    }
    for (final num in issueNumbers) {
      try {
        await service.getIssue(num);
      } on Exception {
        warnings.add('Issue #$num not found in tom_issues');
      }
    }

    if (errors.isEmpty && warnings.isEmpty && fixed.isEmpty) {
      return ItemResult.success(
        path: context.path,
        name: context.name,
        message: '${allTests.length} tests validated — no issues',
      );
    }

    final parts = <String>[];
    if (fixed.isNotEmpty) {
      parts.add('${fixed.length} fix(es):\n${fixed.join('\n')}');
    }
    if (errors.isNotEmpty) {
      parts.add('${errors.length} error(s):\n${errors.join('\n')}');
    }
    if (warnings.isNotEmpty) {
      parts.add('${warnings.length} warning(s):\n${warnings.join('\n')}');
    }

    return ItemResult(
      path: context.path,
      name: context.name,
      success: errors.isEmpty,
      message: parts.join('\n'),
      error: errors.isNotEmpty ? '${errors.length} validation error(s)' : null,
    );
  }

  /// Removes a test ID from its source file by commenting out the test.
  /// Returns the new content if successful, null on failure.
  String? _removeTestId(TestIdMatch match) {
    try {
      final file = File(match.filePath);
      if (!file.existsSync()) return null;

      final lines = file.readAsLinesSync();
      if (match.line < 1 || match.line > lines.length) return null;

      // Comment out the line containing the test ID
      final lineIndex = match.line - 1;
      final line = lines[lineIndex];

      // Check if this line contains the test definition
      if (!line.contains(match.testId)) return null;

      // Comment out the line with a note about why
      lines[lineIndex] =
          '// REMOVED by :validate --fix (promoted version exists): $line';

      final newContent = lines.join('\n');
      file.writeAsStringSync(newContent);
      return newContent;
    } catch (_) {
      return null;
    }
  }
}

/// Executor for :link command.
///
/// Explicitly links a test to an issue via a comment.
/// Issue number is the first positional arg. Options: --test-id (required),
/// --test-file, --note.
class LinkExecutor extends CommandExecutor {
  final IssueService service;

  LinkExecutor(this.service);

  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return ItemResult.failure(
      path: context.path,
      name: context.name,
      error: ':link is a non-traversal command',
    );
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    final issueNumber = _parseIssueNumber(args);
    if (issueNumber == null) {
      return const ToolResult.failure(
        'Missing required argument: issue number',
      );
    }
    final opts = args.extraOptions;
    final testId = opts['test-id'] as String?;
    if (testId == null) {
      return const ToolResult.failure('Missing required option: --test-id');
    }

    if (args.dryRun) {
      return ToolResult(
        success: true,
        processedCount: 0,
        itemResults: [
          ItemResult.success(
            path: 'tom_issues',
            name: '#$issueNumber',
            message:
                '[DRY RUN] Would link test $testId '
                'to issue #$issueNumber',
          ),
        ],
      );
    }

    try {
      await service.linkTest(
        issueNumber: issueNumber,
        testId: testId,
        testFile: opts['test-file'] as String?,
        note: opts['note'] as String?,
      );

      return ToolResult(
        success: true,
        processedCount: 1,
        itemResults: [
          ItemResult.success(
            path: 'tom_issues',
            name: '#$issueNumber',
            message: 'Linked test $testId to issue #$issueNumber',
          ),
        ],
      );
    } on Exception catch (e) {
      return ToolResult.failure('Failed to link test: $e');
    }
  }
}

// =============================================================================
// Workflow Integration Executors
// =============================================================================

/// Executor for :sync command.
///
/// Per-project: scans for issue-linked tests, reads baselines, reports
/// which tests pass/fail. Groups results by issue number and detects:
/// - Issues with all tests passing (candidates for VERIFYING)
/// - Issues with failing tests
/// - Issues with stubs only (missing full tests)
/// - Potential regressions (tests that were OK but now fail)
class SyncExecutor extends CommandExecutor {
  final TestScanner scanner;
  final IssueService service;

  SyncExecutor(this.scanner, this.service);

  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    final opts = args.extraOptions;
    final autoApply = opts['auto'] == true;
    final dryRun = args.dryRun;

    final allTests = scanner
        .scanProject(context.path)
        .where((m) => m.isIssueLinked)
        .toList();

    if (allTests.isEmpty) {
      return ItemResult.success(
        path: context.path,
        name: context.name,
        message: 'No issue-linked tests found',
      );
    }

    // Read baseline
    final baselineContent = scanner.readLatestBaseline(context.path);
    if (baselineContent == null) {
      return ItemResult.success(
        path: context.path,
        name: context.name,
        message: '${allTests.length} issue-linked test(s) — no baseline',
      );
    }

    final statuses = scanner.parseBaseline(baselineContent);

    // Group tests by issue number for state transition detection
    final byIssue = <int, List<TestIdMatch>>{};
    for (final test in allTests) {
      if (test.issueNumber != null) {
        byIssue.putIfAbsent(test.issueNumber!, () => []).add(test);
      }
    }

    final passing = <String>[];
    final failing = <String>[];
    final notRun = <String>[];
    final regressions = <String>[];
    final allPassIssues = <int>[];
    final failingIssues = <int>[];

    for (final entry in byIssue.entries) {
      final issueNum = entry.key;
      var issueAllPass = true;
      final fullTests = entry.value.where((t) => !t.isStub).toList();

      for (final test in fullTests) {
        final status = statuses[test.testId];
        if (status == null) {
          notRun.add(test.testId);
          issueAllPass = false;
        } else if (status.startsWith('OK')) {
          passing.add(test.testId);
        } else {
          failing.add(test.testId);
          issueAllPass = false;
          // Detect regression: status contains OK→X pattern
          if (status.contains('/') && status.contains('OK')) {
            regressions.add('${test.testId} (#$issueNum)');
          }
        }
      }

      if (fullTests.isNotEmpty && issueAllPass) {
        allPassIssues.add(issueNum);
      } else if (!issueAllPass) {
        failingIssues.add(issueNum);
      }
    }

    // Per spec: with --auto, apply state transitions
    if (autoApply && !dryRun) {
      // Reopen issues with regressions
      for (final entry in byIssue.entries) {
        final issueNum = entry.key;
        final fullTests = entry.value.where((t) => !t.isStub).toList();
        final hasRegression = fullTests.any((t) {
          final s = statuses[t.testId];
          if (s == null || !s.contains('/')) return false;
          final parts = s.split('/');
          return parts.length == 2 &&
              parts[0].trim() == 'X' &&
              parts[1].trim() == 'OK';
        });
        if (hasRegression) {
          try {
            await service.reopenIssue(
              issueNum,
              note: 'Regression detected by :sync',
            );
          } on Exception {
            // API failure — continue with other issues
          }
        }
      }
    }

    // Build message
    final parts = <String>[];
    if (passing.isNotEmpty) parts.add('${passing.length} passing');
    if (failing.isNotEmpty) parts.add('${failing.length} failing');
    if (notRun.isNotEmpty) parts.add('${notRun.length} not run');

    final msg = StringBuffer(
      '${allTests.length} issue-linked test(s): ${parts.join(', ')}',
    );

    if (allPassIssues.isNotEmpty) {
      final nums = allPassIssues.map((n) => '#$n').join(', ');
      msg.write('\nAll pass: $nums (candidates for VERIFYING)');
    }
    if (regressions.isNotEmpty) {
      msg.write('\nRegressions: ${regressions.join(', ')}');
    }
    if (dryRun) {
      msg.write('\n(dry-run: no changes applied)');
    }

    return ItemResult(
      path: context.path,
      name: context.name,
      success: failing.isEmpty,
      message: msg.toString(),
      error: failing.isNotEmpty ? 'Failing: ${failing.join(', ')}' : null,
    );
  }
}

/// Executor for :aggregate command.
///
/// Per spec: reads each project's most recent testkit baseline, extracts
/// issue-linked test results, and produces a consolidated view with Project,
/// Test ID, Description, Issue#, and Status. Detects regressions (OK→X)
/// and fixes (X→OK) in baseline status columns.
class AggregateExecutor extends CommandExecutor {
  final TestScanner scanner;

  AggregateExecutor(this.scanner);

  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    final allTests = scanner
        .scanProject(context.path)
        .where((m) => m.isIssueLinked)
        .toList();

    if (allTests.isEmpty) {
      return ItemResult.success(
        path: context.path,
        name: context.name,
        message: 'No issue-linked tests to aggregate',
      );
    }

    // Read baseline and match
    final baselineContent = scanner.readLatestBaseline(context.path);
    final statuses = baselineContent != null
        ? scanner.parseBaseline(baselineContent)
        : <String, String>{};

    // Per spec: CSV-compatible output with Project column
    final lines = <String>[];
    final regressions = <String>[];
    final fixes = <String>[];

    for (final t in allTests) {
      final status = statuses[t.testId] ?? 'NOT RUN';
      lines.add(
        '${t.projectId},${t.testId},${t.description},#${t.issueNumber},$status',
      );
      // Detect regressions (OK→X) and fixes (X→OK) in status
      if (status.contains('/')) {
        final parts = status.split('/');
        if (parts.length == 2) {
          final current = parts[0].trim();
          final previous = parts[1].trim();
          if (current == 'X' && previous == 'OK') {
            regressions.add('${t.testId} (#${t.issueNumber})');
          } else if (current == 'OK' && previous == 'X') {
            fixes.add('${t.testId} (#${t.issueNumber})');
          }
        }
      }
    }

    final msg = StringBuffer(
      '${allTests.length} issue-linked test(s):\n${lines.join('\n')}',
    );
    if (regressions.isNotEmpty) {
      msg.write('\nRegressions: ${regressions.join(', ')}');
    }
    if (fixes.isNotEmpty) {
      msg.write('\nFixes: ${fixes.join(', ')}');
    }

    return ItemResult.success(
      path: context.path,
      name: context.name,
      message: msg.toString(),
    );
  }
}

/// Executor for :export command.
///
/// Exports issues from tom_issues or tom_tests to formatted output.
/// Options: --output (required), --state, --severity, --project, --tags,
/// --all, --repo.
class ExportExecutor extends CommandExecutor {
  final IssueService service;

  ExportExecutor(this.service);

  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return ItemResult.failure(
      path: context.path,
      name: context.name,
      error: ':export is a non-traversal command',
    );
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    final opts = args.extraOptions;

    try {
      final issues = await service.exportIssues(
        repo: opts['repo'] as String? ?? 'issues',
        state: opts['state'] as String?,
        severity: opts['severity'] as String?,
        project: opts['project'] as String?,
        tags: opts.containsKey('tags')
            ? _splitTags(opts['tags'] as String?)
            : null,
        includeAll: opts['all'] == true,
      );

      final items = issues.map((issue) {
        return ItemResult.success(
          path: 'export',
          name: '#${issue.number}',
          message: '#${issue.number}: ${issue.title}',
        );
      }).toList();

      return ToolResult(
        success: true,
        processedCount: issues.length,
        itemResults: items,
      );
    } on Exception catch (e) {
      return ToolResult.failure('Failed to export: $e');
    }
  }
}

/// Executor for :import command.
///
/// Imports issues from a parsed data structure.
/// File path is the first positional arg. Options: --dry-run, --repo.
class ImportExecutor extends CommandExecutor {
  final IssueService service;

  ImportExecutor(this.service);

  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return ItemResult.failure(
      path: context.path,
      name: context.name,
      error: ':import is a non-traversal command',
    );
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    if (args.positionalArgs.isEmpty) {
      return const ToolResult.failure('Missing required argument: file path');
    }
    final filePath = args.positionalArgs.first;
    final opts = args.extraOptions;
    final dryRun = args.dryRun || opts['dry-run'] == true;

    try {
      final repo = opts['repo'] as String? ?? 'issues';

      if (dryRun) {
        return ToolResult(
          success: true,
          processedCount: 0,
          itemResults: [
            ItemResult.success(
              path: 'import',
              name: filePath,
              message: 'Dry-run: would import from $filePath',
            ),
          ],
        );
      }

      // Read and parse the file
      final file = File(filePath);
      if (!file.existsSync()) {
        return ToolResult.failure('File not found: $filePath');
      }

      final content = file.readAsStringSync();
      final entries = _parseImportFile(content);

      final created = await service.importIssues(entries: entries, repo: repo);

      final items = created.map((issue) {
        return ItemResult.success(
          path: 'import',
          name: '#${issue.number}',
          message: 'Imported: #${issue.number} ${issue.title}',
        );
      }).toList();

      return ToolResult(
        success: true,
        processedCount: created.length,
        itemResults: items.isEmpty
            ? [
                ItemResult.success(
                  path: 'import',
                  name: filePath,
                  message: 'Imported ${created.length} entries from $filePath',
                ),
              ]
            : items,
      );
    } on IssueServiceException catch (e) {
      return ToolResult.failure(e.message);
    } on Exception catch (e) {
      return ToolResult.failure('Failed to import: $e');
    }
  }
}

/// Executor for :init command.
///
/// Initializes GitHub repositories with standard labels.
/// Options: --repo (issues|tests|both), --force.
class InitExecutor extends CommandExecutor {
  final IssueService service;

  InitExecutor(this.service);

  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return ItemResult.failure(
      path: context.path,
      name: context.name,
      error: ':init is a non-traversal command',
    );
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    final opts = args.extraOptions;
    final repo = opts['repo'] as String? ?? 'both';
    final force = opts['force'] == true;

    if (args.dryRun) {
      return ToolResult(
        success: true,
        processedCount: 0,
        itemResults: [
          ItemResult.success(
            path: 'init',
            name: 'labels',
            message:
                '[DRY RUN] Would initialize labels '
                'for repo: $repo${force ? ' (force)' : ''}',
          ),
        ],
      );
    }

    try {
      final result = await service.initLabels(repo: repo, force: force);

      return ToolResult(
        success: true,
        processedCount: result.totalCreated,
        itemResults: [
          ItemResult.success(
            path: 'init',
            name: 'labels',
            message:
                'Created ${result.issuesLabelsCreated} issue labels '
                'and ${result.testsLabelsCreated} test labels',
          ),
        ],
      );
    } on Exception catch (e) {
      return ToolResult.failure('Failed to initialize: $e');
    }
  }
}

/// Executor for :snapshot command.
///
/// Creates a snapshot of all issues and/or tests.
/// Options: --issues-only, --tests-only, --output.
class SnapshotExecutor extends CommandExecutor {
  final IssueService service;

  SnapshotExecutor(this.service);

  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return ItemResult.failure(
      path: context.path,
      name: context.name,
      error: ':snapshot is a non-traversal command',
    );
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    final opts = args.extraOptions;
    final issuesOnly = opts['issues-only'] == true;
    final testsOnly = opts['tests-only'] == true;

    if (args.dryRun) {
      final scope = issuesOnly
          ? 'issues only'
          : testsOnly
          ? 'tests only'
          : 'issues and tests';
      return ToolResult(
        success: true,
        processedCount: 0,
        itemResults: [
          ItemResult.success(
            path: 'snapshot',
            name: 'snapshot',
            message: '[DRY RUN] Would create snapshot of $scope',
          ),
        ],
      );
    }

    try {
      final snapshot = await service.createSnapshot(
        issuesOnly: issuesOnly,
        testsOnly: testsOnly,
      );

      final issueCount = snapshot.issues?.length ?? 0;
      final testCount = snapshot.tests?.length ?? 0;

      return ToolResult(
        success: true,
        processedCount: issueCount + testCount,
        itemResults: [
          ItemResult.success(
            path: 'snapshot',
            name: 'snapshot',
            message: 'Snapshot created: $issueCount issues, $testCount tests',
          ),
        ],
      );
    } on Exception catch (e) {
      return ToolResult.failure('Failed to create snapshot: $e');
    }
  }
}

/// Executor for :run-tests command.
///
/// Triggers the nightly test workflow via GitHub Actions.
/// Options: --wait.
class RunTestsExecutor extends CommandExecutor {
  final IssueService service;

  RunTestsExecutor(this.service);

  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return ItemResult.failure(
      path: context.path,
      name: context.name,
      error: ':run-tests is a non-traversal command',
    );
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    final wait = args.extraOptions['wait'] == true;

    if (args.dryRun) {
      return ToolResult(
        success: true,
        processedCount: 0,
        itemResults: [
          ItemResult.success(
            path: 'run-tests',
            name: 'workflow',
            message:
                '[DRY RUN] Would trigger test workflow'
                '${wait ? ' (with wait)' : ''}',
          ),
        ],
      );
    }

    try {
      await service.triggerTestWorkflow(wait: wait);

      return ToolResult(
        success: true,
        processedCount: 1,
        itemResults: [
          ItemResult.success(
            path: 'run-tests',
            name: 'workflow',
            message:
                'Test workflow triggered'
                '${wait ? ' (waiting for completion)' : ''}',
          ),
        ],
      );
    } on Exception catch (e) {
      return ToolResult.failure('Failed to trigger test workflow: $e');
    }
  }
}

// =============================================================================
// Executor Factory
// =============================================================================

/// Create all issuekit command executors.
///
/// Requires an [IssueService] for commands that interact with the GitHub API.
Map<String, CommandExecutor> createIssuekitExecutors({
  required IssueService service,
  TestScanner? scanner,
}) {
  final testScanner = scanner ?? TestScanner();
  return {
    // Issue Management (wired to IssueService)
    'new': NewIssueExecutor(service),
    'edit': EditIssueExecutor(service),
    'analyze': AnalyzeExecutor(service),
    'assign': AssignExecutor(service),
    'testing': TestingExecutor(testScanner, service),
    'verify': VerifyExecutor(testScanner, service),
    'resolve': ResolveExecutor(service),
    'close': CloseExecutor(service),
    'reopen': ReopenExecutor(service),
    // Discovery and Querying (wired to IssueService)
    'list': ListExecutor(service),
    'show': ShowExecutor(service, testScanner),
    'search': SearchExecutor(service),
    'scan': ScanExecutor(testScanner),
    'summary': SummaryExecutor(service),
    // Test Management
    'promote': PromoteExecutor(testScanner),
    'validate': ValidateExecutor(testScanner, service),
    'link': LinkExecutor(service),
    // Workflow Integration
    'sync': SyncExecutor(testScanner, service),
    'aggregate': AggregateExecutor(testScanner),
    'export': ExportExecutor(service),
    'import': ImportExecutor(service),
    'init': InitExecutor(service),
    'snapshot': SnapshotExecutor(service),
    'run-tests': RunTestsExecutor(service),
  };
}
