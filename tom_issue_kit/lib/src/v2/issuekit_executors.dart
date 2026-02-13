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

/// Create a "not implemented" tool result for non-traversal commands.
ToolResult _notImplementedTool(String commandName) {
  return ToolResult.failure(':$commandName command not yet implemented');
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
class AnalyzeExecutor extends CommandExecutor {
  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return _notImplemented(context, 'analyze');
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    return _notImplementedTool('analyze');
  }
}

/// Executor for :assign command.
class AssignExecutor extends CommandExecutor {
  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return _notImplemented(context, 'assign');
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    return _notImplementedTool('assign');
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
class ResolveExecutor extends CommandExecutor {
  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return _notImplemented(context, 'resolve');
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    return _notImplementedTool('resolve');
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
class SummaryExecutor extends CommandExecutor {
  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return _notImplemented(context, 'summary');
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    return _notImplementedTool('summary');
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
class LinkExecutor extends CommandExecutor {
  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return _notImplemented(context, 'link');
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    return _notImplementedTool('link');
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
class ExportExecutor extends CommandExecutor {
  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return _notImplemented(context, 'export');
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    return _notImplementedTool('export');
  }
}

/// Executor for :import command.
class ImportExecutor extends CommandExecutor {
  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return _notImplemented(context, 'import');
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    return _notImplementedTool('import');
  }
}

/// Executor for :init command.
class InitExecutor extends CommandExecutor {
  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return _notImplemented(context, 'init');
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    return _notImplementedTool('init');
  }
}

/// Executor for :snapshot command.
class SnapshotExecutor extends CommandExecutor {
  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return _notImplemented(context, 'snapshot');
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    return _notImplementedTool('snapshot');
  }
}

/// Executor for :run-tests command.
class RunTestsExecutor extends CommandExecutor {
  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return _notImplemented(context, 'run-tests');
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    return _notImplementedTool('run-tests');
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
    'analyze': AnalyzeExecutor(),
    'assign': AssignExecutor(),
    'testing': TestingExecutor(),
    'verify': VerifyExecutor(),
    'resolve': ResolveExecutor(),
    'close': CloseExecutor(service),
    'reopen': ReopenExecutor(service),
    // Discovery and Querying (wired to IssueService)
    'list': ListExecutor(service),
    'show': ShowExecutor(service),
    'search': SearchExecutor(service),
    'scan': ScanExecutor(),
    'summary': SummaryExecutor(),
    // Test Management (stubs)
    'promote': PromoteExecutor(),
    'validate': ValidateExecutor(),
    'link': LinkExecutor(),
    // Workflow Integration (stubs)
    'sync': SyncExecutor(),
    'aggregate': AggregateExecutor(),
    'export': ExportExecutor(),
    'import': ImportExecutor(),
    'init': InitExecutor(),
    'snapshot': SnapshotExecutor(),
    'run-tests': RunTestsExecutor(),
  };
}
