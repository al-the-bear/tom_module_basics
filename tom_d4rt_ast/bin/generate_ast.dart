/// CLI tool to generate a serializable AST from Dart source files
///
/// Usage:
///   dart run bin/generate_ast.dart `<input.dart>` [output.json]
///
/// If output is not specified, it will be printed to stdout.
library;

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';

import 'package:tom_d4rt_ast/ast_converter.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart run bin/generate_ast.dart <input.dart> [output.json]');
    print('');
    print('Generates a serializable AST from a Dart source file.');
    print('');
    print('Arguments:');
    print('  input.dart   The Dart source file to parse');
    print('  output.json  Optional output file (stdout if not specified)');
    exit(1);
  }

  final inputPath = args[0];
  final inputFile = File(inputPath);

  if (!inputFile.existsSync()) {
    print('Error: File not found: $inputPath');
    exit(1);
  }

  // Read and parse the Dart file
  final content = inputFile.readAsStringSync();
  final parseResult = parseString(
    content: content,
    path: inputPath,
  );

  // Check for parse errors
  if (parseResult.errors.isNotEmpty) {
    print('Parse errors found:');
    for (final error in parseResult.errors) {
      print('  ${error.message} at offset ${error.offset}');
    }
    // Continue anyway - partial AST may still be useful
  }

  // Convert to serializable AST
  final converter = AstConverter();
  final ast = converter.convertCompilationUnit(parseResult.unit);

  // Serialize to JSON
  final jsonEncoder = JsonEncoder.withIndent('  ');
  final jsonString = jsonEncoder.convert(ast.toJson());

  // Output
  if (args.length >= 2) {
    final outputPath = args[1];
    final outputFile = File(outputPath);
    outputFile.writeAsStringSync(jsonString);
    print('AST written to: $outputPath');
    print('File size: ${outputFile.lengthSync()} bytes');
  } else {
    print(jsonString);
  }
}
