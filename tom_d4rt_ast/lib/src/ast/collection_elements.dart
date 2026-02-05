part of '../ast.dart';

// =============================================================================
// COLLECTION ELEMENT NODES
// =============================================================================

/// Base class for collection elements.
abstract class SCollectionElement extends SAstNode {
  const SCollectionElement();
}

/// A for element in a collection literal.
///
/// Example: `for (var x in list) x * 2`
final class SForElement extends SCollectionElement {
  /// The 'await' keyword, if any.
  final SToken? awaitKeyword;

  /// The 'for' keyword.
  final SToken forKeyword;

  /// The left parenthesis.
  final SToken leftParenthesis;

  /// The loop parts.
  final SForLoopParts forLoopParts;

  /// The right parenthesis.
  final SToken rightParenthesis;

  /// The body element.
  final SCollectionElement body;

  @override
  int get offset => awaitKeyword?.offset ?? forKeyword.offset;

  @override
  int get end => body.end;

  const SForElement({
    this.awaitKeyword,
    required this.forKeyword,
    required this.leftParenthesis,
    required this.forLoopParts,
    required this.rightParenthesis,
    required this.body,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitForElement(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ForElement',
        if (awaitKeyword != null) 'await': awaitKeyword!.toJson(),
        'for': forKeyword.toJson(),
        'lp': leftParenthesis.toJson(),
        'parts': forLoopParts.toJson(),
        'rp': rightParenthesis.toJson(),
        'body': body.toJson(),
      };

  factory SForElement.fromJson(Map<String, dynamic> json) {
    return SForElement(
      awaitKeyword: json['await'] != null
          ? SToken.fromJson(json['await'] as Map<String, dynamic>)
          : null,
      forKeyword: SToken.fromJson(json['for'] as Map<String, dynamic>),
      leftParenthesis: SToken.fromJson(json['lp'] as Map<String, dynamic>),
      forLoopParts:
          _forLoopPartsFromJson(json['parts'] as Map<String, dynamic>),
      rightParenthesis: SToken.fromJson(json['rp'] as Map<String, dynamic>),
      body: _collectionElementFromJson(json['body'] as Map<String, dynamic>),
    );
  }
}

/// An if element in a collection literal.
///
/// Example: `if (condition) x`, `if (condition) x else y`
final class SIfElement extends SCollectionElement {
  /// The 'if' keyword.
  final SToken ifKeyword;

  /// The left parenthesis.
  final SToken leftParenthesis;

  /// The expression being tested.
  final SExpression? expression;

  /// The case clause, if any (for if-case).
  final SCaseClause? caseClause;

  /// The right parenthesis.
  final SToken rightParenthesis;

  /// The then element.
  final SCollectionElement thenElement;

  /// The 'else' keyword, if any.
  final SToken? elseKeyword;

  /// The else element, if any.
  final SCollectionElement? elseElement;

  @override
  int get offset => ifKeyword.offset;

  @override
  int get end => elseElement?.end ?? thenElement.end;

  const SIfElement({
    required this.ifKeyword,
    required this.leftParenthesis,
    this.expression,
    this.caseClause,
    required this.rightParenthesis,
    required this.thenElement,
    this.elseKeyword,
    this.elseElement,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitIfElement(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'IfElement',
        'if': ifKeyword.toJson(),
        'lp': leftParenthesis.toJson(),
        if (expression != null) 'expr': expression!.toJson(),
        if (caseClause != null) 'case': caseClause!.toJson(),
        'rp': rightParenthesis.toJson(),
        'then': thenElement.toJson(),
        if (elseKeyword != null) 'else': elseKeyword!.toJson(),
        if (elseElement != null) 'elseElem': elseElement!.toJson(),
      };

  factory SIfElement.fromJson(Map<String, dynamic> json) {
    return SIfElement(
      ifKeyword: SToken.fromJson(json['if'] as Map<String, dynamic>),
      leftParenthesis: SToken.fromJson(json['lp'] as Map<String, dynamic>),
      expression: json['expr'] != null
          ? _expressionFromJson(json['expr'] as Map<String, dynamic>)
          : null,
      caseClause: json['case'] != null
          ? SCaseClause.fromJson(json['case'] as Map<String, dynamic>)
          : null,
      rightParenthesis: SToken.fromJson(json['rp'] as Map<String, dynamic>),
      thenElement:
          _collectionElementFromJson(json['then'] as Map<String, dynamic>),
      elseKeyword: json['else'] != null
          ? SToken.fromJson(json['else'] as Map<String, dynamic>)
          : null,
      elseElement: json['elseElem'] != null
          ? _collectionElementFromJson(
              json['elseElem'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// A spread element.
///
/// Example: `...list`, `...?nullableList`
final class SSpreadElement extends SCollectionElement {
  /// The spread operator ('...' or '...?').
  final SToken spreadOperator;

  /// The expression being spread.
  final SExpression expression;

  @override
  int get offset => spreadOperator.offset;

  @override
  int get end => expression.end;

  const SSpreadElement({
    required this.spreadOperator,
    required this.expression,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitSpreadElement(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'SpreadElement',
        'op': spreadOperator.toJson(),
        'expr': expression.toJson(),
      };

  factory SSpreadElement.fromJson(Map<String, dynamic> json) {
    return SSpreadElement(
      spreadOperator: SToken.fromJson(json['op'] as Map<String, dynamic>),
      expression: _expressionFromJson(json['expr'] as Map<String, dynamic>),
    );
  }
}

/// A map literal entry.
///
/// Example: `'key': value`
final class SMapLiteralEntry extends SCollectionElement {
  /// The key expression.
  final SExpression key;

  /// The colon separator.
  final SToken separator;

  /// The value expression.
  final SExpression value;

  @override
  int get offset => key.offset;

  @override
  int get end => value.end;

  const SMapLiteralEntry({
    required this.key,
    required this.separator,
    required this.value,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitMapLiteralEntry(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'MapLiteralEntry',
        'key': key.toJson(),
        'sep': separator.toJson(),
        'value': value.toJson(),
      };

  factory SMapLiteralEntry.fromJson(Map<String, dynamic> json) {
    return SMapLiteralEntry(
      key: _expressionFromJson(json['key'] as Map<String, dynamic>),
      separator: SToken.fromJson(json['sep'] as Map<String, dynamic>),
      value: _expressionFromJson(json['value'] as Map<String, dynamic>),
    );
  }
}

/// A record field in a record literal.
///
/// Example: `x: 1`
final class SRecordField extends SAstNode {
  /// The field name, if any.
  final SSimpleIdentifier? name;

  /// The colon, if named.
  final SToken? colon;

  /// The field expression.
  final SExpression expression;

  @override
  int get offset => name?.offset ?? expression.offset;

  @override
  int get end => expression.end;

  const SRecordField({
    this.name,
    this.colon,
    required this.expression,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitRecordField(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'RecordField',
        if (name != null) 'name': name!.toJson(),
        if (colon != null) 'colon': colon!.toJson(),
        'expr': expression.toJson(),
      };

  factory SRecordField.fromJson(Map<String, dynamic> json) {
    return SRecordField(
      name: json['name'] != null
          ? SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>)
          : null,
      colon: json['colon'] != null
          ? SToken.fromJson(json['colon'] as Map<String, dynamic>)
          : null,
      expression: _expressionFromJson(json['expr'] as Map<String, dynamic>),
    );
  }
}

/// A wrapper for expressions when used as collection elements.
final class SExpressionElement extends SCollectionElement {
  /// The expression.
  final SExpression expression;

  @override
  int get offset => expression.offset;

  @override
  int get end => expression.end;

  const SExpressionElement({required this.expression});

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitExpressionElement(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ExpressionElement',
        'expr': expression.toJson(),
      };

  factory SExpressionElement.fromJson(Map<String, dynamic> json) {
    return SExpressionElement(
      expression: _expressionFromJson(json['expr'] as Map<String, dynamic>),
    );
  }
}

/// A null-aware element in a collection literal.
///
/// Example: `?maybeValue` in `[1, ?maybeValue, 3]`
final class SNullAwareElement extends SCollectionElement {
  /// The question mark token.
  final SToken question;

  /// The value expression.
  final SExpression value;

  @override
  int get offset => question.offset;

  @override
  int get end => value.end;

  const SNullAwareElement({
    required this.question,
    required this.value,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitNullAwareElement(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'NullAwareElement',
        'question': question.toJson(),
        'value': value.toJson(),
      };

  factory SNullAwareElement.fromJson(Map<String, dynamic> json) {
    return SNullAwareElement(
      question: SToken.fromJson(json['question'] as Map<String, dynamic>),
      value: _expressionFromJson(json['value'] as Map<String, dynamic>),
    );
  }
}

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/// Parses a collection element from JSON.
SCollectionElement _collectionElementFromJson(Map<String, dynamic> json) {
  final type = json['type'] as String;
  return switch (type) {
    'ForElement' => SForElement.fromJson(json),
    'IfElement' => SIfElement.fromJson(json),
    'SpreadElement' => SSpreadElement.fromJson(json),
    'MapLiteralEntry' => SMapLiteralEntry.fromJson(json),
    'ExpressionElement' => SExpressionElement.fromJson(json),
    'RecordField' => SRecordField.fromJson(json) as SCollectionElement,
    'NullAwareElement' => SNullAwareElement.fromJson(json),
    _ => throw FormatException('Unknown collection element type: $type'),
  };
}
