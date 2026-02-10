/// Formatting utilities shared across tom_test_kit.
library;

/// Zero-pads an integer to at least 2 digits.
///
/// ```dart
/// padTwo(3)  // '03'
/// padTwo(12) // '12'
/// ```
String padTwo(int n) => n.toString().padLeft(2, '0');

/// Escapes pipe characters in markdown table cells.
///
/// Replaces `|` with `\|` to prevent column splitting.
String escapeMarkdownCell(String text) {
  return text.replaceAll('|', '\\|');
}

/// Generates a compact timestamp string for baseline filenames.
///
/// Format: `MMDD_HHMM` (e.g., `0210_1430`).
String baselineTimestamp(DateTime dateTime) {
  return '${padTwo(dateTime.month)}${padTwo(dateTime.day)}_'
      '${padTwo(dateTime.hour)}${padTwo(dateTime.minute)}';
}
