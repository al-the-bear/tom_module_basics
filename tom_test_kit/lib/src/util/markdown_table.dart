/// Markdown table parsing and formatting helpers.
library;

import '../model/test_entry.dart';
import '../model/test_run.dart';

/// Splits a markdown table row into cell contents.
///
/// Handles escaped pipe characters (`\|`). Returns an empty list if the
/// row doesn't start and end with `|`.
///
/// ```dart
/// splitTableRow('| A | B | C |') // ['A', 'B', 'C'] (trimmed below)
/// ```
List<String> splitTableRow(String row) {
  final cleaned = row.trim();
  if (!cleaned.startsWith('|') || !cleaned.endsWith('|')) return [];

  final inner = cleaned.substring(1, cleaned.length - 1);
  final cells = <String>[];
  final buf = StringBuffer();
  for (var i = 0; i < inner.length; i++) {
    if (inner[i] == '|' && (i == 0 || inner[i - 1] != '\\')) {
      cells.add(buf.toString());
      buf.clear();
    } else {
      buf.write(inner[i]);
    }
  }
  cells.add(buf.toString());
  return cells;
}

/// Parses a column timestamp from a header cell.
///
/// Recognises `[MM-DD HH:MM]` format, with optional `Baseline ` prefix
/// and optional trailing comment text.
/// Uses the current year since tracking files don't store years in headers.
///
/// Returns null if the header doesn't contain a valid timestamp.
DateTime? parseColumnTimestamp(String header) {
  return parseColumnHeader(header)?.timestamp;
}

/// Parsed column header with timestamp, baseline flag, and optional comment.
class ColumnHeader {
  final DateTime timestamp;
  final bool isBaseline;
  final String? comment;

  ColumnHeader({
    required this.timestamp,
    required this.isBaseline,
    this.comment,
  });
}

/// Parses a column header into its components.
///
/// Recognises `[MM-DD HH:MM]` format with optional `Baseline ` prefix
/// and optional trailing comment text after the closing bracket.
///
/// Returns null if the header doesn't contain a valid timestamp.
ColumnHeader? parseColumnHeader(String header) {
  final trimmed = header.trim();
  final isBaseline = trimmed.startsWith('Baseline');

  final match = RegExp(
    r'\[(\d{2})-(\d{2})\s+(\d{2}):(\d{2})\]',
  ).firstMatch(trimmed);
  if (match == null) return null;

  final now = DateTime.now();
  final timestamp = DateTime(
    now.year,
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    int.parse(match.group(4)!),
  );

  // Extract comment: everything after the closing bracket
  final afterBracket = trimmed.substring(match.end).trim();
  final comment = afterBracket.isNotEmpty ? afterBracket : null;

  return ColumnHeader(
    timestamp: timestamp,
    isBaseline: isBaseline,
    comment: comment,
  );
}

/// Parses a result cell string back into a [TestResult].
///
/// Picks the result from the first part of a `<result>/<expectation>` cell.
/// Returns [TestResult.absent] if unrecognised.
TestResult parseResultCell(String cell) {
  if (cell.startsWith('OK')) return TestResult.ok;
  if (cell.startsWith('X')) return TestResult.fail;
  if (cell.startsWith('--')) return TestResult.absent;
  if (cell.startsWith('-')) return TestResult.skip;
  return TestResult.absent;
}

/// Reconstructs a [TestEntry] from a display label in a tracking table.
///
/// Parses the optional ID (before the first colon), creation date
/// `[YYYY-MM-DD HH:MM]`, and expected result `(PASS)` / `(FAIL)`.
TestEntry parseEntryFromLabel(String label) {
  String? id;
  var description = label;
  DateTime? creationDate;
  var expectation = 'OK';

  // Extract ID (text before first colon, max 20 chars)
  final colonIdx = label.indexOf(':');
  if (colonIdx > 0 && colonIdx < 20) {
    id = label.substring(0, colonIdx).trim();
    description = label.substring(colonIdx + 1).trim();
  }

  // Extract creation date [YYYY-MM-DD HH:MM]
  final dateMatch = RegExp(
    r'\[(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})\]',
  ).firstMatch(description);
  if (dateMatch != null) {
    creationDate = DateTime(
      int.parse(dateMatch.group(1)!),
      int.parse(dateMatch.group(2)!),
      int.parse(dateMatch.group(3)!),
      int.parse(dateMatch.group(4)!),
      int.parse(dateMatch.group(5)!),
    );
    description = description.replaceFirst(dateMatch.group(0)!, '').trim();
  }

  // Extract expected result (PASS)/(FAIL) from remaining description
  final expectMatch = RegExp(r'\((PASS|FAIL)\)\s*$').firstMatch(description);
  if (expectMatch != null) {
    expectation = expectMatch.group(1) == 'FAIL' ? 'FAIL' : 'OK';
    description = description.replaceFirst(expectMatch.group(0)!, '').trim();
  }

  return TestEntry(
    id: id,
    fullDescription: label,
    description: description,
    creationDate: creationDate,
    expectation: expectation,
  );
}

/// Reconstructs a [TestEntry] from separate ID, Groups, and Description
/// columns in the new 3-column tracking table format.
///
/// The [description] parameter is the Description column content which may
/// contain creation date `[YYYY-MM-DD HH:MM]` and `(FAIL)` markers.
TestEntry parseEntryFromColumns({
  required String id,
  required String groups,
  required String description,
}) {
  var remaining = description;
  DateTime? creationDate;
  var expectation = 'OK';

  // Extract expected result (PASS)/(FAIL) from end
  final expectMatch = RegExp(r'\((PASS|FAIL)\)\s*$').firstMatch(remaining);
  if (expectMatch != null) {
    expectation = expectMatch.group(1) == 'FAIL' ? 'FAIL' : 'OK';
    remaining = remaining.substring(0, expectMatch.start).trim();
  }

  // Extract creation date [YYYY-MM-DD HH:MM]
  final dateMatch = RegExp(
    r'\[(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})\]',
  ).firstMatch(remaining);
  if (dateMatch != null) {
    creationDate = DateTime(
      int.parse(dateMatch.group(1)!),
      int.parse(dateMatch.group(2)!),
      int.parse(dateMatch.group(3)!),
      int.parse(dateMatch.group(4)!),
      int.parse(dateMatch.group(5)!),
    );
    remaining = remaining.replaceFirst(dateMatch.group(0)!, '').trim();
  }

  // Reconstruct fullDescription to match what DartTestParser produces.
  // fullDescription is the test name WITHOUT groups prefix (groups are stored
  // separately). It includes id prefix, date bracket, and (FAIL) suffix from
  // the original test name.
  final idPrefix = id.isNotEmpty ? '$id: ' : '';

  // Build date bracket if creationDate was present
  String dateBracket = '';
  if (creationDate != null) {
    final d = creationDate;
    dateBracket =
        ' [${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}]';
  }

  // If the test has FAIL expectation, the original test name included (FAIL).
  // For OK expectation, no suffix was present.
  final expectSuffix = expectation == 'FAIL' ? ' (FAIL)' : '';
  final fullDescription = '$idPrefix$remaining$dateBracket$expectSuffix';

  return TestEntry(
    id: id.isNotEmpty ? id : null,
    fullDescription: fullDescription,
    description: remaining,
    groups: groups.isNotEmpty ? groups : null,
    creationDate: creationDate,
    expectation: expectation,
  );
}
