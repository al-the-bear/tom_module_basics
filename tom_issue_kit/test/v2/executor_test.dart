/// Unit tests for issuekit command executors.
///
/// Tests that the wired executors correctly delegate to IssueService
/// and handle arguments, errors, and result formatting.
@TestOn('vm')
library;

import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:tom_build_base/tom_build_base_v2.dart' hide ListExecutor, SyncExecutor;
import 'package:tom_issue_kit/src/services/issue_service.dart';
import 'package:tom_issue_kit/src/v2/issuekit_executors.dart';
import 'package:tom_issue_kit/src/v2/issuekit_tool.dart';

import '../helpers/fixtures.dart';

void main() {
  late MockIssueService mockService;

  setUp(() {
    mockService = MockIssueService();
  });

  // ===========================================================================
  // IK-EXE-NEW: NewIssueExecutor
  // ===========================================================================

  group('IK-EXE-NEW: NewIssueExecutor [2026-02-13]', () {
    late NewIssueExecutor executor;

    setUp(() {
      executor = NewIssueExecutor(mockService);
    });

    test('IK-EXE-NEW-1: creates issue with title only', () async {
      when(() => mockService.createIssue(
            title: any(named: 'title'),
            severity: any(named: 'severity'),
            context: any(named: 'context'),
            expected: any(named: 'expected'),
            symptom: any(named: 'symptom'),
            tags: any(named: 'tags'),
            project: any(named: 'project'),
            reporter: any(named: 'reporter'),
          )).thenAnswer((_) async => CreateIssueResult(
            issue: createTestIssue(number: 42, title: 'Memory leak'),
          ));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(positionalArgs: ['Memory leak']),
      );

      expect(result.success, isTrue);
      expect(result.processedCount, 1);
      expect(result.itemResults.first.message, contains('#42'));
      expect(result.itemResults.first.message, contains('Memory leak'));

      verify(() => mockService.createIssue(
            title: 'Memory leak',
            severity: 'normal',
            context: null,
            expected: null,
            symptom: null,
            tags: [],
            project: null,
            reporter: null,
          )).called(1);
    });

    test('IK-EXE-NEW-2: creates issue with all options', () async {
      when(() => mockService.createIssue(
            title: any(named: 'title'),
            severity: any(named: 'severity'),
            context: any(named: 'context'),
            expected: any(named: 'expected'),
            symptom: any(named: 'symptom'),
            tags: any(named: 'tags'),
            project: any(named: 'project'),
            reporter: any(named: 'reporter'),
          )).thenAnswer((_) async => CreateIssueResult(
            issue: createTestIssue(number: 103, title: 'Cipher fails'),
            testEntry: createTestIssue(number: 1, title: '[CR-103] Cipher fails'),
          ));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(
          positionalArgs: ['Cipher fails'],
          extraOptions: {
            'severity': 'high',
            'context': 'Seen during encryption test',
            'expected': 'Empty input → empty output',
            'symptom': 'Exception on empty input',
            'tags': 'crypto,cipher',
            'project': 'tom_crypto',
            'reporter': 'copilot',
          },
        ),
      );

      expect(result.success, isTrue);
      expect(result.itemResults.first.message, contains('#103'));
      expect(result.itemResults.first.message, contains('Test entry created'));

      verify(() => mockService.createIssue(
            title: 'Cipher fails',
            severity: 'high',
            context: 'Seen during encryption test',
            expected: 'Empty input → empty output',
            symptom: 'Exception on empty input',
            tags: ['crypto', 'cipher'],
            project: 'tom_crypto',
            reporter: 'copilot',
          )).called(1);
    });

    test('IK-EXE-NEW-3: fails when title is missing', () async {
      final result = await executor.executeWithoutTraversal(
        const CliArgs(),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('title'));
      verifyNever(() => mockService.createIssue(
            title: any(named: 'title'),
            severity: any(named: 'severity'),
          ));
    });

    test('IK-EXE-NEW-4: handles service exception', () async {
      when(() => mockService.createIssue(
            title: any(named: 'title'),
            severity: any(named: 'severity'),
            context: any(named: 'context'),
            expected: any(named: 'expected'),
            symptom: any(named: 'symptom'),
            tags: any(named: 'tags'),
            project: any(named: 'project'),
            reporter: any(named: 'reporter'),
          )).thenThrow(IssueServiceException('API rate limited', code: 'RATE_LIMIT'));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(positionalArgs: ['Test issue']),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('API rate limited'));
    });
  });

  // ===========================================================================
  // IK-EXE-EDT: EditIssueExecutor
  // ===========================================================================

  group('IK-EXE-EDT: EditIssueExecutor [2026-02-13]', () {
    late EditIssueExecutor executor;

    setUp(() {
      executor = EditIssueExecutor(mockService);
    });

    test('IK-EXE-EDT-1: updates issue title', () async {
      when(() => mockService.updateIssue(
            issueNumber: any(named: 'issueNumber'),
            title: any(named: 'title'),
            severity: any(named: 'severity'),
            context: any(named: 'context'),
            expected: any(named: 'expected'),
            symptom: any(named: 'symptom'),
            tags: any(named: 'tags'),
            project: any(named: 'project'),
            assignee: any(named: 'assignee'),
          )).thenAnswer((_) async => createTestIssue(
            number: 42,
            title: 'Updated title',
          ));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(
          positionalArgs: ['42'],
          extraOptions: {'title': 'Updated title'},
        ),
      );

      expect(result.success, isTrue);
      expect(result.itemResults.first.message, contains('#42'));
      expect(result.itemResults.first.message, contains('Updated title'));

      verify(() => mockService.updateIssue(
            issueNumber: 42,
            title: 'Updated title',
            severity: null,
            context: null,
            expected: null,
            symptom: null,
            tags: null,
            project: null,
            assignee: null,
          )).called(1);
    });

    test('IK-EXE-EDT-2: updates multiple fields', () async {
      when(() => mockService.updateIssue(
            issueNumber: any(named: 'issueNumber'),
            title: any(named: 'title'),
            severity: any(named: 'severity'),
            context: any(named: 'context'),
            expected: any(named: 'expected'),
            symptom: any(named: 'symptom'),
            tags: any(named: 'tags'),
            project: any(named: 'project'),
            assignee: any(named: 'assignee'),
          )).thenAnswer((_) async => createTestIssue(number: 42));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(
          positionalArgs: ['42'],
          extraOptions: {
            'severity': 'critical',
            'tags': 'parser,regression',
            'assignee': 'dev1',
          },
        ),
      );

      expect(result.success, isTrue);

      verify(() => mockService.updateIssue(
            issueNumber: 42,
            title: null,
            severity: 'critical',
            context: null,
            expected: null,
            symptom: null,
            tags: ['parser', 'regression'],
            project: null,
            assignee: 'dev1',
          )).called(1);
    });

    test('IK-EXE-EDT-3: fails when issue number missing', () async {
      final result = await executor.executeWithoutTraversal(
        const CliArgs(),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('issue number'));
    });

    test('IK-EXE-EDT-4: fails with non-numeric issue number', () async {
      final result = await executor.executeWithoutTraversal(
        const CliArgs(positionalArgs: ['abc']),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('issue number'));
    });
  });

  // ===========================================================================
  // IK-EXE-SHW: ShowExecutor
  // ===========================================================================

  group('IK-EXE-SHW: ShowExecutor [2026-02-13]', () {
    late ShowExecutor executor;

    setUp(() {
      executor = ShowExecutor(mockService);
    });

    test('IK-EXE-SHW-1: shows issue details', () async {
      when(() => mockService.getIssue(any()))
          .thenAnswer((_) async => createTestIssue(
                number: 42,
                title: 'Array parser crashes',
                body: '## Symptom\nParser crashes on empty arrays',
                labels: [
                  createTestLabel(name: 'testing'),
                  createTestLabel(name: 'severity:high'),
                  createTestLabel(name: 'project:D4'),
                ],
                user: createTestUser(login: 'reporter1'),
                assignee: createTestUser(login: 'dev1'),
              ));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(positionalArgs: ['42']),
      );

      expect(result.success, isTrue);
      final message = result.itemResults.first.message!;
      expect(message, contains('#42'));
      expect(message, contains('Array parser crashes'));
      expect(message, contains('testing'));
      expect(message, contains('severity:high'));
      expect(message, contains('project:D4'));
      expect(message, contains('dev1'));
      expect(message, contains('Parser crashes on empty arrays'));

      verify(() => mockService.getIssue(42)).called(1);
    });

    test('IK-EXE-SHW-2: shows issue with no assignee', () async {
      when(() => mockService.getIssue(any()))
          .thenAnswer((_) async => createTestIssue(
                number: 103,
                title: 'Cipher fails',
              ));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(positionalArgs: ['103']),
      );

      expect(result.success, isTrue);
      final message = result.itemResults.first.message!;
      expect(message, contains('unassigned'));
    });

    test('IK-EXE-SHW-3: fails when issue number missing', () async {
      final result = await executor.executeWithoutTraversal(
        const CliArgs(),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('issue number'));
    });

    test('IK-EXE-SHW-4: handles API error', () async {
      when(() => mockService.getIssue(any()))
          .thenThrow(Exception('Not found'));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(positionalArgs: ['999']),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Failed to show issue'));
    });
  });

  // ===========================================================================
  // IK-EXE-LST: ListExecutor
  // ===========================================================================

  group('IK-EXE-LST: ListExecutor [2026-02-13]', () {
    late ListExecutor executor;

    setUp(() {
      executor = ListExecutor(mockService);
    });

    test('IK-EXE-LST-1: lists all open issues with no filters', () async {
      when(() => mockService.listIssues(
            state: any(named: 'state'),
            severity: any(named: 'severity'),
            project: any(named: 'project'),
            tags: any(named: 'tags'),
            reporter: any(named: 'reporter'),
            includeAll: any(named: 'includeAll'),
            sort: any(named: 'sort'),
          )).thenAnswer((_) async => [
            createTestIssue(
              number: 42,
              title: 'Parser crash',
              labels: [
                createTestLabel(name: 'testing'),
                createTestLabel(name: 'severity:high'),
                createTestLabel(name: 'project:D4'),
              ],
            ),
            createTestIssue(
              number: 56,
              title: 'Build fails',
              labels: [
                createTestLabel(name: 'assigned'),
                createTestLabel(name: 'severity:normal'),
                createTestLabel(name: 'project:BK'),
              ],
            ),
          ]);

      final result = await executor.executeWithoutTraversal(
        const CliArgs(),
      );

      expect(result.success, isTrue);
      expect(result.processedCount, 2);
      expect(result.itemResults, hasLength(2));
      expect(result.itemResults[0].message, contains('#42'));
      expect(result.itemResults[0].message, contains('HIGH'));
      expect(result.itemResults[0].message, contains('D4'));
      expect(result.itemResults[0].message, contains('TESTING'));
      expect(result.itemResults[1].message, contains('#56'));
      expect(result.itemResults[1].message, contains('NORMAL'));

      verify(() => mockService.listIssues(
            state: null,
            severity: null,
            project: null,
            tags: null,
            reporter: null,
            includeAll: false,
            sort: null,
          )).called(1);
    });

    test('IK-EXE-LST-2: lists with state filter', () async {
      when(() => mockService.listIssues(
            state: any(named: 'state'),
            severity: any(named: 'severity'),
            project: any(named: 'project'),
            tags: any(named: 'tags'),
            reporter: any(named: 'reporter'),
            includeAll: any(named: 'includeAll'),
            sort: any(named: 'sort'),
          )).thenAnswer((_) async => [
            createTestIssue(number: 78, title: 'New issue', labels: [
              createTestLabel(name: 'new'),
              createTestLabel(name: 'severity:low'),
            ]),
          ]);

      final result = await executor.executeWithoutTraversal(
        const CliArgs(extraOptions: {'state': 'new'}),
      );

      expect(result.success, isTrue);
      expect(result.itemResults.first.message, contains('NEW'));

      verify(() => mockService.listIssues(
            state: 'new',
            severity: null,
            project: null,
            tags: null,
            reporter: null,
            includeAll: false,
            sort: null,
          )).called(1);
    });

    test('IK-EXE-LST-3: lists with multiple filters', () async {
      when(() => mockService.listIssues(
            state: any(named: 'state'),
            severity: any(named: 'severity'),
            project: any(named: 'project'),
            tags: any(named: 'tags'),
            reporter: any(named: 'reporter'),
            includeAll: any(named: 'includeAll'),
            sort: any(named: 'sort'),
          )).thenAnswer((_) async => []);

      final result = await executor.executeWithoutTraversal(
        const CliArgs(extraOptions: {
          'project': 'tom_d4rt',
          'severity': 'high',
          'state': 'assigned',
          'sort': 'created',
        }),
      );

      expect(result.success, isTrue);
      expect(result.processedCount, 0);

      verify(() => mockService.listIssues(
            state: 'assigned',
            severity: 'high',
            project: 'tom_d4rt',
            tags: null,
            reporter: null,
            includeAll: false,
            sort: 'created',
          )).called(1);
    });

    test('IK-EXE-LST-4: lists with --all flag', () async {
      when(() => mockService.listIssues(
            state: any(named: 'state'),
            severity: any(named: 'severity'),
            project: any(named: 'project'),
            tags: any(named: 'tags'),
            reporter: any(named: 'reporter'),
            includeAll: any(named: 'includeAll'),
            sort: any(named: 'sort'),
          )).thenAnswer((_) async => []);

      await executor.executeWithoutTraversal(
        const CliArgs(extraOptions: {'all': true}),
      );

      verify(() => mockService.listIssues(
            state: null,
            severity: null,
            project: null,
            tags: null,
            reporter: null,
            includeAll: true,
            sort: null,
          )).called(1);
    });

    test('IK-EXE-LST-5: lists with tags filter', () async {
      when(() => mockService.listIssues(
            state: any(named: 'state'),
            severity: any(named: 'severity'),
            project: any(named: 'project'),
            tags: any(named: 'tags'),
            reporter: any(named: 'reporter'),
            includeAll: any(named: 'includeAll'),
            sort: any(named: 'sort'),
          )).thenAnswer((_) async => []);

      await executor.executeWithoutTraversal(
        const CliArgs(extraOptions: {'tags': 'parser,regression'}),
      );

      verify(() => mockService.listIssues(
            state: null,
            severity: null,
            project: null,
            tags: ['parser', 'regression'],
            reporter: null,
            includeAll: false,
            sort: null,
          )).called(1);
    });

    test('IK-EXE-LST-6: handles service error', () async {
      when(() => mockService.listIssues(
            state: any(named: 'state'),
            severity: any(named: 'severity'),
            project: any(named: 'project'),
            tags: any(named: 'tags'),
            reporter: any(named: 'reporter'),
            includeAll: any(named: 'includeAll'),
            sort: any(named: 'sort'),
          )).thenThrow(Exception('Connection timeout'));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Failed to list issues'));
    });
  });

  // ===========================================================================
  // IK-EXE-SRC: SearchExecutor
  // ===========================================================================

  group('IK-EXE-SRC: SearchExecutor [2026-02-13]', () {
    late SearchExecutor executor;

    setUp(() {
      executor = SearchExecutor(mockService);
    });

    test('IK-EXE-SRC-1: searches issues by query', () async {
      when(() => mockService.searchIssues(
            query: any(named: 'query'),
            repo: any(named: 'repo'),
          )).thenAnswer((_) async => createTestSearchResult(
            totalCount: 2,
            items: [
              createTestIssue(number: 42, title: 'RangeError in parser'),
              createTestIssue(number: 89, title: 'RangeError in indexer'),
            ],
          ));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(positionalArgs: ['RangeError']),
      );

      expect(result.success, isTrue);
      expect(result.processedCount, 2);
      expect(result.itemResults, hasLength(2));
      expect(result.itemResults[0].message, contains('#42'));
      expect(result.itemResults[1].message, contains('#89'));

      verify(() => mockService.searchIssues(
            query: 'RangeError',
            repo: 'issues',
          )).called(1);
    });

    test('IK-EXE-SRC-2: searches in tests repo', () async {
      when(() => mockService.searchIssues(
            query: any(named: 'query'),
            repo: any(named: 'repo'),
          )).thenAnswer((_) async => createTestSearchResult(
            totalCount: 1,
            items: [createTestIssue(number: 1, title: 'Test entry')],
          ));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(
          positionalArgs: ['parser'],
          extraOptions: {'repo': 'tests'},
        ),
      );

      expect(result.success, isTrue);

      verify(() => mockService.searchIssues(
            query: 'parser',
            repo: 'tests',
          )).called(1);
    });

    test('IK-EXE-SRC-3: fails when query is missing', () async {
      final result = await executor.executeWithoutTraversal(
        const CliArgs(),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('query'));
    });

    test('IK-EXE-SRC-4: returns empty results', () async {
      when(() => mockService.searchIssues(
            query: any(named: 'query'),
            repo: any(named: 'repo'),
          )).thenAnswer((_) async => createTestSearchResult(
            totalCount: 0,
            items: [],
          ));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(positionalArgs: ['nonexistent']),
      );

      expect(result.success, isTrue);
      expect(result.processedCount, 0);
      expect(result.itemResults, isEmpty);
    });
  });

  // ===========================================================================
  // IK-EXE-CLS: CloseExecutor
  // ===========================================================================

  group('IK-EXE-CLS: CloseExecutor [2026-02-13]', () {
    late CloseExecutor executor;

    setUp(() {
      executor = CloseExecutor(mockService);
    });

    test('IK-EXE-CLS-1: closes resolved issue', () async {
      when(() => mockService.closeIssue(any()))
          .thenAnswer((_) async => createTestIssue(
                number: 42,
                title: 'Parser crash',
                state: 'closed',
              ));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(positionalArgs: ['42']),
      );

      expect(result.success, isTrue);
      expect(result.itemResults.first.message, contains('#42'));
      expect(result.itemResults.first.message, contains('Closed'));

      verify(() => mockService.closeIssue(42)).called(1);
    });

    test('IK-EXE-CLS-2: fails when issue is not resolved', () async {
      when(() => mockService.closeIssue(any()))
          .thenThrow(IssueServiceException(
        'Cannot close issue #42: must be in RESOLVED state',
        code: 'NOT_RESOLVED',
      ));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(positionalArgs: ['42']),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('RESOLVED'));
    });

    test('IK-EXE-CLS-3: fails when issue number missing', () async {
      final result = await executor.executeWithoutTraversal(
        const CliArgs(),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('issue number'));
    });
  });

  // ===========================================================================
  // IK-EXE-ROP: ReopenExecutor
  // ===========================================================================

  group('IK-EXE-ROP: ReopenExecutor [2026-02-13]', () {
    late ReopenExecutor executor;

    setUp(() {
      executor = ReopenExecutor(mockService);
    });

    test('IK-EXE-ROP-1: reopens issue without note', () async {
      when(() => mockService.reopenIssue(any(), note: any(named: 'note')))
          .thenAnswer((_) async => createTestIssue(
                number: 42,
                title: 'Parser crash',
                labels: [createTestLabel(name: 'new')],
              ));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(positionalArgs: ['42']),
      );

      expect(result.success, isTrue);
      expect(result.itemResults.first.message, contains('#42'));
      expect(result.itemResults.first.message, contains('Reopened'));

      verify(() => mockService.reopenIssue(42, note: null)).called(1);
    });

    test('IK-EXE-ROP-2: reopens issue with note', () async {
      when(() => mockService.reopenIssue(any(), note: any(named: 'note')))
          .thenAnswer((_) async => createTestIssue(
                number: 42,
                title: 'Parser crash',
              ));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(
          positionalArgs: ['42'],
          extraOptions: {'note': 'Regression detected'},
        ),
      );

      expect(result.success, isTrue);

      verify(() => mockService.reopenIssue(
            42,
            note: 'Regression detected',
          )).called(1);
    });

    test('IK-EXE-ROP-3: fails when issue number missing', () async {
      final result = await executor.executeWithoutTraversal(
        const CliArgs(),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('issue number'));
    });

    test('IK-EXE-ROP-4: handles service error', () async {
      when(() => mockService.reopenIssue(any(), note: any(named: 'note')))
          .thenThrow(Exception('Not found'));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(positionalArgs: ['999']),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Failed to reopen'));
    });
  });

  // ===========================================================================
  // IK-EXE-FAC: Factory function
  // ===========================================================================

  group('IK-EXE-FAC: createIssuekitExecutors [2026-02-13]', () {
    test('IK-EXE-FAC-1: creates all executors matching commands', () {
      final executors = createIssuekitExecutors(service: mockService);
      expect(executors.length, issuekitTool.commands.length);
    });

    test('IK-EXE-FAC-2: wired executors have correct types', () {
      final executors = createIssuekitExecutors(service: mockService);
      expect(executors['new'], isA<NewIssueExecutor>());
      expect(executors['edit'], isA<EditIssueExecutor>());
      expect(executors['show'], isA<ShowExecutor>());
      expect(executors['list'], isA<ListExecutor>());
      expect(executors['search'], isA<SearchExecutor>());
      expect(executors['close'], isA<CloseExecutor>());
      expect(executors['reopen'], isA<ReopenExecutor>());
    });

    test('IK-EXE-FAC-3: stub executors are still present', () {
      final executors = createIssuekitExecutors(service: mockService);
      expect(executors['analyze'], isA<AnalyzeExecutor>());
      expect(executors['assign'], isA<AssignExecutor>());
      expect(executors['testing'], isA<TestingExecutor>());
      expect(executors['verify'], isA<VerifyExecutor>());
      expect(executors['resolve'], isA<ResolveExecutor>());
      expect(executors['scan'], isA<ScanExecutor>());
      expect(executors['promote'], isA<PromoteExecutor>());
      expect(executors['validate'], isA<ValidateExecutor>());
      expect(executors['sync'], isA<SyncExecutor>());
    });
  });
}
