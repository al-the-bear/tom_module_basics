import '../util/format_helpers.dart';

/// Represents a single test entry with parsed metadata from its description.
class TestEntry {
  /// The test ID (text before the first colon), or null if no ID found.
  final String? id;

  /// The full test description as reported by `dart test`.
  final String fullDescription;

  /// The human-readable description (without ID prefix, date, expectation).
  final String description;

  /// The creation date extracted from `[YYYY-MM-DD HH:MM]`, or null.
  final DateTime? creationDate;

  /// The expected result: `OK` (pass) or `FAIL`.
  final String expectation;

  /// The test suite (file path) this test belongs to.
  final String? suite;

  TestEntry({
    this.id,
    required this.fullDescription,
    required this.description,
    this.creationDate,
    this.expectation = 'OK',
    this.suite,
  });

  /// Returns the display label for the tracking table.
  ///
  /// Format: `<ID>: <description> [<creation date>]` or just `<description>`.
  String get displayLabel {
    final buf = StringBuffer();
    if (id != null) buf.write('$id: ');
    buf.write(description);
    if (creationDate != null) {
      final d = creationDate!;
      buf.write(' [${padTwo(d.year)}-${padTwo(d.month)}-${padTwo(d.day)} '
          '${padTwo(d.hour)}:${padTwo(d.minute)}]');
    }
    return buf.toString();
  }

  /// Returns the sort key based on creation date.
  ///
  /// Tests without a creation date sort after dated tests.
  DateTime get sortDate => creationDate ?? DateTime(9999);

  @override
  String toString() => 'TestEntry($displayLabel, expect=$expectation)';
}
