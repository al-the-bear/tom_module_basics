/// Test script to verify round-trip serialization of AST
///
/// Usage:
///   dart run bin/test_roundtrip.dart <input.dart>
///
/// Parses a Dart file, converts to serializable AST, serializes to JSON,
/// deserializes back, and re-serializes to verify the data is preserved.

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';

import 'package:tom_d4rt_ast/ast_converter.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart run bin/test_roundtrip.dart <input.dart>');
    print('');
    print('Tests round-trip serialization of AST (serialize -> deserialize -> serialize).');
    exit(1);
  }

  final inputPath = args[0];
  final inputFile = File(inputPath);

  if (!inputFile.existsSync()) {
    print('Error: File not found: $inputPath');
    exit(1);
  }

  // Read and parse the Dart file
  print('Reading file: $inputPath');
  final content = inputFile.readAsStringSync();
  final parseResult = parseString(
    content: content,
    path: inputPath,
  );

  // Check for parse errors
  if (parseResult.errors.isNotEmpty) {
    print('Parse errors found: ${parseResult.errors.length}');
    for (final error in parseResult.errors) {
      print('  ${error.message} at offset ${error.offset}');
    }
  }

  // Convert to serializable AST
  print('Converting to serializable AST...');
  final converter = AstConverter();
  final ast = converter.convertCompilationUnit(parseResult.unit);

  // First serialization
  print('Serializing to JSON (first pass)...');
  final jsonEncoder = JsonEncoder.withIndent('  ');
  final json1 = jsonEncoder.convert(ast.toJson());
  print('  JSON size: ${json1.length} characters');

  // Deserialize
  print('Deserializing from JSON...');
  final decoded = jsonDecode(json1) as Map<String, dynamic>;
  final ast2 = SCompilationUnit.fromJson(decoded);

  // Re-serialize
  print('Serializing to JSON (second pass)...');
  final json2 = jsonEncoder.convert(ast2.toJson());
  print('  JSON size: ${json2.length} characters');

  // Compare
  print('');
  if (json1 == json2) {
    print('✓ SUCCESS: Round-trip serialization preserved data exactly!');
    print('');
    print('Summary:');
    print('  Directives: ${ast.directives.length}');
    print('  Declarations: ${ast.declarations.length}');
    print('  Comments: ${ast.comments.length}');
    exit(0);
  } else {
    print('✗ FAILURE: Round-trip serialization changed the data!');
    print('');
    print('First 1000 chars of difference analysis:');

    // Find first difference
    for (var i = 0; i < json1.length && i < json2.length; i++) {
      if (json1[i] != json2[i]) {
        final start = (i - 100).clamp(0, json1.length);
        final end = (i + 100).clamp(0, json1.length);
        print('First difference at position $i:');
        print('  JSON1: ${json1.substring(start, end)}');
        print('  JSON2: ${json2.substring(start, (i + 100).clamp(0, json2.length))}');
        break;
      }
    }

    exit(1);
  }
}
