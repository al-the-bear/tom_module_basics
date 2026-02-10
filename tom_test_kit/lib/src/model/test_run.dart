import 'test_entry.dart';

/// The result of a single test in a run.
enum TestResult {
  /// Test passed.
  ok('OK'),

  /// Test failed.
  fail('X'),

  /// Test was skipped.
  skip('SKIP'),

  /// Test was not present in this run.
  absent('-');

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

  /// Results keyed by test full description.
  final Map<String, TestResult> results;

  TestRun({
    required this.timestamp,
    this.isBaseline = false,
    Map<String, TestResult>? results,
  }) : results = results ?? {};

  /// Column header in compact format: `MM-DD HH:MM`.
  String get columnHeader {
    final prefix = isBaseline ? 'Baseline ' : '';
    return '$prefix[${_pad(timestamp.month)}-${_pad(timestamp.day)} '
        '${_pad(timestamp.hour)}:${_pad(timestamp.minute)}]';
  }

  /// Sets the result for a test.
  void setResult(String fullDescription, TestResult result) {
    results[fullDescription] = result;
  }

  /// Gets the result for a test, defaulting to [TestResult.absent].
  TestResult getResult(String fullDescription) {
    return results[fullDescription] ?? TestResult.absent;
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
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
String formatResultCell(TestResult result, String expectation) {
  return '${result.label}/$expectation';
}

/// Represents a sorted test entry with its latest result for sorting.
class SortableTestEntry {
  final TestEntry entry;
  final TestResult latestResult;

  SortableTestEntry(this.entry, this.latestResult);

  int get sortPriority => resultSortPriority(latestResult, entry.expectation);
}
