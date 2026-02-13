/// Unit tests for output formatting utilities.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:tom_issue_kit/src/util/output_formatter.dart';

void main() {
  group('IK-FMT-1: OutputSpec [2026-02-13]', () {
    test('IK-FMT-1: Parse format without filename', () {
      final spec = OutputSpec.tryParse('json');
      expect(spec, isNotNull);
      expect(spec!.format, OutputFormat.json);
      expect(spec.filename, isNull);
      expect(spec.hasFile, isFalse);
    });

    test('IK-FMT-2: Parse format with filename', () {
      final spec = OutputSpec.tryParse('csv:output.csv');
      expect(spec, isNotNull);
      expect(spec!.format, OutputFormat.csv);
      expect(spec.filename, 'output.csv');
      expect(spec.hasFile, isTrue);
    });

    test('IK-FMT-3: Parse all format types', () {
      expect(OutputSpec.tryParse('plain')?.format, OutputFormat.plain);
      expect(OutputSpec.tryParse('text')?.format, OutputFormat.plain);
      expect(OutputSpec.tryParse('csv')?.format, OutputFormat.csv);
      expect(OutputSpec.tryParse('json')?.format, OutputFormat.json);
      expect(OutputSpec.tryParse('md')?.format, OutputFormat.md);
      expect(OutputSpec.tryParse('markdown')?.format, OutputFormat.md);
    });

    test('IK-FMT-4: Return null for invalid format', () {
      expect(OutputSpec.tryParse(null), isNull);
      expect(OutputSpec.tryParse(''), isNull);
      expect(OutputSpec.tryParse('invalid'), isNull);
    });

    test('IK-FMT-5: Handle filename with colon', () {
      final spec = OutputSpec.tryParse('json:path/to:file.json');
      expect(spec, isNotNull);
      expect(spec!.format, OutputFormat.json);
      expect(spec.filename, 'path/to:file.json');
    });
  });

  group('IK-FMT-2: OutputFormatter Table [2026-02-13]', () {
    test('IK-FMT-6: Format plain text table', () {
      final output = OutputFormatter.formatTable(
        [
          ['Alice', '30', 'Engineer'],
          ['Bob', '25', 'Designer'],
        ],
        headers: ['Name', 'Age', 'Title'],
      );

      expect(output, contains('Name'));
      expect(output, contains('Age'));
      expect(output, contains('Title'));
      expect(output, contains('Alice'));
      expect(output, contains('Bob'));
      expect(output, contains('---')); // Separator after header
    });

    test('IK-FMT-7: Format table without headers', () {
      final output = OutputFormatter.formatTable([
        ['A', 'B', 'C'],
        ['D', 'E', 'F'],
      ]);

      expect(output, contains('A'));
      expect(output, contains('D'));
      expect(output, isNot(contains('---'))); // No separator without header
    });

    test('IK-FMT-8: Handle empty table', () {
      final output = OutputFormatter.formatTable([]);
      expect(output, isEmpty);
    });
  });

  group('IK-FMT-3: OutputFormatter CSV [2026-02-13]', () {
    test('IK-FMT-9: Format CSV with headers', () {
      final output = OutputFormatter.formatCsv(
        [
          ['Alice', '30', 'Engineer'],
          ['Bob', '25', 'Designer'],
        ],
        headers: ['Name', 'Age', 'Title'],
      );

      expect(output, contains('Name,Age,Title'));
      expect(output, contains('Alice,30,Engineer'));
      expect(output, contains('Bob,25,Designer'));
    });

    test('IK-FMT-10: Escape CSV values with commas', () {
      final output = OutputFormatter.formatCsv([
        ['Hello, World', 'Value'],
      ]);

      expect(output, contains('"Hello, World",Value'));
    });

    test('IK-FMT-11: Escape CSV values with quotes', () {
      final output = OutputFormatter.formatCsv([
        ['Say "Hello"', 'Value'],
      ]);

      expect(output, contains('"Say ""Hello""",Value'));
    });

    test('IK-FMT-12: Escape CSV values with newlines', () {
      final output = OutputFormatter.formatCsv([
        ['Line1\nLine2', 'Value'],
      ]);

      expect(output, contains('"Line1\nLine2",Value'));
    });
  });

  group('IK-FMT-4: OutputFormatter JSON [2026-02-13]', () {
    test('IK-FMT-13: Format JSON with pretty print', () {
      final output = OutputFormatter.formatJson(
        {'name': 'Alice', 'age': 30},
        pretty: true,
      );

      expect(output, contains('"name": "Alice"'));
      expect(output, contains('\n')); // Pretty format has newlines
    });

    test('IK-FMT-14: Format JSON compact', () {
      final output = OutputFormatter.formatJson(
        {'name': 'Alice', 'age': 30},
        pretty: false,
      );

      expect(output, isNot(contains('\n')));
    });

    test('IK-FMT-15: Format JSON list', () {
      final output = OutputFormatter.formatJson([1, 2, 3]);
      expect(output, contains('['));
      expect(output, contains('1'));
    });
  });

  group('IK-FMT-5: OutputFormatter Markdown [2026-02-13]', () {
    test('IK-FMT-16: Format Markdown table', () {
      final output = OutputFormatter.formatMarkdownTable(
        [
          ['Alice', '30'],
          ['Bob', '25'],
        ],
        headers: ['Name', 'Age'],
      );

      expect(output, contains('| Name | Age |'));
      expect(output, contains('| --- | --- |'));
      expect(output, contains('| Alice | 30 |'));
    });

    test('IK-FMT-17: Format Markdown with alignment', () {
      final output = OutputFormatter.formatMarkdownTable(
        [
          ['Alice', '30'],
        ],
        headers: ['Name', 'Age'],
        alignment: ['left', 'right'],
      );

      expect(output, contains('| --- | ---: |'));
    });

    test('IK-FMT-18: Escape pipe in Markdown cells', () {
      final output = OutputFormatter.formatMarkdownTable([
        ['A | B', 'Value'],
      ]);

      expect(output, contains(r'A \| B'));
    });
  });

  group('IK-FMT-6: Severity Enum [2026-02-13]', () {
    test('IK-FMT-19: Parse severity strings', () {
      expect(Severity.tryParse('critical'), Severity.critical);
      expect(Severity.tryParse('high'), Severity.high);
      expect(Severity.tryParse('normal'), Severity.normal);
      expect(Severity.tryParse('low'), Severity.low);
      expect(Severity.tryParse('CRITICAL'), Severity.critical);
      expect(Severity.tryParse('invalid'), isNull);
    });

    test('IK-FMT-20: Severity display names', () {
      expect(Severity.critical.displayName, 'CRITICAL');
      expect(Severity.high.displayName, 'HIGH');
      expect(Severity.normal.displayName, 'NORMAL');
      expect(Severity.low.displayName, 'LOW');
    });
  });

  group('IK-FMT-7: IssueState Enum [2026-02-13]', () {
    test('IK-FMT-21: Parse issue state strings', () {
      expect(IssueState.tryParse('new'), IssueState.newState);
      expect(IssueState.tryParse('analyzed'), IssueState.analyzed);
      expect(IssueState.tryParse('assigned'), IssueState.assigned);
      expect(IssueState.tryParse('testing'), IssueState.testing);
      expect(IssueState.tryParse('verifying'), IssueState.verifying);
      expect(IssueState.tryParse('resolved'), IssueState.resolved);
      expect(IssueState.tryParse('closed'), IssueState.closed);
      expect(IssueState.tryParse('blocked'), IssueState.blocked);
      expect(IssueState.tryParse('duplicate'), IssueState.duplicate);
      expect(IssueState.tryParse('wontfix'), IssueState.wontfix);
      expect(IssueState.tryParse('invalid'), isNull);
    });

    test('IK-FMT-22: Issue state label names', () {
      expect(IssueState.newState.labelName, 'new');
      expect(IssueState.testing.labelName, 'testing');
      expect(IssueState.verifying.labelName, 'verifying');
    });

    test('IK-FMT-23: Issue state display names', () {
      expect(IssueState.newState.displayName, 'NEW');
      expect(IssueState.testing.displayName, 'TESTING');
      expect(IssueState.verifying.displayName, 'VERIFYING');
    });
  });
}
