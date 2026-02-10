/// Output formatting for testkit commands.
///
/// Supports plain text, CSV, JSON, and Markdown output formats.
/// Output can be directed to stdout or a file.
library;

import 'dart:convert';
import 'dart:io';

/// Supported output formats.
enum OutputFormat {
  plain,
  csv,
  json,
  md;

  /// Parses a format string (case-insensitive).
  static OutputFormat? tryParse(String value) {
    return switch (value.toLowerCase()) {
      'plain' => plain,
      'csv' => csv,
      'json' => json,
      'md' || 'markdown' => md,
      _ => null,
    };
  }
}

/// Parsed output specification from `--output <format>:<filename>`.
class OutputSpec {
  final OutputFormat format;
  final String? filePath;

  OutputSpec({required this.format, this.filePath});

  /// Parses an output spec string.
  ///
  /// Formats:
  /// - `plain` — stdout, plain text
  /// - `csv:results.csv` — file, CSV
  /// - `json` — stdout, JSON
  /// - `md:report.md` — file, Markdown
  static OutputSpec? tryParse(String value) {
    final colonIdx = value.indexOf(':');
    if (colonIdx == -1) {
      // No colon — format only, stdout
      final format = OutputFormat.tryParse(value);
      if (format == null) return null;
      return OutputSpec(format: format);
    }

    final formatStr = value.substring(0, colonIdx);
    final filePath = value.substring(colonIdx + 1);
    final format = OutputFormat.tryParse(formatStr);
    if (format == null) return null;
    if (filePath.isEmpty) return OutputSpec(format: format);
    return OutputSpec(format: format, filePath: filePath);
  }

  /// Default output spec: plain to stdout.
  static OutputSpec get defaultSpec => OutputSpec(format: OutputFormat.plain);
}

/// A table row for diff/output formatting.
class OutputRow {
  final String? id;
  final String? groups;
  final String description;
  final String resultA;
  final String resultB;

  OutputRow({
    this.id,
    this.groups,
    required this.description,
    required this.resultA,
    required this.resultB,
  });
}

/// Formats output rows into the specified format and writes to stdout or file.
class OutputWriter {
  final OutputSpec spec;

  OutputWriter(this.spec);

  /// Writes a simple table of rows.
  Future<void> writeTable({
    required List<String> headers,
    required List<List<String>> rows,
    String? title,
  }) async {
    final content = switch (spec.format) {
      OutputFormat.plain => _formatPlain(headers, rows, title: title),
      OutputFormat.csv => _formatCsv(headers, rows),
      OutputFormat.json => _formatJson(headers, rows, title: title),
      OutputFormat.md => _formatMarkdown(headers, rows, title: title),
    };

    if (spec.filePath != null) {
      final file = File(spec.filePath!);
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
    } else {
      stdout.write(content);
    }
  }

  String _formatPlain(List<String> headers, List<List<String>> rows,
      {String? title}) {
    if (rows.isEmpty) return title != null ? '$title\nNo differences.\n' : '';

    // Calculate column widths
    final widths = List<int>.generate(
        headers.length, (i) => headers[i].length);
    for (final row in rows) {
      for (var i = 0; i < row.length && i < widths.length; i++) {
        if (row[i].length > widths[i]) widths[i] = row[i].length;
      }
    }

    final buf = StringBuffer();
    if (title != null) {
      buf.writeln(title);
      buf.writeln();
    }

    // Header
    for (var i = 0; i < headers.length; i++) {
      if (i > 0) buf.write('  ');
      buf.write(headers[i].padRight(widths[i]));
    }
    buf.writeln();

    // Separator
    for (var i = 0; i < headers.length; i++) {
      if (i > 0) buf.write('  ');
      buf.write('-' * widths[i]);
    }
    buf.writeln();

    // Rows
    for (final row in rows) {
      for (var i = 0; i < row.length && i < widths.length; i++) {
        if (i > 0) buf.write('  ');
        buf.write(row[i].padRight(widths[i]));
      }
      buf.writeln();
    }

    return buf.toString();
  }

  String _formatCsv(List<String> headers, List<List<String>> rows) {
    final buf = StringBuffer();
    buf.writeln(headers.map(_escapeCsv).join(','));
    for (final row in rows) {
      buf.writeln(row.map(_escapeCsv).join(','));
    }
    return buf.toString();
  }

  String _formatJson(List<String> headers, List<List<String>> rows,
      {String? title}) {
    final result = <String, dynamic>{};
    if (title != null) result['title'] = title;
    result['headers'] = headers;
    result['rows'] = rows
        .map((row) {
          final map = <String, String>{};
          for (var i = 0; i < headers.length && i < row.length; i++) {
            map[headers[i]] = row[i];
          }
          return map;
        })
        .toList();
    result['count'] = rows.length;

    const encoder = JsonEncoder.withIndent('  ');
    return '${encoder.convert(result)}\n';
  }

  String _formatMarkdown(List<String> headers, List<List<String>> rows,
      {String? title}) {
    final buf = StringBuffer();
    if (title != null) {
      buf.writeln('# $title');
      buf.writeln();
    }

    if (rows.isEmpty) {
      buf.writeln('No differences.');
      return buf.toString();
    }

    // Header row
    buf.write('| ');
    buf.write(headers.join(' | '));
    buf.writeln(' |');

    // Separator
    buf.write('| ');
    buf.write(headers.map((h) => '-' * h.length).join(' | '));
    buf.writeln(' |');

    // Data rows
    for (final row in rows) {
      buf.write('| ');
      buf.write(row.join(' | '));
      buf.writeln(' |');
    }

    return buf.toString();
  }

  static String _escapeCsv(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
