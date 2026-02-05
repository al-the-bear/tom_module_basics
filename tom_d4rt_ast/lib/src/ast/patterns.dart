part of '../ast.dart';

// =============================================================================
// PATTERN NODES (Dart 3.0+)
// =============================================================================

/// Base class for all pattern nodes.
abstract class SDartPattern extends SAstNode {
  const SDartPattern();
}

/// A declared identifier (used in variable patterns).
final class SDeclaredIdentifier extends SAstNode {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// The 'final' or 'var' keyword, if any.
  final SToken? keyword;

  /// The type annotation, if any.
  final STypeAnnotation? type;

  /// The identifier name.
  final SSimpleIdentifier name;

  @override
  int get offset =>
      metadata.firstOrNull?.offset ?? keyword?.offset ?? type?.offset ?? name.offset;

  @override
  int get end => name.end;

  const SDeclaredIdentifier({
    required this.metadata,
    this.keyword,
    this.type,
    required this.name,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitDeclaredIdentifier(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'DeclaredIdentifier',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        if (keyword != null) 'kw': keyword!.toJson(),
        if (type != null) 'declType': type!.toJson(),
        'name': name.toJson(),
      };

  factory SDeclaredIdentifier.fromJson(Map<String, dynamic> json) {
    return SDeclaredIdentifier(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      keyword: json['kw'] != null
          ? SToken.fromJson(json['kw'] as Map<String, dynamic>)
          : null,
      type: json['declType'] != null
          ? _typeFromJson(json['declType'] as Map<String, dynamic>)
          : null,
      name: SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>),
    );
  }
}

/// A wildcard pattern.
///
/// Example: `_`, `int _`
final class SWildcardPattern extends SDartPattern {
  /// The 'final' or 'var' keyword, if any.
  final SToken? keyword;

  /// The type annotation, if any.
  final STypeAnnotation? type;

  /// The underscore token.
  final SToken name;

  @override
  int get offset => keyword?.offset ?? type?.offset ?? name.offset;

  @override
  int get end => name.end;

  const SWildcardPattern({
    this.keyword,
    this.type,
    required this.name,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitWildcardPattern(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'WildcardPattern',
        if (keyword != null) 'kw': keyword!.toJson(),
        if (type != null) 'patType': type!.toJson(),
        'name': name.toJson(),
      };

  factory SWildcardPattern.fromJson(Map<String, dynamic> json) {
    return SWildcardPattern(
      keyword: json['kw'] != null
          ? SToken.fromJson(json['kw'] as Map<String, dynamic>)
          : null,
      type: json['patType'] != null
          ? _typeFromJson(json['patType'] as Map<String, dynamic>)
          : null,
      name: SToken.fromJson(json['name'] as Map<String, dynamic>),
    );
  }
}

/// A constant pattern.
///
/// Example: `1`, `'hello'`, `const Point(0, 0)`
final class SConstantPattern extends SDartPattern {
  /// The 'const' keyword, if any.
  final SToken? constKeyword;

  /// The expression.
  final SExpression expression;

  @override
  int get offset => constKeyword?.offset ?? expression.offset;

  @override
  int get end => expression.end;

  const SConstantPattern({
    this.constKeyword,
    required this.expression,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitConstantPattern(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ConstantPattern',
        if (constKeyword != null) 'const': constKeyword!.toJson(),
        'expr': expression.toJson(),
      };

  factory SConstantPattern.fromJson(Map<String, dynamic> json) {
    return SConstantPattern(
      constKeyword: json['const'] != null
          ? SToken.fromJson(json['const'] as Map<String, dynamic>)
          : null,
      expression: _expressionFromJson(json['expr'] as Map<String, dynamic>),
    );
  }
}

/// A variable pattern.
///
/// Example: `var x`, `int x`, `final String name`
final class SVariablePattern extends SDartPattern {
  /// The 'final' or 'var' keyword, if any.
  final SToken? keyword;

  /// The type annotation, if any.
  final STypeAnnotation? type;

  /// The variable name.
  final SSimpleIdentifier name;

  @override
  int get offset => keyword?.offset ?? type?.offset ?? name.offset;

  @override
  int get end => name.end;

  const SVariablePattern({
    this.keyword,
    this.type,
    required this.name,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitVariablePattern(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'VariablePattern',
        if (keyword != null) 'kw': keyword!.toJson(),
        if (type != null) 'patType': type!.toJson(),
        'name': name.toJson(),
      };

  factory SVariablePattern.fromJson(Map<String, dynamic> json) {
    return SVariablePattern(
      keyword: json['kw'] != null
          ? SToken.fromJson(json['kw'] as Map<String, dynamic>)
          : null,
      type: json['patType'] != null
          ? _typeFromJson(json['patType'] as Map<String, dynamic>)
          : null,
      name: SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>),
    );
  }
}

/// An assigned variable pattern (pattern that assigns to an existing variable).
///
/// Example: `(x, y) = (y, x)` where x and y are pre-existing variables
final class SAssignedVariablePattern extends SDartPattern {
  /// The variable name.
  final SSimpleIdentifier name;

  @override
  int get offset => name.offset;

  @override
  int get end => name.end;

  const SAssignedVariablePattern({
    required this.name,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitAssignedVariablePattern(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'AssignedVariablePattern',
        'name': name.toJson(),
      };

  factory SAssignedVariablePattern.fromJson(Map<String, dynamic> json) {
    return SAssignedVariablePattern(
      name: SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>),
    );
  }
}

/// A declared variable pattern (declares a new variable in a pattern).
///
/// Example: `var x`, `int x`, `final String name` in a pattern context.
/// This is the same as SVariablePattern but with an explicit class name for
/// analyzer API compatibility.
final class SDeclaredVariablePattern extends SDartPattern {
  /// The 'final' or 'var' keyword, if any.
  final SToken? keyword;

  /// The type annotation, if any.
  final STypeAnnotation? type;

  /// The variable name.
  final SSimpleIdentifier name;

  @override
  int get offset => keyword?.offset ?? type?.offset ?? name.offset;

  @override
  int get end => name.end;

  const SDeclaredVariablePattern({
    this.keyword,
    this.type,
    required this.name,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitDeclaredVariablePattern(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'DeclaredVariablePattern',
        if (keyword != null) 'kw': keyword!.toJson(),
        if (type != null) 'patType': type!.toJson(),
        'name': name.toJson(),
      };

  factory SDeclaredVariablePattern.fromJson(Map<String, dynamic> json) {
    return SDeclaredVariablePattern(
      keyword: json['kw'] != null
          ? SToken.fromJson(json['kw'] as Map<String, dynamic>)
          : null,
      type: json['patType'] != null
          ? _typeFromJson(json['patType'] as Map<String, dynamic>)
          : null,
      name: SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>),
    );
  }
}

/// A list pattern.
///
/// Example: `[a, b, c]`, `[first, ...rest]`
final class SListPattern extends SDartPattern {
  /// The type arguments, if any.
  final STypeArgumentList? typeArguments;

  /// The left bracket.
  final SToken leftBracket;

  /// The element patterns.
  final List<SListPatternElement> elements;

  /// The right bracket.
  final SToken rightBracket;

  @override
  int get offset => typeArguments?.offset ?? leftBracket.offset;

  @override
  int get end => rightBracket.end;

  const SListPattern({
    this.typeArguments,
    required this.leftBracket,
    required this.elements,
    required this.rightBracket,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitListPattern(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ListPattern',
        if (typeArguments != null) 'typeArgs': typeArguments!.toJson(),
        'lb': leftBracket.toJson(),
        'elements': elements.map((e) => e.toJson()).toList(),
        'rb': rightBracket.toJson(),
      };

  factory SListPattern.fromJson(Map<String, dynamic> json) {
    return SListPattern(
      typeArguments: json['typeArgs'] != null
          ? STypeArgumentList.fromJson(json['typeArgs'] as Map<String, dynamic>)
          : null,
      leftBracket: SToken.fromJson(json['lb'] as Map<String, dynamic>),
      elements: (json['elements'] as List)
          .map((e) => _listPatternElementFromJson(e as Map<String, dynamic>))
          .toList(),
      rightBracket: SToken.fromJson(json['rb'] as Map<String, dynamic>),
    );
  }
}

/// Base class for list pattern elements.
abstract class SListPatternElement extends SAstNode {
  const SListPatternElement();
}

/// A pattern element in a list pattern.
final class SPatternElement extends SListPatternElement {
  /// The pattern.
  final SDartPattern pattern;

  @override
  int get offset => pattern.offset;

  @override
  int get end => pattern.end;

  const SPatternElement({required this.pattern});

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitPatternElement(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'PatternElement',
        'pattern': pattern.toJson(),
      };

  factory SPatternElement.fromJson(Map<String, dynamic> json) {
    return SPatternElement(
      pattern: _patternFromJson(json['pattern'] as Map<String, dynamic>),
    );
  }
}

/// A rest pattern element.
///
/// Example: `...`, `...rest`
final class SRestPatternElement extends SListPatternElement {
  /// The '...' operator.
  final SToken operator;

  /// The pattern, if any.
  final SDartPattern? pattern;

  @override
  int get offset => operator.offset;

  @override
  int get end => pattern?.end ?? operator.end;

  const SRestPatternElement({
    required this.operator,
    this.pattern,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitRestPatternElement(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'RestPatternElement',
        'op': operator.toJson(),
        if (pattern != null) 'pattern': pattern!.toJson(),
      };

  factory SRestPatternElement.fromJson(Map<String, dynamic> json) {
    return SRestPatternElement(
      operator: SToken.fromJson(json['op'] as Map<String, dynamic>),
      pattern: json['pattern'] != null
          ? _patternFromJson(json['pattern'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// A map pattern.
///
/// Example: `{'key': value}`, `{...}`
final class SMapPattern extends SDartPattern {
  /// The type arguments, if any.
  final STypeArgumentList? typeArguments;

  /// The left brace.
  final SToken leftBrace;

  /// The entry patterns.
  final List<SMapPatternElement> elements;

  /// The right brace.
  final SToken rightBrace;

  @override
  int get offset => typeArguments?.offset ?? leftBrace.offset;

  @override
  int get end => rightBrace.end;

  const SMapPattern({
    this.typeArguments,
    required this.leftBrace,
    required this.elements,
    required this.rightBrace,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitMapPattern(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'MapPattern',
        if (typeArguments != null) 'typeArgs': typeArguments!.toJson(),
        'lb': leftBrace.toJson(),
        'elements': elements.map((e) => e.toJson()).toList(),
        'rb': rightBrace.toJson(),
      };

  factory SMapPattern.fromJson(Map<String, dynamic> json) {
    return SMapPattern(
      typeArguments: json['typeArgs'] != null
          ? STypeArgumentList.fromJson(json['typeArgs'] as Map<String, dynamic>)
          : null,
      leftBrace: SToken.fromJson(json['lb'] as Map<String, dynamic>),
      elements: (json['elements'] as List)
          .map((e) => _mapPatternEntryFromJson(e as Map<String, dynamic>))
          .toList(),
      rightBrace: SToken.fromJson(json['rb'] as Map<String, dynamic>),
    );
  }
}

/// An element in a map pattern (base class).
abstract class SMapPatternElement extends SAstNode {
  const SMapPatternElement();
}

/// A key-value entry in a map pattern.
final class SMapPatternKeyValue extends SMapPatternElement {
  /// The key expression.
  final SExpression key;

  /// The colon.
  final SToken separator;

  /// The value pattern.
  final SDartPattern value;

  @override
  int get offset => key.offset;

  @override
  int get end => value.end;

  const SMapPatternKeyValue({
    required this.key,
    required this.separator,
    required this.value,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitMapPatternKeyValue(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'MapPatternKeyValue',
        'key': key.toJson(),
        'sep': separator.toJson(),
        'value': value.toJson(),
      };

  factory SMapPatternKeyValue.fromJson(Map<String, dynamic> json) {
    return SMapPatternKeyValue(
      key: _expressionFromJson(json['key'] as Map<String, dynamic>),
      separator: SToken.fromJson(json['sep'] as Map<String, dynamic>),
      value: _patternFromJson(json['value'] as Map<String, dynamic>),
    );
  }
}

/// A map pattern entry (concrete type for analyzer API compatibility).
/// This is the same as SMapPatternKeyValue but with a different name.
///
/// Example: `'key': pattern` in `{'key': value}`
final class SMapPatternEntry extends SMapPatternElement {
  /// The key expression.
  final SExpression key;

  /// The colon.
  final SToken separator;

  /// The value pattern.
  final SDartPattern value;

  @override
  int get offset => key.offset;

  @override
  int get end => value.end;

  const SMapPatternEntry({
    required this.key,
    required this.separator,
    required this.value,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitMapPatternEntry(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'MapPatternEntry',
        'key': key.toJson(),
        'sep': separator.toJson(),
        'value': value.toJson(),
      };

  factory SMapPatternEntry.fromJson(Map<String, dynamic> json) {
    return SMapPatternEntry(
      key: _expressionFromJson(json['key'] as Map<String, dynamic>),
      separator: SToken.fromJson(json['sep'] as Map<String, dynamic>),
      value: _patternFromJson(json['value'] as Map<String, dynamic>),
    );
  }
}

/// A rest element in a map pattern.
final class SMapPatternRest extends SMapPatternElement {
  /// The '...' operator.
  final SToken operator;

  @override
  int get offset => operator.offset;

  @override
  int get end => operator.end;

  const SMapPatternRest({required this.operator});

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitMapPatternRest(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'MapPatternRest',
        'op': operator.toJson(),
      };

  factory SMapPatternRest.fromJson(Map<String, dynamic> json) {
    return SMapPatternRest(
      operator: SToken.fromJson(json['op'] as Map<String, dynamic>),
    );
  }
}

/// A record pattern.
///
/// Example: `(x, y)`, `(x: 1, y: 2)`
final class SRecordPattern extends SDartPattern {
  /// The left parenthesis.
  final SToken leftParenthesis;

  /// The field patterns.
  final List<SPatternField> fields;

  /// The right parenthesis.
  final SToken rightParenthesis;

  @override
  int get offset => leftParenthesis.offset;

  @override
  int get end => rightParenthesis.end;

  const SRecordPattern({
    required this.leftParenthesis,
    required this.fields,
    required this.rightParenthesis,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitRecordPattern(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'RecordPattern',
        'lp': leftParenthesis.toJson(),
        'fields': fields.map((f) => f.toJson()).toList(),
        'rp': rightParenthesis.toJson(),
      };

  factory SRecordPattern.fromJson(Map<String, dynamic> json) {
    return SRecordPattern(
      leftParenthesis: SToken.fromJson(json['lp'] as Map<String, dynamic>),
      fields: (json['fields'] as List)
          .map((f) => SPatternField.fromJson(f as Map<String, dynamic>))
          .toList(),
      rightParenthesis: SToken.fromJson(json['rp'] as Map<String, dynamic>),
    );
  }
}

/// A field in a pattern.
final class SPatternField extends SAstNode {
  /// The field name and colon, if named.
  final SPatternFieldName? name;

  /// The pattern.
  final SDartPattern pattern;

  @override
  int get offset => name?.offset ?? pattern.offset;

  @override
  int get end => pattern.end;

  const SPatternField({
    this.name,
    required this.pattern,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitPatternField(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'PatternField',
        if (name != null) 'name': name!.toJson(),
        'pattern': pattern.toJson(),
      };

  factory SPatternField.fromJson(Map<String, dynamic> json) {
    return SPatternField(
      name: json['name'] != null
          ? SPatternFieldName.fromJson(json['name'] as Map<String, dynamic>)
          : null,
      pattern: _patternFromJson(json['pattern'] as Map<String, dynamic>),
    );
  }
}

/// The name of a pattern field.
final class SPatternFieldName extends SAstNode {
  /// The field name, if any.
  final SSimpleIdentifier? name;

  /// The colon.
  final SToken colon;

  @override
  int get offset => name?.offset ?? colon.offset;

  @override
  int get end => colon.end;

  const SPatternFieldName({
    this.name,
    required this.colon,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitPatternFieldName(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'PatternFieldName',
        if (name != null) 'name': name!.toJson(),
        'colon': colon.toJson(),
      };

  factory SPatternFieldName.fromJson(Map<String, dynamic> json) {
    return SPatternFieldName(
      name: json['name'] != null
          ? SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>)
          : null,
      colon: SToken.fromJson(json['colon'] as Map<String, dynamic>),
    );
  }
}

/// An object pattern.
///
/// Example: `Point(x: 1, y: 2)`, `String(length: > 5)`
final class SObjectPattern extends SDartPattern {
  /// The type name.
  final SNamedType type;

  /// The left parenthesis.
  final SToken leftParenthesis;

  /// The field patterns.
  final List<SPatternField> fields;

  /// The right parenthesis.
  final SToken rightParenthesis;

  @override
  int get offset => type.offset;

  @override
  int get end => rightParenthesis.end;

  const SObjectPattern({
    required this.type,
    required this.leftParenthesis,
    required this.fields,
    required this.rightParenthesis,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitObjectPattern(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ObjectPattern',
        'objType': type.toJson(),
        'lp': leftParenthesis.toJson(),
        'fields': fields.map((f) => f.toJson()).toList(),
        'rp': rightParenthesis.toJson(),
      };

  factory SObjectPattern.fromJson(Map<String, dynamic> json) {
    return SObjectPattern(
      type: SNamedType.fromJson(json['objType'] as Map<String, dynamic>),
      leftParenthesis: SToken.fromJson(json['lp'] as Map<String, dynamic>),
      fields: (json['fields'] as List)
          .map((f) => SPatternField.fromJson(f as Map<String, dynamic>))
          .toList(),
      rightParenthesis: SToken.fromJson(json['rp'] as Map<String, dynamic>),
    );
  }
}

/// A logical and pattern.
///
/// Example: `int x && x > 0`
final class SLogicalAndPattern extends SDartPattern {
  /// The left pattern.
  final SDartPattern leftOperand;

  /// The '&&' operator.
  final SToken operator;

  /// The right pattern.
  final SDartPattern rightOperand;

  @override
  int get offset => leftOperand.offset;

  @override
  int get end => rightOperand.end;

  const SLogicalAndPattern({
    required this.leftOperand,
    required this.operator,
    required this.rightOperand,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitLogicalAndPattern(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'LogicalAndPattern',
        'left': leftOperand.toJson(),
        'op': operator.toJson(),
        'right': rightOperand.toJson(),
      };

  factory SLogicalAndPattern.fromJson(Map<String, dynamic> json) {
    return SLogicalAndPattern(
      leftOperand: _patternFromJson(json['left'] as Map<String, dynamic>),
      operator: SToken.fromJson(json['op'] as Map<String, dynamic>),
      rightOperand: _patternFromJson(json['right'] as Map<String, dynamic>),
    );
  }
}

/// A logical or pattern.
///
/// Example: `1 || 2 || 3`
final class SLogicalOrPattern extends SDartPattern {
  /// The left pattern.
  final SDartPattern leftOperand;

  /// The '||' operator.
  final SToken operator;

  /// The right pattern.
  final SDartPattern rightOperand;

  @override
  int get offset => leftOperand.offset;

  @override
  int get end => rightOperand.end;

  const SLogicalOrPattern({
    required this.leftOperand,
    required this.operator,
    required this.rightOperand,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitLogicalOrPattern(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'LogicalOrPattern',
        'left': leftOperand.toJson(),
        'op': operator.toJson(),
        'right': rightOperand.toJson(),
      };

  factory SLogicalOrPattern.fromJson(Map<String, dynamic> json) {
    return SLogicalOrPattern(
      leftOperand: _patternFromJson(json['left'] as Map<String, dynamic>),
      operator: SToken.fromJson(json['op'] as Map<String, dynamic>),
      rightOperand: _patternFromJson(json['right'] as Map<String, dynamic>),
    );
  }
}

/// A cast pattern.
///
/// Example: `x as int`
final class SCastPattern extends SDartPattern {
  /// The pattern.
  final SDartPattern pattern;

  /// The 'as' keyword.
  final SToken asToken;

  /// The cast type.
  final STypeAnnotation type;

  @override
  int get offset => pattern.offset;

  @override
  int get end => type.end;

  const SCastPattern({
    required this.pattern,
    required this.asToken,
    required this.type,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitCastPattern(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'CastPattern',
        'pattern': pattern.toJson(),
        'as': asToken.toJson(),
        'castType': type.toJson(),
      };

  factory SCastPattern.fromJson(Map<String, dynamic> json) {
    return SCastPattern(
      pattern: _patternFromJson(json['pattern'] as Map<String, dynamic>),
      asToken: SToken.fromJson(json['as'] as Map<String, dynamic>),
      type: _typeFromJson(json['castType'] as Map<String, dynamic>),
    );
  }
}

/// A null check pattern.
///
/// Example: `x?`
final class SNullCheckPattern extends SDartPattern {
  /// The pattern.
  final SDartPattern pattern;

  /// The '?' operator.
  final SToken operator;

  @override
  int get offset => pattern.offset;

  @override
  int get end => operator.end;

  const SNullCheckPattern({
    required this.pattern,
    required this.operator,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitNullCheckPattern(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'NullCheckPattern',
        'pattern': pattern.toJson(),
        'op': operator.toJson(),
      };

  factory SNullCheckPattern.fromJson(Map<String, dynamic> json) {
    return SNullCheckPattern(
      pattern: _patternFromJson(json['pattern'] as Map<String, dynamic>),
      operator: SToken.fromJson(json['op'] as Map<String, dynamic>),
    );
  }
}

/// A null assert pattern.
///
/// Example: `x!`
final class SNullAssertPattern extends SDartPattern {
  /// The pattern.
  final SDartPattern pattern;

  /// The '!' operator.
  final SToken operator;

  @override
  int get offset => pattern.offset;

  @override
  int get end => operator.end;

  const SNullAssertPattern({
    required this.pattern,
    required this.operator,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitNullAssertPattern(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'NullAssertPattern',
        'pattern': pattern.toJson(),
        'op': operator.toJson(),
      };

  factory SNullAssertPattern.fromJson(Map<String, dynamic> json) {
    return SNullAssertPattern(
      pattern: _patternFromJson(json['pattern'] as Map<String, dynamic>),
      operator: SToken.fromJson(json['op'] as Map<String, dynamic>),
    );
  }
}

/// A parenthesized pattern.
///
/// Example: `(x || y)`
final class SParenthesizedPattern extends SDartPattern {
  /// The left parenthesis.
  final SToken leftParenthesis;

  /// The pattern.
  final SDartPattern pattern;

  /// The right parenthesis.
  final SToken rightParenthesis;

  @override
  int get offset => leftParenthesis.offset;

  @override
  int get end => rightParenthesis.end;

  const SParenthesizedPattern({
    required this.leftParenthesis,
    required this.pattern,
    required this.rightParenthesis,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitParenthesizedPattern(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ParenthesizedPattern',
        'lp': leftParenthesis.toJson(),
        'pattern': pattern.toJson(),
        'rp': rightParenthesis.toJson(),
      };

  factory SParenthesizedPattern.fromJson(Map<String, dynamic> json) {
    return SParenthesizedPattern(
      leftParenthesis: SToken.fromJson(json['lp'] as Map<String, dynamic>),
      pattern: _patternFromJson(json['pattern'] as Map<String, dynamic>),
      rightParenthesis: SToken.fromJson(json['rp'] as Map<String, dynamic>),
    );
  }
}

/// A relational pattern.
///
/// Example: `< 5`, `>= 0`
final class SRelationalPattern extends SDartPattern {
  /// The relational operator.
  final SToken operator;

  /// The operand expression.
  final SExpression operand;

  @override
  int get offset => operator.offset;

  @override
  int get end => operand.end;

  const SRelationalPattern({
    required this.operator,
    required this.operand,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitRelationalPattern(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'RelationalPattern',
        'op': operator.toJson(),
        'operand': operand.toJson(),
      };

  factory SRelationalPattern.fromJson(Map<String, dynamic> json) {
    return SRelationalPattern(
      operator: SToken.fromJson(json['op'] as Map<String, dynamic>),
      operand: _expressionFromJson(json['operand'] as Map<String, dynamic>),
    );
  }
}

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/// Parses a pattern from JSON.
SDartPattern _patternFromJson(Map<String, dynamic> json) {
  final type = json['type'] as String;
  return switch (type) {
    'WildcardPattern' => SWildcardPattern.fromJson(json),
    'ConstantPattern' => SConstantPattern.fromJson(json),
    'VariablePattern' => SVariablePattern.fromJson(json),
    'ListPattern' => SListPattern.fromJson(json),
    'MapPattern' => SMapPattern.fromJson(json),
    'RecordPattern' => SRecordPattern.fromJson(json),
    'ObjectPattern' => SObjectPattern.fromJson(json),
    'LogicalAndPattern' => SLogicalAndPattern.fromJson(json),
    'LogicalOrPattern' => SLogicalOrPattern.fromJson(json),
    'CastPattern' => SCastPattern.fromJson(json),
    'NullCheckPattern' => SNullCheckPattern.fromJson(json),
    'NullAssertPattern' => SNullAssertPattern.fromJson(json),
    'ParenthesizedPattern' => SParenthesizedPattern.fromJson(json),
    'RelationalPattern' => SRelationalPattern.fromJson(json),
    _ => throw FormatException('Unknown pattern type: $type'),
  };
}

/// Parses a list pattern element from JSON.
SListPatternElement _listPatternElementFromJson(Map<String, dynamic> json) {
  final type = json['type'] as String;
  return switch (type) {
    'PatternElement' => SPatternElement.fromJson(json),
    'RestPatternElement' => SRestPatternElement.fromJson(json),
    _ => throw FormatException('Unknown list pattern element type: $type'),
  };
}

/// Parses a map pattern entry from JSON.
SMapPatternElement _mapPatternEntryFromJson(Map<String, dynamic> json) {
  final type = json['type'] as String;
  return switch (type) {
    'MapPatternEntry' => SMapPatternEntry.fromJson(json),
    'MapPatternRest' => SMapPatternRest.fromJson(json),
    _ => throw FormatException('Unknown map pattern entry type: $type'),
  };
}
