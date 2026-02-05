import 'package:tom_d4rt_ast/tom_d4rt_ast.dart';
import 'package:test/test.dart';

void main() {
  group('AST Serialization', () {
    test('SSimpleIdentifier serialization round-trip', () {
      final identifier = SSimpleIdentifier(
        token: SToken(
          offset: 0,
          lexeme: 'testVar',
          type: STokenType.identifier,
        ),
      );

      final json = identifier.toJson();
      final restored = SSimpleIdentifier.fromJson(json);

      expect(restored.name, equals('testVar'));
      expect(restored.offset, equals(0));
    });

    test('SIntegerLiteral serialization round-trip', () {
      final literal = SIntegerLiteral(
        literal: SToken(
          offset: 10,
          lexeme: '42',
          type: STokenType.integerLiteral,
        ),
        value: 42,
      );

      final json = literal.toJson();
      final restored = SIntegerLiteral.fromJson(json);

      expect(restored.value, equals(42));
      expect(restored.offset, equals(10));
    });
  });
}
