part of '../ast.dart';

// =============================================================================
// CLAUSE NODES
// =============================================================================

/// An extends clause.
///
/// Example: `extends BaseClass`
final class SExtendsClause extends SAstNode {
  /// The 'extends' keyword.
  final SToken extendsKeyword;

  /// The superclass type.
  final SNamedType superclass;

  @override
  int get offset => extendsKeyword.offset;

  @override
  int get end => superclass.end;

  const SExtendsClause({
    required this.extendsKeyword,
    required this.superclass,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitExtendsClause(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ExtendsClause',
        'extends': extendsKeyword.toJson(),
        'superclass': superclass.toJson(),
      };

  factory SExtendsClause.fromJson(Map<String, dynamic> json) {
    return SExtendsClause(
      extendsKeyword: SToken.fromJson(json['extends'] as Map<String, dynamic>),
      superclass: SNamedType.fromJson(json['superclass'] as Map<String, dynamic>),
    );
  }
}

/// An implements clause.
///
/// Example: `implements Interface1, Interface2`
final class SImplementsClause extends SAstNode {
  /// The 'implements' keyword.
  final SToken implementsKeyword;

  /// The implemented interfaces.
  final List<SNamedType> interfaces;

  @override
  int get offset => implementsKeyword.offset;

  @override
  int get end => interfaces.last.end;

  const SImplementsClause({
    required this.implementsKeyword,
    required this.interfaces,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitImplementsClause(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ImplementsClause',
        'implements': implementsKeyword.toJson(),
        'interfaces': interfaces.map((i) => i.toJson()).toList(),
      };

  factory SImplementsClause.fromJson(Map<String, dynamic> json) {
    return SImplementsClause(
      implementsKeyword:
          SToken.fromJson(json['implements'] as Map<String, dynamic>),
      interfaces: (json['interfaces'] as List)
          .map((i) => SNamedType.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A with clause.
///
/// Example: `with Mixin1, Mixin2`
final class SWithClause extends SAstNode {
  /// The 'with' keyword.
  final SToken withKeyword;

  /// The mixed-in types.
  final List<SNamedType> mixinTypes;

  @override
  int get offset => withKeyword.offset;

  @override
  int get end => mixinTypes.last.end;

  const SWithClause({
    required this.withKeyword,
    required this.mixinTypes,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitWithClause(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'WithClause',
        'with': withKeyword.toJson(),
        'mixins': mixinTypes.map((m) => m.toJson()).toList(),
      };

  factory SWithClause.fromJson(Map<String, dynamic> json) {
    return SWithClause(
      withKeyword: SToken.fromJson(json['with'] as Map<String, dynamic>),
      mixinTypes: (json['mixins'] as List)
          .map((m) => SNamedType.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// An on clause for mixin declarations.
///
/// Example: `on BaseClass`
final class SOnClause extends SAstNode {
  /// The 'on' keyword.
  final SToken onKeyword;

  /// The superclass constraints.
  final List<SNamedType> superclassConstraints;

  @override
  int get offset => onKeyword.offset;

  @override
  int get end => superclassConstraints.last.end;

  const SOnClause({
    required this.onKeyword,
    required this.superclassConstraints,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitOnClause(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'OnClause',
        'on': onKeyword.toJson(),
        'constraints': superclassConstraints.map((c) => c.toJson()).toList(),
      };

  factory SOnClause.fromJson(Map<String, dynamic> json) {
    return SOnClause(
      onKeyword: SToken.fromJson(json['on'] as Map<String, dynamic>),
      superclassConstraints: (json['constraints'] as List)
          .map((c) => SNamedType.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// An on clause for extension declarations.
///
/// Example: `on String`
final class SExtensionOnClause extends SAstNode {
  /// The 'on' keyword.
  final SToken onKeyword;

  /// The extended type.
  final STypeAnnotation extendedType;

  @override
  int get offset => onKeyword.offset;

  @override
  int get end => extendedType.end;

  const SExtensionOnClause({
    required this.onKeyword,
    required this.extendedType,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitExtensionOnClause(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ExtensionOnClause',
        'on': onKeyword.toJson(),
        'extendedType': extendedType.toJson(),
      };

  factory SExtensionOnClause.fromJson(Map<String, dynamic> json) {
    return SExtensionOnClause(
      onKeyword: SToken.fromJson(json['on'] as Map<String, dynamic>),
      extendedType:
          _typeFromJson(json['extendedType'] as Map<String, dynamic>),
    );
  }
}

/// An on clause for mixin declarations (with superclass constraints).
///
/// Example: `on Object, Comparable<T>`
final class SMixinOnClause extends SAstNode {
  /// The 'on' keyword.
  final SToken onKeyword;

  /// The superclass constraints.
  final List<SNamedType> superclassConstraints;

  @override
  int get offset => onKeyword.offset;

  @override
  int get end => superclassConstraints.isNotEmpty
      ? superclassConstraints.last.end
      : onKeyword.end;

  const SMixinOnClause({
    required this.onKeyword,
    required this.superclassConstraints,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitMixinOnClause(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'MixinOnClause',
        'on': onKeyword.toJson(),
        'constraints': superclassConstraints.map((c) => c.toJson()).toList(),
      };

  factory SMixinOnClause.fromJson(Map<String, dynamic> json) {
    return SMixinOnClause(
      onKeyword: SToken.fromJson(json['on'] as Map<String, dynamic>),
      superclassConstraints: (json['constraints'] as List)
          .map((c) => SNamedType.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}

// =============================================================================
// CATCH CLAUSE
// =============================================================================

/// A catch clause.
///
/// Example: `catch (e)`, `on FormatException catch (e, s)`
final class SCatchClause extends SAstNode {
  /// The 'on' keyword, if any.
  final SToken? onKeyword;

  /// The exception type, if any.
  final STypeAnnotation? exceptionType;

  /// The 'catch' keyword, if any.
  final SToken? catchKeyword;

  /// The left parenthesis, if any.
  final SToken? leftParenthesis;

  /// The exception parameter.
  final SSimpleIdentifier? exceptionParameter;

  /// The comma before the stack trace parameter, if any.
  final SToken? comma;

  /// The stack trace parameter, if any.
  final SSimpleIdentifier? stackTraceParameter;

  /// The right parenthesis, if any.
  final SToken? rightParenthesis;

  /// The catch body.
  final SBlock body;

  @override
  int get offset => onKeyword?.offset ?? catchKeyword?.offset ?? body.offset;

  @override
  int get end => body.end;

  const SCatchClause({
    this.onKeyword,
    this.exceptionType,
    this.catchKeyword,
    this.leftParenthesis,
    this.exceptionParameter,
    this.comma,
    this.stackTraceParameter,
    this.rightParenthesis,
    required this.body,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitCatchClause(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'CatchClause',
        if (onKeyword != null) 'on': onKeyword!.toJson(),
        if (exceptionType != null) 'exType': exceptionType!.toJson(),
        if (catchKeyword != null) 'catch': catchKeyword!.toJson(),
        if (leftParenthesis != null) 'lp': leftParenthesis!.toJson(),
        if (exceptionParameter != null) 'ex': exceptionParameter!.toJson(),
        if (comma != null) 'comma': comma!.toJson(),
        if (stackTraceParameter != null) 'st': stackTraceParameter!.toJson(),
        if (rightParenthesis != null) 'rp': rightParenthesis!.toJson(),
        'body': body.toJson(),
      };

  factory SCatchClause.fromJson(Map<String, dynamic> json) {
    return SCatchClause(
      onKeyword: json['on'] != null
          ? SToken.fromJson(json['on'] as Map<String, dynamic>)
          : null,
      exceptionType: json['exType'] != null
          ? _typeFromJson(json['exType'] as Map<String, dynamic>)
          : null,
      catchKeyword: json['catch'] != null
          ? SToken.fromJson(json['catch'] as Map<String, dynamic>)
          : null,
      leftParenthesis: json['lp'] != null
          ? SToken.fromJson(json['lp'] as Map<String, dynamic>)
          : null,
      exceptionParameter: json['ex'] != null
          ? SSimpleIdentifier.fromJson(json['ex'] as Map<String, dynamic>)
          : null,
      comma: json['comma'] != null
          ? SToken.fromJson(json['comma'] as Map<String, dynamic>)
          : null,
      stackTraceParameter: json['st'] != null
          ? SSimpleIdentifier.fromJson(json['st'] as Map<String, dynamic>)
          : null,
      rightParenthesis: json['rp'] != null
          ? SToken.fromJson(json['rp'] as Map<String, dynamic>)
          : null,
      body: SBlock.fromJson(json['body'] as Map<String, dynamic>),
    );
  }
}

// =============================================================================
// FINALLY CLAUSE
// =============================================================================

/// A finally clause.
///
/// Example: `finally { cleanup(); }`
final class SFinallyClause extends SAstNode {
  /// The 'finally' keyword.
  final SToken finallyKeyword;

  /// The finally body.
  final SBlock body;

  @override
  int get offset => finallyKeyword.offset;

  @override
  int get end => body.end;

  const SFinallyClause({
    required this.finallyKeyword,
    required this.body,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitFinallyClause(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'FinallyClause',
        'finally': finallyKeyword.toJson(),
        'body': body.toJson(),
      };

  factory SFinallyClause.fromJson(Map<String, dynamic> json) {
    return SFinallyClause(
      finallyKeyword: SToken.fromJson(json['finally'] as Map<String, dynamic>),
      body: SBlock.fromJson(json['body'] as Map<String, dynamic>),
    );
  }
}

// =============================================================================
// NATIVE CLAUSE
// =============================================================================

/// A native clause in a function declaration.
///
/// Example: `native 'dart:math'`
final class SNativeClause extends SAstNode {
  /// The 'native' keyword.
  final SToken nativeKeyword;

  /// The name of the native object, if any.
  final SStringLiteral? name;

  @override
  int get offset => nativeKeyword.offset;

  @override
  int get end => name?.end ?? nativeKeyword.end;

  const SNativeClause({
    required this.nativeKeyword,
    this.name,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitNativeClause(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'NativeClause',
        'native': nativeKeyword.toJson(),
        if (name != null) 'name': name!.toJson(),
      };

  factory SNativeClause.fromJson(Map<String, dynamic> json) {
    return SNativeClause(
      nativeKeyword: SToken.fromJson(json['native'] as Map<String, dynamic>),
      name: json['name'] != null
          ? _stringLiteralFromJson(json['name'] as Map<String, dynamic>)
          : null,
    );
  }
}

// =============================================================================
// CATCH CLAUSE PARAMETER
// =============================================================================

/// A parameter in a catch clause.
///
/// Example: `e` in `catch (e)` or `e` and `st` in `catch (e, st)`
final class SCatchClauseParameter extends SAstNode {
  /// The name of the parameter.
  final SToken name;

  @override
  int get offset => name.offset;

  @override
  int get end => name.end;

  const SCatchClauseParameter({
    required this.name,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitCatchClauseParameter(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'CatchClauseParameter',
        'name': name.toJson(),
      };

  factory SCatchClauseParameter.fromJson(Map<String, dynamic> json) {
    return SCatchClauseParameter(
      name: SToken.fromJson(json['name'] as Map<String, dynamic>),
    );
  }
}
