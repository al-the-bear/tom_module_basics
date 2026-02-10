/// Shared test helpers for tracking command tests.
///
/// Provides factory functions to create TrackingFile instances with
/// known data for deterministic testing.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tom_test_kit/tom_test_kit.dart';

/// Creates a minimal tracking file with one baseline run.
///
/// 3 tests: test A (OK), test B (FAIL), test C (SKIP).
TrackingFile createSingleRunTracking() {
  final entries = [
    TestEntry(
      id: 'TK-A',
      fullDescription: 'group A test A',
      description: 'test A',
      groups: 'group A',
      creationDate: DateTime(2026, 1, 1),
    ),
    TestEntry(
      id: 'TK-B',
      fullDescription: 'group B test B',
      description: 'test B',
      groups: 'group B',
      expectation: 'FAIL',
      creationDate: DateTime(2026, 1, 2),
    ),
    TestEntry(
      id: 'TK-C',
      fullDescription: 'group C test C',
      description: 'test C',
      groups: 'group C',
      creationDate: DateTime(2026, 1, 3),
    ),
  ];
  final run = TestRun(
    timestamp: DateTime(2026, 2, 10, 14, 30),
    isBaseline: true,
    results: {
      'group A test A': TestResult.ok,
      'group B test B': TestResult.fail,
      'group C test C': TestResult.skip,
    },
  );
  return TrackingFile.fromBaseline(entries, run);
}

/// Creates a tracking file with 3 runs for diff/history/status testing.
///
/// Baseline:  A=OK,  B=FAIL, C=SKIP
/// Run 2:     A=FAIL, B=OK,  C=OK     (A regresses, B fixes)
/// Run 3:     A=OK,  B=OK,  C=FAIL    (A fixes, C regresses)
TrackingFile createMultiRunTracking() {
  final tracking = createSingleRunTracking();

  final run2 = TestRun(
    timestamp: DateTime(2026, 2, 11, 10, 0),
    comment: 'second run',
    results: {
      'group A test A': TestResult.fail,
      'group B test B': TestResult.ok,
      'group C test C': TestResult.ok,
    },
  );
  tracking.addRun(run2, []);

  final run3 = TestRun(
    timestamp: DateTime(2026, 2, 12, 16, 45),
    comment: 'third run',
    results: {
      'group A test A': TestResult.ok,
      'group B test B': TestResult.ok,
      'group C test C': TestResult.fail,
    },
  );
  tracking.addRun(run3, []);

  return tracking;
}

/// Creates a tracking file with 4 runs, including flaky patterns.
///
/// Baseline:  A=OK,  B=FAIL, C=OK
/// Run 2:     A=FAIL, B=OK,  C=OK
/// Run 3:     A=OK,  B=FAIL, C=OK
/// Run 4:     A=FAIL, B=OK,  C=OK
///
/// Test A flips 3 times (OK→X→OK→X), test B flips 3 times (X→OK→X→OK).
/// Test C is stable (always OK after baseline).
TrackingFile createFlakyTracking() {
  final entries = [
    TestEntry(
      id: 'TK-A',
      fullDescription: 'group A test A',
      description: 'test A',
      groups: 'group A',
    ),
    TestEntry(
      id: 'TK-B',
      fullDescription: 'group B test B',
      description: 'test B',
      groups: 'group B',
    ),
    TestEntry(
      id: 'TK-C',
      fullDescription: 'group C test C',
      description: 'test C',
      groups: 'group C',
    ),
  ];
  final baseline = TestRun(
    timestamp: DateTime(2026, 3, 1, 10, 0),
    isBaseline: true,
    results: {
      'group A test A': TestResult.ok,
      'group B test B': TestResult.fail,
      'group C test C': TestResult.ok,
    },
  );
  final tracking = TrackingFile.fromBaseline(entries, baseline);

  tracking.addRun(
    TestRun(
      timestamp: DateTime(2026, 3, 2, 10, 0),
      results: {
        'group A test A': TestResult.fail,
        'group B test B': TestResult.ok,
        'group C test C': TestResult.ok,
      },
    ),
    [],
  );
  tracking.addRun(
    TestRun(
      timestamp: DateTime(2026, 3, 3, 10, 0),
      results: {
        'group A test A': TestResult.ok,
        'group B test B': TestResult.fail,
        'group C test C': TestResult.ok,
      },
    ),
    [],
  );
  tracking.addRun(
    TestRun(
      timestamp: DateTime(2026, 3, 4, 10, 0),
      results: {
        'group A test A': TestResult.fail,
        'group B test B': TestResult.ok,
        'group C test C': TestResult.ok,
      },
    ),
    [],
  );

  return tracking;
}

/// Writes a tracking file to a temp directory in the standard doc/ location.
///
/// Returns the path to the written file.
Future<String> writeTrackingToTemp(
  TrackingFile tracking,
  Directory tempDir, {
  String filename = 'baseline_0210_1430.csv',
}) async {
  final filePath = p.join(tempDir.path, 'doc', filename);
  await tracking.write(filePath);
  return filePath;
}

/// Creates a fake last_testrun.json in the doc/ directory.
///
/// Contains test events for the given test descriptions with optional
/// error information for failed tests.
Future<String> writeLastTestRunJson(
  Directory tempDir, {
  Map<String, String?> testErrors = const {},
}) async {
  final jsonPath = p.join(tempDir.path, 'doc', 'last_testrun.json');
  final file = File(jsonPath);
  await file.parent.create(recursive: true);

  final buf = StringBuffer();
  var testId = 1;

  for (final entry in testErrors.entries) {
    // testStart event
    buf.writeln('{"type":"testStart","test":{"id":$testId,'
        '"name":"${entry.key}","suiteID":0,"groupIDs":[0],'
        '"metadata":{"skip":false},"line":1,"column":1,'
        '"url":"file:///test/test.dart"}}');

    // error event if error message provided
    if (entry.value != null) {
      buf.writeln('{"type":"error","testID":$testId,'
          '"error":"${entry.value}","stackTrace":"test_file.dart:10",'
          '"isFailure":true}');
    }

    // testDone event
    final result = entry.value != null ? 'failure' : 'success';
    buf.writeln('{"type":"testDone","testID":$testId,'
        '"result":"$result","time":100}');

    testId++;
  }

  await file.writeAsString(buf.toString());
  return jsonPath;
}
