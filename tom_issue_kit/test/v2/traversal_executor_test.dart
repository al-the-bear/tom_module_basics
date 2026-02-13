/// Unit tests for traversal-based issuekit command executors.
///
/// Tests for ScanExecutor, TestingExecutor, VerifyExecutor, PromoteExecutor,
/// ValidateExecutor, SyncExecutor, and AggregateExecutor. These executors
/// use [TestScanner] for filesystem operations and process projects during
/// workspace traversal.
@TestOn('vm')
library;

import 'dart:io';

import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:tom_build_base/tom_build_base_v2.dart'
    hide ListExecutor, SyncExecutor;
import 'package:tom_issue_kit/src/services/test_scanner.dart';
import 'package:tom_issue_kit/src/v2/issuekit_executors.dart';

import '../helpers/fixtures.dart';

// =============================================================================
// Test Helpers
// =============================================================================

/// Create a [CommandContext] for testing with a temporary directory.
CommandContext createTestContext({
  required String path,
  String executionRoot = '/workspace',
}) {
  return CommandContext(
    fsFolder: FsFolder(path: path),
    natures: [],
    executionRoot: executionRoot,
  );
}

/// Create a [TestIdMatch] fixture for mocking scanner results.
TestIdMatch createTestIdMatch({
  String testId = 'D4-42-PAR-7',
  String projectId = 'D4',
  int? issueNumber = 42,
  String projectSpecific = 'PAR-7',
  String filePath = '/projects/d4rt/test/parser_test.dart',
  int line = 15,
  String description = 'D4-42-PAR-7: Parser handles nested arrays',
}) {
  return TestIdMatch(
    testId: testId,
    projectId: projectId,
    issueNumber: issueNumber,
    projectSpecific: projectSpecific,
    filePath: filePath,
    line: line,
    description: description,
  );
}

void main() {
  late MockTestScanner mockScanner;
  late MockIssueService mockService;
  late CommandContext context;

  setUp(() {
    mockScanner = MockTestScanner();
    mockService = MockIssueService();
    context = createTestContext(path: '/projects/d4rt');
  });

  // ===========================================================================
  // IK-EXE-SCN: ScanExecutor
  // ===========================================================================

  group('IK-EXE-SCN: ScanExecutor [2026-02-14]', () {
    late ScanExecutor executor;

    setUp(() {
      executor = ScanExecutor(mockScanner);
    });

    test('IK-EXE-SCN-1: finds issue-linked tests in project', () async {
      final matches = [
        createTestIdMatch(
          testId: 'D4-42-PAR-7',
          issueNumber: 42,
          filePath: '/projects/d4rt/test/parser_test.dart',
          line: 15,
        ),
        createTestIdMatch(
          testId: 'D4-99-LEX-3',
          issueNumber: 99,
          projectSpecific: 'LEX-3',
          filePath: '/projects/d4rt/test/lexer_test.dart',
          line: 42,
        ),
      ];

      when(() => mockScanner.scanProject(any())).thenReturn(matches);

      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('Found 2 test(s)'));
      expect(result.message, contains('D4-42-PAR-7'));
      expect(result.message, contains('D4-99-LEX-3'));
      verify(() => mockScanner.scanProject('/projects/d4rt')).called(1);
    });

    test('IK-EXE-SCN-2: filters by issue number', () async {
      final matches = [
        createTestIdMatch(
          testId: 'D4-42-PAR-7',
          issueNumber: 42,
        ),
      ];

      when(() => mockScanner.scanForIssue(any(), any()))
          .thenReturn(matches);

      final result = await executor.execute(
        context,
        const CliArgs(positionalArgs: ['42']),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('Found 1 test(s)'));
      expect(result.message, contains('D4-42-PAR-7'));
      verify(() => mockScanner.scanForIssue('/projects/d4rt', 42)).called(1);
    });

    test('IK-EXE-SCN-3: returns empty when no issue-linked tests', () async {
      when(() => mockScanner.scanProject(any())).thenReturn([]);

      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('No issue-linked tests found'));
    });

    test('IK-EXE-SCN-4: filters stubs with --missing-tests', () async {
      final matches = [
        createTestIdMatch(
          testId: 'D4-42-PAR-7',
          issueNumber: 42,
          projectSpecific: 'PAR-7',
        ),
        createTestIdMatch(
          testId: 'D4-99-',
          issueNumber: 99,
          projectSpecific: '',
          filePath: '/projects/d4rt/test/stub_test.dart',
          line: 5,
        ),
      ];

      when(() => mockScanner.scanProject(any())).thenReturn(matches);

      final result = await executor.execute(
        context,
        const CliArgs(extraOptions: {'missing-tests': true}),
      );

      expect(result.success, isTrue);
      // Only the stub (empty projectSpecific) should be in results
      expect(result.message, contains('Found 1 test(s)'));
      expect(result.message, contains('D4-99-'));
    });
  });

  // ===========================================================================
  // IK-EXE-TST: TestingExecutor
  // ===========================================================================

  group('IK-EXE-TST: TestingExecutor [2026-02-14]', () {
    late TestingExecutor executor;

    setUp(() {
      executor = TestingExecutor(mockScanner, mockService);
    });

    test('IK-EXE-TST-1: finds tests for given issue', () async {
      final matches = [
        createTestIdMatch(testId: 'D4-42-PAR-7', issueNumber: 42),
        createTestIdMatch(
          testId: 'D4-42-PAR-8',
          issueNumber: 42,
          projectSpecific: 'PAR-8',
        ),
      ];

      when(() => mockScanner.scanForIssue(any(), any()))
          .thenReturn(matches);

      final result = await executor.execute(
        context,
        const CliArgs(positionalArgs: ['42']),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('Found 2 test(s) for #42'));
      expect(result.message, contains('D4-42-PAR-7'));
      expect(result.message, contains('D4-42-PAR-8'));
    });

    test('IK-EXE-TST-2: returns empty when no tests for issue', () async {
      when(() => mockScanner.scanForIssue(any(), any()))
          .thenReturn([]);

      final result = await executor.execute(
        context,
        const CliArgs(positionalArgs: ['42']),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('No tests for issue #42'));
    });

    test('IK-EXE-TST-3: fails when no issue number provided', () async {
      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Missing required argument'));
    });
  });

  // ===========================================================================
  // IK-EXE-VRF: VerifyExecutor
  // ===========================================================================

  group('IK-EXE-VRF: VerifyExecutor [2026-02-14]', () {
    late VerifyExecutor executor;

    setUp(() {
      executor = VerifyExecutor(mockScanner);
    });

    test('IK-EXE-VRF-1: verifies all tests pass', () async {
      final matches = [
        createTestIdMatch(testId: 'D4-42-PAR-7', issueNumber: 42),
        createTestIdMatch(
          testId: 'D4-42-PAR-8',
          issueNumber: 42,
          projectSpecific: 'PAR-8',
        ),
      ];

      when(() => mockScanner.scanForIssue(any(), any()))
          .thenReturn(matches);
      when(() => mockScanner.readLatestBaseline(any()))
          .thenReturn('ID,Groups,Description,Run1\nD4-42-PAR-7,,test,OK\nD4-42-PAR-8,,test,OK');
      when(() => mockScanner.parseBaseline(any()))
          .thenReturn({'D4-42-PAR-7': 'OK', 'D4-42-PAR-8': 'OK'});

      final result = await executor.execute(
        context,
        const CliArgs(positionalArgs: ['42']),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('ALL PASS'));
      expect(result.message, contains('D4-42-PAR-7: OK'));
    });

    test('IK-EXE-VRF-2: reports failures when tests fail', () async {
      final matches = [
        createTestIdMatch(testId: 'D4-42-PAR-7', issueNumber: 42),
        createTestIdMatch(
          testId: 'D4-42-PAR-8',
          issueNumber: 42,
          projectSpecific: 'PAR-8',
        ),
      ];

      when(() => mockScanner.scanForIssue(any(), any()))
          .thenReturn(matches);
      when(() => mockScanner.readLatestBaseline(any()))
          .thenReturn('content');
      when(() => mockScanner.parseBaseline(any()))
          .thenReturn({'D4-42-PAR-7': 'OK', 'D4-42-PAR-8': 'X'});

      final result = await executor.execute(
        context,
        const CliArgs(positionalArgs: ['42']),
      );

      expect(result.success, isFalse);
      expect(result.message, contains('SOME FAIL'));
      expect(result.message, contains('D4-42-PAR-8: X'));
    });

    test('IK-EXE-VRF-3: reports error when no baseline', () async {
      final matches = [
        createTestIdMatch(testId: 'D4-42-PAR-7', issueNumber: 42),
      ];

      when(() => mockScanner.scanForIssue(any(), any()))
          .thenReturn(matches);
      when(() => mockScanner.readLatestBaseline(any()))
          .thenReturn(null);

      final result = await executor.execute(
        context,
        const CliArgs(positionalArgs: ['42']),
      );

      expect(result.success, isFalse);
      expect(result.error, contains('No testkit baseline found'));
    });

    test('IK-EXE-VRF-4: returns empty when no tests for issue', () async {
      when(() => mockScanner.scanForIssue(any(), any()))
          .thenReturn([]);

      final result = await executor.execute(
        context,
        const CliArgs(positionalArgs: ['42']),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('No tests for issue #42'));
    });

    test('IK-EXE-VRF-5: fails when no issue number provided', () async {
      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Missing required argument'));
    });
  });

  // ===========================================================================
  // IK-EXE-PRM: PromoteExecutor
  // ===========================================================================

  group('IK-EXE-PRM: PromoteExecutor [2026-02-14]', () {
    late PromoteExecutor executor;
    late Directory tempDir;

    setUp(() {
      executor = PromoteExecutor(mockScanner);
      tempDir = Directory.systemTemp.createTempSync('issuekit_promote_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('IK-EXE-PRM-1: promotes test ID with dry-run', () async {
      final match = createTestIdMatch(
        testId: 'D4-PAR-7',
        projectId: 'D4',
        issueNumber: null,
        projectSpecific: 'PAR-7',
        filePath: '/projects/d4rt/test/parser_test.dart',
        line: 15,
      );

      when(() => mockScanner.scanProject(any())).thenReturn([match]);

      final result = await executor.execute(
        context,
        const CliArgs(
          positionalArgs: ['D4-PAR-7'],
          extraOptions: {'issue': 42},
          dryRun: true,
        ),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('Would rename'));
      expect(result.message, contains('D4-PAR-7'));
      expect(result.message, contains('D4-42-PAR-7'));
    });

    test('IK-EXE-PRM-2: applies rename to source file', () async {
      // Create a temp test file
      final testFile = File('${tempDir.path}/test/parser_test.dart');
      testFile.parent.createSync(recursive: true);
      testFile.writeAsStringSync(
        "test('D4-PAR-7: Parser handles arrays', () {});\n",
      );

      final tempContext = createTestContext(path: tempDir.path);
      final match = createTestIdMatch(
        testId: 'D4-PAR-7',
        projectId: 'D4',
        issueNumber: null,
        projectSpecific: 'PAR-7',
        filePath: testFile.path,
        line: 1,
      );

      when(() => mockScanner.scanProject(any())).thenReturn([match]);

      final result = await executor.execute(
        tempContext,
        const CliArgs(
          positionalArgs: ['D4-PAR-7'],
          extraOptions: {'issue': 42},
        ),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('Promoted'));
      expect(result.message, contains('D4-42-PAR-7'));

      // Verify file was modified
      final content = testFile.readAsStringSync();
      expect(content, contains('D4-42-PAR-7'));
      expect(content, isNot(contains("'D4-PAR-7:")));
    });

    test('IK-EXE-PRM-3: reports not found in project', () async {
      when(() => mockScanner.scanProject(any())).thenReturn([]);

      final result = await executor.execute(
        context,
        const CliArgs(
          positionalArgs: ['D4-PAR-99'],
          extraOptions: {'issue': 42},
        ),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('not found in project'));
    });

    test('IK-EXE-PRM-4: fails when missing test-id', () async {
      final result = await executor.execute(
        context,
        const CliArgs(extraOptions: {'issue': 42}),
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Missing required argument: test-id'));
    });

    test('IK-EXE-PRM-5: fails when missing --issue', () async {
      final result = await executor.execute(
        context,
        const CliArgs(positionalArgs: ['D4-PAR-7']),
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Missing required option: --issue'));
    });
  });

  // ===========================================================================
  // IK-EXE-VAL: ValidateExecutor
  // ===========================================================================

  group('IK-EXE-VAL: ValidateExecutor [2026-02-14]', () {
    late ValidateExecutor executor;

    setUp(() {
      executor = ValidateExecutor(mockScanner);
    });

    test('IK-EXE-VAL-1: validates clean project', () async {
      final matches = [
        createTestIdMatch(
          testId: 'D4-PAR-7',
          projectId: 'D4',
          issueNumber: null,
          projectSpecific: 'PAR-7',
        ),
        createTestIdMatch(
          testId: 'D4-42-LEX-3',
          projectId: 'D4',
          issueNumber: 42,
          projectSpecific: 'LEX-3',
        ),
      ];

      when(() => mockScanner.scanProject(any())).thenReturn(matches);

      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('2 tests validated'));
      expect(result.message, contains('no issues'));
    });

    test('IK-EXE-VAL-2: detects duplicate project-specific IDs', () async {
      final matches = [
        createTestIdMatch(
          testId: 'D4-PAR-7',
          projectId: 'D4',
          issueNumber: null,
          projectSpecific: 'PAR-7',
          filePath: '/projects/d4rt/test/parser_test.dart',
          line: 10,
        ),
        createTestIdMatch(
          testId: 'D4-PAR-7',
          projectId: 'D4',
          issueNumber: null,
          projectSpecific: 'PAR-7',
          filePath: '/projects/d4rt/test/parser_v2_test.dart',
          line: 20,
        ),
      ];

      when(() => mockScanner.scanProject(any())).thenReturn(matches);

      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Duplicate D4-PAR-7'));
    });

    test('IK-EXE-VAL-3: detects regular+promoted conflict', () async {
      final matches = [
        createTestIdMatch(
          testId: 'D4-PAR-7',
          projectId: 'D4',
          issueNumber: null,
          projectSpecific: 'PAR-7',
        ),
        createTestIdMatch(
          testId: 'D4-42-PAR-7',
          projectId: 'D4',
          issueNumber: 42,
          projectSpecific: 'PAR-7',
        ),
      ];

      when(() => mockScanner.scanProject(any())).thenReturn(matches);

      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Conflict'));
      expect(result.error, contains('D4-PAR-7'));
      expect(result.error, contains('D4-42-PAR-7'));
    });

    test('IK-EXE-VAL-4: returns empty for no tests', () async {
      when(() => mockScanner.scanProject(any())).thenReturn([]);

      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('No tests found'));
    });
  });

  // ===========================================================================
  // IK-EXE-SYN: SyncExecutor
  // ===========================================================================

  group('IK-EXE-SYN: SyncExecutor [2026-02-14]', () {
    late SyncExecutor executor;

    setUp(() {
      executor = SyncExecutor(mockScanner);
    });

    test('IK-EXE-SYN-1: reports passing/failing/not-run', () async {
      final matches = [
        createTestIdMatch(testId: 'D4-42-PAR-7', issueNumber: 42),
        createTestIdMatch(
          testId: 'D4-42-PAR-8',
          issueNumber: 42,
          projectSpecific: 'PAR-8',
        ),
        createTestIdMatch(
          testId: 'D4-99-LEX-3',
          issueNumber: 99,
          projectSpecific: 'LEX-3',
        ),
      ];

      when(() => mockScanner.scanProject(any())).thenReturn(matches);
      when(() => mockScanner.readLatestBaseline(any()))
          .thenReturn('content');
      when(() => mockScanner.parseBaseline(any())).thenReturn({
        'D4-42-PAR-7': 'OK',
        'D4-42-PAR-8': 'X',
      });

      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      expect(result.success, isFalse); // has failures
      expect(result.message, contains('3 issue-linked test(s)'));
      expect(result.message, contains('1 passing'));
      expect(result.message, contains('1 failing'));
      expect(result.message, contains('1 not run'));
      expect(result.error, contains('Failing: D4-42-PAR-8'));
    });

    test('IK-EXE-SYN-2: returns empty when no issue-linked tests', () async {
      // Return regular tests only (not issue-linked)
      final matches = [
        createTestIdMatch(
          testId: 'D4-PAR-7',
          projectId: 'D4',
          issueNumber: null,
          projectSpecific: 'PAR-7',
        ),
      ];

      when(() => mockScanner.scanProject(any())).thenReturn(matches);

      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('No issue-linked tests found'));
    });

    test('IK-EXE-SYN-3: reports when no baseline', () async {
      final matches = [
        createTestIdMatch(testId: 'D4-42-PAR-7', issueNumber: 42),
      ];

      when(() => mockScanner.scanProject(any())).thenReturn(matches);
      when(() => mockScanner.readLatestBaseline(any())).thenReturn(null);

      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('no baseline'));
    });

    test('IK-EXE-SYN-4: success when all issue-linked tests pass', () async {
      final matches = [
        createTestIdMatch(testId: 'D4-42-PAR-7', issueNumber: 42),
      ];

      when(() => mockScanner.scanProject(any())).thenReturn(matches);
      when(() => mockScanner.readLatestBaseline(any()))
          .thenReturn('content');
      when(() => mockScanner.parseBaseline(any())).thenReturn({
        'D4-42-PAR-7': 'OK',
      });

      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('1 passing'));
      expect(result.error, isNull);
    });
  });

  // ===========================================================================
  // IK-EXE-AGG: AggregateExecutor
  // ===========================================================================

  group('IK-EXE-AGG: AggregateExecutor [2026-02-14]', () {
    late AggregateExecutor executor;

    setUp(() {
      executor = AggregateExecutor(mockScanner);
    });

    test('IK-EXE-AGG-1: aggregates issue-linked test results', () async {
      final matches = [
        createTestIdMatch(testId: 'D4-42-PAR-7', issueNumber: 42),
        createTestIdMatch(
          testId: 'D4-99-LEX-3',
          issueNumber: 99,
          projectSpecific: 'LEX-3',
        ),
      ];

      when(() => mockScanner.scanProject(any())).thenReturn(matches);
      when(() => mockScanner.readLatestBaseline(any()))
          .thenReturn('content');
      when(() => mockScanner.parseBaseline(any())).thenReturn({
        'D4-42-PAR-7': 'OK',
        'D4-99-LEX-3': 'X',
      });

      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('2 issue-linked test(s)'));
      expect(result.message, contains('D4-42-PAR-7'));
      expect(result.message, contains('OK'));
      expect(result.message, contains('D4-99-LEX-3'));
      expect(result.message, contains('#42'));
      expect(result.message, contains('#99'));
    });

    test('IK-EXE-AGG-2: returns empty when no issue-linked tests', () async {
      when(() => mockScanner.scanProject(any())).thenReturn([]);

      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('No issue-linked tests to aggregate'));
    });

    test('IK-EXE-AGG-3: handles missing baseline', () async {
      final matches = [
        createTestIdMatch(testId: 'D4-42-PAR-7', issueNumber: 42),
      ];

      when(() => mockScanner.scanProject(any())).thenReturn(matches);
      when(() => mockScanner.readLatestBaseline(any())).thenReturn(null);

      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('NOT RUN'));
      expect(result.message, contains('#42'));
    });
  });

  // ===========================================================================
  // IK-EXE-FAC: Factory function (updated for traversal executors)
  // ===========================================================================

  group('IK-EXE-FAC-TRV: factory with TestScanner [2026-02-14]', () {
    test('IK-EXE-FAC-TRV-1: factory accepts custom TestScanner', () {
      final executors = createIssuekitExecutors(
        service: mockService,
        scanner: mockScanner,
      );

      expect(executors['scan'], isA<ScanExecutor>());
      expect(executors['testing'], isA<TestingExecutor>());
      expect(executors['verify'], isA<VerifyExecutor>());
      expect(executors['promote'], isA<PromoteExecutor>());
      expect(executors['validate'], isA<ValidateExecutor>());
      expect(executors['sync'], isA<SyncExecutor>());
      expect(executors['aggregate'], isA<AggregateExecutor>());
    });

    test('IK-EXE-FAC-TRV-2: factory creates default TestScanner', () {
      final executors = createIssuekitExecutors(service: mockService);

      // All traversal executors should be created even without explicit scanner
      expect(executors['scan'], isA<ScanExecutor>());
      expect(executors['testing'], isA<TestingExecutor>());
      expect(executors['verify'], isA<VerifyExecutor>());
      expect(executors['promote'], isA<PromoteExecutor>());
      expect(executors['validate'], isA<ValidateExecutor>());
      expect(executors['sync'], isA<SyncExecutor>());
      expect(executors['aggregate'], isA<AggregateExecutor>());
    });
  });
}
