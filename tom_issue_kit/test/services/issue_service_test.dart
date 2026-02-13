/// Unit tests for IssueService.
///
/// Tests the high-level issue operations using mocked GitHubApiClient.
@TestOn('vm')
library;

import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:tom_issue_kit/src/services/issue_service.dart';

import '../helpers/fixtures.dart';

void main() {
  late MockGitHubApiClient mockClient;
  late IssueService service;

  setUp(() {
    mockClient = MockGitHubApiClient();
    service = IssueService(
      client: mockClient,
      issuesRepo: 'al-the-bear/tom_issues',
      testsRepo: 'al-the-bear/tom_tests',
    );
  });

  tearDown(() {
    // Note: mockClient.close() is not needed for mocks
  });

  group('IK-NEW: createIssue [2026-02-13]', () {
    test('IK-NEW-1: creates issue with title only', () async {
      when(() => mockClient.createIssue(
            repoSlug: any(named: 'repoSlug'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            labels: any(named: 'labels'),
            assignee: any(named: 'assignee'),
          )).thenAnswer((_) async => createTestIssue(
            number: 42,
            title: 'Memory leak in server',
            labels: [
              createTestLabel(name: 'new'),
              createTestLabel(name: 'severity:normal'),
            ],
          ));

      final result = await service.createIssue(
        title: 'Memory leak in server',
      );

      expect(result.issue.number, 42);
      expect(result.issue.title, 'Memory leak in server');
      expect(result.testEntry, isNull);

      verify(() => mockClient.createIssue(
            repoSlug: 'al-the-bear/tom_issues',
            title: 'Memory leak in server',
            body: any(named: 'body'),
            labels: ['new', 'severity:normal'],
            assignee: null,
          )).called(1);
    });

    test('IK-NEW-2: creates issue with severity', () async {
      when(() => mockClient.createIssue(
            repoSlug: any(named: 'repoSlug'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            labels: any(named: 'labels'),
            assignee: any(named: 'assignee'),
          )).thenAnswer((_) async => createTestIssue(
            number: 43,
            title: 'Critical bug',
            labels: [
              createTestLabel(name: 'new'),
              createTestLabel(name: 'severity:critical'),
            ],
          ));

      final result = await service.createIssue(
        title: 'Critical bug',
        severity: 'critical',
      );

      expect(result.issue.number, 43);

      verify(() => mockClient.createIssue(
            repoSlug: 'al-the-bear/tom_issues',
            title: 'Critical bug',
            body: any(named: 'body'),
            labels: ['new', 'severity:critical'],
            assignee: null,
          )).called(1);
    });

    test('IK-NEW-3: creates issue with context and expected', () async {
      when(() => mockClient.createIssue(
            repoSlug: any(named: 'repoSlug'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            labels: any(named: 'labels'),
            assignee: any(named: 'assignee'),
          )).thenAnswer((_) async => createTestIssue(number: 44));

      await service.createIssue(
        title: 'Parser fails',
        context: 'Seen during stress test',
        expected: 'Should handle gracefully',
      );

      final captured = verify(() => mockClient.createIssue(
            repoSlug: 'al-the-bear/tom_issues',
            title: 'Parser fails',
            body: captureAny(named: 'body'),
            labels: any(named: 'labels'),
            assignee: null,
          )).captured;

      final body = captured.first as String;
      expect(body, contains('## Symptom'));
      expect(body, contains('## Context'));
      expect(body, contains('Seen during stress test'));
      expect(body, contains('## Expected'));
      expect(body, contains('Should handle gracefully'));
    });

    test('IK-NEW-4: creates issue with tags', () async {
      when(() => mockClient.createIssue(
            repoSlug: any(named: 'repoSlug'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            labels: any(named: 'labels'),
            assignee: any(named: 'assignee'),
          )).thenAnswer((_) async => createTestIssue(number: 45));

      await service.createIssue(
        title: 'Bug with tags',
        tags: ['parser', 'regression'],
      );

      verify(() => mockClient.createIssue(
            repoSlug: 'al-the-bear/tom_issues',
            title: 'Bug with tags',
            body: any(named: 'body'),
            labels: ['new', 'severity:normal', 'parser', 'regression'],
            assignee: null,
          )).called(1);
    });

    test('IK-NEW-5: creates issue with reporter', () async {
      when(() => mockClient.createIssue(
            repoSlug: any(named: 'repoSlug'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            labels: any(named: 'labels'),
            assignee: any(named: 'assignee'),
          )).thenAnswer((_) async => createTestIssue(number: 46));

      await service.createIssue(
        title: 'Copilot found bug',
        reporter: 'copilot',
      );

      verify(() => mockClient.createIssue(
            repoSlug: 'al-the-bear/tom_issues',
            title: 'Copilot found bug',
            body: any(named: 'body'),
            labels: ['new', 'severity:normal', 'reporter:copilot'],
            assignee: null,
          )).called(1);
    });

    test('IK-NEW-6: creates issue with --project skips to ASSIGNED', () async {
      // First call creates the issue
      when(() => mockClient.createIssue(
            repoSlug: 'al-the-bear/tom_issues',
            title: any(named: 'title'),
            body: any(named: 'body'),
            labels: any(named: 'labels'),
            assignee: any(named: 'assignee'),
          )).thenAnswer((_) async => createTestIssue(
            number: 47,
            labels: [
              createTestLabel(name: 'assigned'),
              createTestLabel(name: 'severity:high'),
              createTestLabel(name: 'project:D4'),
            ],
          ));

      // Second call creates the test entry
      when(() => mockClient.createIssue(
            repoSlug: 'al-the-bear/tom_tests',
            title: any(named: 'title'),
            body: any(named: 'body'),
            labels: any(named: 'labels'),
            assignee: any(named: 'assignee'),
          )).thenAnswer((_) async => createTestIssue(
            number: 1,
            title: '[D4-47] Parser bug',
          ));

      final result = await service.createIssue(
        title: 'Parser bug',
        severity: 'high',
        project: 'D4',
      );

      expect(result.issue.number, 47);
      expect(result.testEntry, isNotNull);
      expect(result.testEntry!.title, contains('D4-47'));

      // Verify issue created with 'assigned' not 'new'
      verify(() => mockClient.createIssue(
            repoSlug: 'al-the-bear/tom_issues',
            title: 'Parser bug',
            body: any(named: 'body'),
            labels: ['assigned', 'severity:high', 'project:D4'],
            assignee: null,
          )).called(1);

      // Verify test entry created
      verify(() => mockClient.createIssue(
            repoSlug: 'al-the-bear/tom_tests',
            title: '[D4-47] Parser bug',
            body: any(named: 'body'),
            labels: ['stub', 'project:D4'],
            assignee: null,
          )).called(1);
    });
  });

  group('IK-SHW: getIssue [2026-02-13]', () {
    test('IK-SHW-1: gets issue by number', () async {
      when(() => mockClient.getIssue(
            repoSlug: any(named: 'repoSlug'),
            number: any(named: 'number'),
            owner: any(named: 'owner'),
            repo: any(named: 'repo'),
          )).thenAnswer((_) async => createTestIssue(
            number: 42,
            title: 'Test issue',
          ));

      final issue = await service.getIssue(42);

      expect(issue.number, 42);
      expect(issue.title, 'Test issue');

      verify(() => mockClient.getIssue(
            repoSlug: 'al-the-bear/tom_issues',
            number: 42,
          )).called(1);
    });
  });

  group('IK-LST: listIssues [2026-02-13]', () {
    test('IK-LST-1: lists all open issues', () async {
      when(() => mockClient.listAllIssues(
            repoSlug: any(named: 'repoSlug'),
            state: any(named: 'state'),
            labels: any(named: 'labels'),
            sort: any(named: 'sort'),
            direction: any(named: 'direction'),
            since: any(named: 'since'),
            owner: any(named: 'owner'),
            repo: any(named: 'repo'),
          )).thenAnswer((_) async => [
            createTestIssue(number: 1),
            createTestIssue(number: 2),
          ]);

      final issues = await service.listIssues();

      expect(issues.length, 2);

      verify(() => mockClient.listAllIssues(
            repoSlug: 'al-the-bear/tom_issues',
            state: 'open',
            labels: null,
            sort: null,
          )).called(1);
    });

    test('IK-LST-2: lists issues by state', () async {
      when(() => mockClient.listAllIssues(
            repoSlug: any(named: 'repoSlug'),
            state: any(named: 'state'),
            labels: any(named: 'labels'),
            sort: any(named: 'sort'),
            direction: any(named: 'direction'),
            since: any(named: 'since'),
            owner: any(named: 'owner'),
            repo: any(named: 'repo'),
          )).thenAnswer((_) async => [createNewIssue()]);

      await service.listIssues(state: 'new');

      verify(() => mockClient.listAllIssues(
            repoSlug: 'al-the-bear/tom_issues',
            state: 'open',
            labels: ['new'],
            sort: null,
          )).called(1);
    });

    test('IK-LST-3: lists issues by severity', () async {
      when(() => mockClient.listAllIssues(
            repoSlug: any(named: 'repoSlug'),
            state: any(named: 'state'),
            labels: any(named: 'labels'),
            sort: any(named: 'sort'),
            direction: any(named: 'direction'),
            since: any(named: 'since'),
            owner: any(named: 'owner'),
            repo: any(named: 'repo'),
          )).thenAnswer((_) async => []);

      await service.listIssues(severity: 'critical');

      verify(() => mockClient.listAllIssues(
            repoSlug: 'al-the-bear/tom_issues',
            state: 'open',
            labels: ['severity:critical'],
            sort: null,
          )).called(1);
    });

    test('IK-LST-4: lists issues including closed', () async {
      when(() => mockClient.listAllIssues(
            repoSlug: any(named: 'repoSlug'),
            state: any(named: 'state'),
            labels: any(named: 'labels'),
            sort: any(named: 'sort'),
            direction: any(named: 'direction'),
            since: any(named: 'since'),
            owner: any(named: 'owner'),
            repo: any(named: 'repo'),
          )).thenAnswer((_) async => []);

      await service.listIssues(includeAll: true);

      verify(() => mockClient.listAllIssues(
            repoSlug: 'al-the-bear/tom_issues',
            state: 'all',
            labels: null,
            sort: null,
          )).called(1);
    });
  });

  group('IK-SRC: searchIssues [2026-02-13]', () {
    test('IK-SRC-1: searches issues by query', () async {
      when(() => mockClient.searchIssues(
            query: any(named: 'query'),
            sort: any(named: 'sort'),
            order: any(named: 'order'),
            perPage: any(named: 'perPage'),
            page: any(named: 'page'),
          )).thenAnswer((_) async => createTestSearchResult());

      final result = await service.searchIssues(query: 'RangeError');

      expect(result.totalCount, 1);

      verify(() => mockClient.searchIssues(
            query: 'RangeError repo:al-the-bear/tom_issues is:issue',
          )).called(1);
    });

    test('IK-SRC-2: searches in tests repo', () async {
      when(() => mockClient.searchIssues(
            query: any(named: 'query'),
            sort: any(named: 'sort'),
            order: any(named: 'order'),
            perPage: any(named: 'perPage'),
            page: any(named: 'page'),
          )).thenAnswer((_) async => createTestSearchResult());

      await service.searchIssues(query: 'parser', repo: 'tests');

      verify(() => mockClient.searchIssues(
            query: 'parser repo:al-the-bear/tom_tests is:issue',
          )).called(1);
    });
  });

  group('IK-CLS: closeIssue [2026-02-13]', () {
    test('IK-CLS-1: closes resolved issue', () async {
      when(() => mockClient.getIssue(
            repoSlug: any(named: 'repoSlug'),
            number: any(named: 'number'),
            owner: any(named: 'owner'),
            repo: any(named: 'repo'),
          )).thenAnswer((_) async => createTestIssue(
            number: 42,
            labels: [createTestLabel(name: 'resolved')],
          ));

      when(() => mockClient.closeIssue(
            repoSlug: any(named: 'repoSlug'),
            number: any(named: 'number'),
            owner: any(named: 'owner'),
            repo: any(named: 'repo'),
          )).thenAnswer((_) async => createClosedIssue(number: 42));

      final issue = await service.closeIssue(42);

      expect(issue.state, 'closed');
    });

    test('IK-CLS-2: throws when issue is not resolved', () async {
      when(() => mockClient.getIssue(
            repoSlug: any(named: 'repoSlug'),
            number: any(named: 'number'),
            owner: any(named: 'owner'),
            repo: any(named: 'repo'),
          )).thenAnswer((_) async => createTestIssue(
            number: 42,
            labels: [createTestLabel(name: 'testing')],
          ));

      expect(
        () => service.closeIssue(42),
        throwsA(isA<IssueServiceException>()),
      );
    });
  });

  group('IK-ROP: reopenIssue [2026-02-13]', () {
    test('IK-ROP-1: reopens closed issue', () async {
      when(() => mockClient.reopenIssue(
            repoSlug: any(named: 'repoSlug'),
            number: any(named: 'number'),
            owner: any(named: 'owner'),
            repo: any(named: 'repo'),
          )).thenAnswer((_) async => createTestIssue(
            number: 42,
            labels: [createTestLabel(name: 'resolved')],
          ));

      when(() => mockClient.updateIssue(
            repoSlug: any(named: 'repoSlug'),
            number: any(named: 'number'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            state: any(named: 'state'),
            labels: any(named: 'labels'),
            assignee: any(named: 'assignee'),
            owner: any(named: 'owner'),
            repo: any(named: 'repo'),
          )).thenAnswer((_) async => createNewIssue(number: 42));

      final issue = await service.reopenIssue(42);

      expect(issue.labels.any((l) => l.name == 'new'), isTrue);
    });

    test('IK-ROP-2: reopens with note adds comment', () async {
      when(() => mockClient.reopenIssue(
            repoSlug: any(named: 'repoSlug'),
            number: any(named: 'number'),
            owner: any(named: 'owner'),
            repo: any(named: 'repo'),
          )).thenAnswer((_) async => createTestIssue(number: 42));

      when(() => mockClient.updateIssue(
            repoSlug: any(named: 'repoSlug'),
            number: any(named: 'number'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            state: any(named: 'state'),
            labels: any(named: 'labels'),
            assignee: any(named: 'assignee'),
            owner: any(named: 'owner'),
            repo: any(named: 'repo'),
          )).thenAnswer((_) async => createNewIssue(number: 42));

      when(() => mockClient.addComment(
            repoSlug: any(named: 'repoSlug'),
            issueNumber: any(named: 'issueNumber'),
            body: any(named: 'body'),
            owner: any(named: 'owner'),
            repo: any(named: 'repo'),
          )).thenAnswer((_) async => createTestComment());

      await service.reopenIssue(42, note: 'Fix was incomplete');

      verify(() => mockClient.addComment(
            repoSlug: 'al-the-bear/tom_issues',
            issueNumber: 42,
            body: '**Reopened**: Fix was incomplete',
          )).called(1);
    });
  });

  group('IK-EDT: updateIssue [2026-02-13]', () {
    test('IK-EDT-1: updates issue title', () async {
      when(() => mockClient.getIssue(
            repoSlug: any(named: 'repoSlug'),
            number: any(named: 'number'),
            owner: any(named: 'owner'),
            repo: any(named: 'repo'),
          )).thenAnswer((_) async => createTestIssue(number: 42));

      when(() => mockClient.updateIssue(
            repoSlug: any(named: 'repoSlug'),
            number: any(named: 'number'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            state: any(named: 'state'),
            labels: any(named: 'labels'),
            assignee: any(named: 'assignee'),
            owner: any(named: 'owner'),
            repo: any(named: 'repo'),
          )).thenAnswer((_) async => createTestIssue(
            number: 42,
            title: 'Updated title',
          ));

      final issue = await service.updateIssue(
        issueNumber: 42,
        title: 'Updated title',
      );

      expect(issue.title, 'Updated title');
    });

    test('IK-EDT-2: updates issue severity', () async {
      when(() => mockClient.getIssue(
            repoSlug: any(named: 'repoSlug'),
            number: any(named: 'number'),
            owner: any(named: 'owner'),
            repo: any(named: 'repo'),
          )).thenAnswer((_) async => createTestIssue(
            number: 42,
            labels: [
              createTestLabel(name: 'new'),
              createTestLabel(name: 'severity:normal'),
            ],
          ));

      when(() => mockClient.updateIssue(
            repoSlug: any(named: 'repoSlug'),
            number: any(named: 'number'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            state: any(named: 'state'),
            labels: any(named: 'labels'),
            assignee: any(named: 'assignee'),
            owner: any(named: 'owner'),
            repo: any(named: 'repo'),
          )).thenAnswer((_) async => createTestIssue(number: 42));

      await service.updateIssue(
        issueNumber: 42,
        severity: 'critical',
      );

      final captured = verify(() => mockClient.updateIssue(
            repoSlug: 'al-the-bear/tom_issues',
            number: 42,
            title: null,
            labels: captureAny(named: 'labels'),
            assignee: null,
          )).captured;

      final labels = captured.first as List<String>;
      expect(labels, contains('severity:critical'));
      expect(labels, isNot(contains('severity:normal')));
    });
  });

  // ===========================================================================
  // IK-ANZ: analyzeIssue
  // ===========================================================================

  group('IK-ANZ: analyzeIssue [2026-02-13]', () {
    test('IK-ANZ-1: analyze without project transitions to ANALYZED', () async {
      // Stub addComment
      when(() => mockClient.addComment(
            repoSlug: any(named: 'repoSlug'),
            issueNumber: any(named: 'issueNumber'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => createTestComment());

      // Stub getIssue
      when(() => mockClient.getIssue(
            repoSlug: any(named: 'repoSlug'),
            number: any(named: 'number'),
          )).thenAnswer((_) async => createNewIssue(number: 42));

      // Stub updateIssue
      when(() => mockClient.updateIssue(
            repoSlug: any(named: 'repoSlug'),
            number: any(named: 'number'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            state: any(named: 'state'),
            labels: any(named: 'labels'),
            assignee: any(named: 'assignee'),
            owner: any(named: 'owner'),
            repo: any(named: 'repo'),
          )).thenAnswer((_) async => createTestIssue(
            number: 42,
            labels: [createTestLabel(name: 'analyzed')],
          ));

      final result = await service.analyzeIssue(
        issueNumber: 42,
        rootCause: 'Parser does not handle empty arrays',
        note: 'Likely in _parseArrayElements()',
      );

      expect(result.issue.number, 42);
      expect(result.testEntry, isNull);

      // Verify comment was posted
      verify(() => mockClient.addComment(
            repoSlug: 'al-the-bear/tom_issues',
            issueNumber: 42,
            body: any(named: 'body'),
          )).called(1);

      // Verify labels updated to analyzed state
      final captured = verify(() => mockClient.updateIssue(
            repoSlug: 'al-the-bear/tom_issues',
            number: 42,
            labels: captureAny(named: 'labels'),
          )).captured;

      final labels = captured.first as List<String>;
      expect(labels, contains('analyzed'));
      expect(labels, isNot(contains('new')));
    });

    test('IK-ANZ-2: analyze with project transitions to ASSIGNED and creates test entry', () async {
      // Stub addComment
      when(() => mockClient.addComment(
            repoSlug: any(named: 'repoSlug'),
            issueNumber: any(named: 'issueNumber'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => createTestComment());

      // Stub getIssue
      when(() => mockClient.getIssue(
            repoSlug: any(named: 'repoSlug'),
            number: any(named: 'number'),
          )).thenAnswer((_) async => createNewIssue(number: 42));

      // Stub updateIssue
      when(() => mockClient.updateIssue(
            repoSlug: any(named: 'repoSlug'),
            number: any(named: 'number'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            state: any(named: 'state'),
            labels: any(named: 'labels'),
            assignee: any(named: 'assignee'),
            owner: any(named: 'owner'),
            repo: any(named: 'repo'),
          )).thenAnswer((_) async => createTestIssue(
            number: 42,
            labels: [
              createTestLabel(name: 'assigned'),
              createTestLabel(name: 'project:D4'),
            ],
          ));

      // Stub createIssue for test entry
      when(() => mockClient.createIssue(
            repoSlug: 'al-the-bear/tom_tests',
            title: any(named: 'title'),
            body: any(named: 'body'),
            labels: any(named: 'labels'),
            assignee: any(named: 'assignee'),
          )).thenAnswer((_) async => createTestIssue(
            number: 1,
            title: '[D4-42] Array parser crashes on empty arrays',
          ));

      final result = await service.analyzeIssue(
        issueNumber: 42,
        rootCause: 'Missing empty check in parser',
        project: 'D4',
        module: 'parser',
      );

      expect(result.issue.number, 42);
      expect(result.testEntry, isNotNull);
      expect(result.testEntry!.number, 1);

      // Verify labels have assigned + project
      final captured = verify(() => mockClient.updateIssue(
            repoSlug: 'al-the-bear/tom_issues',
            number: 42,
            labels: captureAny(named: 'labels'),
          )).captured;

      final labels = captured.first as List<String>;
      expect(labels, contains('assigned'));
      expect(labels, contains('project:D4'));

      // Verify test entry creation in tom_tests
      verify(() => mockClient.createIssue(
            repoSlug: 'al-the-bear/tom_tests',
            title: any(named: 'title'),
            body: any(named: 'body'),
            labels: any(named: 'labels'),
            assignee: null,
          )).called(1);
    });

    test('IK-ANZ-3: analysis comment contains root cause and note', () async {
      when(() => mockClient.addComment(
            repoSlug: any(named: 'repoSlug'),
            issueNumber: any(named: 'issueNumber'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => createTestComment());
      when(() => mockClient.getIssue(
            repoSlug: any(named: 'repoSlug'),
            number: any(named: 'number'),
          )).thenAnswer((_) async => createNewIssue(number: 42));
      when(() => mockClient.updateIssue(
            repoSlug: any(named: 'repoSlug'),
            number: any(named: 'number'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            state: any(named: 'state'),
            labels: any(named: 'labels'),
            assignee: any(named: 'assignee'),
            owner: any(named: 'owner'),
            repo: any(named: 'repo'),
          )).thenAnswer((_) async => createTestIssue(number: 42));

      await service.analyzeIssue(
        issueNumber: 42,
        rootCause: 'Buffer overflow in parser',
        note: 'Needs further investigation',
      );

      final captured = verify(() => mockClient.addComment(
            repoSlug: 'al-the-bear/tom_issues',
            issueNumber: 42,
            body: captureAny(named: 'body'),
          )).captured;

      final body = captured.first as String;
      expect(body, contains('## Analysis'));
      expect(body, contains('Buffer overflow in parser'));
      expect(body, contains('Needs further investigation'));
    });
  });

  // ===========================================================================
  // IK-ASN: assignIssue
  // ===========================================================================

  group('IK-ASN: assignIssue [2026-02-13]', () {
    test('IK-ASN-1: assigns issue to project and creates test entry', () async {
      // Stub getIssue
      when(() => mockClient.getIssue(
            repoSlug: any(named: 'repoSlug'),
            number: any(named: 'number'),
          )).thenAnswer((_) async => createNewIssue(number: 42));

      // Stub updateIssue
      when(() => mockClient.updateIssue(
            repoSlug: any(named: 'repoSlug'),
            number: any(named: 'number'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            state: any(named: 'state'),
            labels: any(named: 'labels'),
            assignee: any(named: 'assignee'),
            owner: any(named: 'owner'),
            repo: any(named: 'repo'),
          )).thenAnswer((_) async => createAssignedIssue(number: 42));

      // Stub createIssue for test entry
      when(() => mockClient.createIssue(
            repoSlug: 'al-the-bear/tom_tests',
            title: any(named: 'title'),
            body: any(named: 'body'),
            labels: any(named: 'labels'),
            assignee: any(named: 'assignee'),
          )).thenAnswer((_) async => createTestIssue(
            number: 1,
            title: '[D4-42] Array parser crashes',
          ));

      // Stub addComment
      when(() => mockClient.addComment(
            repoSlug: any(named: 'repoSlug'),
            issueNumber: any(named: 'issueNumber'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => createTestComment());

      final result = await service.assignIssue(
        issueNumber: 42,
        project: 'D4',
      );

      expect(result.issue.number, 42);
      expect(result.testEntry.number, 1);

      // Verify labels updated to assigned with project
      final captured = verify(() => mockClient.updateIssue(
            repoSlug: 'al-the-bear/tom_issues',
            number: 42,
            labels: captureAny(named: 'labels'),
            assignee: null,
          )).captured;

      final labels = captured.first as List<String>;
      expect(labels, contains('assigned'));
      expect(labels, contains('project:D4'));
    });

    test('IK-ASN-2: assign with module and assignee', () async {
      when(() => mockClient.getIssue(
            repoSlug: any(named: 'repoSlug'),
            number: any(named: 'number'),
          )).thenAnswer((_) async => createNewIssue(number: 42));
      when(() => mockClient.updateIssue(
            repoSlug: any(named: 'repoSlug'),
            number: any(named: 'number'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            state: any(named: 'state'),
            labels: any(named: 'labels'),
            assignee: any(named: 'assignee'),
            owner: any(named: 'owner'),
            repo: any(named: 'repo'),
          )).thenAnswer((_) async => createAssignedIssue(number: 42));
      when(() => mockClient.createIssue(
            repoSlug: 'al-the-bear/tom_tests',
            title: any(named: 'title'),
            body: any(named: 'body'),
            labels: any(named: 'labels'),
            assignee: any(named: 'assignee'),
          )).thenAnswer((_) async => createTestIssue(number: 1));
      when(() => mockClient.addComment(
            repoSlug: any(named: 'repoSlug'),
            issueNumber: any(named: 'issueNumber'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => createTestComment());

      await service.assignIssue(
        issueNumber: 42,
        project: 'D4',
        module: 'parser',
        assignee: 'alexis',
      );

      // Verify assignee passed to updateIssue
      verify(() => mockClient.updateIssue(
            repoSlug: 'al-the-bear/tom_issues',
            number: 42,
            labels: any(named: 'labels'),
            assignee: 'alexis',
          )).called(1);

      // Verify assignment comment contains module info
      final captured = verify(() => mockClient.addComment(
            repoSlug: 'al-the-bear/tom_issues',
            issueNumber: 42,
            body: captureAny(named: 'body'),
          )).captured;

      final body = captured.first as String;
      expect(body, contains('D4'));
      expect(body, contains('parser'));
      expect(body, contains('alexis'));
    });

    test('IK-ASN-3: test entry includes module label when specified', () async {
      when(() => mockClient.getIssue(
            repoSlug: any(named: 'repoSlug'),
            number: any(named: 'number'),
          )).thenAnswer((_) async => createNewIssue(number: 42));
      when(() => mockClient.updateIssue(
            repoSlug: any(named: 'repoSlug'),
            number: any(named: 'number'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            state: any(named: 'state'),
            labels: any(named: 'labels'),
            assignee: any(named: 'assignee'),
            owner: any(named: 'owner'),
            repo: any(named: 'repo'),
          )).thenAnswer((_) async => createAssignedIssue(number: 42));
      when(() => mockClient.createIssue(
            repoSlug: 'al-the-bear/tom_tests',
            title: any(named: 'title'),
            body: any(named: 'body'),
            labels: any(named: 'labels'),
            assignee: any(named: 'assignee'),
          )).thenAnswer((_) async => createTestIssue(number: 1));
      when(() => mockClient.addComment(
            repoSlug: any(named: 'repoSlug'),
            issueNumber: any(named: 'issueNumber'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => createTestComment());

      await service.assignIssue(
        issueNumber: 42,
        project: 'D4',
        module: 'parser',
      );

      // Verify test entry created with module label
      final captured = verify(() => mockClient.createIssue(
            repoSlug: 'al-the-bear/tom_tests',
            title: any(named: 'title'),
            body: any(named: 'body'),
            labels: captureAny(named: 'labels'),
            assignee: null,
          )).captured;

      final labels = captured.first as List<String>;
      expect(labels, contains('stub'));
      expect(labels, contains('project:D4'));
      expect(labels, contains('module:parser'));
    });
  });

  // ===========================================================================
  // IK-RSV: resolveIssue
  // ===========================================================================

  group('IK-RSV: resolveIssue [2026-02-13]', () {
    test('IK-RSV-1: resolves verifying issue to RESOLVED', () async {
      // Stub getIssue — must be in VERIFYING state
      when(() => mockClient.getIssue(
            repoSlug: any(named: 'repoSlug'),
            number: any(named: 'number'),
          )).thenAnswer((_) async => createTestIssue(
            number: 42,
            labels: [
              createTestLabel(name: 'verifying'),
              createTestLabel(name: 'severity:high'),
            ],
          ));

      // Stub updateIssue
      when(() => mockClient.updateIssue(
            repoSlug: any(named: 'repoSlug'),
            number: any(named: 'number'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            state: any(named: 'state'),
            labels: any(named: 'labels'),
            assignee: any(named: 'assignee'),
            owner: any(named: 'owner'),
            repo: any(named: 'repo'),
          )).thenAnswer((_) async => createTestIssue(
            number: 42,
            labels: [createTestLabel(name: 'resolved')],
          ));

      // Stub addComment
      when(() => mockClient.addComment(
            repoSlug: any(named: 'repoSlug'),
            issueNumber: any(named: 'issueNumber'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => createTestComment());

      final resolved = await service.resolveIssue(
        issueNumber: 42,
        fix: 'Added empty check in ArrayParser',
      );

      expect(resolved.number, 42);

      // Verify labels updated to resolved
      final captured = verify(() => mockClient.updateIssue(
            repoSlug: 'al-the-bear/tom_issues',
            number: 42,
            labels: captureAny(named: 'labels'),
          )).captured;

      final labels = captured.first as List<String>;
      expect(labels, contains('resolved'));
      expect(labels, isNot(contains('verifying')));
    });

    test('IK-RSV-2: throws if issue is not in VERIFYING state', () async {
      when(() => mockClient.getIssue(
            repoSlug: any(named: 'repoSlug'),
            number: any(named: 'number'),
          )).thenAnswer((_) async => createTestingIssue(number: 42));

      expect(
        () => service.resolveIssue(issueNumber: 42),
        throwsA(isA<IssueServiceException>().having(
          (e) => e.code,
          'code',
          'NOT_VERIFYING',
        )),
      );
    });

    test('IK-RSV-3: resolution comment contains fix and note', () async {
      when(() => mockClient.getIssue(
            repoSlug: any(named: 'repoSlug'),
            number: any(named: 'number'),
          )).thenAnswer((_) async => createTestIssue(
            number: 42,
            labels: [createTestLabel(name: 'verifying')],
          ));
      when(() => mockClient.updateIssue(
            repoSlug: any(named: 'repoSlug'),
            number: any(named: 'number'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            state: any(named: 'state'),
            labels: any(named: 'labels'),
            assignee: any(named: 'assignee'),
            owner: any(named: 'owner'),
            repo: any(named: 'repo'),
          )).thenAnswer((_) async => createTestIssue(number: 42));
      when(() => mockClient.addComment(
            repoSlug: any(named: 'repoSlug'),
            issueNumber: any(named: 'issueNumber'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => createTestComment());

      await service.resolveIssue(
        issueNumber: 42,
        fix: 'Added null guard',
        note: 'Also documented the edge case',
      );

      final captured = verify(() => mockClient.addComment(
            repoSlug: 'al-the-bear/tom_issues',
            issueNumber: 42,
            body: captureAny(named: 'body'),
          )).captured;

      final body = captured.first as String;
      expect(body, contains('## Resolved'));
      expect(body, contains('Added null guard'));
      expect(body, contains('Also documented the edge case'));
    });
  });

  // ===========================================================================
  // IK-SUM: getSummary
  // ===========================================================================

  group('IK-SUM: getSummary [2026-02-13]', () {
    test('IK-SUM-1: aggregates issues by state, severity, project', () async {
      when(() => mockClient.listAllIssues(
            repoSlug: any(named: 'repoSlug'),
            state: any(named: 'state'),
            labels: any(named: 'labels'),
            sort: any(named: 'sort'),
          )).thenAnswer((_) async => [
            createTestIssue(
              number: 1,
              labels: [
                createTestLabel(name: 'new'),
                createTestLabel(name: 'severity:high'),
              ],
            ),
            createTestIssue(
              number: 2,
              labels: [
                createTestLabel(name: 'assigned'),
                createTestLabel(name: 'severity:normal'),
                createTestLabel(name: 'project:D4'),
              ],
            ),
            createTestIssue(
              number: 3,
              labels: [
                createTestLabel(name: 'testing'),
                createTestLabel(name: 'severity:high'),
                createTestLabel(name: 'project:D4'),
              ],
            ),
            createTestIssue(
              number: 4,
              labels: [
                createTestLabel(name: 'verifying'),
                createTestLabel(name: 'severity:critical'),
                createTestLabel(name: 'project:CR'),
              ],
            ),
          ]);

      final summary = await service.getSummary();

      expect(summary.totalCount, 4);
      expect(summary.byState['new'], 1);
      expect(summary.byState['assigned'], 1);
      expect(summary.byState['testing'], 1);
      expect(summary.byState['verifying'], 1);
      expect(summary.bySeverity['high'], 2);
      expect(summary.bySeverity['normal'], 1);
      expect(summary.bySeverity['critical'], 1);
      expect(summary.byProject['D4'], 2);
      expect(summary.byProject['CR'], 1);
      expect(summary.missingTests, 1); // #2 is ASSIGNED without TESTING
      expect(summary.awaitingVerify, 1); // #4 is VERIFYING
    });

    test('IK-SUM-2: returns empty summary for no issues', () async {
      when(() => mockClient.listAllIssues(
            repoSlug: any(named: 'repoSlug'),
            state: any(named: 'state'),
            labels: any(named: 'labels'),
            sort: any(named: 'sort'),
          )).thenAnswer((_) async => []);

      final summary = await service.getSummary();

      expect(summary.totalCount, 0);
      expect(summary.byState, isEmpty);
      expect(summary.bySeverity, isEmpty);
      expect(summary.byProject, isEmpty);
    });
  });

  // ===========================================================================
  // IK-INIT: initLabels
  // ===========================================================================

  group('IK-INIT: initLabels [2026-02-13]', () {
    test('IK-INIT-1: creates labels in both repos', () async {
      when(() => mockClient.createLabel(
            repoSlug: any(named: 'repoSlug'),
            name: any(named: 'name'),
            color: any(named: 'color'),
            description: any(named: 'description'),
          )).thenAnswer((_) async => createTestLabel());

      final result = await service.initLabels();

      expect(result.issuesLabelsCreated, 14); // 14 issue labels
      expect(result.testsLabelsCreated, 4); // 4 test labels
      expect(result.totalCreated, 18);
    });

    test('IK-INIT-2: creates labels only in issues repo', () async {
      when(() => mockClient.createLabel(
            repoSlug: any(named: 'repoSlug'),
            name: any(named: 'name'),
            color: any(named: 'color'),
            description: any(named: 'description'),
          )).thenAnswer((_) async => createTestLabel());

      final result = await service.initLabels(repo: 'issues');

      expect(result.issuesLabelsCreated, 14);
      expect(result.testsLabelsCreated, 0);
    });

    test('IK-INIT-3: skips existing labels without force', () async {
      // First call succeeds, subsequent ones throw (label exists)
      var callCount = 0;
      when(() => mockClient.createLabel(
            repoSlug: any(named: 'repoSlug'),
            name: any(named: 'name'),
            color: any(named: 'color'),
            description: any(named: 'description'),
          )).thenAnswer((_) async {
        callCount++;
        if (callCount > 2) throw Exception('Label already exists');
        return createTestLabel();
      });

      final result = await service.initLabels();

      // Only first 2 succeed
      expect(result.totalCreated, 2);
    });
  });

  // ===========================================================================
  // IK-LINK: linkTest
  // ===========================================================================

  group('IK-LINK: linkTest [2026-02-13]', () {
    test('IK-LINK-1: posts link comment with test ID', () async {
      when(() => mockClient.addComment(
            repoSlug: any(named: 'repoSlug'),
            issueNumber: any(named: 'issueNumber'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => createTestComment());

      await service.linkTest(
        issueNumber: 42,
        testId: 'D4-42-PAR-7',
        testFile: 'test/parser/array_parser_test.dart',
        note: 'Pre-convention test',
      );

      final captured = verify(() => mockClient.addComment(
            repoSlug: 'al-the-bear/tom_issues',
            issueNumber: 42,
            body: captureAny(named: 'body'),
          )).captured;

      final body = captured.first as String;
      expect(body, contains('## Test Link'));
      expect(body, contains('D4-42-PAR-7'));
      expect(body, contains('array_parser_test.dart'));
      expect(body, contains('Pre-convention test'));
    });
  });

  // ===========================================================================
  // IK-EXP: exportIssues
  // ===========================================================================

  group('IK-EXP: exportIssues [2026-02-13]', () {
    test('IK-EXP-1: exports issues from issues repo', () async {
      when(() => mockClient.listAllIssues(
            repoSlug: any(named: 'repoSlug'),
            state: any(named: 'state'),
            labels: any(named: 'labels'),
            sort: any(named: 'sort'),
          )).thenAnswer((_) async => [
            createTestIssue(number: 1),
            createTestIssue(number: 2),
          ]);

      final issues = await service.exportIssues();

      expect(issues.length, 2);
      verify(() => mockClient.listAllIssues(
            repoSlug: 'al-the-bear/tom_issues',
            state: 'open',
            labels: null,
            sort: null,
          )).called(1);
    });

    test('IK-EXP-2: exports from tests repo with filters', () async {
      when(() => mockClient.listAllIssues(
            repoSlug: any(named: 'repoSlug'),
            state: any(named: 'state'),
            labels: any(named: 'labels'),
            sort: any(named: 'sort'),
          )).thenAnswer((_) async => [createTestIssue()]);

      final issues = await service.exportIssues(
        repo: 'tests',
        severity: 'high',
        includeAll: true,
      );

      expect(issues.length, 1);
      verify(() => mockClient.listAllIssues(
            repoSlug: 'al-the-bear/tom_tests',
            state: 'all',
            labels: ['severity:high'],
            sort: null,
          )).called(1);
    });
  });

  // ===========================================================================
  // IK-SNAP: createSnapshot
  // ===========================================================================

  group('IK-SNAP: createSnapshot [2026-02-13]', () {
    test('IK-SNAP-1: creates full snapshot of both repos', () async {
      when(() => mockClient.listAllIssues(
            repoSlug: 'al-the-bear/tom_issues',
            state: any(named: 'state'),
            labels: any(named: 'labels'),
            sort: any(named: 'sort'),
          )).thenAnswer((_) async => [
            createTestIssue(number: 1),
            createTestIssue(number: 2),
          ]);
      when(() => mockClient.listAllIssues(
            repoSlug: 'al-the-bear/tom_tests',
            state: any(named: 'state'),
            labels: any(named: 'labels'),
            sort: any(named: 'sort'),
          )).thenAnswer((_) async => [
            createTestIssue(number: 1),
          ]);

      final snapshot = await service.createSnapshot();

      expect(snapshot.issues, hasLength(2));
      expect(snapshot.tests, hasLength(1));
      expect(snapshot.snapshotDate, isNotNull);
    });

    test('IK-SNAP-2: issues-only snapshot skips tests', () async {
      when(() => mockClient.listAllIssues(
            repoSlug: 'al-the-bear/tom_issues',
            state: any(named: 'state'),
            labels: any(named: 'labels'),
            sort: any(named: 'sort'),
          )).thenAnswer((_) async => [createTestIssue()]);

      final snapshot = await service.createSnapshot(issuesOnly: true);

      expect(snapshot.issues, hasLength(1));
      expect(snapshot.tests, isNull);

      verifyNever(() => mockClient.listAllIssues(
            repoSlug: 'al-the-bear/tom_tests',
            state: any(named: 'state'),
            labels: any(named: 'labels'),
            sort: any(named: 'sort'),
          ));
    });
  });

  // ===========================================================================
  // IK-RUNTESTS: triggerTestWorkflow
  // ===========================================================================

  group('IK-RUNTESTS: triggerTestWorkflow [2026-02-13]', () {
    test('IK-RUNTESTS-1: dispatches workflow', () async {
      when(() => mockClient.dispatchWorkflow(
            repoSlug: any(named: 'repoSlug'),
            workflowId: any(named: 'workflowId'),
            ref: any(named: 'ref'),
            inputs: any(named: 'inputs'),
          )).thenAnswer((_) async {});

      await service.triggerTestWorkflow();

      verify(() => mockClient.dispatchWorkflow(
            repoSlug: 'al-the-bear/tom_tests',
            workflowId: 'nightly_tests.yml',
            ref: 'main',
          )).called(1);
    });
  });

  // ===========================================================================
  // IK-IMP: importIssues
  // ===========================================================================

  group('IK-IMP: importIssues [2026-02-13]', () {
    test('IK-IMP-1: creates issues from entries', () async {
      when(() => mockClient.createIssue(
            repoSlug: any(named: 'repoSlug'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            labels: any(named: 'labels'),
            assignee: any(named: 'assignee'),
          )).thenAnswer((_) async => createTestIssue(number: 201));

      final entries = [
        {'title': 'Bug 1', 'body': 'Description 1'},
        {'title': 'Bug 2', 'body': 'Description 2'},
      ];

      final result = await service.importIssues(entries: entries);

      expect(result.length, 2);
      verify(() => mockClient.createIssue(
            repoSlug: 'al-the-bear/tom_issues',
            title: any(named: 'title'),
            body: any(named: 'body'),
            labels: null,
            assignee: null,
          )).called(2);
    });

    test('IK-IMP-2: dry-run returns empty without creating', () async {
      final result = await service.importIssues(
        entries: [{'title': 'Bug 1'}],
        dryRun: true,
      );

      expect(result, isEmpty);
      verifyNever(() => mockClient.createIssue(
            repoSlug: any(named: 'repoSlug'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            labels: any(named: 'labels'),
            assignee: any(named: 'assignee'),
          ));
    });
  });
}
