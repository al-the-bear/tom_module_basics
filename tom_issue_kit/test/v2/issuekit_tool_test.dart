/// Unit tests for issuekit tool definition.
///
/// Tests that the CLI tool definition is correctly structured.
@TestOn('vm')
library;

import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:tom_build_base/tom_build_base_v2.dart';
import 'package:tom_issue_kit/src/services/issue_service.dart';
import 'package:tom_issue_kit/src/v2/issuekit_tool.dart';
import 'package:tom_issue_kit/src/v2/issuekit_executors.dart';

/// Mock IssueService for executor registration tests.
class _MockIssueService extends Mock implements IssueService {}

void main() {
  group('IK-CLI-1: Tool Definition [2026-02-13]', () {
    test('IK-CLI-1: Tool has correct name and version', () {
      expect(issuekitTool.name, 'issuekit');
      expect(issuekitTool.version, isNotEmpty);
      expect(issuekitTool.mode, ToolMode.multiCommand);
    });

    test('IK-CLI-2: Tool has all required commands', () {
      final commandNames = issuekitTool.commands.map((c) => c.name).toSet();

      // Issue Management
      expect(commandNames, contains('new'));
      expect(commandNames, contains('edit'));
      expect(commandNames, contains('analyze'));
      expect(commandNames, contains('assign'));
      expect(commandNames, contains('testing'));
      expect(commandNames, contains('verify'));
      expect(commandNames, contains('resolve'));
      expect(commandNames, contains('close'));
      expect(commandNames, contains('reopen'));

      // Discovery and Querying
      expect(commandNames, contains('list'));
      expect(commandNames, contains('show'));
      expect(commandNames, contains('search'));
      expect(commandNames, contains('scan'));
      expect(commandNames, contains('summary'));

      // Test Management
      expect(commandNames, contains('promote'));
      expect(commandNames, contains('validate'));
      expect(commandNames, contains('link'));

      // Workflow Integration
      expect(commandNames, contains('sync'));
      expect(commandNames, contains('aggregate'));
      expect(commandNames, contains('export'));
      expect(commandNames, contains('import'));
      expect(commandNames, contains('init'));
      expect(commandNames, contains('snapshot'));
      expect(commandNames, contains('run-tests'));
    });

    test('IK-CLI-3: All commands have descriptions', () {
      for (final command in issuekitTool.commands) {
        expect(
          command.description,
          isNotEmpty,
          reason: ':${command.name} should have a description',
        );
      }
    });

    test('IK-CLI-4: Project traversal commands are marked correctly', () {
      // Commands that need workspace scanning
      const traversalCommands = [
        'testing',
        'verify',
        'show',
        'scan',
        'promote',
        'validate',
        'sync',
        'aggregate',
      ];

      // Commands that don't need traversal (GitHub API only)
      const noTraversalCommands = [
        'new',
        'edit',
        'analyze',
        'assign',
        'resolve',
        'close',
        'reopen',
        'list',
        'search',
        'summary',
        'link',
        'export',
        'import',
        'init',
        'snapshot',
        'run-tests',
      ];

      for (final command in issuekitTool.commands) {
        if (traversalCommands.contains(command.name)) {
          expect(
            command.supportsProjectTraversal,
            isTrue,
            reason: ':${command.name} should support project traversal',
          );
        }
        if (noTraversalCommands.contains(command.name)) {
          expect(
            command.supportsProjectTraversal,
            isFalse,
            reason: ':${command.name} should not support project traversal',
          );
        }
      }
    });

    test('IK-CLI-5: Navigation features are configured correctly', () {
      expect(issuekitTool.features.projectTraversal, isTrue);
      expect(issuekitTool.features.recursiveScan, isTrue);
      expect(issuekitTool.features.verbose, isTrue);
    });
  });

  group('IK-CLI-2: Command Options [2026-02-13]', () {
    test('IK-CLI-6: :new command has required options', () {
      final cmd = issuekitTool.commands.firstWhere((c) => c.name == 'new');
      final optionNames = cmd.options.map((o) => o.name).toSet();

      expect(optionNames, contains('severity'));
      expect(optionNames, contains('context'));
      expect(optionNames, contains('expected'));
      expect(optionNames, contains('tags'));
      expect(optionNames, contains('project'));
      expect(optionNames, contains('reporter'));
    });

    test('IK-CLI-7: :list command has required options', () {
      final cmd = issuekitTool.commands.firstWhere((c) => c.name == 'list');
      final optionNames = cmd.options.map((o) => o.name).toSet();

      expect(optionNames, contains('state'));
      expect(optionNames, contains('severity'));
      expect(optionNames, contains('project'));
      expect(optionNames, contains('tags'));
      expect(optionNames, contains('reporter'));
      expect(optionNames, contains('all'));
      expect(optionNames, contains('sort'));
      expect(optionNames, contains('output'));
      expect(optionNames, contains('repo'));
    });

    test('IK-CLI-8: :scan command has required options', () {
      final cmd = issuekitTool.commands.firstWhere((c) => c.name == 'scan');
      final optionNames = cmd.options.map((o) => o.name).toSet();

      expect(optionNames, contains('project'));
      expect(optionNames, contains('state'));
      expect(optionNames, contains('missing-tests'));
      expect(optionNames, contains('output'));
    });

    test('IK-CLI-9: :sync command has required options', () {
      final cmd = issuekitTool.commands.firstWhere((c) => c.name == 'sync');
      final optionNames = cmd.options.map((o) => o.name).toSet();

      expect(optionNames, contains('auto'));
      expect(optionNames, contains('project'));
      expect(optionNames, contains('dry-run'));
    });
  });

  group('IK-CLI-3: Executor Registration [2026-02-13]', () {
    late _MockIssueService mockService;

    setUp(() {
      mockService = _MockIssueService();
    });

    test('IK-CLI-10: All commands have executors', () {
      final executors = createIssuekitExecutors(service: mockService);
      final commandNames = issuekitTool.commands.map((c) => c.name).toSet();

      for (final name in commandNames) {
        expect(
          executors.containsKey(name),
          isTrue,
          reason: 'Executor for :$name should exist',
        );
      }
    });

    test('IK-CLI-11: Executor count matches command count', () {
      final executors = createIssuekitExecutors(service: mockService);
      expect(executors.length, issuekitTool.commands.length);
    });
  });
}
