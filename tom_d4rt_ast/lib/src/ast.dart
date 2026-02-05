/// Serializable AST nodes for Dart code.
///
/// This library provides a complete serializable representation of Dart's
/// Abstract Syntax Tree (AST). It mirrors the structure of the analyzer
/// package's AST but with full JSON and binary serialization support.
///
/// The AST nodes are organized hierarchically:
/// - [SAstNode] - Base class for all nodes
///   - [SExpression] - Base for expressions
///   - [SStatement] - Base for statements
///   - [SDeclaration] - Base for declarations
///   - [SDirective] - Base for directives
///   - [STypeAnnotation] - Base for type annotations
///
/// Example usage:
/// ```dart
/// // Parse an AST from JSON
/// final ast = SAstNode.fromJson(jsonData);
///
/// // Visit nodes
/// final visitor = MyVisitor();
/// ast.accept(visitor);
///
/// // Serialize to JSON
/// final json = ast.toJson();
/// ```
library;

import 'token.dart';
export 'token.dart';

part 'ast/base.dart';
part 'ast/expressions.dart';
part 'ast/statements.dart';
part 'ast/declarations.dart';
part 'ast/directives.dart';
part 'ast/types.dart';
part 'ast/literals.dart';
part 'ast/patterns.dart';
part 'ast/function_body.dart';
part 'ast/parameters.dart';
part 'ast/clauses.dart';
part 'ast/collection_elements.dart';
part 'ast/visitor.dart';
