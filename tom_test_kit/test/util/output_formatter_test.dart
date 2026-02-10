import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_test_kit/tom_test_kit.dart';

/// Test IDs: TK-OFMT-1 through TK-OFMT-14
void main() {
  group('OutputFormat', () {
    test('TK-OFMT-1: tryParse returns correct formats', () {
      expect(OutputFormat.tryParse('plain'), equals(OutputFormat.plain));
      expect(OutputFormat.tryParse('csv'), equals(OutputFormat.csv));
      expect(OutputFormat.tryParse('json'), equals(OutputFormat.json));
      expect(OutputFormat.tryParse('md'), equals(OutputFormat.md));
      expect(OutputFormat.tryParse('markdown'), equals(OutputFormat.md));
    });

    test('TK-OFMT-2: tryParse is case-insensitive', () {
      expect(OutputFormat.tryParse('PLAIN'), equals(OutputFormat.plain));
      expect(OutputFormat.tryParse('Csv'), equals(OutputFormat.csv));
      expect(OutputFormat.tryParse('JSON'), equals(OutputFormat.json));
      expect(OutputFormat.tryParse('MD'), equals(OutputFormat.md));
    });

    test('TK-OFMT-3: tryParse returns null for invalid format', () {
      expect(OutputFormat.tryParse('xml'), isNull);
      expect(OutputFormat.tryParse(''), isNull);
      expect(OutputFormat.tryParse('html'), isNull);
    });
  });

  group('OutputSpec', () {
    test('TK-OFMT-4: tryParse with format only', () {
      final spec = OutputSpec.tryParse('csv');
      expect(spec, isNotNull);
      expect(spec!.format, equals(OutputFormat.csv));
      expect(spec.filePath, isNull);
    });

    test('TK-OFMT-5: tryParse with format and file path', () {
      final spec = OutputSpec.tryParse('csv:output.csv');
      expect(spec, isNotNull);
      expect(spec!.format, equals(OutputFormat.csv));
      expect(spec.filePath, equals('output.csv'));
    });

    test('TK-OFMT-6: tryParse returns null for invalid format', () {
      expect(OutputSpec.tryParse('xml:output.xml'), isNull);
      expect(OutputSpec.tryParse(''), isNull);
    });

    test('TK-OFMT-7: tryParse with colon but empty file path', () {
      final spec = OutputSpec.tryParse('json:');
      expect(spec, isNotNull);
      expect(spec!.format, equals(OutputFormat.json));
      expect(spec.filePath, isNull);
    });

    test('TK-OFMT-8: defaultSpec is plain to stdout', () {
      final spec = OutputSpec.defaultSpec;
      expect(spec.format, equals(OutputFormat.plain));
      expect(spec.filePath, isNull);
    });

    test('TK-OFMT-9: tryParse with markdown alias', () {
      final spec = OutputSpec.tryParse('markdown:report.md');
      expect(spec, isNotNull);
      expect(spec!.format, equals(OutputFormat.md));
      expect(spec.filePath, equals('report.md'));
    });
  });

  group('OutputWriter', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('tk_output_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    final headers = ['ID', 'Name', 'Result'];
    final rows = [
      ['TK-1', 'test one', 'OK'],
      ['TK-2', 'test two', 'X'],
    ];

    test('TK-OFMT-10: writes CSV to file', () async {
      final outputPath = '${tempDir.path}/output.csv';
      final writer = OutputWriter(
        OutputSpec(format: OutputFormat.csv, filePath: outputPath),
      );

      await writer.writeTable(headers: headers, rows: rows);

      final content = File(outputPath).readAsStringSync();
      final lines =
          content.split('\n').where((l) => l.trim().isNotEmpty).toList();
      expect(lines.length, equals(3)); // header + 2 rows
      expect(lines[0], equals('ID,Name,Result'));
      expect(lines[1], contains('TK-1'));
      expect(lines[2], contains('TK-2'));
    });

    test('TK-OFMT-11: writes JSON to file', () async {
      final outputPath = '${tempDir.path}/output.json';
      final writer = OutputWriter(
        OutputSpec(format: OutputFormat.json, filePath: outputPath),
      );

      await writer.writeTable(
        headers: headers,
        rows: rows,
        title: 'Test Report',
      );

      final content = File(outputPath).readAsStringSync();
      final parsed = jsonDecode(content) as Map<String, dynamic>;
      expect(parsed['title'], equals('Test Report'));
      expect(parsed['headers'], equals(['ID', 'Name', 'Result']));
      final jsonRows = parsed['rows'] as List;
      expect(jsonRows.length, equals(2));
    });

    test('TK-OFMT-12: writes Markdown to file', () async {
      final outputPath = '${tempDir.path}/output.md';
      final writer = OutputWriter(
        OutputSpec(format: OutputFormat.md, filePath: outputPath),
      );

      await writer.writeTable(
        headers: headers,
        rows: rows,
        title: 'Test Results',
      );

      final content = File(outputPath).readAsStringSync();
      // Markdown should have title, header row, separator, and data rows
      expect(content, contains('# Test Results'));
      expect(content, contains('| ID'));
      expect(content, contains('| TK-1'));
      expect(content, contains('| TK-2'));
    });

    test('TK-OFMT-13: writes plain text to file', () async {
      final outputPath = '${tempDir.path}/output.txt';
      final writer = OutputWriter(
        OutputSpec(format: OutputFormat.plain, filePath: outputPath),
      );

      await writer.writeTable(
        headers: headers,
        rows: rows,
        title: 'Plain Output',
      );

      final content = File(outputPath).readAsStringSync();
      expect(content, contains('Plain Output'));
      expect(content, contains('ID'));
      expect(content, contains('TK-1'));
    });

    test('TK-OFMT-14: creates parent directories for output file', () async {
      final outputPath = '${tempDir.path}/sub/dir/output.csv';
      final writer = OutputWriter(
        OutputSpec(format: OutputFormat.csv, filePath: outputPath),
      );

      await writer.writeTable(headers: headers, rows: rows);

      expect(File(outputPath).existsSync(), isTrue);
    });
  });
}
