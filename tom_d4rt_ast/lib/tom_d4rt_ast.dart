/// Serializable AST model for Dart code.
///
/// This library provides AST node classes that:
/// 1. Mirror the structure of `package:analyzer/dart/ast/ast.dart`
/// 2. Can be serialized to/from JSON or compact binary format
/// 3. Can be interpreted without the analyzer dependency
///
/// ## Usage
///
/// **Runtime (without analyzer):**
/// ```dart
/// import 'package:tom_d4rt_ast/tom_d4rt_ast.dart';
///
/// final ast = SCompilationUnit.fromJson(json);
/// final result = ast.accept(MyInterpreterVisitor());
/// ```
///
/// ## Package Structure
///
/// - `ast.dart` - Main AST library with all node classes (via parts)
/// - `token.dart` - Serializable token representation
library;

export 'src/ast.dart';
export 'src/token.dart';
