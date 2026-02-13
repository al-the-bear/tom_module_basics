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
  // IK-EXE-ANZ: AnalyzeExecutor
  // ===========================================================================

  group('IK-EXE-ANZ: AnalyzeExecutor [2026-02-13]', () {
    late AnalyzeExecutor executor;

    setUp(() {
      executor = AnalyzeExecutor(mockService);
    });

    test('IK-EXE-ANZ-1: analyzes issue with root cause only (→ ANALYZED)', () async {
      when(() => mockService.analyzeIssue(
            issueNumber: any(named: 'issueNumber'),
            rootCause: any(named: 'rootCause'),
            project: any(named: 'project'),
            module: any(named: 'module'),
            note: any(named: 'note'),
          )).thenAnswer((_) async => AnalyzeResult(
            issue: createTestIssue(number: 42, title: 'Parser crash'),
          ));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(
          positionalArgs: ['42'],
          extraOptions: {
            'root-cause': 'Missing empty check',
          },
        ),
      );

      expect(result.success, isTrue);
      expect(result.processedCount, 1);
      expect(result.itemResults.first.message, contains('#42'));
      expect(result.itemResults.first.message, contains('ANALYZED'));

      verify(() => mockService.analyzeIssue(
            issueNumber: 42,
            rootCause: 'Missing empty check',
            project: null,
            module: null,
            note: null,
          )).called(1);
    });

    test('IK-EXE-ANZ-2: analyzes with project (→ ASSIGNED + test entry)', () async {
      when(() => mockService.analyzeIssue(
            issueNumber: any(named: 'issueNumber'),
            rootCause: any(named: 'rootCause'),
            project: any(named: 'project'),
            module: any(named: 'module'),
            note: any(named: 'note'),
          )).thenAnswer((_) async => AnalyzeResult(
            issue: createTestIssue(number: 42, title: 'Parser crash'),
            testEntry: createTestIssue(number: 1, title: '[D4-42] Parser crash'),
          ));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(
          positionalArgs: ['42'],
          extraOptions: {
            'root-cause': 'Empty check missing',
            'project': 'D4',
            'module': 'parser',
          },
        ),
      );

      expect(result.success, isTrue);
      expect(result.itemResults.first.message, contains('ASSIGNED'));
      expect(result.itemResults.first.message, contains('Test entry created'));
    });

    test('IK-EXE-ANZ-3: returns failure when issue number missing', () async {
      final result = await executor.executeWithoutTraversal(
        const CliArgs(positionalArgs: []),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('issue number'));
    });

    test('IK-EXE-ANZ-4: returns failure on service exception', () async {
      when(() => mockService.analyzeIssue(
            issueNumber: any(named: 'issueNumber'),
            rootCause: any(named: 'rootCause'),
            project: any(named: 'project'),
            module: any(named: 'module'),
            note: any(named: 'note'),
          )).thenThrow(IssueServiceException('Issue not found'));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(positionalArgs: ['999']),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Issue not found'));
    });
  });

  // ===========================================================================
  // IK-EXE-ASN: AssignExecutor
  // ===========================================================================

  group('IK-EXE-ASN: AssignExecutor [2026-02-13]', () {
    late AssignExecutor executor;

    setUp(() {
      executor = AssignExecutor(mockService);
    });

    test('IK-EXE-ASN-1: assigns issue to project', () async {
      when(() => mockService.assignIssue(
            issueNumber: any(named: 'issueNumber'),
            project: any(named: 'project'),
            module: any(named: 'module'),
            assignee: any(named: 'assignee'),
          )).thenAnswer((_) async => AssignResult(
            issue: createAssignedIssue(number: 42),
            testEntry: createTestIssue(number: 1, title: '[D4-42] Parser crash'),
          ));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(
          positionalArgs: ['42'],
          extraOptions: {'project': 'D4'},
        ),
      );

      expect(result.success, isTrue);
      expect(result.processedCount, 1);
      expect(result.itemResults.first.message, contains('#42'));
      expect(result.itemResults.first.message, contains('D4'));
      expect(result.itemResults.first.message, contains('Test entry created'));

      verify(() => mockService.assignIssue(
            issueNumber: 42,
            project: 'D4',
            module: null,
            assignee: null,
          )).called(1);
    });

    test('IK-EXE-ASN-2: assigns with module and assignee', () async {
      when(() => mockService.assignIssue(
            issueNumber: any(named: 'issueNumber'),
            project: any(named: 'project'),
            module: any(named: 'module'),
            assignee: any(named: 'assignee'),
          )).thenAnswer((_) async => AssignResult(
            issue: createAssignedIssue(number: 42),
            testEntry: createTestIssue(number: 1),
          ));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(
          positionalArgs: ['42'],
          extraOptions: {
            'project': 'D4',
            'module': 'parser',
            'assignee': 'alexis',
          },
        ),
      );

      expect(result.success, isTrue);

      verify(() => mockService.assignIssue(
            issueNumber: 42,
            project: 'D4',
            module: 'parser',
            assignee: 'alexis',
          )).called(1);
    });

    test('IK-EXE-ASN-3: returns failure when issue number missing', () async {
      final result = await executor.executeWithoutTraversal(
        const CliArgs(positionalArgs: []),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('issue number'));
    });

    test('IK-EXE-ASN-4: returns failure when --project missing', () async {
      final result = await executor.executeWithoutTraversal(
        const CliArgs(positionalArgs: ['42']),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('--project'));
    });

    test('IK-EXE-ASN-5: returns failure on service exception', () async {
      when(() => mockService.assignIssue(
            issueNumber: any(named: 'issueNumber'),
            project: any(named: 'project'),
            module: any(named: 'module'),
            assignee: any(named: 'assignee'),
          )).thenThrow(IssueServiceException('Cannot reassign'));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(
          positionalArgs: ['42'],
          extraOptions: {'project': 'D4'},
        ),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Cannot reassign'));
    });
  });

  // ===========================================================================
  // IK-EXE-RSV: ResolveExecutor
  // ===========================================================================

  group('IK-EXE-RSV: ResolveExecutor [2026-02-13]', () {
    late ResolveExecutor executor;

    setUp(() {
      executor = ResolveExecutor(mockService);
    });

    test('IK-EXE-RSV-1: resolves issue with fix description', () async {
      when(() => mockService.resolveIssue(
            issueNumber: any(named: 'issueNumber'),
            fix: any(named: 'fix'),
            note: any(named: 'note'),
          )).thenAnswer((_) async => createTestIssue(
            number: 42,
            title: 'Parser crash',
            labels: [createTestLabel(name: 'resolved')],
          ));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(
          positionalArgs: ['42'],
          extraOptions: {'fix': 'Added empty check'},
        ),
      );

      expect(result.success, isTrue);
      expect(result.processedCount, 1);
      expect(result.itemResults.first.message, contains('#42'));
      expect(result.itemResults.first.message, contains('RESOLVED'));

      verify(() => mockService.resolveIssue(
            issueNumber: 42,
            fix: 'Added empty check',
            note: null,
          )).called(1);
    });

    test('IK-EXE-RSV-2: resolves with fix and note', () async {
      when(() => mockService.resolveIssue(
            issueNumber: any(named: 'issueNumber'),
            fix: any(named: 'fix'),
            note: any(named: 'note'),
          )).thenAnswer((_) async => createTestIssue(number: 42, title: 'Bug'));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(
          positionalArgs: ['42'],
          extraOptions: {
            'fix': 'Guard clause',
            'note': 'Also added docs',
          },
        ),
      );

      expect(result.success, isTrue);

      verify(() => mockService.resolveIssue(
            issueNumber: 42,
            fix: 'Guard clause',
            note: 'Also added docs',
          )).called(1);
    });

    test('IK-EXE-RSV-3: returns failure when issue number missing', () async {
      final result = await executor.executeWithoutTraversal(
        const CliArgs(positionalArgs: []),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('issue number'));
    });

    test('IK-EXE-RSV-4: returns failure when not in VERIFYING state', () async {
      when(() => mockService.resolveIssue(
            issueNumber: any(named: 'issueNumber'),
            fix: any(named: 'fix'),
            note: any(named: 'note'),
          )).thenThrow(IssueServiceException(
            'Cannot resolve issue #42: must be in VERIFYING state',
            code: 'NOT_VERIFYING',
          ));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(positionalArgs: ['42']),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('VERIFYING'));
    });
  });

  // ===========================================================================
  // IK-EXE-SUM: SummaryExecutor
  // ===========================================================================

  group('IK-EXE-SUM: SummaryExecutor [2026-02-13]', () {
    late SummaryExecutor executor;

    setUp(() {
      executor = SummaryExecutor(mockService);
    });

    test('IK-EXE-SUM-1: returns summary on success', () async {
      when(() => mockService.getSummary())
          .thenAnswer((_) async => IssueSummary(
                totalCount: 5,
                byState: {'new': 2, 'assigned': 3},
                bySeverity: {'high': 1, 'normal': 4},
                byProject: {'D4': 3, 'CR': 2},
                missingTests: 1,
                awaitingVerify: 2,
              ));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(),
      );

      expect(result.success, isTrue);
      expect(result.processedCount, 5);
      expect(result.itemResults.first.message, contains('Total: 5'));
      expect(result.itemResults.first.message, contains('NEW'));
      expect(result.itemResults.first.message, contains('Missing tests'));
    });

    test('IK-EXE-SUM-2: returns failure on exception', () async {
      when(() => mockService.getSummary())
          .thenThrow(Exception('API error'));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('summary'));
    });
  });

  // ===========================================================================
  // IK-EXE-LNK: LinkExecutor
  // ===========================================================================

  group('IK-EXE-LNK: LinkExecutor [2026-02-13]', () {
    late LinkExecutor executor;

    setUp(() {
      executor = LinkExecutor(mockService);
    });

    test('IK-EXE-LNK-1: links test on success', () async {
      when(() => mockService.linkTest(
            issueNumber: any(named: 'issueNumber'),
            testId: any(named: 'testId'),
            testFile: any(named: 'testFile'),
            note: any(named: 'note'),
          )).thenAnswer((_) async => createTestComment());

      final result = await executor.executeWithoutTraversal(
        const CliArgs(
          positionalArgs: ['42'],
          extraOptions: {
            'test-id': 'D4-42-PAR-7',
            'test-file': 'test/parser_test.dart',
          },
        ),
      );

      expect(result.success, isTrue);
      expect(result.itemResults.first.message, contains('D4-42-PAR-7'));
      expect(result.itemResults.first.message, contains('#42'));
    });

    test('IK-EXE-LNK-2: fails without issue number', () async {
      final result = await executor.executeWithoutTraversal(
        const CliArgs(
          extraOptions: {'test-id': 'D4-42-PAR-7'},
        ),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('issue number'));
    });

    test('IK-EXE-LNK-3: fails without test-id', () async {
      final result = await executor.executeWithoutTraversal(
        const CliArgs(
          positionalArgs: ['42'],
        ),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('test-id'));
    });

    test('IK-EXE-LNK-4: fails on service exception', () async {
      when(() => mockService.linkTest(
            issueNumber: any(named: 'issueNumber'),
            testId: any(named: 'testId'),
            testFile: any(named: 'testFile'),
            note: any(named: 'note'),
          )).thenThrow(Exception('Network error'));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(
          positionalArgs: ['42'],
          extraOptions: {'test-id': 'D4-42-PAR-7'},
        ),
      );

      expect(result.success, isFalse);
    });
  });

  // ===========================================================================
  // IK-EXE-EXP: ExportExecutor
  // ===========================================================================

  group('IK-EXE-EXP: ExportExecutor [2026-02-13]', () {
    late ExportExecutor executor;

    setUp(() {
      executor = ExportExecutor(mockService);
    });

    test('IK-EXE-EXP-1: exports issues and builds result', () async {
      when(() => mockService.exportIssues(
            repo: any(named: 'repo'),
            state: any(named: 'state'),
            severity: any(named: 'severity'),
            project: any(named: 'project'),
            tags: any(named: 'tags'),
            includeAll: any(named: 'includeAll'),
          )).thenAnswer((_) async => [
            createTestIssue(number: 1, title: 'Bug A'),
            createTestIssue(number: 2, title: 'Bug B'),
          ]);

      final result = await executor.executeWithoutTraversal(
        const CliArgs(),
      );

      expect(result.success, isTrue);
      expect(result.processedCount, 2);
      expect(result.itemResults[0].message, contains('#1'));
      expect(result.itemResults[1].message, contains('#2'));
    });

    test('IK-EXE-EXP-2: passes filters to service', () async {
      when(() => mockService.exportIssues(
            repo: any(named: 'repo'),
            state: any(named: 'state'),
            severity: any(named: 'severity'),
            project: any(named: 'project'),
            tags: any(named: 'tags'),
            includeAll: any(named: 'includeAll'),
          )).thenAnswer((_) async => []);

      await executor.executeWithoutTraversal(
        const CliArgs(
          extraOptions: {
            'repo': 'tests',
            'severity': 'high',
            'project': 'D4',
            'all': true,
          },
        ),
      );

      verify(() => mockService.exportIssues(
            repo: 'tests',
            state: null,
            severity: 'high',
            project: 'D4',
            tags: null,
            includeAll: true,
          )).called(1);
    });

    test('IK-EXE-EXP-3: fails on service exception', () async {
      when(() => mockService.exportIssues(
            repo: any(named: 'repo'),
            state: any(named: 'state'),
            severity: any(named: 'severity'),
            project: any(named: 'project'),
            tags: any(named: 'tags'),
            includeAll: any(named: 'includeAll'),
          )).thenThrow(Exception('API error'));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(),
      );

      expect(result.success, isFalse);
    });
  });

  // ===========================================================================
  // IK-EXE-IMP: ImportExecutor
  // ===========================================================================

  group('IK-EXE-IMP: ImportExecutor [2026-02-13]', () {
    late ImportExecutor executor;

    setUp(() {
      executor = ImportExecutor(mockService);
    });

    test('IK-EXE-IMP-1: reports file path in result', () async {
      final result = await executor.executeWithoutTraversal(
        const CliArgs(
          positionalArgs: ['issues.yaml'],
        ),
      );

      expect(result.success, isTrue);
      expect(result.itemResults.first.message, contains('issues.yaml'));
    });

    test('IK-EXE-IMP-2: fails without file path', () async {
      final result = await executor.executeWithoutTraversal(
        const CliArgs(),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('file path'));
    });

    test('IK-EXE-IMP-3: reports dry-run in message', () async {
      final result = await executor.executeWithoutTraversal(
        const CliArgs(
          positionalArgs: ['issues.yaml'],
          extraOptions: {'dry-run': true},
        ),
      );

      expect(result.success, isTrue);
      expect(result.itemResults.first.message, contains('Dry-run'));
    });
  });

  // ===========================================================================
  // IK-EXE-INIT: InitExecutor
  // ===========================================================================

  group('IK-EXE-INIT: InitExecutor [2026-02-13]', () {
    late InitExecutor executor;

    setUp(() {
      executor = InitExecutor(mockService);
    });

    test('IK-EXE-INIT-1: initializes labels on success', () async {
      when(() => mockService.initLabels(
            repo: any(named: 'repo'),
            force: any(named: 'force'),
          )).thenAnswer((_) async => InitResult(
            issuesLabelsCreated: 14,
            testsLabelsCreated: 4,
          ));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(),
      );

      expect(result.success, isTrue);
      expect(result.processedCount, 18);
      expect(result.itemResults.first.message, contains('14 issue labels'));
      expect(result.itemResults.first.message, contains('4 test labels'));
    });

    test('IK-EXE-INIT-2: passes repo and force options', () async {
      when(() => mockService.initLabels(
            repo: any(named: 'repo'),
            force: any(named: 'force'),
          )).thenAnswer((_) async => InitResult(
            issuesLabelsCreated: 14,
            testsLabelsCreated: 0,
          ));

      await executor.executeWithoutTraversal(
        const CliArgs(
          extraOptions: {'repo': 'issues', 'force': true},
        ),
      );

      verify(() => mockService.initLabels(
            repo: 'issues',
            force: true,
          )).called(1);
    });

    test('IK-EXE-INIT-3: fails on service exception', () async {
      when(() => mockService.initLabels(
            repo: any(named: 'repo'),
            force: any(named: 'force'),
          )).thenThrow(Exception('Permission denied'));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('initialize'));
    });
  });

  // ===========================================================================
  // IK-EXE-SNP: SnapshotExecutor
  // ===========================================================================

  group('IK-EXE-SNP: SnapshotExecutor [2026-02-13]', () {
    late SnapshotExecutor executor;

    setUp(() {
      executor = SnapshotExecutor(mockService);
    });

    test('IK-EXE-SNP-1: creates snapshot on success', () async {
      when(() => mockService.createSnapshot(
            issuesOnly: any(named: 'issuesOnly'),
            testsOnly: any(named: 'testsOnly'),
          )).thenAnswer((_) async => SnapshotResult(
            issues: [createTestIssue(), createTestIssue()],
            tests: [createTestIssue()],
            snapshotDate: DateTime(2026, 2, 13),
          ));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(),
      );

      expect(result.success, isTrue);
      expect(result.processedCount, 3);
      expect(result.itemResults.first.message, contains('2 issues'));
      expect(result.itemResults.first.message, contains('1 tests'));
    });

    test('IK-EXE-SNP-2: passes filter options', () async {
      when(() => mockService.createSnapshot(
            issuesOnly: any(named: 'issuesOnly'),
            testsOnly: any(named: 'testsOnly'),
          )).thenAnswer((_) async => SnapshotResult(
            issues: [],
            tests: null,
            snapshotDate: DateTime(2026, 2, 13),
          ));

      await executor.executeWithoutTraversal(
        const CliArgs(
          extraOptions: {'issues-only': true},
        ),
      );

      verify(() => mockService.createSnapshot(
            issuesOnly: true,
            testsOnly: false,
          )).called(1);
    });

    test('IK-EXE-SNP-3: fails on service exception', () async {
      when(() => mockService.createSnapshot(
            issuesOnly: any(named: 'issuesOnly'),
            testsOnly: any(named: 'testsOnly'),
          )).thenThrow(Exception('Timeout'));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(),
      );

      expect(result.success, isFalse);
    });
  });

  // ===========================================================================
  // IK-EXE-RT: RunTestsExecutor
  // ===========================================================================

  group('IK-EXE-RT: RunTestsExecutor [2026-02-13]', () {
    late RunTestsExecutor executor;

    setUp(() {
      executor = RunTestsExecutor(mockService);
    });

    test('IK-EXE-RT-1: triggers workflow on success', () async {
      when(() => mockService.triggerTestWorkflow(
            wait: any(named: 'wait'),
          )).thenAnswer((_) async {});

      final result = await executor.executeWithoutTraversal(
        const CliArgs(),
      );

      expect(result.success, isTrue);
      expect(result.processedCount, 1);
      expect(result.itemResults.first.message, contains('triggered'));
    });

    test('IK-EXE-RT-2: passes wait option', () async {
      when(() => mockService.triggerTestWorkflow(
            wait: any(named: 'wait'),
          )).thenAnswer((_) async {});

      final result = await executor.executeWithoutTraversal(
        const CliArgs(
          extraOptions: {'wait': true},
        ),
      );

      expect(result.success, isTrue);
      expect(result.itemResults.first.message, contains('waiting'));
      verify(() => mockService.triggerTestWorkflow(wait: true)).called(1);
    });

    test('IK-EXE-RT-3: fails on service exception', () async {
      when(() => mockService.triggerTestWorkflow(
            wait: any(named: 'wait'),
          )).thenThrow(Exception('GitHub error'));

      final result = await executor.executeWithoutTraversal(
        const CliArgs(),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('workflow'));
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
      expect(executors['analyze'], isA<AnalyzeExecutor>());
      expect(executors['assign'], isA<AssignExecutor>());
      expect(executors['resolve'], isA<ResolveExecutor>());
      expect(executors['summary'], isA<SummaryExecutor>());
      expect(executors['link'], isA<LinkExecutor>());
      expect(executors['export'], isA<ExportExecutor>());
      expect(executors['import'], isA<ImportExecutor>());
      expect(executors['init'], isA<InitExecutor>());
      expect(executors['snapshot'], isA<SnapshotExecutor>());
      expect(executors['run-tests'], isA<RunTestsExecutor>());
    });

    test('IK-EXE-FAC-3: stub executors are still present', () {
      final executors = createIssuekitExecutors(service: mockService);
      expect(executors['testing'], isA<TestingExecutor>());
      expect(executors['verify'], isA<VerifyExecutor>());
      expect(executors['scan'], isA<ScanExecutor>());
      expect(executors['promote'], isA<PromoteExecutor>());
      expect(executors['validate'], isA<ValidateExecutor>());
      expect(executors['sync'], isA<SyncExecutor>());
    });
  });
}
