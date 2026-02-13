/// Issuekit v2 command executors.
///
/// These executors implement the issuekit commands using the v2 ToolRunner
/// framework. Core commands (:new, :edit, :show, :list, :search, :close,
/// :reopen) are wired to [IssueService]. Remaining commands are stubs.
library;

import 'package:tom_build_base/tom_build_base_v2.dart';

import '../services/issue_service.dart';

// =============================================================================
// Helper Functions
// =============================================================================

/// Create a "not implemented" result for traversal-based commands.
ItemResult _notImplemented(CommandContext context, String commandName) {
  return ItemResult.failure(
    path: context.path,
    name: context.name,
    error: ':$commandName command not yet implemented',
  );
}

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
  return value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
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
      final msg = StringBuffer('Created issue #${issue.number}: ${issue.title}');
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
      return const ToolResult.failure(
        'Missing required option: --project',
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
class TestingExecutor extends CommandExecutor {
  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return _notImplemented(context, 'testing');
  }
}

/// Executor for :verify command.
class VerifyExecutor extends CommandExecutor {
  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return _notImplemented(context, 'verify');
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
        final stateLabel = issue.labels
            .map((l) => l.name)
            .where((n) =>
                const ['new', 'analyzed', 'assigned', 'testing', 'verifying', 'resolved']
                    .contains(n))
            .firstOrNull ?? '';
        final severityLabel = issue.labels
            .map((l) => l.name)
            .where((n) => n.startsWith('severity:'))
            .firstOrNull ?? '';
        final projectLabel = issue.labels
            .map((l) => l.name)
            .where((n) => n.startsWith('project:'))
            .firstOrNull ?? '';

        return ItemResult.success(
          path: 'tom_issues',
          name: '#${issue.number}',
          message: '#${issue.number}  '
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

  ShowExecutor(this.service);

  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    // When called with traversal, perform workspace scan for linked tests.
    // For now, just show the API data.
    return _notImplemented(context, 'show');
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
class ScanExecutor extends CommandExecutor {
  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return _notImplemented(context, 'scan');
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
          msg.writeln('  ${entry.key.toUpperCase().padRight(14)} ${entry.value}');
        }
        msg.writeln();
      }

      if (summary.bySeverity.isNotEmpty) {
        msg.writeln('By Severity:');
        for (final entry in summary.bySeverity.entries) {
          msg.writeln('  ${entry.key.toUpperCase().padRight(14)} ${entry.value}');
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
class PromoteExecutor extends CommandExecutor {
  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return _notImplemented(context, 'promote');
  }
}

/// Executor for :validate command.
class ValidateExecutor extends CommandExecutor {
  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return _notImplemented(context, 'validate');
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
      return const ToolResult.failure(
        'Missing required option: --test-id',
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
class SyncExecutor extends CommandExecutor {
  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return _notImplemented(context, 'sync');
  }
}

/// Executor for :aggregate command.
class AggregateExecutor extends CommandExecutor {
  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return _notImplemented(context, 'aggregate');
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
    final dryRun = opts['dry-run'] == true;

    try {
      // Parse file will be implemented later; for now report the file path
      final msg = dryRun
          ? 'Dry-run: would import from $filePath'
          : 'Import from $filePath (file parsing not yet implemented)';

      return ToolResult(
        success: true,
        processedCount: 0,
        itemResults: [
          ItemResult.success(
            path: 'import',
            name: filePath,
            message: msg,
          ),
        ],
      );
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

    try {
      final result = await service.initLabels(repo: repo, force: force);

      return ToolResult(
        success: true,
        processedCount: result.totalCreated,
        itemResults: [
          ItemResult.success(
            path: 'init',
            name: 'labels',
            message: 'Created ${result.issuesLabelsCreated} issue labels '
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

    try {
      await service.triggerTestWorkflow(wait: wait);

      return ToolResult(
        success: true,
        processedCount: 1,
        itemResults: [
          ItemResult.success(
            path: 'run-tests',
            name: 'workflow',
            message: 'Test workflow triggered'
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
}) {
  return {
    // Issue Management (wired to IssueService)
    'new': NewIssueExecutor(service),
    'edit': EditIssueExecutor(service),
    'analyze': AnalyzeExecutor(service),
    'assign': AssignExecutor(service),
    'testing': TestingExecutor(),
    'verify': VerifyExecutor(),
    'resolve': ResolveExecutor(service),
    'close': CloseExecutor(service),
    'reopen': ReopenExecutor(service),
    // Discovery and Querying (wired to IssueService)
    'list': ListExecutor(service),
    'show': ShowExecutor(service),
    'search': SearchExecutor(service),
    'scan': ScanExecutor(),
    'summary': SummaryExecutor(service),
    // Test Management
    'promote': PromoteExecutor(),
    'validate': ValidateExecutor(),
    'link': LinkExecutor(service),
    // Workflow Integration
    'sync': SyncExecutor(),
    'aggregate': AggregateExecutor(),
    'export': ExportExecutor(service),
    'import': ImportExecutor(service),
    'init': InitExecutor(service),
    'snapshot': SnapshotExecutor(service),
    'run-tests': RunTestsExecutor(service),
  };
}
