part of '../ast.dart';

// =============================================================================
// FORMAL PARAMETER NODES
// =============================================================================

/// A formal parameter list.
///
/// Example: `(int x, String y)`, `(int a, {required String b})`
final class SFormalParameterList extends SAstNode {
  /// The left parenthesis.
  final SToken leftParenthesis;

  /// The parameters.
  final List<SFormalParameter> parameters;

  /// The left delimiter ('{' or '[') for optional/named parameters.
  final SToken? leftDelimiter;

  /// The right delimiter ('}' or ']') for optional/named parameters.
  final SToken? rightDelimiter;

  /// The right parenthesis.
  final SToken rightParenthesis;

  @override
  int get offset => leftParenthesis.offset;

  @override
  int get end => rightParenthesis.end;

  const SFormalParameterList({
    required this.leftParenthesis,
    required this.parameters,
    this.leftDelimiter,
    this.rightDelimiter,
    required this.rightParenthesis,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitFormalParameterList(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'FormalParameterList',
        'lp': leftParenthesis.toJson(),
        'params': parameters.map((p) => p.toJson()).toList(),
        if (leftDelimiter != null) 'ld': leftDelimiter!.toJson(),
        if (rightDelimiter != null) 'rd': rightDelimiter!.toJson(),
        'rp': rightParenthesis.toJson(),
      };

  factory SFormalParameterList.fromJson(Map<String, dynamic> json) {
    return SFormalParameterList(
      leftParenthesis: SToken.fromJson(json['lp'] as Map<String, dynamic>),
      parameters: (json['params'] as List)
          .map((p) => _formalParameterFromJson(p as Map<String, dynamic>))
          .toList(),
      leftDelimiter: json['ld'] != null
          ? SToken.fromJson(json['ld'] as Map<String, dynamic>)
          : null,
      rightDelimiter: json['rd'] != null
          ? SToken.fromJson(json['rd'] as Map<String, dynamic>)
          : null,
      rightParenthesis: SToken.fromJson(json['rp'] as Map<String, dynamic>),
    );
  }
}

/// Base class for formal parameters.
abstract class SFormalParameter extends SAstNode {
  const SFormalParameter();
}

/// A simple formal parameter.
///
/// Example: `int x`, `String name`
final class SSimpleFormalParameter extends SFormalParameter {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// The 'required' keyword, if any.
  final SToken? requiredKeyword;

  /// The 'covariant' keyword, if any.
  final SToken? covariantKeyword;

  /// The 'final' keyword, if any.
  final SToken? keyword;

  /// The parameter type, if any.
  final STypeAnnotation? type;

  /// The parameter name.
  final SSimpleIdentifier? name;

  @override
  int get offset =>
      metadata.firstOrNull?.offset ??
      requiredKeyword?.offset ??
      covariantKeyword?.offset ??
      keyword?.offset ??
      type?.offset ??
      name?.offset ??
      0;

  @override
  int get end =>
      name?.end ?? type?.end ?? keyword?.end ?? covariantKeyword?.end ?? 0;

  const SSimpleFormalParameter({
    required this.metadata,
    this.requiredKeyword,
    this.covariantKeyword,
    this.keyword,
    this.type,
    this.name,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitSimpleFormalParameter(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'SimpleFormalParameter',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        if (requiredKeyword != null) 'required': requiredKeyword!.toJson(),
        if (covariantKeyword != null) 'covariant': covariantKeyword!.toJson(),
        if (keyword != null) 'kw': keyword!.toJson(),
        if (type != null) 'paramType': type!.toJson(),
        if (name != null) 'name': name!.toJson(),
      };

  factory SSimpleFormalParameter.fromJson(Map<String, dynamic> json) {
    return SSimpleFormalParameter(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      requiredKeyword: json['required'] != null
          ? SToken.fromJson(json['required'] as Map<String, dynamic>)
          : null,
      covariantKeyword: json['covariant'] != null
          ? SToken.fromJson(json['covariant'] as Map<String, dynamic>)
          : null,
      keyword: json['kw'] != null
          ? SToken.fromJson(json['kw'] as Map<String, dynamic>)
          : null,
      type: json['paramType'] != null
          ? _typeFromJson(json['paramType'] as Map<String, dynamic>)
          : null,
      name: json['name'] != null
          ? SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// A default formal parameter.
///
/// Example: `int x = 0`, `String name = 'default'`
final class SDefaultFormalParameter extends SFormalParameter {
  /// The underlying parameter.
  final SFormalParameter parameter;

  /// The kind of parameter (optional positional, named, etc.).
  final SParameterKind kind;

  /// The separator ('=' or ':').
  final SToken? separator;

  /// The default value, if any.
  final SExpression? defaultValue;

  @override
  int get offset => parameter.offset;

  @override
  int get end => defaultValue?.end ?? parameter.end;

  const SDefaultFormalParameter({
    required this.parameter,
    required this.kind,
    this.separator,
    this.defaultValue,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitDefaultFormalParameter(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'DefaultFormalParameter',
        'param': parameter.toJson(),
        'kind': kind.name,
        if (separator != null) 'sep': separator!.toJson(),
        if (defaultValue != null) 'default': defaultValue!.toJson(),
      };

  factory SDefaultFormalParameter.fromJson(Map<String, dynamic> json) {
    return SDefaultFormalParameter(
      parameter:
          _formalParameterFromJson(json['param'] as Map<String, dynamic>),
      kind: SParameterKind.values.byName(json['kind'] as String),
      separator: json['sep'] != null
          ? SToken.fromJson(json['sep'] as Map<String, dynamic>)
          : null,
      defaultValue: json['default'] != null
          ? _expressionFromJson(json['default'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// A field formal parameter.
///
/// Example: `this.x`, `this.name = 'default'`
final class SFieldFormalParameter extends SFormalParameter {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// The 'required' keyword, if any.
  final SToken? requiredKeyword;

  /// The 'covariant' keyword, if any.
  final SToken? covariantKeyword;

  /// The 'final' keyword, if any.
  final SToken? keyword;

  /// The parameter type, if any.
  final STypeAnnotation? type;

  /// The 'this' keyword.
  final SToken thisKeyword;

  /// The period.
  final SToken period;

  /// The parameter name.
  final SSimpleIdentifier name;

  /// The type parameters, if any.
  final STypeParameterList? typeParameters;

  /// The parameters (for function-typed field parameters).
  final SFormalParameterList? parameters;

  /// The question mark for nullable types.
  final SToken? question;

  @override
  int get offset =>
      metadata.firstOrNull?.offset ??
      requiredKeyword?.offset ??
      covariantKeyword?.offset ??
      keyword?.offset ??
      type?.offset ??
      thisKeyword.offset;

  @override
  int get end => parameters?.end ?? question?.end ?? name.end;

  const SFieldFormalParameter({
    required this.metadata,
    this.requiredKeyword,
    this.covariantKeyword,
    this.keyword,
    this.type,
    required this.thisKeyword,
    required this.period,
    required this.name,
    this.typeParameters,
    this.parameters,
    this.question,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitFieldFormalParameter(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'FieldFormalParameter',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        if (requiredKeyword != null) 'required': requiredKeyword!.toJson(),
        if (covariantKeyword != null) 'covariant': covariantKeyword!.toJson(),
        if (keyword != null) 'kw': keyword!.toJson(),
        if (type != null) 'paramType': type!.toJson(),
        'this': thisKeyword.toJson(),
        'period': period.toJson(),
        'name': name.toJson(),
        if (typeParameters != null) 'typeParams': typeParameters!.toJson(),
        if (parameters != null) 'params': parameters!.toJson(),
        if (question != null) 'q': question!.toJson(),
      };

  factory SFieldFormalParameter.fromJson(Map<String, dynamic> json) {
    return SFieldFormalParameter(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      requiredKeyword: json['required'] != null
          ? SToken.fromJson(json['required'] as Map<String, dynamic>)
          : null,
      covariantKeyword: json['covariant'] != null
          ? SToken.fromJson(json['covariant'] as Map<String, dynamic>)
          : null,
      keyword: json['kw'] != null
          ? SToken.fromJson(json['kw'] as Map<String, dynamic>)
          : null,
      type: json['paramType'] != null
          ? _typeFromJson(json['paramType'] as Map<String, dynamic>)
          : null,
      thisKeyword: SToken.fromJson(json['this'] as Map<String, dynamic>),
      period: SToken.fromJson(json['period'] as Map<String, dynamic>),
      name: SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>),
      typeParameters: json['typeParams'] != null
          ? STypeParameterList.fromJson(
              json['typeParams'] as Map<String, dynamic>)
          : null,
      parameters: json['params'] != null
          ? SFormalParameterList.fromJson(
              json['params'] as Map<String, dynamic>)
          : null,
      question: json['q'] != null
          ? SToken.fromJson(json['q'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// A function-typed formal parameter.
///
/// Example: `void callback(int x)`, `int compare(T a, T b)`
final class SFunctionTypedFormalParameter extends SFormalParameter {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// The 'required' keyword, if any.
  final SToken? requiredKeyword;

  /// The 'covariant' keyword, if any.
  final SToken? covariantKeyword;

  /// The return type, if any.
  final STypeAnnotation? returnType;

  /// The parameter name.
  final SSimpleIdentifier name;

  /// The type parameters, if any.
  final STypeParameterList? typeParameters;

  /// The parameters.
  final SFormalParameterList parameters;

  /// The question mark for nullable types.
  final SToken? question;

  @override
  int get offset =>
      metadata.firstOrNull?.offset ??
      requiredKeyword?.offset ??
      covariantKeyword?.offset ??
      returnType?.offset ??
      name.offset;

  @override
  int get end => question?.end ?? parameters.end;

  const SFunctionTypedFormalParameter({
    required this.metadata,
    this.requiredKeyword,
    this.covariantKeyword,
    this.returnType,
    required this.name,
    this.typeParameters,
    required this.parameters,
    this.question,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitFunctionTypedFormalParameter(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'FunctionTypedFormalParameter',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        if (requiredKeyword != null) 'required': requiredKeyword!.toJson(),
        if (covariantKeyword != null) 'covariant': covariantKeyword!.toJson(),
        if (returnType != null) 'returnType': returnType!.toJson(),
        'name': name.toJson(),
        if (typeParameters != null) 'typeParams': typeParameters!.toJson(),
        'params': parameters.toJson(),
        if (question != null) 'q': question!.toJson(),
      };

  factory SFunctionTypedFormalParameter.fromJson(Map<String, dynamic> json) {
    return SFunctionTypedFormalParameter(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      requiredKeyword: json['required'] != null
          ? SToken.fromJson(json['required'] as Map<String, dynamic>)
          : null,
      covariantKeyword: json['covariant'] != null
          ? SToken.fromJson(json['covariant'] as Map<String, dynamic>)
          : null,
      returnType: json['returnType'] != null
          ? _typeFromJson(json['returnType'] as Map<String, dynamic>)
          : null,
      name: SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>),
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

/// A super formal parameter.
///
/// Example: `super.x`, `super.name()`
final class SSuperFormalParameter extends SFormalParameter {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// The 'required' keyword, if any.
  final SToken? requiredKeyword;

  /// The 'covariant' keyword, if any.
  final SToken? covariantKeyword;

  /// The 'final' keyword, if any.
  final SToken? keyword;

  /// The parameter type, if any.
  final STypeAnnotation? type;

  /// The 'super' keyword.
  final SToken superKeyword;

  /// The period.
  final SToken period;

  /// The parameter name.
  final SSimpleIdentifier name;

  /// The type parameters, if any.
  final STypeParameterList? typeParameters;

  /// The parameters, if any.
  final SFormalParameterList? parameters;

  /// The question mark for nullable types.
  final SToken? question;

  @override
  int get offset =>
      metadata.firstOrNull?.offset ??
      requiredKeyword?.offset ??
      covariantKeyword?.offset ??
      keyword?.offset ??
      type?.offset ??
      superKeyword.offset;

  @override
  int get end => parameters?.end ?? question?.end ?? name.end;

  const SSuperFormalParameter({
    required this.metadata,
    this.requiredKeyword,
    this.covariantKeyword,
    this.keyword,
    this.type,
    required this.superKeyword,
    required this.period,
    required this.name,
    this.typeParameters,
    this.parameters,
    this.question,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitSuperFormalParameter(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'SuperFormalParameter',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        if (requiredKeyword != null) 'required': requiredKeyword!.toJson(),
        if (covariantKeyword != null) 'covariant': covariantKeyword!.toJson(),
        if (keyword != null) 'kw': keyword!.toJson(),
        if (type != null) 'paramType': type!.toJson(),
        'super': superKeyword.toJson(),
        'period': period.toJson(),
        'name': name.toJson(),
        if (typeParameters != null) 'typeParams': typeParameters!.toJson(),
        if (parameters != null) 'params': parameters!.toJson(),
        if (question != null) 'q': question!.toJson(),
      };

  factory SSuperFormalParameter.fromJson(Map<String, dynamic> json) {
    return SSuperFormalParameter(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      requiredKeyword: json['required'] != null
          ? SToken.fromJson(json['required'] as Map<String, dynamic>)
          : null,
      covariantKeyword: json['covariant'] != null
          ? SToken.fromJson(json['covariant'] as Map<String, dynamic>)
          : null,
      keyword: json['kw'] != null
          ? SToken.fromJson(json['kw'] as Map<String, dynamic>)
          : null,
      type: json['paramType'] != null
          ? _typeFromJson(json['paramType'] as Map<String, dynamic>)
          : null,
      superKeyword: SToken.fromJson(json['super'] as Map<String, dynamic>),
      period: SToken.fromJson(json['period'] as Map<String, dynamic>),
      name: SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>),
      typeParameters: json['typeParams'] != null
          ? STypeParameterList.fromJson(
              json['typeParams'] as Map<String, dynamic>)
          : null,
      parameters: json['params'] != null
          ? SFormalParameterList.fromJson(
              json['params'] as Map<String, dynamic>)
          : null,
      question: json['q'] != null
          ? SToken.fromJson(json['q'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// The kind of a formal parameter.
enum SParameterKind {
  /// A positional required parameter.
  requiredPositional,

  /// A positional optional parameter.
  optionalPositional,

  /// A named required parameter.
  requiredNamed,

  /// A named optional parameter.
  optionalNamed,
}

// =============================================================================
// ARGUMENT NODES
// =============================================================================

/// An argument list.
///
/// Example: `(1, 'hello', x: true)`
final class SArgumentList extends SAstNode {
  /// The left parenthesis.
  final SToken leftParenthesis;

  /// The arguments.
  final List<SExpression> arguments;

  /// The right parenthesis.
  final SToken rightParenthesis;

  @override
  int get offset => leftParenthesis.offset;

  @override
  int get end => rightParenthesis.end;

  const SArgumentList({
    required this.leftParenthesis,
    required this.arguments,
    required this.rightParenthesis,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitArgumentList(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ArgumentList',
        'lp': leftParenthesis.toJson(),
        'args': arguments.map((a) => a.toJson()).toList(),
        'rp': rightParenthesis.toJson(),
      };

  factory SArgumentList.fromJson(Map<String, dynamic> json) {
    return SArgumentList(
      leftParenthesis: SToken.fromJson(json['lp'] as Map<String, dynamic>),
      arguments: (json['args'] as List)
          .map((a) => _expressionFromJson(a as Map<String, dynamic>))
          .toList(),
      rightParenthesis: SToken.fromJson(json['rp'] as Map<String, dynamic>),
    );
  }
}

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/// Parses a formal parameter from JSON.
SFormalParameter _formalParameterFromJson(Map<String, dynamic> json) {
  final type = json['type'] as String;
  return switch (type) {
    'SimpleFormalParameter' => SSimpleFormalParameter.fromJson(json),
    'DefaultFormalParameter' => SDefaultFormalParameter.fromJson(json),
    'FieldFormalParameter' => SFieldFormalParameter.fromJson(json),
    'FunctionTypedFormalParameter' =>
      SFunctionTypedFormalParameter.fromJson(json),
    'SuperFormalParameter' => SSuperFormalParameter.fromJson(json),
    _ => throw FormatException('Unknown formal parameter type: $type'),
  };
}
