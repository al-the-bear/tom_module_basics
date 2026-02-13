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
      when(() => mockService.updateIssue(
            issueNumber: any(named: 'issueNumber'),
            tags: any(named: 'tags'),
          )).thenAnswer((_) async => createTestIssue());

      final result = await executor.execute(
        context,
        const CliArgs(positionalArgs: ['42']),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('Found 2 full test(s) for #42'));
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

    test('IK-EXE-TST-4: rejects stubs, only accepts full test IDs', () async {
      // Per spec: stubs like D4-42 (no project-specific part) are rejected
      final matches = [
        createTestIdMatch(
          testId: 'D4-42',
          projectId: 'D4',
          issueNumber: 42,
          projectSpecific: '',
          filePath: '/projects/d4rt/test/stub_test.dart',
          line: 5,
          description: 'D4-42: stub entry',
        ),
      ];

      when(() => mockScanner.scanForIssue(any(), any()))
          .thenReturn(matches);

      final result = await executor.execute(
        context,
        const CliArgs(positionalArgs: ['42']),
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Only stub(s) found'));
      expect(result.error, contains('D4-42'));
      expect(result.error,
          contains('create a full dart test with project-specific ID'));
    });

    test('IK-EXE-TST-5: reports full tests and notes stubs', () async {
      // Per spec: when both full tests and stubs exist, count only full tests
      // but note the existence of stubs
      final matches = [
        createTestIdMatch(
          testId: 'D4-42-PAR-7',
          projectId: 'D4',
          issueNumber: 42,
          projectSpecific: 'PAR-7',
        ),
        createTestIdMatch(
          testId: 'D4-42',
          projectId: 'D4',
          issueNumber: 42,
          projectSpecific: '',
          filePath: '/projects/d4rt/test/stub_test.dart',
          line: 5,
        ),
      ];

      when(() => mockScanner.scanForIssue(any(), any()))
          .thenReturn(matches);
      when(() => mockService.updateIssue(
            issueNumber: any(named: 'issueNumber'),
            tags: any(named: 'tags'),
          )).thenAnswer((_) async => createTestIssue());

      final result = await executor.execute(
        context,
        const CliArgs(positionalArgs: ['42']),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('Found 1 full test(s) for #42'));
      expect(result.message, contains('D4-42-PAR-7'));
      expect(result.message, contains('1 stub(s) also present'));
    });

    test('IK-EXE-TST-6: multiple full tests reported correctly', () async {
      final matches = [
        createTestIdMatch(
          testId: 'D4-42-PAR-7',
          issueNumber: 42,
          projectSpecific: 'PAR-7',
        ),
        createTestIdMatch(
          testId: 'D4-42-PAR-8',
          issueNumber: 42,
          projectSpecific: 'PAR-8',
        ),
        createTestIdMatch(
          testId: 'D4-42-LEX-1',
          issueNumber: 42,
          projectSpecific: 'LEX-1',
        ),
      ];

      when(() => mockScanner.scanForIssue(any(), any()))
          .thenReturn(matches);
      when(() => mockService.updateIssue(
            issueNumber: any(named: 'issueNumber'),
            tags: any(named: 'tags'),
          )).thenAnswer((_) async => createTestIssue());

      final result = await executor.execute(
        context,
        const CliArgs(positionalArgs: ['42']),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('Found 3 full test(s) for #42'));
      expect(result.message, contains('D4-42-PAR-7'));
      expect(result.message, contains('D4-42-PAR-8'));
      expect(result.message, contains('D4-42-LEX-1'));
      // No stubs → no stub note
      expect(result.message, isNot(contains('stub')));
    });
  });

  // ===========================================================================
  // IK-EXE-VRF: VerifyExecutor
  // ===========================================================================

  group('IK-EXE-VRF: VerifyExecutor [2026-02-14]', () {
    late VerifyExecutor executor;

    setUp(() {
      executor = VerifyExecutor(mockScanner, mockService);
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
      when(() => mockService.updateIssue(
            issueNumber: any(named: 'issueNumber'),
            tags: any(named: 'tags'),
          )).thenAnswer((_) async => createTestIssue());

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

    test('IK-EXE-VRF-6: reports NOT RUN when test not in baseline', () async {
      // Per spec: if testkit hasn't been run recently, report NOT RUN
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
      // Only one test appears in baseline
      when(() => mockScanner.parseBaseline(any()))
          .thenReturn({'D4-42-PAR-7': 'OK'});

      final result = await executor.execute(
        context,
        const CliArgs(positionalArgs: ['42']),
      );

      expect(result.success, isFalse); // NOT RUN counts as failure
      expect(result.message, contains('SOME FAIL'));
      expect(result.message, contains('D4-42-PAR-7: OK'));
      expect(result.message, contains('D4-42-PAR-8: NOT RUN'));
    });

    test('IK-EXE-VRF-7: reports mixed OK and failure statuses', () async {
      final matches = [
        createTestIdMatch(testId: 'D4-42-PAR-7', issueNumber: 42),
        createTestIdMatch(
          testId: 'D4-42-PAR-8',
          issueNumber: 42,
          projectSpecific: 'PAR-8',
        ),
        createTestIdMatch(
          testId: 'D4-42-LEX-1',
          issueNumber: 42,
          projectSpecific: 'LEX-1',
        ),
      ];

      when(() => mockScanner.scanForIssue(any(), any()))
          .thenReturn(matches);
      when(() => mockScanner.readLatestBaseline(any()))
          .thenReturn('content');
      when(() => mockScanner.parseBaseline(any())).thenReturn({
        'D4-42-PAR-7': 'OK',
        'D4-42-PAR-8': 'X/OK', // currently failing, was OK → regression
        'D4-42-LEX-1': 'X',
      });

      final result = await executor.execute(
        context,
        const CliArgs(positionalArgs: ['42']),
      );

      expect(result.success, isFalse);
      expect(result.message, contains('SOME FAIL'));
      expect(result.message, contains('D4-42-PAR-7: OK'));
      expect(result.message, contains('D4-42-PAR-8: X/OK'));
      expect(result.message, contains('D4-42-LEX-1: X'));
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

    test('IK-EXE-PRM-6: handles already-promoted test ID', () async {
      // Trying to promote a test that already has an issue number
      final match = createTestIdMatch(
        testId: 'D4-42-PAR-7',
        projectId: 'D4',
        issueNumber: 42,
        projectSpecific: 'PAR-7',
        filePath: '/projects/d4rt/test/parser_test.dart',
        line: 15,
      );

      when(() => mockScanner.scanProject(any())).thenReturn([match]);

      // Try to promote to a different issue
      final result = await executor.execute(
        context,
        const CliArgs(
          positionalArgs: ['D4-42-PAR-7'],
          extraOptions: {'issue': 99},
          dryRun: true,
        ),
      );

      // Current impl will create D4-99-PAR-7 from the projectSpecific part
      expect(result.success, isTrue);
      expect(result.message, contains('Would rename'));
      // New ID: D4-99-PAR-7 (replaces the original issue number)
      expect(result.message, contains('D4-99-PAR-7'));
    });

    test('IK-EXE-PRM-7: handles multiple occurrences in file', () async {
      // Create a temp test file with the test ID used multiple times
      final testFile = File('${tempDir.path}/test/parser_test.dart');
      testFile.parent.createSync(recursive: true);
      testFile.writeAsStringSync(
        "// Reference: D4-PAR-7\n"
        "test('D4-PAR-7: Parser handles arrays', () {\n"
        "  // linked to D4-PAR-7\n"
        "});\n",
      );

      final tempContext = createTestContext(path: tempDir.path);
      final match = createTestIdMatch(
        testId: 'D4-PAR-7',
        projectId: 'D4',
        issueNumber: null,
        projectSpecific: 'PAR-7',
        filePath: testFile.path,
        line: 2,
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

      // All occurrences should be replaced
      final content = testFile.readAsStringSync();
      expect(content.contains('D4-42-PAR-7'), isTrue);
      // Original ID should not appear
      expect(content.contains("'D4-PAR-7"), isFalse);
    });
  });

  // ===========================================================================
  // IK-EXE-VAL: ValidateExecutor
  // ===========================================================================

  group('IK-EXE-VAL: ValidateExecutor [2026-02-14]', () {
    late ValidateExecutor executor;
    late Directory tempDir;

    setUp(() {
      executor = ValidateExecutor(mockScanner, mockService);
      tempDir = Directory.systemTemp.createTempSync('issuekit_validate_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
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
      // Check 3: issue #42 exists
      when(() => mockService.getIssue(42))
          .thenAnswer((_) async => createTestIssue(number: 42));

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
      expect(result.message, contains('Duplicate D4-PAR-7'));
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
      // Check 3: issue #42 exists (but conflict takes precedence)
      when(() => mockService.getIssue(42))
          .thenAnswer((_) async => createTestIssue(number: 42));

      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      expect(result.success, isFalse);
      expect(result.message, contains('Conflict'));
      expect(result.message, contains('D4-PAR-7'));
      expect(result.message, contains('D4-42-PAR-7'));
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

    test('IK-EXE-VAL-5: detects invalid issue references (Check 3)',
        () async {
      // Per spec: validate that issue numbers in test IDs exist in tom_issues
      final matches = [
        createTestIdMatch(
          testId: 'D4-999-PAR-7',
          projectId: 'D4',
          issueNumber: 999,
          projectSpecific: 'PAR-7',
        ),
      ];

      when(() => mockScanner.scanProject(any())).thenReturn(matches);
      // Issue #999 doesn't exist
      when(() => mockService.getIssue(999))
          .thenThrow(Exception('Issue not found'));

      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      // Warnings don't cause failure, but are reported
      expect(result.success, isTrue);
      expect(result.message, contains('Issue #999 not found'));
      expect(result.message, contains('warning'));
    });

    test('IK-EXE-VAL-6: reports both errors and warnings together', () async {
      // Per spec: output has Errors section and Warnings section
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
          filePath: '/projects/d4rt/test/other_test.dart',
          line: 20,
        ),
        createTestIdMatch(
          testId: 'D4-999-LEX-3',
          projectId: 'D4',
          issueNumber: 999,
          projectSpecific: 'LEX-3',
        ),
      ];

      when(() => mockScanner.scanProject(any())).thenReturn(matches);
      when(() => mockService.getIssue(999))
          .thenThrow(Exception('Issue not found'));

      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      // Has errors → failure
      expect(result.success, isFalse);
      expect(result.message, contains('error(s)'));
      expect(result.message, contains('Duplicate D4-PAR-7'));
      expect(result.message, contains('warning(s)'));
      expect(result.message, contains('Issue #999 not found'));
    });

    test('IK-EXE-VAL-7: valid issue refs pass Check 3', () async {
      final matches = [
        createTestIdMatch(
          testId: 'D4-42-PAR-7',
          projectId: 'D4',
          issueNumber: 42,
          projectSpecific: 'PAR-7',
        ),
        createTestIdMatch(
          testId: 'D4-99-LEX-3',
          projectId: 'D4',
          issueNumber: 99,
          projectSpecific: 'LEX-3',
        ),
      ];

      when(() => mockScanner.scanProject(any())).thenReturn(matches);
      when(() => mockService.getIssue(42))
          .thenAnswer((_) async => createTestIssue(number: 42));
      when(() => mockService.getIssue(99))
          .thenAnswer((_) async => createTestIssue(number: 99));

      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('2 tests validated'));
      expect(result.message, contains('no issues'));
    });

    test('IK-EXE-VAL-8: reports multiple duplicate groups separately', () async {
      // Multiple groups of duplicates should all be reported
      final matches = [
        createTestIdMatch(
          testId: 'D4-PAR-7',
          projectId: 'D4',
          issueNumber: null,
          projectSpecific: 'PAR-7',
          filePath: '/projects/d4rt/test/file_a.dart',
          line: 10,
        ),
        createTestIdMatch(
          testId: 'D4-PAR-7',
          projectId: 'D4',
          issueNumber: null,
          projectSpecific: 'PAR-7',
          filePath: '/projects/d4rt/test/file_b.dart',
          line: 20,
        ),
        createTestIdMatch(
          testId: 'D4-LEX-3',
          projectId: 'D4',
          issueNumber: null,
          projectSpecific: 'LEX-3',
          filePath: '/projects/d4rt/test/file_a.dart',
          line: 30,
        ),
        createTestIdMatch(
          testId: 'D4-LEX-3',
          projectId: 'D4',
          issueNumber: null,
          projectSpecific: 'LEX-3',
          filePath: '/projects/d4rt/test/file_c.dart',
          line: 40,
        ),
      ];

      when(() => mockScanner.scanProject(any())).thenReturn(matches);

      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      expect(result.success, isFalse);
      expect(result.message, contains('Duplicate D4-PAR-7'));
      expect(result.message, contains('Duplicate D4-LEX-3'));
      expect(result.message, contains('2 error(s)'));
    });

    test('IK-EXE-VAL-9: multiple conflicts reported separately', () async {
      // Multiple regular+promoted conflicts - different file paths
      final matches = [
        createTestIdMatch(
          testId: 'D4-PAR-7',
          projectId: 'D4',
          issueNumber: null,
          projectSpecific: 'PAR-7',
          filePath: '/projects/d4rt/test/parser_a.dart',
          line: 10,
        ),
        createTestIdMatch(
          testId: 'D4-42-PAR-7',
          projectId: 'D4',
          issueNumber: 42,
          projectSpecific: 'PAR-7',
          filePath: '/projects/d4rt/test/parser_b.dart',
          line: 20,
        ),
        createTestIdMatch(
          testId: 'D4-LEX-3',
          projectId: 'D4',
          issueNumber: null,
          projectSpecific: 'LEX-3',
          filePath: '/projects/d4rt/test/lexer_a.dart',
          line: 30,
        ),
        createTestIdMatch(
          testId: 'D4-99-LEX-3',
          projectId: 'D4',
          issueNumber: 99,
          projectSpecific: 'LEX-3',
          filePath: '/projects/d4rt/test/lexer_b.dart',
          line: 40,
        ),
      ];

      when(() => mockScanner.scanProject(any())).thenReturn(matches);
      when(() => mockService.getIssue(42))
          .thenAnswer((_) async => createTestIssue(number: 42));
      when(() => mockService.getIssue(99))
          .thenAnswer((_) async => createTestIssue(number: 99));

      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      expect(result.success, isFalse);
      expect(result.message, contains('Conflict: regular D4-PAR-7'));
      expect(result.message, contains('Conflict: regular D4-LEX-3'));
      // Regular+promoted pairs are reported as conflicts only, not duplicates
      expect(result.message, contains('2 error(s)'));
    });

    test('IK-EXE-VAL-10: warnings-only does not cause failure', () async {
      // Only warnings (invalid issue refs), no errors
      final matches = [
        createTestIdMatch(
          testId: 'D4-999-PAR-7',
          projectId: 'D4',
          issueNumber: 999,
          projectSpecific: 'PAR-7',
        ),
        createTestIdMatch(
          testId: 'D4-888-LEX-3',
          projectId: 'D4',
          issueNumber: 888,
          projectSpecific: 'LEX-3',
        ),
      ];

      when(() => mockScanner.scanProject(any())).thenReturn(matches);
      when(() => mockService.getIssue(999))
          .thenThrow(Exception('Issue not found'));
      when(() => mockService.getIssue(888))
          .thenThrow(Exception('Issue not found'));

      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      // Warnings don't cause failure
      expect(result.success, isTrue);
      expect(result.message, contains('warning(s)'));
      expect(result.message, contains('Issue #999 not found'));
      expect(result.message, contains('Issue #888 not found'));
      expect(result.error, isNull);
    });

    test('IK-EXE-VAL-11: --fix with dry-run reports would-remove', () async {
      // Regular+promoted conflict with --fix and --dry-run
      final matches = [
        createTestIdMatch(
          testId: 'D4-PAR-7',
          projectId: 'D4',
          issueNumber: null,
          projectSpecific: 'PAR-7',
          filePath: '/projects/d4rt/test/parser_a.dart',
          line: 10,
        ),
        createTestIdMatch(
          testId: 'D4-42-PAR-7',
          projectId: 'D4',
          issueNumber: 42,
          projectSpecific: 'PAR-7',
          filePath: '/projects/d4rt/test/parser_b.dart',
          line: 20,
        ),
      ];

      when(() => mockScanner.scanProject(any())).thenReturn(matches);
      when(() => mockService.getIssue(42))
          .thenAnswer((_) async => createTestIssue(number: 42));

      final result = await executor.execute(
        context,
        const CliArgs(
          extraOptions: {'fix': true},
          dryRun: true,
        ),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('fix(es)'));
      expect(result.message, contains('Would remove D4-PAR-7'));
      expect(result.message, contains('promoted D4-42-PAR-7 exists'));
    });

    test('IK-EXE-VAL-12: --fix applies to source file', () async {
      // Create a temp test file with regular ID
      final testFile = File('${tempDir.path}/test/parser_test.dart');
      testFile.parent.createSync(recursive: true);
      testFile.writeAsStringSync(
        "test('D4-PAR-7: Parser handles arrays', () {});\n",
      );

      final tempContext = createTestContext(path: tempDir.path);

      final regularMatch = createTestIdMatch(
        testId: 'D4-PAR-7',
        projectId: 'D4',
        issueNumber: null,
        projectSpecific: 'PAR-7',
        filePath: testFile.path,
        line: 1,
      );
      final promotedMatch = createTestIdMatch(
        testId: 'D4-42-PAR-7',
        projectId: 'D4',
        issueNumber: 42,
        projectSpecific: 'PAR-7',
        filePath: '${tempDir.path}/test/other_test.dart',
        line: 5,
      );

      when(() => mockScanner.scanProject(any()))
          .thenReturn([regularMatch, promotedMatch]);
      when(() => mockService.getIssue(42))
          .thenAnswer((_) async => createTestIssue(number: 42));

      final result = await executor.execute(
        tempContext,
        const CliArgs(extraOptions: {'fix': true}),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('fix(es)'));
      expect(result.message, contains('Removed D4-PAR-7'));

      // Verify file was modified
      final content = testFile.readAsStringSync();
      expect(content, contains('// REMOVED by :validate --fix'));
      expect(content, contains('promoted version exists'));
    });

    test('IK-EXE-VAL-13: --fix without conflicts has no fixes', () async {
      // No conflicts to fix
      final matches = [
        createTestIdMatch(
          testId: 'D4-PAR-7',
          projectId: 'D4',
          issueNumber: null,
          projectSpecific: 'PAR-7',
          filePath: '/projects/d4rt/test/parser_a.dart',
          line: 10,
        ),
        createTestIdMatch(
          testId: 'D4-42-LEX-3',
          projectId: 'D4',
          issueNumber: 42,
          projectSpecific: 'LEX-3',
          filePath: '/projects/d4rt/test/lexer_b.dart',
          line: 20,
        ),
      ];

      when(() => mockScanner.scanProject(any())).thenReturn(matches);
      when(() => mockService.getIssue(42))
          .thenAnswer((_) async => createTestIssue(number: 42));

      final result = await executor.execute(
        context,
        const CliArgs(extraOptions: {'fix': true}),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('validated'));
      expect(result.message, contains('no issues'));
    });
  });

  // ===========================================================================
  // IK-EXE-SYN: SyncExecutor
  // ===========================================================================

  group('IK-EXE-SYN: SyncExecutor [2026-02-14]', () {
    late SyncExecutor executor;

    setUp(() {
      executor = SyncExecutor(mockScanner, mockService);
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

    test('IK-EXE-SYN-5: identifies issues as VERIFYING candidates', () async {
      // Per spec: when all tests for an issue pass, suggest VERIFYING
      final matches = [
        createTestIdMatch(
          testId: 'D4-42-PAR-7',
          issueNumber: 42,
          projectSpecific: 'PAR-7',
        ),
        createTestIdMatch(
          testId: 'D4-42-PAR-8',
          issueNumber: 42,
          projectSpecific: 'PAR-8',
        ),
      ];

      when(() => mockScanner.scanProject(any())).thenReturn(matches);
      when(() => mockScanner.readLatestBaseline(any()))
          .thenReturn('content');
      when(() => mockScanner.parseBaseline(any())).thenReturn({
        'D4-42-PAR-7': 'OK',
        'D4-42-PAR-8': 'OK',
      });

      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('candidates for VERIFYING'));
      expect(result.message, contains('#42'));
    });

    test('IK-EXE-SYN-6: detects regressions (OK→X)', () async {
      // Per spec: detect regressions in baseline status
      final matches = [
        createTestIdMatch(
          testId: 'D4-42-PAR-7',
          issueNumber: 42,
          projectSpecific: 'PAR-7',
        ),
      ];

      when(() => mockScanner.scanProject(any())).thenReturn(matches);
      when(() => mockScanner.readLatestBaseline(any()))
          .thenReturn('content');
      when(() => mockScanner.parseBaseline(any())).thenReturn({
        'D4-42-PAR-7': 'X/OK', // regression: was OK now X
      });

      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      expect(result.success, isFalse);
      expect(result.message, contains('Regressions'));
      expect(result.message, contains('D4-42-PAR-7 (#42)'));
    });

    test('IK-EXE-SYN-7: groups multiple issues separately', () async {
      // Per spec: group by issue number for per-issue state transitions
      final matches = [
        createTestIdMatch(
          testId: 'D4-42-PAR-7',
          issueNumber: 42,
          projectSpecific: 'PAR-7',
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
        'D4-99-LEX-3': 'X',
      });

      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      expect(result.success, isFalse); // has failures
      expect(result.message, contains('1 passing'));
      expect(result.message, contains('1 failing'));
      // Issue #42 all pass → VERIFYING candidate
      expect(result.message, contains('#42'));
      expect(result.message, contains('candidates for VERIFYING'));
    });

    test('IK-EXE-SYN-8: skips stubs in per-issue grouping', () async {
      // Per spec: stubs should not contribute to pass/fail counts
      final matches = [
        createTestIdMatch(
          testId: 'D4-42-PAR-7',
          issueNumber: 42,
          projectSpecific: 'PAR-7',
        ),
        createTestIdMatch(
          testId: 'D4-42',
          issueNumber: 42,
          projectSpecific: '',
          filePath: '/projects/d4rt/test/stub_test.dart',
          line: 5,
        ),
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
      // Issue #42 full test passes → VERIFYING candidate
      expect(result.message, contains('candidates for VERIFYING'));
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

    test('IK-EXE-AGG-4: produces CSV-formatted output with Project column',
        () async {
      // Per spec: output has Project, Test ID, Description, Issue#, Status
      final matches = [
        createTestIdMatch(
          testId: 'D4-42-PAR-7',
          issueNumber: 42,
          projectSpecific: 'PAR-7',
          description: 'D4-42-PAR-7: Parser handles arrays',
        ),
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
      // CSV format: Project,TestID,Description,Issue,Status
      expect(result.message, contains('D4,D4-42-PAR-7,'));
      expect(result.message, contains('#42'));
      expect(result.message, contains('OK'));
    });

    test('IK-EXE-AGG-5: detects regressions in baseline', () async {
      // Per spec: detect OK→X (regression) and X→OK (fix)
      final matches = [
        createTestIdMatch(
          testId: 'D4-42-PAR-7',
          issueNumber: 42,
          projectSpecific: 'PAR-7',
          description: 'D4-42-PAR-7: Parser test',
        ),
        createTestIdMatch(
          testId: 'D4-99-LEX-3',
          issueNumber: 99,
          projectSpecific: 'LEX-3',
          description: 'D4-99-LEX-3: Lexer test',
        ),
      ];

      when(() => mockScanner.scanProject(any())).thenReturn(matches);
      when(() => mockScanner.readLatestBaseline(any()))
          .thenReturn('content');
      when(() => mockScanner.parseBaseline(any())).thenReturn({
        'D4-42-PAR-7': 'X/OK', // regression
        'D4-99-LEX-3': 'OK/X', // fix
      });

      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('Regressions'));
      expect(result.message, contains('D4-42-PAR-7 (#42)'));
      expect(result.message, contains('Fixes'));
      expect(result.message, contains('D4-99-LEX-3 (#99)'));
    });

    test('IK-EXE-AGG-6: aggregates multiple tests with mixed statuses',
        () async {
      final matches = [
        createTestIdMatch(
          testId: 'D4-42-PAR-7',
          issueNumber: 42,
          projectSpecific: 'PAR-7',
          description: 'Parser test',
        ),
        createTestIdMatch(
          testId: 'D4-42-PAR-8',
          issueNumber: 42,
          projectSpecific: 'PAR-8',
          description: 'Parser test 2',
        ),
        createTestIdMatch(
          testId: 'D4-99-LEX-3',
          issueNumber: 99,
          projectSpecific: 'LEX-3',
          description: 'Lexer test',
        ),
      ];

      when(() => mockScanner.scanProject(any())).thenReturn(matches);
      when(() => mockScanner.readLatestBaseline(any()))
          .thenReturn('content');
      when(() => mockScanner.parseBaseline(any())).thenReturn({
        'D4-42-PAR-7': 'OK',
        'D4-42-PAR-8': 'X',
        'D4-99-LEX-3': 'OK',
      });

      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('3 issue-linked test(s)'));
      // Each entry has CSV format
      expect(result.message, contains('D4,D4-42-PAR-7'));
      expect(result.message, contains('D4,D4-42-PAR-8'));
      expect(result.message, contains('D4,D4-99-LEX-3'));
    });
  });

  // ===========================================================================
  // IK-EXE-SHW-TRV: ShowExecutor (traversal path)
  // ===========================================================================

  group('IK-EXE-SHW-TRV: ShowExecutor traversal [2026-02-15]', () {
    late ShowExecutor executor;

    setUp(() {
      executor = ShowExecutor(mockService, mockScanner);
    });

    test('IK-EXE-SHW-5: scans project for linked tests with file paths',
        () async {
      final matches = [
        createTestIdMatch(
          testId: 'D4-42-PAR-7',
          issueNumber: 42,
          filePath: '/projects/d4rt/test/parser_test.dart',
          line: 15,
        ),
        createTestIdMatch(
          testId: 'D4-42-LEX-3',
          issueNumber: 42,
          projectSpecific: 'LEX-3',
          filePath: '/projects/d4rt/test/lexer_test.dart',
          line: 42,
        ),
      ];

      when(() => mockScanner.scanForIssue(any(), any()))
          .thenReturn(matches);
      when(() => mockScanner.readLatestBaseline(any()))
          .thenReturn(null);

      final result = await executor.execute(
        context,
        const CliArgs(positionalArgs: ['42']),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('Issue #42 tests in project'));
      expect(result.message, contains('D4-42-PAR-7'));
      expect(result.message, contains('D4-42-LEX-3'));
      expect(result.message, contains('test/parser_test.dart:15'));
      expect(result.message, contains('test/lexer_test.dart:42'));
      verify(() => mockScanner.scanForIssue('/projects/d4rt', 42)).called(1);
    });

    test('IK-EXE-SHW-6: no tests found in project', () async {
      when(() => mockScanner.scanForIssue(any(), any())).thenReturn([]);

      final result = await executor.execute(
        context,
        const CliArgs(positionalArgs: ['42']),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('No tests for issue #42'));
    });

    test('IK-EXE-SHW-7: shows baseline status per test', () async {
      final matches = [
        createTestIdMatch(
          testId: 'D4-42-PAR-7',
          issueNumber: 42,
          filePath: '/projects/d4rt/test/parser_test.dart',
          line: 15,
        ),
        createTestIdMatch(
          testId: 'D4-42-PAR-8',
          issueNumber: 42,
          projectSpecific: 'PAR-8',
          filePath: '/projects/d4rt/test/parser_test.dart',
          line: 30,
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

      expect(result.success, isTrue);
      expect(result.message, contains('OK'));
      expect(result.message, contains('X'));
    });

    test('IK-EXE-SHW-8: missing baseline shows NOT RUN', () async {
      final matches = [
        createTestIdMatch(
          testId: 'D4-42-PAR-7',
          issueNumber: 42,
          filePath: '/projects/d4rt/test/parser_test.dart',
          line: 15,
        ),
      ];

      when(() => mockScanner.scanForIssue(any(), any()))
          .thenReturn(matches);
      when(() => mockScanner.readLatestBaseline(any()))
          .thenReturn(null);

      final result = await executor.execute(
        context,
        const CliArgs(positionalArgs: ['42']),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('NOT RUN'));
    });

    test('IK-EXE-SHW-9: traversal fails without issue number', () async {
      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Missing required argument'));
    });
  });

  // ===========================================================================
  // IK-EXE-TST: TestingExecutor (additional spec-driven tests)
  // ===========================================================================

  group('IK-EXE-TST: TestingExecutor service interactions [2026-02-15]', () {
    late TestingExecutor executor;

    setUp(() {
      executor = TestingExecutor(mockScanner, mockService);
    });

    test('IK-EXE-TST-7: non-numeric issue number fails', () async {
      final result = await executor.execute(
        context,
        const CliArgs(positionalArgs: ['abc']),
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Missing required argument'));
    });

    test('IK-EXE-TST-8: service.updateIssue failure handled gracefully',
        () async {
      final matches = [
        createTestIdMatch(testId: 'D4-42-PAR-7', issueNumber: 42),
      ];

      when(() => mockScanner.scanForIssue(any(), any()))
          .thenReturn(matches);
      when(() => mockService.updateIssue(
            issueNumber: any(named: 'issueNumber'),
            tags: any(named: 'tags'),
          )).thenThrow(Exception('API unavailable'));

      final result = await executor.execute(
        context,
        const CliArgs(positionalArgs: ['42']),
      );

      // Per spec: scan result is still valid even if API call fails
      expect(result.success, isTrue);
      expect(result.message, contains('Found 1 full test(s) for #42'));
    });

    test('IK-EXE-TST-9: verifies service.updateIssue called with testing tag',
        () async {
      final matches = [
        createTestIdMatch(testId: 'D4-42-PAR-7', issueNumber: 42),
      ];

      when(() => mockScanner.scanForIssue(any(), any()))
          .thenReturn(matches);
      when(() => mockService.updateIssue(
            issueNumber: any(named: 'issueNumber'),
            tags: any(named: 'tags'),
          )).thenAnswer((_) async => createTestIssue());

      await executor.execute(
        context,
        const CliArgs(positionalArgs: ['42']),
      );

      verify(() => mockService.updateIssue(
            issueNumber: 42,
            tags: ['testing'],
          )).called(1);
    });
  });

  // ===========================================================================
  // IK-EXE-VRF: VerifyExecutor (additional spec-driven tests)
  // ===========================================================================

  group('IK-EXE-VRF: VerifyExecutor service interactions [2026-02-15]', () {
    late VerifyExecutor executor;

    setUp(() {
      executor = VerifyExecutor(mockScanner, mockService);
    });

    test('IK-EXE-VRF-8: non-numeric issue number fails', () async {
      final result = await executor.execute(
        context,
        const CliArgs(positionalArgs: ['abc']),
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Missing required argument'));
    });

    test('IK-EXE-VRF-9: service.updateIssue called with verifying on all-pass',
        () async {
      final matches = [
        createTestIdMatch(testId: 'D4-42-PAR-7', issueNumber: 42),
      ];

      when(() => mockScanner.scanForIssue(any(), any()))
          .thenReturn(matches);
      when(() => mockScanner.readLatestBaseline(any()))
          .thenReturn('content');
      when(() => mockScanner.parseBaseline(any()))
          .thenReturn({'D4-42-PAR-7': 'OK'});
      when(() => mockService.updateIssue(
            issueNumber: any(named: 'issueNumber'),
            tags: any(named: 'tags'),
          )).thenAnswer((_) async => createTestIssue());

      await executor.execute(
        context,
        const CliArgs(positionalArgs: ['42']),
      );

      verify(() => mockService.updateIssue(
            issueNumber: 42,
            tags: ['verifying'],
          )).called(1);
    });

    test('IK-EXE-VRF-10: service.updateIssue NOT called when some fail',
        () async {
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

      await executor.execute(
        context,
        const CliArgs(positionalArgs: ['42']),
      );

      verifyNever(() => mockService.updateIssue(
            issueNumber: any(named: 'issueNumber'),
            tags: any(named: 'tags'),
          ));
    });

    test('IK-EXE-VRF-11: service.updateIssue failure does not break result',
        () async {
      final matches = [
        createTestIdMatch(testId: 'D4-42-PAR-7', issueNumber: 42),
      ];

      when(() => mockScanner.scanForIssue(any(), any()))
          .thenReturn(matches);
      when(() => mockScanner.readLatestBaseline(any()))
          .thenReturn('content');
      when(() => mockScanner.parseBaseline(any()))
          .thenReturn({'D4-42-PAR-7': 'OK'});
      when(() => mockService.updateIssue(
            issueNumber: any(named: 'issueNumber'),
            tags: any(named: 'tags'),
          )).thenThrow(Exception('API unavailable'));

      final result = await executor.execute(
        context,
        const CliArgs(positionalArgs: ['42']),
      );

      // Per spec: verification result is still valid even if API call fails
      expect(result.success, isTrue);
      expect(result.message, contains('ALL PASS'));
    });
  });

  // ===========================================================================
  // IK-EXE-SYN: SyncExecutor (additional spec-driven tests)
  // ===========================================================================

  group('IK-EXE-SYN: SyncExecutor --auto/--dry-run [2026-02-15]', () {
    late SyncExecutor executor;

    setUp(() {
      executor = SyncExecutor(mockScanner, mockService);
    });

    test('IK-EXE-SYN-9: --auto reopens on regression', () async {
      final tests = [
        createTestIdMatch(
          testId: 'D4-42-PAR-7',
          issueNumber: 42,
          filePath: '/projects/d4rt/test/parser_test.dart',
          line: 15,
        ),
      ];

      when(() => mockScanner.scanProject(any())).thenReturn(tests);
      when(() => mockScanner.readLatestBaseline(any()))
          .thenReturn('content');
      when(() => mockScanner.parseBaseline(any()))
          .thenReturn({'D4-42-PAR-7': 'X/OK'});
      when(() => mockService.reopenIssue(any(), note: any(named: 'note')))
          .thenAnswer((_) async => createTestIssue());

      await executor.execute(
        context,
        const CliArgs(extraOptions: {'auto': true}),
      );

      verify(() => mockService.reopenIssue(
            42,
            note: 'Regression detected by :sync',
          )).called(1);
    });

    test('IK-EXE-SYN-10: --auto with --dry-run does not reopen', () async {
      final tests = [
        createTestIdMatch(
          testId: 'D4-42-PAR-7',
          issueNumber: 42,
          filePath: '/projects/d4rt/test/parser_test.dart',
          line: 15,
        ),
      ];

      when(() => mockScanner.scanProject(any())).thenReturn(tests);
      when(() => mockScanner.readLatestBaseline(any()))
          .thenReturn('content');
      when(() => mockScanner.parseBaseline(any()))
          .thenReturn({'D4-42-PAR-7': 'X/OK'});

      final result = await executor.execute(
        context,
        const CliArgs(
          extraOptions: {'auto': true},
          dryRun: true,
        ),
      );

      verifyNever(
          () => mockService.reopenIssue(any(), note: any(named: 'note')));
      expect(result.message, contains('dry-run'));
    });

    test('IK-EXE-SYN-11: --auto with service failure continues gracefully',
        () async {
      final tests = [
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

      when(() => mockScanner.scanProject(any())).thenReturn(tests);
      when(() => mockScanner.readLatestBaseline(any()))
          .thenReturn('content');
      when(() => mockScanner.parseBaseline(any()))
          .thenReturn({
        'D4-42-PAR-7': 'X/OK',
        'D4-99-LEX-3': 'X/OK',
      });
      // First call fails, second succeeds
      var callCount = 0;
      when(() => mockService.reopenIssue(any(), note: any(named: 'note')))
          .thenAnswer((_) async {
        callCount++;
        if (callCount == 1) throw Exception('API error');
        return createTestIssue();
      });

      final result = await executor.execute(
        context,
        const CliArgs(extraOptions: {'auto': true}),
      );

      // Should continue despite first failure
      expect(result.message, contains('Regressions'));
    });

    test('IK-EXE-SYN-12: dry-run appends message note', () async {
      final tests = [
        createTestIdMatch(
          testId: 'D4-42-PAR-7',
          issueNumber: 42,
          filePath: '/projects/d4rt/test/parser_test.dart',
          line: 15,
        ),
      ];

      when(() => mockScanner.scanProject(any())).thenReturn(tests);
      when(() => mockScanner.readLatestBaseline(any()))
          .thenReturn('content');
      when(() => mockScanner.parseBaseline(any()))
          .thenReturn({'D4-42-PAR-7': 'OK'});

      final result = await executor.execute(
        context,
        const CliArgs(dryRun: true),
      );

      expect(result.message, contains('(dry-run: no changes applied)'));
    });

    test('IK-EXE-SYN-13: --auto with all passing does not reopen', () async {
      final tests = [
        createTestIdMatch(
          testId: 'D4-42-PAR-7',
          issueNumber: 42,
          filePath: '/projects/d4rt/test/parser_test.dart',
          line: 15,
        ),
      ];

      when(() => mockScanner.scanProject(any())).thenReturn(tests);
      when(() => mockScanner.readLatestBaseline(any()))
          .thenReturn('content');
      when(() => mockScanner.parseBaseline(any()))
          .thenReturn({'D4-42-PAR-7': 'OK'});

      await executor.execute(
        context,
        const CliArgs(extraOptions: {'auto': true}),
      );

      verifyNever(
          () => mockService.reopenIssue(any(), note: any(named: 'note')));
    });
  });

  // ===========================================================================
  // IK-EXE-SCN: ScanExecutor (additional spec-driven tests)
  // ===========================================================================

  group('IK-EXE-SCN: ScanExecutor additional [2026-02-15]', () {
    late ScanExecutor executor;

    setUp(() {
      executor = ScanExecutor(mockScanner);
    });

    test('IK-EXE-SCN-5: non-numeric issue number falls through to full scan',
        () async {
      when(() => mockScanner.scanProject(any())).thenReturn([]);

      final result = await executor.execute(
        context,
        const CliArgs(positionalArgs: ['abc']),
      );

      // 'abc' is not a valid issue number; scanProject (full scan) should be called
      expect(result.success, isTrue);
      verify(() => mockScanner.scanProject('/projects/d4rt')).called(1);
      verifyNever(() => mockScanner.scanForIssue(any(), any()));
    });

    test('IK-EXE-SCN-6: output contains relative file paths', () async {
      final matches = [
        createTestIdMatch(
          testId: 'D4-42-PAR-7',
          issueNumber: 42,
          filePath: '/projects/d4rt/test/parser_test.dart',
          line: 15,
        ),
      ];

      when(() => mockScanner.scanProject(any())).thenReturn(matches);

      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      expect(result.success, isTrue);
      // File path should be relative (stripped of context.path prefix)
      expect(result.message, contains('test/parser_test.dart'));
      expect(result.message, contains(':15'));
    });

    test('IK-EXE-SCN-7: output contains line numbers', () async {
      final matches = [
        createTestIdMatch(
          testId: 'D4-42-PAR-7',
          issueNumber: 42,
          filePath: '/projects/d4rt/test/parser_test.dart',
          line: 42,
        ),
      ];

      when(() => mockScanner.scanProject(any())).thenReturn(matches);

      final result = await executor.execute(
        context,
        const CliArgs(),
      );

      expect(result.success, isTrue);
      expect(result.message, contains(':42'));
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
