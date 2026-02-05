import 'package:tom_d4rt_ast/tom_d4rt_ast.dart';

void main() {
  // Example: Create a simple AST node and serialize it
  final identifier = SSimpleIdentifier(
    token: SToken(
      offset: 0,
      lexeme: 'hello',
      type: STokenType.identifier,
    ),
  );

  // Serialize to JSON
  final json = identifier.toJson();
  print('JSON: $json');

  // Deserialize from JSON
  final restored = SSimpleIdentifier.fromJson(json);
  print('Restored: ${restored.name}');
}
