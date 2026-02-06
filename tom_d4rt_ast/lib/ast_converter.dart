/// AST Converter - Converts from Dart analyzer AST to serializable AST
///
/// This library depends on the analyzer package.
/// Import this only when you need to convert from analyzer AST.
///
/// For the pure serializable AST model (no analyzer dependency),
/// use `package:tom_d4rt_ast/ast.dart` instead.
library tom_d4rt_ast.ast_converter;

export 'src/ast/ast_core.dart';
export 'src/converter/ast_converter.dart' show AstConverter;
