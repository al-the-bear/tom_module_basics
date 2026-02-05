part of '../ast.dart';

// =============================================================================
// TYPE ANNOTATION NODES
// =============================================================================

/// A named type.
///
/// Example: `String`, `List<int>`, `Map<String, dynamic>`
final class SNamedType extends STypeAnnotation {
  /// The question mark for nullable types.
  final SToken? question;

  /// The import prefix, if any.
  final SSimpleIdentifier? importPrefix;

  /// The period after the prefix, if any.
  final SToken? period;

  /// The type name.
  final SSimpleIdentifier name2;

  /// The type arguments, if any.
  final STypeArgumentList? typeArguments;

  @override
  int get offset => importPrefix?.offset ?? name2.offset;

  @override
  int get end => question?.end ?? typeArguments?.end ?? name2.end;

  const SNamedType({
    this.question,
    this.importPrefix,
    this.period,
    required this.name2,
    this.typeArguments,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitNamedType(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'NamedType',
        if (question != null) 'q': question!.toJson(),
        if (importPrefix != null) 'prefix': importPrefix!.toJson(),
        if (period != null) 'period': period!.toJson(),
        'name': name2.toJson(),
        if (typeArguments != null) 'typeArgs': typeArguments!.toJson(),
      };

  factory SNamedType.fromJson(Map<String, dynamic> json) {
    return SNamedType(
      question: json['q'] != null
          ? SToken.fromJson(json['q'] as Map<String, dynamic>)
          : null,
      importPrefix: json['prefix'] != null
          ? SSimpleIdentifier.fromJson(json['prefix'] as Map<String, dynamic>)
          : null,
      period: json['period'] != null
          ? SToken.fromJson(json['period'] as Map<String, dynamic>)
          : null,
      name2: SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>),
      typeArguments: json['typeArgs'] != null
          ? STypeArgumentList.fromJson(json['typeArgs'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// A generic function type.
///
/// Example: `T Function<T>(T, int)`
final class SGenericFunctionType extends STypeAnnotation {
  /// The return type.
  final STypeAnnotation? returnType;

  /// The 'Function' keyword.
  final SToken functionKeyword;

  /// The type parameters, if any.
  final STypeParameterList? typeParameters;

  /// The parameters.
  final SFormalParameterList parameters;

  /// The question mark for nullable function types.
  final SToken? question;

  @override
  int get offset => returnType?.offset ?? functionKeyword.offset;

  @override
  int get end => question?.end ?? parameters.end;

  const SGenericFunctionType({
    this.returnType,
    required this.functionKeyword,
    this.typeParameters,
    required this.parameters,
    this.question,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitGenericFunctionType(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'GenericFunctionType',
        if (returnType != null) 'returnType': returnType!.toJson(),
        'function': functionKeyword.toJson(),
        if (typeParameters != null) 'typeParams': typeParameters!.toJson(),
        'params': parameters.toJson(),
        if (question != null) 'q': question!.toJson(),
      };

  factory SGenericFunctionType.fromJson(Map<String, dynamic> json) {
    return SGenericFunctionType(
      returnType: json['returnType'] != null
          ? _typeFromJson(json['returnType'] as Map<String, dynamic>)
          : null,
      functionKeyword:
          SToken.fromJson(json['function'] as Map<String, dynamic>),
      typeParameters: json['typeParams'] != null
          ? STypeParameterList.fromJson(
              json['typeParams'] as Map<String, dynamic>)
          : null,
      parameters:
          SFormalParameterList.fromJson(json['params'] as Map<String, dynamic>),
      question: json['q'] != null
          ? SToken.fromJson(json['q'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// A record type annotation.
///
/// Example: `(int, String)`, `({int x, String y})`
final class SRecordTypeAnnotation extends STypeAnnotation {
  /// The left parenthesis.
  final SToken leftParenthesis;

  /// The positional fields.
  final List<SRecordTypeAnnotationPositionalField> positionalFields;

  /// The named fields, if any.
  final SRecordTypeAnnotationNamedFields? namedFields;

  /// The right parenthesis.
  final SToken rightParenthesis;

  /// The question mark for nullable record types.
  final SToken? question;

  @override
  int get offset => leftParenthesis.offset;

  @override
  int get end => question?.end ?? rightParenthesis.end;

  const SRecordTypeAnnotation({
    required this.leftParenthesis,
    required this.positionalFields,
    this.namedFields,
    required this.rightParenthesis,
    this.question,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitRecordTypeAnnotation(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'RecordTypeAnnotation',
        'lp': leftParenthesis.toJson(),
        'positional': positionalFields.map((f) => f.toJson()).toList(),
        if (namedFields != null) 'named': namedFields!.toJson(),
        'rp': rightParenthesis.toJson(),
        if (question != null) 'q': question!.toJson(),
      };

  factory SRecordTypeAnnotation.fromJson(Map<String, dynamic> json) {
    return SRecordTypeAnnotation(
      leftParenthesis: SToken.fromJson(json['lp'] as Map<String, dynamic>),
      positionalFields: (json['positional'] as List)
          .map((f) => SRecordTypeAnnotationPositionalField.fromJson(
              f as Map<String, dynamic>))
          .toList(),
      namedFields: json['named'] != null
          ? SRecordTypeAnnotationNamedFields.fromJson(
              json['named'] as Map<String, dynamic>)
          : null,
      rightParenthesis: SToken.fromJson(json['rp'] as Map<String, dynamic>),
      question: json['q'] != null
          ? SToken.fromJson(json['q'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// A positional field in a record type.
final class SRecordTypeAnnotationPositionalField extends SAstNode {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// The field type.
  final STypeAnnotation type;

  /// The field name, if any.
  final SSimpleIdentifier? name;

  @override
  int get offset => metadata.firstOrNull?.offset ?? type.offset;

  @override
  int get end => name?.end ?? type.end;

  const SRecordTypeAnnotationPositionalField({
    required this.metadata,
    required this.type,
    this.name,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitRecordTypeAnnotationPositionalField(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'RecordTypeAnnotationPositionalField',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        'fieldType': type.toJson(),
        if (name != null) 'name': name!.toJson(),
      };

  factory SRecordTypeAnnotationPositionalField.fromJson(
      Map<String, dynamic> json) {
    return SRecordTypeAnnotationPositionalField(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      type: _typeFromJson(json['fieldType'] as Map<String, dynamic>),
      name: json['name'] != null
          ? SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Named fields in a record type.
final class SRecordTypeAnnotationNamedFields extends SAstNode {
  /// The left brace.
  final SToken leftBrace;

  /// The named fields.
  final List<SRecordTypeAnnotationNamedField> fields;

  /// The right brace.
  final SToken rightBrace;

  @override
  int get offset => leftBrace.offset;

  @override
  int get end => rightBrace.end;

  const SRecordTypeAnnotationNamedFields({
    required this.leftBrace,
    required this.fields,
    required this.rightBrace,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitRecordTypeAnnotationNamedFields(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'RecordTypeAnnotationNamedFields',
        'lb': leftBrace.toJson(),
        'fields': fields.map((f) => f.toJson()).toList(),
        'rb': rightBrace.toJson(),
      };

  factory SRecordTypeAnnotationNamedFields.fromJson(Map<String, dynamic> json) {
    return SRecordTypeAnnotationNamedFields(
      leftBrace: SToken.fromJson(json['lb'] as Map<String, dynamic>),
      fields: (json['fields'] as List)
          .map((f) => SRecordTypeAnnotationNamedField.fromJson(
              f as Map<String, dynamic>))
          .toList(),
      rightBrace: SToken.fromJson(json['rb'] as Map<String, dynamic>),
    );
  }
}

/// A named field in a record type.
final class SRecordTypeAnnotationNamedField extends SAstNode {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// The field type.
  final STypeAnnotation type;

  /// The field name.
  final SSimpleIdentifier name;

  @override
  int get offset => metadata.firstOrNull?.offset ?? type.offset;

  @override
  int get end => name.end;

  const SRecordTypeAnnotationNamedField({
    required this.metadata,
    required this.type,
    required this.name,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitRecordTypeAnnotationNamedField(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'RecordTypeAnnotationNamedField',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        'fieldType': type.toJson(),
        'name': name.toJson(),
      };

  factory SRecordTypeAnnotationNamedField.fromJson(Map<String, dynamic> json) {
    return SRecordTypeAnnotationNamedField(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      type: _typeFromJson(json['fieldType'] as Map<String, dynamic>),
      name: SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>),
    );
  }
}

// =============================================================================
// TYPE ARGUMENT NODES
// =============================================================================

/// A type argument list.
///
/// Example: `<int, String>`
final class STypeArgumentList extends SAstNode {
  /// The left bracket.
  final SToken leftBracket;

  /// The type arguments.
  final List<STypeAnnotation> arguments;

  /// The right bracket.
  final SToken rightBracket;

  @override
  int get offset => leftBracket.offset;

  @override
  int get end => rightBracket.end;

  const STypeArgumentList({
    required this.leftBracket,
    required this.arguments,
    required this.rightBracket,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitTypeArgumentList(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'TypeArgumentList',
        'lt': leftBracket.toJson(),
        'args': arguments.map((a) => a.toJson()).toList(),
        'gt': rightBracket.toJson(),
      };

  factory STypeArgumentList.fromJson(Map<String, dynamic> json) {
    return STypeArgumentList(
      leftBracket: SToken.fromJson(json['lt'] as Map<String, dynamic>),
      arguments: (json['args'] as List)
          .map((a) => _typeFromJson(a as Map<String, dynamic>))
          .toList(),
      rightBracket: SToken.fromJson(json['gt'] as Map<String, dynamic>),
    );
  }
}

// =============================================================================
// TYPE PARAMETER NODES
// =============================================================================

/// A type parameter.
///
/// Example: `T`, `E extends Comparable<E>`
final class STypeParameter extends SAstNode {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// The type parameter name.
  final SSimpleIdentifier name;

  /// The 'extends' keyword, if any.
  final SToken? extendsKeyword;

  /// The bound type, if any.
  final STypeAnnotation? bound;

  @override
  int get offset => metadata.firstOrNull?.offset ?? name.offset;

  @override
  int get end => bound?.end ?? name.end;

  const STypeParameter({
    required this.metadata,
    required this.name,
    this.extendsKeyword,
    this.bound,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitTypeParameter(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'TypeParameter',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        'name': name.toJson(),
        if (extendsKeyword != null) 'extends': extendsKeyword!.toJson(),
        if (bound != null) 'bound': bound!.toJson(),
      };

  factory STypeParameter.fromJson(Map<String, dynamic> json) {
    return STypeParameter(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      name: SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>),
      extendsKeyword: json['extends'] != null
          ? SToken.fromJson(json['extends'] as Map<String, dynamic>)
          : null,
      bound: json['bound'] != null
          ? _typeFromJson(json['bound'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// A type parameter list.
///
/// Example: `<T, E extends Comparable<E>>`
final class STypeParameterList extends SAstNode {
  /// The left bracket.
  final SToken leftBracket;

  /// The type parameters.
  final List<STypeParameter> typeParameters;

  /// The right bracket.
  final SToken rightBracket;

  @override
  int get offset => leftBracket.offset;

  @override
  int get end => rightBracket.end;

  const STypeParameterList({
    required this.leftBracket,
    required this.typeParameters,
    required this.rightBracket,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitTypeParameterList(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'TypeParameterList',
        'lt': leftBracket.toJson(),
        'params': typeParameters.map((p) => p.toJson()).toList(),
        'gt': rightBracket.toJson(),
      };

  factory STypeParameterList.fromJson(Map<String, dynamic> json) {
    return STypeParameterList(
      leftBracket: SToken.fromJson(json['lt'] as Map<String, dynamic>),
      typeParameters: (json['params'] as List)
          .map((p) => STypeParameter.fromJson(p as Map<String, dynamic>))
          .toList(),
      rightBracket: SToken.fromJson(json['gt'] as Map<String, dynamic>),
    );
  }
}
