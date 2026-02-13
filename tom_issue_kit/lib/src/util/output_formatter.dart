/// Output formatting utilities for issuekit.
///
/// Supports plain text, CSV, JSON, and Markdown output formats.
library;

import 'dart:convert';
import 'dart:io';

/// Output format specifier.
class OutputSpec {
  /// Constructor.
  const OutputSpec({
    required this.format,
    this.filename,
  });

  /// The output format.
  final OutputFormat format;

  /// Optional filename for output redirection.
  final String? filename;

  /// Parse from a string (e.g., 'json' or 'csv:output.csv').
  static OutputSpec? tryParse(String? spec) {
    if (spec == null || spec.isEmpty) return null;

    String formatStr;
    String? filename;

    if (spec.contains(':')) {
      final parts = spec.split(':');
      formatStr = parts[0];
      filename = parts.sublist(1).join(':');
    } else {
      formatStr = spec;
    }

    final format = OutputFormat.tryParse(formatStr);
    if (format == null) return null;

    return OutputSpec(format: format, filename: filename);
  }

  /// Whether this spec directs output to a file.
  bool get hasFile => filename != null && filename!.isNotEmpty;
}

/// Supported output formats.
enum OutputFormat {
  /// Plain text (default).
  plain,

  /// CSV (comma-separated values).
  csv,

  /// JSON.
  json,

  /// Markdown.
  md;

  /// Parse from string.
  static OutputFormat? tryParse(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'plain':
      case 'text':
        return OutputFormat.plain;
      case 'csv':
        return OutputFormat.csv;
      case 'json':
        return OutputFormat.json;
      case 'md':
      case 'markdown':
        return OutputFormat.md;
      default:
        return null;
    }
  }
}

/// Output writer that can write to stdout or a file.
class OutputWriter {
  /// Constructor.
  OutputWriter({this.spec});

  /// Output specification.
  final OutputSpec? spec;

  /// The output sink (file or stdout).
  IOSink? _sink;

  /// Whether we created a file sink that needs closing.
  bool _needsClose = false;

  /// Get the output sink.
  IOSink get sink {
    if (_sink != null) return _sink!;

    if (spec?.hasFile ?? false) {
      final file = File(spec!.filename!);
      _sink = file.openWrite();
      _needsClose = true;
    } else {
      _sink = stdout;
    }

    return _sink!;
  }

  /// Write text to the output.
  void write(String text) {
    sink.write(text);
  }

  /// Write a line to the output.
  void writeln([String text = '']) {
    sink.writeln(text);
  }

  /// Close the output (if writing to a file).
  Future<void> close() async {
    if (_needsClose && _sink != null) {
      await _sink!.close();
      _sink = null;
      _needsClose = false;
    }
  }
}

/// Utility class for formatting output in different formats.
class OutputFormatter {
  /// Format a list of rows as plain text table.
  static String formatTable(
    List<List<String>> rows, {
    List<String>? headers,
    List<int>? columnWidths,
  }) {
    if (rows.isEmpty && headers == null) return '';

    final allRows = <List<String>>[];
    if (headers != null) {
      allRows.add(headers);
    }
    allRows.addAll(rows);

    // Calculate column widths
    final numCols =
        allRows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    final widths = columnWidths ?? List.filled(numCols, 0);

    for (final row in allRows) {
      for (var i = 0; i < row.length && i < widths.length; i++) {
        if (row[i].length > widths[i]) {
          widths[i] = row[i].length;
        }
      }
    }

    // Format rows
    final buffer = StringBuffer();

    for (var rowIndex = 0; rowIndex < allRows.length; rowIndex++) {
      final row = allRows[rowIndex];
      final cells = <String>[];

      for (var i = 0; i < numCols; i++) {
        final cell = i < row.length ? row[i] : '';
        cells.add(cell.padRight(widths[i]));
      }

      buffer.writeln(cells.join('  '));

      // Add separator after header
      if (headers != null && rowIndex == 0) {
        final separatorCells =
            widths.map((w) => '-' * w).toList();
        buffer.writeln(separatorCells.join('  '));
      }
    }

    return buffer.toString();
  }

  /// Format rows as CSV.
  static String formatCsv(
    List<List<String>> rows, {
    List<String>? headers,
  }) {
    final buffer = StringBuffer();

    if (headers != null) {
      buffer.writeln(_csvRow(headers));
    }

    for (final row in rows) {
      buffer.writeln(_csvRow(row));
    }

    return buffer.toString();
  }

  /// Format a single CSV row.
  static String _csvRow(List<String> cells) {
    return cells.map(_csvEscape).join(',');
  }

  /// Escape a CSV cell value.
  static String _csvEscape(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Format data as JSON.
  static String formatJson(
    dynamic data, {
    bool pretty = true,
  }) {
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(data);
    }
    return jsonEncode(data);
  }

  /// Format rows as a Markdown table.
  static String formatMarkdownTable(
    List<List<String>> rows, {
    List<String>? headers,
    List<String>? alignment,
  }) {
    if (rows.isEmpty && headers == null) return '';

    final buffer = StringBuffer();

    // Header row
    if (headers != null) {
      buffer.writeln('| ${headers.join(' | ')} |');

      // Separator with alignment
      final separators = <String>[];
      for (var i = 0; i < headers.length; i++) {
        final align = alignment != null && i < alignment.length
            ? alignment[i]
            : 'left';
        switch (align) {
          case 'center':
            separators.add(':---:');
          case 'right':
            separators.add('---:');
          default:
            separators.add('---');
        }
      }
      buffer.writeln('| ${separators.join(' | ')} |');
    }

    // Data rows
    for (final row in rows) {
      // Escape pipe characters in cell values
      final escapedRow = row.map((cell) => cell.replaceAll('|', '\\|'));
      buffer.writeln('| ${escapedRow.join(' | ')} |');
    }

    return buffer.toString();
  }
}

/// Severity levels for issues.
enum Severity {
  /// Critical severity.
  critical,

  /// High severity.
  high,

  /// Normal severity (default).
  normal,

  /// Low severity.
  low;

  /// Parse from string.
  static Severity? tryParse(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'critical':
        return Severity.critical;
      case 'high':
        return Severity.high;
      case 'normal':
        return Severity.normal;
      case 'low':
        return Severity.low;
      default:
        return null;
    }
  }

  /// Get display string.
  String get displayName {
    switch (this) {
      case Severity.critical:
        return 'CRITICAL';
      case Severity.high:
        return 'HIGH';
      case Severity.normal:
        return 'NORMAL';
      case Severity.low:
        return 'LOW';
    }
  }
}

/// Issue states.
enum IssueState {
  /// New issue.
  newState,

  /// Analyzed issue.
  analyzed,

  /// Assigned to a project.
  assigned,

  /// Reproduction test created.
  testing,

  /// All tests pass, awaiting confirmation.
  verifying,

  /// Fix confirmed.
  resolved,

  /// Closed/archived.
  closed,

  /// Blocked.
  blocked,

  /// Duplicate.
  duplicate,

  /// Won't fix.
  wontfix;

  /// Parse from string.
  static IssueState? tryParse(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'new':
        return IssueState.newState;
      case 'analyzed':
        return IssueState.analyzed;
      case 'assigned':
        return IssueState.assigned;
      case 'testing':
        return IssueState.testing;
      case 'verifying':
        return IssueState.verifying;
      case 'resolved':
        return IssueState.resolved;
      case 'closed':
        return IssueState.closed;
      case 'blocked':
        return IssueState.blocked;
      case 'duplicate':
        return IssueState.duplicate;
      case 'wontfix':
        return IssueState.wontfix;
      default:
        return null;
    }
  }

  /// Get the label name used in GitHub.
  String get labelName {
    switch (this) {
      case IssueState.newState:
        return 'new';
      case IssueState.analyzed:
        return 'analyzed';
      case IssueState.assigned:
        return 'assigned';
      case IssueState.testing:
        return 'testing';
      case IssueState.verifying:
        return 'verifying';
      case IssueState.resolved:
        return 'resolved';
      case IssueState.closed:
        return 'closed';
      case IssueState.blocked:
        return 'blocked';
      case IssueState.duplicate:
        return 'duplicate';
      case IssueState.wontfix:
        return 'wontfix';
    }
  }

  /// Get display string.
  String get displayName {
    switch (this) {
      case IssueState.newState:
        return 'NEW';
      case IssueState.analyzed:
        return 'ANALYZED';
      case IssueState.assigned:
        return 'ASSIGNED';
      case IssueState.testing:
        return 'TESTING';
      case IssueState.verifying:
        return 'VERIFYING';
      case IssueState.resolved:
        return 'RESOLVED';
      case IssueState.closed:
        return 'CLOSED';
      case IssueState.blocked:
        return 'BLOCKED';
      case IssueState.duplicate:
        return 'DUPLICATE';
      case IssueState.wontfix:
        return 'WONTFIX';
    }
  }
}
