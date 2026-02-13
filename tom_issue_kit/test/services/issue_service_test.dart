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
}
