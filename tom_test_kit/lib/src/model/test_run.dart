import 'test_entry.dart';
import '../util/format_helpers.dart';

/// The result of a single test in a run.
enum TestResult {
  /// Test passed.
  ok('OK'),

  /// Test failed.
  fail('X'),

  /// Test was skipped.
  skip('-'),

  /// Test was not present in this run.
  absent('--');

  final String label;
  const TestResult(this.label);

  @override
  String toString() => label;
}

/// A single test run with timestamp and results for each test.
class TestRun {
  /// Timestamp of this run.
  final DateTime timestamp;

  /// Whether this is the baseline run.
  final bool isBaseline;

  /// Optional short comment describing this run.
  String? comment;

  /// Results keyed by test full description.
  final Map<String, TestResult> results;

  TestRun({
    required this.timestamp,
    this.isBaseline = false,
    this.comment,
    Map<String, TestResult>? results,
  }) : results = results ?? {};

  /// Column header in compact format: `[MM-DD HH:MM]` or `[MM-DD HH:MM] comment`.
  String get columnHeader {
    final prefix = isBaseline ? 'Baseline ' : '';
    final ts = '[${padTwo(timestamp.month)}-${padTwo(timestamp.day)} '
        '${padTwo(timestamp.hour)}:${padTwo(timestamp.minute)}]';
    final suffix = comment != null && comment!.isNotEmpty ? ' $comment' : '';
    return '$prefix$ts$suffix';
  }

  /// Sets the result for a test.
  void setResult(String fullDescription, TestResult result) {
    results[fullDescription] = result;
  }

  /// Gets the result for a test, defaulting to [TestResult.absent].
  TestResult getResult(String fullDescription) {
    return results[fullDescription] ?? TestResult.absent;
  }
}

/// Sort priority for a result/expectation combination.
///
/// Lower values sort first (higher priority).
int resultSortPriority(TestResult result, String expectation) {
  return switch ((result, expectation)) {
    (TestResult.fail, 'OK') => 0, // Regression — highest priority
    (TestResult.fail, 'FAIL') => 1, // Expected failure
    (TestResult.ok, 'FAIL') => 2, // Unexpected pass (progress)
    (TestResult.ok, 'OK') => 3, // Healthy
    (TestResult.skip, _) => 4, // Skipped
    (TestResult.absent, _) => 5, // Not present
    _ => 6,
  };
}

/// Formats a result cell: `<result>/<expectation>`.
///
/// Expectation is mapped to match result labels: `OK` stays `OK`,
/// `FAIL` becomes `X`.
String formatResultCell(TestResult result, String expectation) {
  final expectLabel = expectation == 'FAIL' ? 'X' : expectation;
  return '${result.label}/$expectLabel';
}

/// Represents a sorted test entry with its latest result for sorting.
class SortableTestEntry {
  final TestEntry entry;
  final TestResult latestResult;

  SortableTestEntry(this.entry, this.latestResult);

  int get sortPriority => resultSortPriority(latestResult, entry.expectation);
}
