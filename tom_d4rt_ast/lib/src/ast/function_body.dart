part of '../ast.dart';

// =============================================================================
// FUNCTION BODY NODES
// =============================================================================

/// Base class for function bodies.
abstract class SFunctionBody extends SAstNode {
  const SFunctionBody();
}

/// A block function body.
///
/// Example: `{ return x; }`
final class SBlockFunctionBody extends SFunctionBody {
  /// The 'async' keyword, if any.
  final SToken? keyword;

  /// The '*' for async* or sync*.
  final SToken? star;

  /// The block.
  final SBlock block;

  @override
  int get offset => keyword?.offset ?? block.offset;

  @override
  int get end => block.end;

  const SBlockFunctionBody({
    this.keyword,
    this.star,
    required this.block,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitBlockFunctionBody(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'BlockFunctionBody',
        if (keyword != null) 'kw': keyword!.toJson(),
        if (star != null) 'star': star!.toJson(),
        'block': block.toJson(),
      };

  factory SBlockFunctionBody.fromJson(Map<String, dynamic> json) {
    return SBlockFunctionBody(
      keyword: json['kw'] != null
          ? SToken.fromJson(json['kw'] as Map<String, dynamic>)
          : null,
      star: json['star'] != null
          ? SToken.fromJson(json['star'] as Map<String, dynamic>)
          : null,
      block: SBlock.fromJson(json['block'] as Map<String, dynamic>),
    );
  }
}

/// An expression function body.
///
/// Example: `=> x + 1`, `async => await fetchData()`
final class SExpressionFunctionBody extends SFunctionBody {
  /// The 'async' keyword, if any.
  final SToken? keyword;

  /// The '=>' operator.
  final SToken functionDefinition;

  /// The expression.
  final SExpression expression;

  /// The semicolon, if any (required at statement level, not in lambdas).
  final SToken? semicolon;

  @override
  int get offset => keyword?.offset ?? functionDefinition.offset;

  @override
  int get end => semicolon?.end ?? expression.end;

  const SExpressionFunctionBody({
    this.keyword,
    required this.functionDefinition,
    required this.expression,
    this.semicolon,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitExpressionFunctionBody(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ExpressionFunctionBody',
        if (keyword != null) 'kw': keyword!.toJson(),
        'arrow': functionDefinition.toJson(),
        'expr': expression.toJson(),
        if (semicolon != null) 'semi': semicolon!.toJson(),
      };

  factory SExpressionFunctionBody.fromJson(Map<String, dynamic> json) {
    return SExpressionFunctionBody(
      keyword: json['kw'] != null
          ? SToken.fromJson(json['kw'] as Map<String, dynamic>)
          : null,
      functionDefinition:
          SToken.fromJson(json['arrow'] as Map<String, dynamic>),
      expression: _expressionFromJson(json['expr'] as Map<String, dynamic>),
      semicolon: json['semi'] != null
          ? SToken.fromJson(json['semi'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// An empty function body.
///
/// Example: `abstract void foo();` - the `;` is the empty body
final class SEmptyFunctionBody extends SFunctionBody {
  /// The semicolon.
  final SToken semicolon;

  @override
  int get offset => semicolon.offset;

  @override
  int get end => semicolon.end;

  const SEmptyFunctionBody({required this.semicolon});

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitEmptyFunctionBody(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'EmptyFunctionBody',
        'semi': semicolon.toJson(),
      };

  factory SEmptyFunctionBody.fromJson(Map<String, dynamic> json) {
    return SEmptyFunctionBody(
      semicolon: SToken.fromJson(json['semi'] as Map<String, dynamic>),
    );
  }
}

/// A native function body.
///
/// Example: `native 'nativeFunction';`
final class SNativeFunctionBody extends SFunctionBody {
  /// The 'native' keyword.
  final SToken nativeKeyword;

  /// The native method name, if any.
  final SStringLiteral? stringLiteral;

  /// The semicolon.
  final SToken semicolon;

  @override
  int get offset => nativeKeyword.offset;

  @override
  int get end => semicolon.end;

  const SNativeFunctionBody({
    required this.nativeKeyword,
    this.stringLiteral,
    required this.semicolon,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitNativeFunctionBody(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'NativeFunctionBody',
        'native': nativeKeyword.toJson(),
        if (stringLiteral != null) 'str': stringLiteral!.toJson(),
        'semi': semicolon.toJson(),
      };

  factory SNativeFunctionBody.fromJson(Map<String, dynamic> json) {
    return SNativeFunctionBody(
      nativeKeyword: SToken.fromJson(json['native'] as Map<String, dynamic>),
      stringLiteral: json['str'] != null
          ? _stringLiteralFromJson(json['str'] as Map<String, dynamic>)
          : null,
      semicolon: SToken.fromJson(json['semi'] as Map<String, dynamic>),
    );
  }
}

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/// Parses a function body from JSON.
SFunctionBody _functionBodyFromJson(Map<String, dynamic> json) {
  final type = json['type'] as String;
  return switch (type) {
    'BlockFunctionBody' => SBlockFunctionBody.fromJson(json),
    'ExpressionFunctionBody' => SExpressionFunctionBody.fromJson(json),
    'EmptyFunctionBody' => SEmptyFunctionBody.fromJson(json),
    'NativeFunctionBody' => SNativeFunctionBody.fromJson(json),
    _ => throw FormatException('Unknown function body type: $type'),
  };
}
