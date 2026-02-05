part of '../ast.dart';

// =============================================================================
// LITERAL NODES
// =============================================================================

/// An integer literal.
///
/// Example: `42`, `0xFF`, `0b1010`
final class SIntegerLiteral extends SExpression {
  /// The literal token.
  final SToken literal;

  /// The integer value.
  final int value;

  @override
  int get offset => literal.offset;

  @override
  int get end => literal.end;

  const SIntegerLiteral({
    required this.literal,
    required this.value,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitIntegerLiteral(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'IntegerLiteral',
        'literal': literal.toJson(),
        'value': value,
      };

  factory SIntegerLiteral.fromJson(Map<String, dynamic> json) {
    return SIntegerLiteral(
      literal: SToken.fromJson(json['literal'] as Map<String, dynamic>),
      value: json['value'] as int,
    );
  }
}

/// A double literal.
///
/// Example: `3.14`, `1e10`, `.5`
final class SDoubleLiteral extends SExpression {
  /// The literal token.
  final SToken literal;

  /// The double value.
  final double value;

  @override
  int get offset => literal.offset;

  @override
  int get end => literal.end;

  const SDoubleLiteral({
    required this.literal,
    required this.value,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitDoubleLiteral(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'DoubleLiteral',
        'literal': literal.toJson(),
        'value': value,
      };

  factory SDoubleLiteral.fromJson(Map<String, dynamic> json) {
    return SDoubleLiteral(
      literal: SToken.fromJson(json['literal'] as Map<String, dynamic>),
      value: (json['value'] as num).toDouble(),
    );
  }
}

/// A boolean literal.
///
/// Example: `true`, `false`
final class SBooleanLiteral extends SExpression {
  /// The literal token.
  final SToken literal;

  /// The boolean value.
  final bool value;

  @override
  int get offset => literal.offset;

  @override
  int get end => literal.end;

  const SBooleanLiteral({
    required this.literal,
    required this.value,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitBooleanLiteral(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'BooleanLiteral',
        'literal': literal.toJson(),
        'value': value,
      };

  factory SBooleanLiteral.fromJson(Map<String, dynamic> json) {
    return SBooleanLiteral(
      literal: SToken.fromJson(json['literal'] as Map<String, dynamic>),
      value: json['value'] as bool,
    );
  }
}

/// A null literal.
///
/// Example: `null`
final class SNullLiteral extends SExpression {
  /// The literal token.
  final SToken literal;

  @override
  int get offset => literal.offset;

  @override
  int get end => literal.end;

  const SNullLiteral({required this.literal});

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitNullLiteral(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'NullLiteral',
        'literal': literal.toJson(),
      };

  factory SNullLiteral.fromJson(Map<String, dynamic> json) {
    return SNullLiteral(
      literal: SToken.fromJson(json['literal'] as Map<String, dynamic>),
    );
  }
}

/// Base class for string literals.
abstract class SStringLiteral extends SExpression {
  /// The string value (with escapes processed).
  String get stringValue;

  const SStringLiteral();
}

/// A simple string literal (no interpolation).
///
/// Example: `'hello'`, `"world"`, `r'raw'`
final class SSimpleStringLiteral extends SStringLiteral {
  /// The literal token.
  final SToken literal;

  /// The string value.
  @override
  final String stringValue;

  /// Whether this is a raw string.
  final bool isRaw;

  /// Whether this is a multi-line string.
  final bool isMultiline;

  @override
  int get offset => literal.offset;

  @override
  int get end => literal.end;

  const SSimpleStringLiteral({
    required this.literal,
    required this.stringValue,
    this.isRaw = false,
    this.isMultiline = false,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitSimpleStringLiteral(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'SimpleStringLiteral',
        'literal': literal.toJson(),
        'value': stringValue,
        if (isRaw) 'raw': true,
        if (isMultiline) 'multi': true,
      };

  factory SSimpleStringLiteral.fromJson(Map<String, dynamic> json) {
    return SSimpleStringLiteral(
      literal: SToken.fromJson(json['literal'] as Map<String, dynamic>),
      stringValue: json['value'] as String,
      isRaw: json['raw'] as bool? ?? false,
      isMultiline: json['multi'] as bool? ?? false,
    );
  }
}

/// Adjacent string literals.
///
/// Example: `'hello' ' ' 'world'`
final class SAdjacentStrings extends SStringLiteral {
  /// The string literals.
  final List<SStringLiteral> strings;

  @override
  String get stringValue => strings.map((s) => s.stringValue).join();

  @override
  int get offset => strings.first.offset;

  @override
  int get end => strings.last.end;

  const SAdjacentStrings({required this.strings});

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitAdjacentStrings(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'AdjacentStrings',
        'strings': strings.map((s) => s.toJson()).toList(),
      };

  factory SAdjacentStrings.fromJson(Map<String, dynamic> json) {
    return SAdjacentStrings(
      strings: (json['strings'] as List)
          .map((s) => _stringLiteralFromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A string interpolation.
///
/// Example: `'Hello $name!'`, `"Value: ${obj.value}"`
final class SStringInterpolation extends SStringLiteral {
  /// The elements of the interpolation.
  final List<SInterpolationElement> elements;

  @override
  String get stringValue =>
      elements.whereType<SInterpolationString>().map((s) => s.value).join();

  @override
  int get offset => elements.first.offset;

  @override
  int get end => elements.last.end;

  const SStringInterpolation({required this.elements});

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitStringInterpolation(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'StringInterpolation',
        'elements': elements.map((e) => e.toJson()).toList(),
      };

  factory SStringInterpolation.fromJson(Map<String, dynamic> json) {
    return SStringInterpolation(
      elements: (json['elements'] as List)
          .map((e) => _interpolationElementFromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Base class for interpolation elements.
abstract class SInterpolationElement extends SAstNode {
  const SInterpolationElement();
}

/// A string part of an interpolation.
final class SInterpolationString extends SInterpolationElement {
  /// The string token.
  final SToken contents;

  /// The string value.
  final String value;

  @override
  int get offset => contents.offset;

  @override
  int get end => contents.end;

  const SInterpolationString({
    required this.contents,
    required this.value,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitInterpolationString(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'InterpolationString',
        'contents': contents.toJson(),
        'value': value,
      };

  factory SInterpolationString.fromJson(Map<String, dynamic> json) {
    return SInterpolationString(
      contents: SToken.fromJson(json['contents'] as Map<String, dynamic>),
      value: json['value'] as String,
    );
  }
}

/// An expression part of an interpolation.
final class SInterpolationExpression extends SInterpolationElement {
  /// The left brace (or $).
  final SToken leftBracket;

  /// The expression.
  final SExpression expression;

  /// The right brace (if using ${}).
  final SToken? rightBracket;

  @override
  int get offset => leftBracket.offset;

  @override
  int get end => rightBracket?.end ?? expression.end;

  const SInterpolationExpression({
    required this.leftBracket,
    required this.expression,
    this.rightBracket,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitInterpolationExpression(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'InterpolationExpression',
        'lb': leftBracket.toJson(),
        'expr': expression.toJson(),
        if (rightBracket != null) 'rb': rightBracket!.toJson(),
      };

  factory SInterpolationExpression.fromJson(Map<String, dynamic> json) {
    return SInterpolationExpression(
      leftBracket: SToken.fromJson(json['lb'] as Map<String, dynamic>),
      expression: _expressionFromJson(json['expr'] as Map<String, dynamic>),
      rightBracket: json['rb'] != null
          ? SToken.fromJson(json['rb'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// A symbol literal.
///
/// Example: `#mySymbol`, `#library.identifier`
final class SSymbolLiteral extends SExpression {
  /// The pound sign token.
  final SToken poundSign;

  /// The symbol components.
  final List<SToken> components;

  @override
  int get offset => poundSign.offset;

  @override
  int get end => components.last.end;

  const SSymbolLiteral({
    required this.poundSign,
    required this.components,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitSymbolLiteral(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'SymbolLiteral',
        'pound': poundSign.toJson(),
        'components': components.map((c) => c.toJson()).toList(),
      };

  factory SSymbolLiteral.fromJson(Map<String, dynamic> json) {
    return SSymbolLiteral(
      poundSign: SToken.fromJson(json['pound'] as Map<String, dynamic>),
      components: (json['components'] as List)
          .map((c) => SToken.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A list literal.
///
/// Example: `[1, 2, 3]`, `const <int>[]`
final class SListLiteral extends SExpression {
  /// The 'const' keyword, if any.
  final SToken? constKeyword;

  /// The type arguments, if any.
  final STypeArgumentList? typeArguments;

  /// The left bracket.
  final SToken leftBracket;

  /// The elements.
  final List<SCollectionElement> elements;

  /// The right bracket.
  final SToken rightBracket;

  @override
  int get offset => constKeyword?.offset ?? typeArguments?.offset ?? leftBracket.offset;

  @override
  int get end => rightBracket.end;

  /// Whether this is a const literal.
  bool get isConst => constKeyword != null;

  const SListLiteral({
    this.constKeyword,
    this.typeArguments,
    required this.leftBracket,
    required this.elements,
    required this.rightBracket,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitListLiteral(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ListLiteral',
        if (constKeyword != null) 'const': constKeyword!.toJson(),
        if (typeArguments != null) 'typeArgs': typeArguments!.toJson(),
        'lb': leftBracket.toJson(),
        'elements': elements.map((e) => e.toJson()).toList(),
        'rb': rightBracket.toJson(),
      };

  factory SListLiteral.fromJson(Map<String, dynamic> json) {
    return SListLiteral(
      constKeyword: json['const'] != null
          ? SToken.fromJson(json['const'] as Map<String, dynamic>)
          : null,
      typeArguments: json['typeArgs'] != null
          ? STypeArgumentList.fromJson(json['typeArgs'] as Map<String, dynamic>)
          : null,
      leftBracket: SToken.fromJson(json['lb'] as Map<String, dynamic>),
      elements: (json['elements'] as List)
          .map((e) => _collectionElementFromJson(e as Map<String, dynamic>))
          .toList(),
      rightBracket: SToken.fromJson(json['rb'] as Map<String, dynamic>),
    );
  }
}

/// A set or map literal.
///
/// Example: `{1, 2, 3}`, `{'a': 1, 'b': 2}`
final class SSetOrMapLiteral extends SExpression {
  /// The 'const' keyword, if any.
  final SToken? constKeyword;

  /// The type arguments, if any.
  final STypeArgumentList? typeArguments;

  /// The left brace.
  final SToken leftBrace;

  /// The elements.
  final List<SCollectionElement> elements;

  /// The right brace.
  final SToken rightBrace;

  /// Whether this is definitely a map (has map entries).
  bool get isMap => elements.any((e) => e is SMapLiteralEntry);

  /// Whether this is definitely a set.
  bool get isSet => elements.isNotEmpty && !isMap;

  @override
  int get offset => constKeyword?.offset ?? typeArguments?.offset ?? leftBrace.offset;

  @override
  int get end => rightBrace.end;

  const SSetOrMapLiteral({
    this.constKeyword,
    this.typeArguments,
    required this.leftBrace,
    required this.elements,
    required this.rightBrace,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitSetOrMapLiteral(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'SetOrMapLiteral',
        if (constKeyword != null) 'const': constKeyword!.toJson(),
        if (typeArguments != null) 'typeArgs': typeArguments!.toJson(),
        'lb': leftBrace.toJson(),
        'elements': elements.map((e) => e.toJson()).toList(),
        'rb': rightBrace.toJson(),
      };

  factory SSetOrMapLiteral.fromJson(Map<String, dynamic> json) {
    return SSetOrMapLiteral(
      constKeyword: json['const'] != null
          ? SToken.fromJson(json['const'] as Map<String, dynamic>)
          : null,
      typeArguments: json['typeArgs'] != null
          ? STypeArgumentList.fromJson(json['typeArgs'] as Map<String, dynamic>)
          : null,
      leftBrace: SToken.fromJson(json['lb'] as Map<String, dynamic>),
      elements: (json['elements'] as List)
          .map((e) => _collectionElementFromJson(e as Map<String, dynamic>))
          .toList(),
      rightBrace: SToken.fromJson(json['rb'] as Map<String, dynamic>),
    );
  }
}

/// A record literal.
///
/// Example: `(1, 2)`, `(x: 1, y: 2)`
final class SRecordLiteral extends SExpression {
  /// The 'const' keyword, if any.
  final SToken? constKeyword;

  /// The left parenthesis.
  final SToken leftParenthesis;

  /// The fields.
  final List<SExpression> fields;

  /// The right parenthesis.
  final SToken rightParenthesis;

  @override
  int get offset => constKeyword?.offset ?? leftParenthesis.offset;

  @override
  int get end => rightParenthesis.end;

  const SRecordLiteral({
    this.constKeyword,
    required this.leftParenthesis,
    required this.fields,
    required this.rightParenthesis,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitRecordLiteral(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'RecordLiteral',
        if (constKeyword != null) 'const': constKeyword!.toJson(),
        'lp': leftParenthesis.toJson(),
        'fields': fields.map((f) => f.toJson()).toList(),
        'rp': rightParenthesis.toJson(),
      };

  factory SRecordLiteral.fromJson(Map<String, dynamic> json) {
    return SRecordLiteral(
      constKeyword: json['const'] != null
          ? SToken.fromJson(json['const'] as Map<String, dynamic>)
          : null,
      leftParenthesis: SToken.fromJson(json['lp'] as Map<String, dynamic>),
      fields: (json['fields'] as List)
          .map((f) => _expressionFromJson(f as Map<String, dynamic>))
          .toList(),
      rightParenthesis: SToken.fromJson(json['rp'] as Map<String, dynamic>),
    );
  }
}

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/// Parses a string literal from JSON.
SStringLiteral _stringLiteralFromJson(Map<String, dynamic> json) {
  final type = json['type'] as String;
  return switch (type) {
    'SimpleStringLiteral' => SSimpleStringLiteral.fromJson(json),
    'AdjacentStrings' => SAdjacentStrings.fromJson(json),
    'StringInterpolation' => SStringInterpolation.fromJson(json),
    _ => throw FormatException('Unknown string literal type: $type'),
  };
}

/// Parses an interpolation element from JSON.
SInterpolationElement _interpolationElementFromJson(Map<String, dynamic> json) {
  final type = json['type'] as String;
  return switch (type) {
    'InterpolationString' => SInterpolationString.fromJson(json),
    'InterpolationExpression' => SInterpolationExpression.fromJson(json),
    _ => throw FormatException('Unknown interpolation element type: $type'),
  };
}
