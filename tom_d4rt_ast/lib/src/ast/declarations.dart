part of '../ast.dart';

// =============================================================================
// DECLARATION NODES
// =============================================================================

/// A class declaration.
///
/// Example: `class Foo extends Bar with Mixin implements Interface { }`
final class SClassDeclaration extends SDeclaration {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// Modifiers: abstract, sealed, base, interface, mixin, final.
  final SToken? abstractKeyword;
  final SToken? sealedKeyword;
  final SToken? baseKeyword;
  final SToken? interfaceKeyword;
  final SToken? finalKeyword;
  final SToken? mixinKeyword;

  /// The 'class' keyword.
  final SToken classKeyword;

  /// The class name.
  final SSimpleIdentifier name;

  /// The type parameters, if any.
  final STypeParameterList? typeParameters;

  /// The extends clause, if any.
  final SExtendsClause? extendsClause;

  /// The with clause, if any.
  final SWithClause? withClause;

  /// The implements clause, if any.
  final SImplementsClause? implementsClause;

  /// The left brace.
  final SToken leftBrace;

  /// The members.
  final List<SClassMember> members;

  /// The right brace.
  final SToken rightBrace;

  @override
  int get offset =>
      metadata.firstOrNull?.offset ??
      abstractKeyword?.offset ??
      sealedKeyword?.offset ??
      baseKeyword?.offset ??
      interfaceKeyword?.offset ??
      finalKeyword?.offset ??
      mixinKeyword?.offset ??
      classKeyword.offset;

  @override
  int get end => rightBrace.end;

  const SClassDeclaration({
    required this.metadata,
    this.abstractKeyword,
    this.sealedKeyword,
    this.baseKeyword,
    this.interfaceKeyword,
    this.finalKeyword,
    this.mixinKeyword,
    required this.classKeyword,
    required this.name,
    this.typeParameters,
    this.extendsClause,
    this.withClause,
    this.implementsClause,
    required this.leftBrace,
    required this.members,
    required this.rightBrace,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitClassDeclaration(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ClassDeclaration',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        if (abstractKeyword != null) 'abstract': abstractKeyword!.toJson(),
        if (sealedKeyword != null) 'sealed': sealedKeyword!.toJson(),
        if (baseKeyword != null) 'base': baseKeyword!.toJson(),
        if (interfaceKeyword != null) 'interface': interfaceKeyword!.toJson(),
        if (finalKeyword != null) 'final': finalKeyword!.toJson(),
        if (mixinKeyword != null) 'mixin': mixinKeyword!.toJson(),
        'class': classKeyword.toJson(),
        'name': name.toJson(),
        if (typeParameters != null) 'typeParams': typeParameters!.toJson(),
        if (extendsClause != null) 'extends': extendsClause!.toJson(),
        if (withClause != null) 'with': withClause!.toJson(),
        if (implementsClause != null) 'implements': implementsClause!.toJson(),
        'lb': leftBrace.toJson(),
        'members': members.map((m) => m.toJson()).toList(),
        'rb': rightBrace.toJson(),
      };

  factory SClassDeclaration.fromJson(Map<String, dynamic> json) {
    return SClassDeclaration(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      abstractKeyword: json['abstract'] != null
          ? SToken.fromJson(json['abstract'] as Map<String, dynamic>)
          : null,
      sealedKeyword: json['sealed'] != null
          ? SToken.fromJson(json['sealed'] as Map<String, dynamic>)
          : null,
      baseKeyword: json['base'] != null
          ? SToken.fromJson(json['base'] as Map<String, dynamic>)
          : null,
      interfaceKeyword: json['interface'] != null
          ? SToken.fromJson(json['interface'] as Map<String, dynamic>)
          : null,
      finalKeyword: json['final'] != null
          ? SToken.fromJson(json['final'] as Map<String, dynamic>)
          : null,
      mixinKeyword: json['mixin'] != null
          ? SToken.fromJson(json['mixin'] as Map<String, dynamic>)
          : null,
      classKeyword: SToken.fromJson(json['class'] as Map<String, dynamic>),
      name: SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>),
      typeParameters: json['typeParams'] != null
          ? STypeParameterList.fromJson(
              json['typeParams'] as Map<String, dynamic>)
          : null,
      extendsClause: json['extends'] != null
          ? SExtendsClause.fromJson(json['extends'] as Map<String, dynamic>)
          : null,
      withClause: json['with'] != null
          ? SWithClause.fromJson(json['with'] as Map<String, dynamic>)
          : null,
      implementsClause: json['implements'] != null
          ? SImplementsClause.fromJson(
              json['implements'] as Map<String, dynamic>)
          : null,
      leftBrace: SToken.fromJson(json['lb'] as Map<String, dynamic>),
      members: (json['members'] as List)
          .map((m) => _classMemberFromJson(m as Map<String, dynamic>))
          .toList(),
      rightBrace: SToken.fromJson(json['rb'] as Map<String, dynamic>),
    );
  }
}

/// Base class for class members.
abstract class SClassMember extends SAstNode {
  const SClassMember();
}

/// An enum declaration.
///
/// Example: `enum Color { red, green, blue }`
final class SEnumDeclaration extends SDeclaration {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// The 'enum' keyword.
  final SToken enumKeyword;

  /// The enum name.
  final SSimpleIdentifier name;

  /// The type parameters, if any.
  final STypeParameterList? typeParameters;

  /// The with clause, if any.
  final SWithClause? withClause;

  /// The implements clause, if any.
  final SImplementsClause? implementsClause;

  /// The left brace.
  final SToken leftBrace;

  /// The enum constants.
  final List<SEnumConstantDeclaration> constants;

  /// The semicolon separating constants from members, if any.
  final SToken? semicolon;

  /// The members (methods, fields, etc.).
  final List<SClassMember> members;

  /// The right brace.
  final SToken rightBrace;

  @override
  int get offset => metadata.firstOrNull?.offset ?? enumKeyword.offset;

  @override
  int get end => rightBrace.end;

  const SEnumDeclaration({
    required this.metadata,
    required this.enumKeyword,
    required this.name,
    this.typeParameters,
    this.withClause,
    this.implementsClause,
    required this.leftBrace,
    required this.constants,
    this.semicolon,
    required this.members,
    required this.rightBrace,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitEnumDeclaration(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'EnumDeclaration',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        'enum': enumKeyword.toJson(),
        'name': name.toJson(),
        if (typeParameters != null) 'typeParams': typeParameters!.toJson(),
        if (withClause != null) 'with': withClause!.toJson(),
        if (implementsClause != null) 'implements': implementsClause!.toJson(),
        'lb': leftBrace.toJson(),
        'constants': constants.map((c) => c.toJson()).toList(),
        if (semicolon != null) 'semi': semicolon!.toJson(),
        'members': members.map((m) => m.toJson()).toList(),
        'rb': rightBrace.toJson(),
      };

  factory SEnumDeclaration.fromJson(Map<String, dynamic> json) {
    return SEnumDeclaration(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      enumKeyword: SToken.fromJson(json['enum'] as Map<String, dynamic>),
      name: SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>),
      typeParameters: json['typeParams'] != null
          ? STypeParameterList.fromJson(
              json['typeParams'] as Map<String, dynamic>)
          : null,
      withClause: json['with'] != null
          ? SWithClause.fromJson(json['with'] as Map<String, dynamic>)
          : null,
      implementsClause: json['implements'] != null
          ? SImplementsClause.fromJson(
              json['implements'] as Map<String, dynamic>)
          : null,
      leftBrace: SToken.fromJson(json['lb'] as Map<String, dynamic>),
      constants: (json['constants'] as List)
          .map((c) =>
              SEnumConstantDeclaration.fromJson(c as Map<String, dynamic>))
          .toList(),
      semicolon: json['semi'] != null
          ? SToken.fromJson(json['semi'] as Map<String, dynamic>)
          : null,
      members: (json['members'] as List)
          .map((m) => _classMemberFromJson(m as Map<String, dynamic>))
          .toList(),
      rightBrace: SToken.fromJson(json['rb'] as Map<String, dynamic>),
    );
  }
}

/// An enum constant declaration.
final class SEnumConstantDeclaration extends SAstNode {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// The constant name.
  final SSimpleIdentifier name;

  /// The type arguments, if any.
  final STypeArgumentList? typeArguments;

  /// The arguments, if any.
  final SArgumentList? arguments;

  @override
  int get offset => metadata.firstOrNull?.offset ?? name.offset;

  @override
  int get end => arguments?.end ?? typeArguments?.end ?? name.end;

  const SEnumConstantDeclaration({
    required this.metadata,
    required this.name,
    this.typeArguments,
    this.arguments,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitEnumConstantDeclaration(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'EnumConstantDeclaration',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        'name': name.toJson(),
        if (typeArguments != null) 'typeArgs': typeArguments!.toJson(),
        if (arguments != null) 'args': arguments!.toJson(),
      };

  factory SEnumConstantDeclaration.fromJson(Map<String, dynamic> json) {
    return SEnumConstantDeclaration(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      name: SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>),
      typeArguments: json['typeArgs'] != null
          ? STypeArgumentList.fromJson(json['typeArgs'] as Map<String, dynamic>)
          : null,
      arguments: json['args'] != null
          ? SArgumentList.fromJson(json['args'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// An extension declaration.
///
/// Example: `extension StringExt on String { }`
final class SExtensionDeclaration extends SDeclaration {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// The 'extension' keyword.
  final SToken extensionKeyword;

  /// The 'type' keyword for extension types, if any.
  final SToken? typeKeyword;

  /// The extension name, if any.
  final SSimpleIdentifier? name;

  /// The type parameters, if any.
  final STypeParameterList? typeParameters;

  /// The 'on' keyword.
  final SToken? onKeyword;

  /// The extended type.
  final STypeAnnotation? extendedType;

  /// The representation clause for extension types, if any.
  final SExtensionTypeRepresentation? representation;

  /// The implements clause, if any.
  final SImplementsClause? implementsClause;

  /// The left brace.
  final SToken leftBrace;

  /// The members.
  final List<SClassMember> members;

  /// The right brace.
  final SToken rightBrace;

  @override
  int get offset => metadata.firstOrNull?.offset ?? extensionKeyword.offset;

  @override
  int get end => rightBrace.end;

  const SExtensionDeclaration({
    required this.metadata,
    required this.extensionKeyword,
    this.typeKeyword,
    this.name,
    this.typeParameters,
    this.onKeyword,
    this.extendedType,
    this.representation,
    this.implementsClause,
    required this.leftBrace,
    required this.members,
    required this.rightBrace,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitExtensionDeclaration(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ExtensionDeclaration',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        'extension': extensionKeyword.toJson(),
        if (typeKeyword != null) 'typeKw': typeKeyword!.toJson(),
        if (name != null) 'name': name!.toJson(),
        if (typeParameters != null) 'typeParams': typeParameters!.toJson(),
        if (onKeyword != null) 'on': onKeyword!.toJson(),
        if (extendedType != null) 'extendedType': extendedType!.toJson(),
        if (representation != null) 'repr': representation!.toJson(),
        if (implementsClause != null) 'implements': implementsClause!.toJson(),
        'lb': leftBrace.toJson(),
        'members': members.map((m) => m.toJson()).toList(),
        'rb': rightBrace.toJson(),
      };

  factory SExtensionDeclaration.fromJson(Map<String, dynamic> json) {
    return SExtensionDeclaration(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      extensionKeyword:
          SToken.fromJson(json['extension'] as Map<String, dynamic>),
      typeKeyword: json['typeKw'] != null
          ? SToken.fromJson(json['typeKw'] as Map<String, dynamic>)
          : null,
      name: json['name'] != null
          ? SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>)
          : null,
      typeParameters: json['typeParams'] != null
          ? STypeParameterList.fromJson(
              json['typeParams'] as Map<String, dynamic>)
          : null,
      onKeyword: json['on'] != null
          ? SToken.fromJson(json['on'] as Map<String, dynamic>)
          : null,
      extendedType: json['extendedType'] != null
          ? _typeFromJson(json['extendedType'] as Map<String, dynamic>)
          : null,
      representation: json['repr'] != null
          ? SExtensionTypeRepresentation.fromJson(
              json['repr'] as Map<String, dynamic>)
          : null,
      implementsClause: json['implements'] != null
          ? SImplementsClause.fromJson(
              json['implements'] as Map<String, dynamic>)
          : null,
      leftBrace: SToken.fromJson(json['lb'] as Map<String, dynamic>),
      members: (json['members'] as List)
          .map((m) => _classMemberFromJson(m as Map<String, dynamic>))
          .toList(),
      rightBrace: SToken.fromJson(json['rb'] as Map<String, dynamic>),
    );
  }
}

/// The representation clause for extension types.
final class SExtensionTypeRepresentation extends SAstNode {
  /// The left parenthesis.
  final SToken leftParenthesis;

  /// The field declaration.
  final SSimpleFormalParameter fieldDeclaration;

  /// The right parenthesis.
  final SToken rightParenthesis;

  @override
  int get offset => leftParenthesis.offset;

  @override
  int get end => rightParenthesis.end;

  const SExtensionTypeRepresentation({
    required this.leftParenthesis,
    required this.fieldDeclaration,
    required this.rightParenthesis,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitExtensionTypeRepresentation(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ExtensionTypeRepresentation',
        'lp': leftParenthesis.toJson(),
        'field': fieldDeclaration.toJson(),
        'rp': rightParenthesis.toJson(),
      };

  factory SExtensionTypeRepresentation.fromJson(Map<String, dynamic> json) {
    return SExtensionTypeRepresentation(
      leftParenthesis: SToken.fromJson(json['lp'] as Map<String, dynamic>),
      fieldDeclaration: SSimpleFormalParameter.fromJson(
          json['field'] as Map<String, dynamic>),
      rightParenthesis: SToken.fromJson(json['rp'] as Map<String, dynamic>),
    );
  }
}

/// A mixin declaration.
///
/// Example: `mixin MyMixin on Base implements Interface { }`
final class SMixinDeclaration extends SDeclaration {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// The 'base' keyword, if any.
  final SToken? baseKeyword;

  /// The 'mixin' keyword.
  final SToken mixinKeyword;

  /// The mixin name.
  final SSimpleIdentifier name;

  /// The type parameters, if any.
  final STypeParameterList? typeParameters;

  /// The on clause, if any.
  final SOnClause? onClause;

  /// The implements clause, if any.
  final SImplementsClause? implementsClause;

  /// The left brace.
  final SToken leftBrace;

  /// The members.
  final List<SClassMember> members;

  /// The right brace.
  final SToken rightBrace;

  @override
  int get offset =>
      metadata.firstOrNull?.offset ?? baseKeyword?.offset ?? mixinKeyword.offset;

  @override
  int get end => rightBrace.end;

  const SMixinDeclaration({
    required this.metadata,
    this.baseKeyword,
    required this.mixinKeyword,
    required this.name,
    this.typeParameters,
    this.onClause,
    this.implementsClause,
    required this.leftBrace,
    required this.members,
    required this.rightBrace,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitMixinDeclaration(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'MixinDeclaration',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        if (baseKeyword != null) 'base': baseKeyword!.toJson(),
        'mixin': mixinKeyword.toJson(),
        'name': name.toJson(),
        if (typeParameters != null) 'typeParams': typeParameters!.toJson(),
        if (onClause != null) 'on': onClause!.toJson(),
        if (implementsClause != null) 'implements': implementsClause!.toJson(),
        'lb': leftBrace.toJson(),
        'members': members.map((m) => m.toJson()).toList(),
        'rb': rightBrace.toJson(),
      };

  factory SMixinDeclaration.fromJson(Map<String, dynamic> json) {
    return SMixinDeclaration(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      baseKeyword: json['base'] != null
          ? SToken.fromJson(json['base'] as Map<String, dynamic>)
          : null,
      mixinKeyword: SToken.fromJson(json['mixin'] as Map<String, dynamic>),
      name: SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>),
      typeParameters: json['typeParams'] != null
          ? STypeParameterList.fromJson(
              json['typeParams'] as Map<String, dynamic>)
          : null,
      onClause: json['on'] != null
          ? SOnClause.fromJson(json['on'] as Map<String, dynamic>)
          : null,
      implementsClause: json['implements'] != null
          ? SImplementsClause.fromJson(
              json['implements'] as Map<String, dynamic>)
          : null,
      leftBrace: SToken.fromJson(json['lb'] as Map<String, dynamic>),
      members: (json['members'] as List)
          .map((m) => _classMemberFromJson(m as Map<String, dynamic>))
          .toList(),
      rightBrace: SToken.fromJson(json['rb'] as Map<String, dynamic>),
    );
  }
}

/// A function declaration.
///
/// Example: `void foo() { }`, `int bar(String s) => s.length;`
final class SFunctionDeclaration extends SDeclaration {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// The 'external' keyword, if any.
  final SToken? externalKeyword;

  /// The return type, if any.
  final STypeAnnotation? returnType;

  /// The 'get' keyword for getters.
  final SToken? propertyKeyword;

  /// The function name.
  final SSimpleIdentifier name;

  /// The function expression (parameters and body).
  final SFunctionExpression functionExpression;

  @override
  int get offset =>
      metadata.firstOrNull?.offset ??
      externalKeyword?.offset ??
      returnType?.offset ??
      propertyKeyword?.offset ??
      name.offset;

  @override
  int get end => functionExpression.end;

  /// Whether this is a getter.
  bool get isGetter => propertyKeyword?.type == STokenType.$get;

  /// Whether this is a setter.
  bool get isSetter => propertyKeyword?.type == STokenType.$set;

  const SFunctionDeclaration({
    required this.metadata,
    this.externalKeyword,
    this.returnType,
    this.propertyKeyword,
    required this.name,
    required this.functionExpression,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitFunctionDeclaration(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'FunctionDeclaration',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        if (externalKeyword != null) 'external': externalKeyword!.toJson(),
        if (returnType != null) 'returnType': returnType!.toJson(),
        if (propertyKeyword != null) 'property': propertyKeyword!.toJson(),
        'name': name.toJson(),
        'funcExpr': functionExpression.toJson(),
      };

  factory SFunctionDeclaration.fromJson(Map<String, dynamic> json) {
    return SFunctionDeclaration(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      externalKeyword: json['external'] != null
          ? SToken.fromJson(json['external'] as Map<String, dynamic>)
          : null,
      returnType: json['returnType'] != null
          ? _typeFromJson(json['returnType'] as Map<String, dynamic>)
          : null,
      propertyKeyword: json['property'] != null
          ? SToken.fromJson(json['property'] as Map<String, dynamic>)
          : null,
      name: SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>),
      functionExpression: SFunctionExpression.fromJson(
          json['funcExpr'] as Map<String, dynamic>),
    );
  }
}

/// A top-level variable declaration.
///
/// Example: `const x = 1;`, `var y = 'hello';`
final class STopLevelVariableDeclaration extends SDeclaration {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// The 'external' keyword, if any.
  final SToken? externalKeyword;

  /// The variable declaration list.
  final SVariableDeclarationList variables;

  /// The semicolon.
  final SToken semicolon;

  @override
  int get offset =>
      metadata.firstOrNull?.offset ??
      externalKeyword?.offset ??
      variables.offset;

  @override
  int get end => semicolon.end;

  const STopLevelVariableDeclaration({
    required this.metadata,
    this.externalKeyword,
    required this.variables,
    required this.semicolon,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitTopLevelVariableDeclaration(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'TopLevelVariableDeclaration',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        if (externalKeyword != null) 'external': externalKeyword!.toJson(),
        'vars': variables.toJson(),
        'semi': semicolon.toJson(),
      };

  factory STopLevelVariableDeclaration.fromJson(Map<String, dynamic> json) {
    return STopLevelVariableDeclaration(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      externalKeyword: json['external'] != null
          ? SToken.fromJson(json['external'] as Map<String, dynamic>)
          : null,
      variables: SVariableDeclarationList.fromJson(
          json['vars'] as Map<String, dynamic>),
      semicolon: SToken.fromJson(json['semi'] as Map<String, dynamic>),
    );
  }
}

/// A method declaration.
///
/// Example: `void method() { }`, `int get value => _value;`
final class SMethodDeclaration extends SClassMember {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// The 'external' keyword, if any.
  final SToken? externalKeyword;

  /// Modifiers.
  final SToken? staticKeyword;
  final SToken? abstractKeyword;

  /// The return type, if any.
  final STypeAnnotation? returnType;

  /// The property keyword (get/set), if any.
  final SToken? propertyKeyword;

  /// The 'operator' keyword for operator declarations.
  final SToken? operatorKeyword;

  /// The method name (or operator symbol).
  final SSimpleIdentifier name;

  /// The type parameters, if any.
  final STypeParameterList? typeParameters;

  /// The parameters.
  final SFormalParameterList? parameters;

  /// The function body.
  final SFunctionBody body;

  @override
  int get offset =>
      metadata.firstOrNull?.offset ??
      externalKeyword?.offset ??
      staticKeyword?.offset ??
      abstractKeyword?.offset ??
      returnType?.offset ??
      propertyKeyword?.offset ??
      operatorKeyword?.offset ??
      name.offset;

  @override
  int get end => body.end;

  const SMethodDeclaration({
    required this.metadata,
    this.externalKeyword,
    this.staticKeyword,
    this.abstractKeyword,
    this.returnType,
    this.propertyKeyword,
    this.operatorKeyword,
    required this.name,
    this.typeParameters,
    this.parameters,
    required this.body,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitMethodDeclaration(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'MethodDeclaration',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        if (externalKeyword != null) 'external': externalKeyword!.toJson(),
        if (staticKeyword != null) 'static': staticKeyword!.toJson(),
        if (abstractKeyword != null) 'abstract': abstractKeyword!.toJson(),
        if (returnType != null) 'returnType': returnType!.toJson(),
        if (propertyKeyword != null) 'property': propertyKeyword!.toJson(),
        if (operatorKeyword != null) 'operator': operatorKeyword!.toJson(),
        'name': name.toJson(),
        if (typeParameters != null) 'typeParams': typeParameters!.toJson(),
        if (parameters != null) 'params': parameters!.toJson(),
        'body': body.toJson(),
      };

  factory SMethodDeclaration.fromJson(Map<String, dynamic> json) {
    return SMethodDeclaration(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      externalKeyword: json['external'] != null
          ? SToken.fromJson(json['external'] as Map<String, dynamic>)
          : null,
      staticKeyword: json['static'] != null
          ? SToken.fromJson(json['static'] as Map<String, dynamic>)
          : null,
      abstractKeyword: json['abstract'] != null
          ? SToken.fromJson(json['abstract'] as Map<String, dynamic>)
          : null,
      returnType: json['returnType'] != null
          ? _typeFromJson(json['returnType'] as Map<String, dynamic>)
          : null,
      propertyKeyword: json['property'] != null
          ? SToken.fromJson(json['property'] as Map<String, dynamic>)
          : null,
      operatorKeyword: json['operator'] != null
          ? SToken.fromJson(json['operator'] as Map<String, dynamic>)
          : null,
      name: SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>),
      typeParameters: json['typeParams'] != null
          ? STypeParameterList.fromJson(
              json['typeParams'] as Map<String, dynamic>)
          : null,
      parameters: json['params'] != null
          ? SFormalParameterList.fromJson(
              json['params'] as Map<String, dynamic>)
          : null,
      body: _functionBodyFromJson(json['body'] as Map<String, dynamic>),
    );
  }
}

/// A constructor declaration.
///
/// Example: `MyClass() { }`, `MyClass.named(this.x);`
final class SConstructorDeclaration extends SClassMember {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// The 'external' keyword, if any.
  final SToken? externalKeyword;

  /// The 'const' keyword, if any.
  final SToken? constKeyword;

  /// The 'factory' keyword, if any.
  final SToken? factoryKeyword;

  /// The class/enum name.
  final SSimpleIdentifier returnType;

  /// The period before the constructor name, if named.
  final SToken? period;

  /// The constructor name, if named.
  final SSimpleIdentifier? name;

  /// The parameters.
  final SFormalParameterList parameters;

  /// The separator before initializers.
  final SToken? separator;

  /// The initializers.
  final List<SConstructorInitializer> initializers;

  /// The redirect clause, if any.
  final SConstructorName? redirectedConstructor;

  /// The function body.
  final SFunctionBody body;

  @override
  int get offset =>
      metadata.firstOrNull?.offset ??
      externalKeyword?.offset ??
      constKeyword?.offset ??
      factoryKeyword?.offset ??
      returnType.offset;

  @override
  int get end => body.end;

  const SConstructorDeclaration({
    required this.metadata,
    this.externalKeyword,
    this.constKeyword,
    this.factoryKeyword,
    required this.returnType,
    this.period,
    this.name,
    required this.parameters,
    this.separator,
    required this.initializers,
    this.redirectedConstructor,
    required this.body,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitConstructorDeclaration(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ConstructorDeclaration',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        if (externalKeyword != null) 'external': externalKeyword!.toJson(),
        if (constKeyword != null) 'const': constKeyword!.toJson(),
        if (factoryKeyword != null) 'factory': factoryKeyword!.toJson(),
        'returnType': returnType.toJson(),
        if (period != null) 'period': period!.toJson(),
        if (name != null) 'name': name!.toJson(),
        'params': parameters.toJson(),
        if (separator != null) 'sep': separator!.toJson(),
        'inits': initializers.map((i) => i.toJson()).toList(),
        if (redirectedConstructor != null)
          'redirect': redirectedConstructor!.toJson(),
        'body': body.toJson(),
      };

  factory SConstructorDeclaration.fromJson(Map<String, dynamic> json) {
    return SConstructorDeclaration(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      externalKeyword: json['external'] != null
          ? SToken.fromJson(json['external'] as Map<String, dynamic>)
          : null,
      constKeyword: json['const'] != null
          ? SToken.fromJson(json['const'] as Map<String, dynamic>)
          : null,
      factoryKeyword: json['factory'] != null
          ? SToken.fromJson(json['factory'] as Map<String, dynamic>)
          : null,
      returnType: SSimpleIdentifier.fromJson(
          json['returnType'] as Map<String, dynamic>),
      period: json['period'] != null
          ? SToken.fromJson(json['period'] as Map<String, dynamic>)
          : null,
      name: json['name'] != null
          ? SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>)
          : null,
      parameters:
          SFormalParameterList.fromJson(json['params'] as Map<String, dynamic>),
      separator: json['sep'] != null
          ? SToken.fromJson(json['sep'] as Map<String, dynamic>)
          : null,
      initializers: (json['inits'] as List)
          .map((i) =>
              _constructorInitializerFromJson(i as Map<String, dynamic>))
          .toList(),
      redirectedConstructor: json['redirect'] != null
          ? SConstructorName.fromJson(json['redirect'] as Map<String, dynamic>)
          : null,
      body: _functionBodyFromJson(json['body'] as Map<String, dynamic>),
    );
  }
}

/// Base class for constructor initializers.
abstract class SConstructorInitializer extends SAstNode {
  const SConstructorInitializer();
}

/// A super constructor invocation.
final class SSuperConstructorInvocation extends SConstructorInitializer {
  /// The 'super' keyword.
  final SToken superKeyword;

  /// The period before the constructor name, if any.
  final SToken? period;

  /// The constructor name, if any.
  final SSimpleIdentifier? constructorName;

  /// The arguments.
  final SArgumentList argumentList;

  @override
  int get offset => superKeyword.offset;

  @override
  int get end => argumentList.end;

  const SSuperConstructorInvocation({
    required this.superKeyword,
    this.period,
    this.constructorName,
    required this.argumentList,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitSuperConstructorInvocation(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'SuperConstructorInvocation',
        'super': superKeyword.toJson(),
        if (period != null) 'period': period!.toJson(),
        if (constructorName != null) 'name': constructorName!.toJson(),
        'args': argumentList.toJson(),
      };

  factory SSuperConstructorInvocation.fromJson(Map<String, dynamic> json) {
    return SSuperConstructorInvocation(
      superKeyword: SToken.fromJson(json['super'] as Map<String, dynamic>),
      period: json['period'] != null
          ? SToken.fromJson(json['period'] as Map<String, dynamic>)
          : null,
      constructorName: json['name'] != null
          ? SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>)
          : null,
      argumentList:
          SArgumentList.fromJson(json['args'] as Map<String, dynamic>),
    );
  }
}

/// A redirecting constructor invocation.
final class SRedirectingConstructorInvocation extends SConstructorInitializer {
  /// The 'this' keyword.
  final SToken thisKeyword;

  /// The period before the constructor name, if any.
  final SToken? period;

  /// The constructor name, if any.
  final SSimpleIdentifier? constructorName;

  /// The arguments.
  final SArgumentList argumentList;

  @override
  int get offset => thisKeyword.offset;

  @override
  int get end => argumentList.end;

  const SRedirectingConstructorInvocation({
    required this.thisKeyword,
    this.period,
    this.constructorName,
    required this.argumentList,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitRedirectingConstructorInvocation(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'RedirectingConstructorInvocation',
        'this': thisKeyword.toJson(),
        if (period != null) 'period': period!.toJson(),
        if (constructorName != null) 'name': constructorName!.toJson(),
        'args': argumentList.toJson(),
      };

  factory SRedirectingConstructorInvocation.fromJson(
      Map<String, dynamic> json) {
    return SRedirectingConstructorInvocation(
      thisKeyword: SToken.fromJson(json['this'] as Map<String, dynamic>),
      period: json['period'] != null
          ? SToken.fromJson(json['period'] as Map<String, dynamic>)
          : null,
      constructorName: json['name'] != null
          ? SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>)
          : null,
      argumentList:
          SArgumentList.fromJson(json['args'] as Map<String, dynamic>),
    );
  }
}

/// A constructor field initializer.
final class SConstructorFieldInitializer extends SConstructorInitializer {
  /// The 'this' keyword, if any.
  final SToken? thisKeyword;

  /// The period, if any.
  final SToken? period;

  /// The field name.
  final SSimpleIdentifier fieldName;

  /// The equals sign.
  final SToken equals;

  /// The initializer expression.
  final SExpression expression;

  @override
  int get offset => thisKeyword?.offset ?? fieldName.offset;

  @override
  int get end => expression.end;

  const SConstructorFieldInitializer({
    this.thisKeyword,
    this.period,
    required this.fieldName,
    required this.equals,
    required this.expression,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitConstructorFieldInitializer(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ConstructorFieldInitializer',
        if (thisKeyword != null) 'this': thisKeyword!.toJson(),
        if (period != null) 'period': period!.toJson(),
        'field': fieldName.toJson(),
        'eq': equals.toJson(),
        'expr': expression.toJson(),
      };

  factory SConstructorFieldInitializer.fromJson(Map<String, dynamic> json) {
    return SConstructorFieldInitializer(
      thisKeyword: json['this'] != null
          ? SToken.fromJson(json['this'] as Map<String, dynamic>)
          : null,
      period: json['period'] != null
          ? SToken.fromJson(json['period'] as Map<String, dynamic>)
          : null,
      fieldName:
          SSimpleIdentifier.fromJson(json['field'] as Map<String, dynamic>),
      equals: SToken.fromJson(json['eq'] as Map<String, dynamic>),
      expression: _expressionFromJson(json['expr'] as Map<String, dynamic>),
    );
  }
}

/// An assert initializer.
final class SAssertInitializer extends SConstructorInitializer {
  /// The 'assert' keyword.
  final SToken assertKeyword;

  /// The left parenthesis.
  final SToken leftParenthesis;

  /// The condition.
  final SExpression condition;

  /// The comma before the message, if any.
  final SToken? comma;

  /// The message, if any.
  final SExpression? message;

  /// The right parenthesis.
  final SToken rightParenthesis;

  @override
  int get offset => assertKeyword.offset;

  @override
  int get end => rightParenthesis.end;

  const SAssertInitializer({
    required this.assertKeyword,
    required this.leftParenthesis,
    required this.condition,
    this.comma,
    this.message,
    required this.rightParenthesis,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitAssertInitializer(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'AssertInitializer',
        'assert': assertKeyword.toJson(),
        'lp': leftParenthesis.toJson(),
        'cond': condition.toJson(),
        if (comma != null) 'comma': comma!.toJson(),
        if (message != null) 'msg': message!.toJson(),
        'rp': rightParenthesis.toJson(),
      };

  factory SAssertInitializer.fromJson(Map<String, dynamic> json) {
    return SAssertInitializer(
      assertKeyword: SToken.fromJson(json['assert'] as Map<String, dynamic>),
      leftParenthesis: SToken.fromJson(json['lp'] as Map<String, dynamic>),
      condition: _expressionFromJson(json['cond'] as Map<String, dynamic>),
      comma: json['comma'] != null
          ? SToken.fromJson(json['comma'] as Map<String, dynamic>)
          : null,
      message: json['msg'] != null
          ? _expressionFromJson(json['msg'] as Map<String, dynamic>)
          : null,
      rightParenthesis: SToken.fromJson(json['rp'] as Map<String, dynamic>),
    );
  }
}

/// A field declaration.
///
/// Example: `int x;`, `final String name = 'default';`
final class SFieldDeclaration extends SClassMember {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// The 'abstract' keyword, if any.
  final SToken? abstractKeyword;

  /// The 'covariant' keyword, if any.
  final SToken? covariantKeyword;

  /// The 'external' keyword, if any.
  final SToken? externalKeyword;

  /// The 'static' keyword, if any.
  final SToken? staticKeyword;

  /// The variable declaration list.
  final SVariableDeclarationList fields;

  /// The semicolon.
  final SToken semicolon;

  @override
  int get offset =>
      metadata.firstOrNull?.offset ??
      abstractKeyword?.offset ??
      covariantKeyword?.offset ??
      externalKeyword?.offset ??
      staticKeyword?.offset ??
      fields.offset;

  @override
  int get end => semicolon.end;

  const SFieldDeclaration({
    required this.metadata,
    this.abstractKeyword,
    this.covariantKeyword,
    this.externalKeyword,
    this.staticKeyword,
    required this.fields,
    required this.semicolon,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitFieldDeclaration(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'FieldDeclaration',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        if (abstractKeyword != null) 'abstract': abstractKeyword!.toJson(),
        if (covariantKeyword != null) 'covariant': covariantKeyword!.toJson(),
        if (externalKeyword != null) 'external': externalKeyword!.toJson(),
        if (staticKeyword != null) 'static': staticKeyword!.toJson(),
        'fields': fields.toJson(),
        'semi': semicolon.toJson(),
      };

  factory SFieldDeclaration.fromJson(Map<String, dynamic> json) {
    return SFieldDeclaration(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      abstractKeyword: json['abstract'] != null
          ? SToken.fromJson(json['abstract'] as Map<String, dynamic>)
          : null,
      covariantKeyword: json['covariant'] != null
          ? SToken.fromJson(json['covariant'] as Map<String, dynamic>)
          : null,
      externalKeyword: json['external'] != null
          ? SToken.fromJson(json['external'] as Map<String, dynamic>)
          : null,
      staticKeyword: json['static'] != null
          ? SToken.fromJson(json['static'] as Map<String, dynamic>)
          : null,
      fields:
          SVariableDeclarationList.fromJson(json['fields'] as Map<String, dynamic>),
      semicolon: SToken.fromJson(json['semi'] as Map<String, dynamic>),
    );
  }
}

/// A variable declaration.
///
/// Example: `x`, `y = 10`
final class SVariableDeclaration extends SAstNode {
  /// The variable name.
  final SSimpleIdentifier name;

  /// The equals sign, if initialized.
  final SToken? equals;

  /// The initializer expression, if initialized.
  final SExpression? initializer;

  @override
  int get offset => name.offset;

  @override
  int get end => initializer?.end ?? name.end;

  const SVariableDeclaration({
    required this.name,
    this.equals,
    this.initializer,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitVariableDeclaration(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'VariableDeclaration',
        'name': name.toJson(),
        if (equals != null) 'eq': equals!.toJson(),
        if (initializer != null) 'init': initializer!.toJson(),
      };

  factory SVariableDeclaration.fromJson(Map<String, dynamic> json) {
    return SVariableDeclaration(
      name: SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>),
      equals: json['eq'] != null
          ? SToken.fromJson(json['eq'] as Map<String, dynamic>)
          : null,
      initializer: json['init'] != null
          ? _expressionFromJson(json['init'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// A variable declaration list.
///
/// Example: `var x, y = 1`, `final int a = 0, b = 1`
final class SVariableDeclarationList extends SAstNode {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// The 'late' keyword, if any.
  final SToken? lateKeyword;

  /// The keyword (var, final, const).
  final SToken? keyword;

  /// The type annotation, if any.
  final STypeAnnotation? type;

  /// The variable declarations.
  final List<SVariableDeclaration> variables;

  @override
  int get offset =>
      metadata.firstOrNull?.offset ??
      lateKeyword?.offset ??
      keyword?.offset ??
      type?.offset ??
      variables.first.offset;

  @override
  int get end => variables.last.end;

  const SVariableDeclarationList({
    required this.metadata,
    this.lateKeyword,
    this.keyword,
    this.type,
    required this.variables,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitVariableDeclarationList(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'VariableDeclarationList',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        if (lateKeyword != null) 'late': lateKeyword!.toJson(),
        if (keyword != null) 'kw': keyword!.toJson(),
        if (type != null) 'varType': type!.toJson(),
        'vars': variables.map((v) => v.toJson()).toList(),
      };

  factory SVariableDeclarationList.fromJson(Map<String, dynamic> json) {
    return SVariableDeclarationList(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      lateKeyword: json['late'] != null
          ? SToken.fromJson(json['late'] as Map<String, dynamic>)
          : null,
      keyword: json['kw'] != null
          ? SToken.fromJson(json['kw'] as Map<String, dynamic>)
          : null,
      type: json['varType'] != null
          ? _typeFromJson(json['varType'] as Map<String, dynamic>)
          : null,
      variables: (json['vars'] as List)
          .map((v) => SVariableDeclaration.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A type alias declaration.
///
/// Example: `typedef IntList = List<int>;`, `typedef F = void Function(int);`
final class STypeAlias extends SDeclaration {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// The 'typedef' keyword.
  final SToken typedefKeyword;

  /// The type alias name.
  final SSimpleIdentifier name;

  /// The type parameters, if any.
  final STypeParameterList? typeParameters;

  /// The equals sign.
  final SToken equals;

  /// The aliased type.
  final STypeAnnotation type;

  /// The semicolon.
  final SToken semicolon;

  @override
  int get offset => metadata.firstOrNull?.offset ?? typedefKeyword.offset;

  @override
  int get end => semicolon.end;

  const STypeAlias({
    required this.metadata,
    required this.typedefKeyword,
    required this.name,
    this.typeParameters,
    required this.equals,
    required this.type,
    required this.semicolon,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitTypeAlias(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'TypeAlias',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        'typedef': typedefKeyword.toJson(),
        'name': name.toJson(),
        if (typeParameters != null) 'typeParams': typeParameters!.toJson(),
        'eq': equals.toJson(),
        'aliasType': type.toJson(),
        'semi': semicolon.toJson(),
      };

  factory STypeAlias.fromJson(Map<String, dynamic> json) {
    return STypeAlias(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      typedefKeyword: SToken.fromJson(json['typedef'] as Map<String, dynamic>),
      name: SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>),
      typeParameters: json['typeParams'] != null
          ? STypeParameterList.fromJson(
              json['typeParams'] as Map<String, dynamic>)
          : null,
      equals: SToken.fromJson(json['eq'] as Map<String, dynamic>),
      type: _typeFromJson(json['aliasType'] as Map<String, dynamic>),
      semicolon: SToken.fromJson(json['semi'] as Map<String, dynamic>),
    );
  }
}

/// A class type alias declaration.
///
/// Example: `class C = S with M;`
final class SClassTypeAlias extends SDeclaration {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// The 'abstract' keyword, if any.
  final SToken? abstractKeyword;

  /// The 'sealed' keyword, if any.
  final SToken? sealedKeyword;

  /// The 'base' keyword, if any.
  final SToken? baseKeyword;

  /// The 'interface' keyword, if any.
  final SToken? interfaceKeyword;

  /// The 'final' keyword, if any.
  final SToken? finalKeyword;

  /// The 'mixin' keyword, if any.
  final SToken? mixinKeyword;

  /// The 'typedef' or 'class' keyword.
  final SToken typedefKeyword;

  /// The name.
  final SSimpleIdentifier name;

  /// The type parameters, if any.
  final STypeParameterList? typeParameters;

  /// The '=' token.
  final SToken equals;

  /// The superclass.
  final SNamedType superclass;

  /// The with clause.
  final SWithClause withClause;

  /// The implements clause, if any.
  final SImplementsClause? implementsClause;

  /// The semicolon.
  final SToken semicolon;

  @override
  int get offset =>
      metadata.firstOrNull?.offset ??
      abstractKeyword?.offset ??
      sealedKeyword?.offset ??
      baseKeyword?.offset ??
      interfaceKeyword?.offset ??
      finalKeyword?.offset ??
      mixinKeyword?.offset ??
      typedefKeyword.offset;

  @override
  int get end => semicolon.end;

  const SClassTypeAlias({
    required this.metadata,
    this.abstractKeyword,
    this.sealedKeyword,
    this.baseKeyword,
    this.interfaceKeyword,
    this.finalKeyword,
    this.mixinKeyword,
    required this.typedefKeyword,
    required this.name,
    this.typeParameters,
    required this.equals,
    required this.superclass,
    required this.withClause,
    this.implementsClause,
    required this.semicolon,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitClassTypeAlias(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ClassTypeAlias',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        if (abstractKeyword != null) 'abstract': abstractKeyword!.toJson(),
        if (sealedKeyword != null) 'sealed': sealedKeyword!.toJson(),
        if (baseKeyword != null) 'base': baseKeyword!.toJson(),
        if (interfaceKeyword != null) 'interface': interfaceKeyword!.toJson(),
        if (finalKeyword != null) 'final': finalKeyword!.toJson(),
        if (mixinKeyword != null) 'mixin': mixinKeyword!.toJson(),
        'typedef': typedefKeyword.toJson(),
        'name': name.toJson(),
        if (typeParameters != null) 'typeParams': typeParameters!.toJson(),
        'eq': equals.toJson(),
        'superclass': superclass.toJson(),
        'with': withClause.toJson(),
        if (implementsClause != null) 'implements': implementsClause!.toJson(),
        'semi': semicolon.toJson(),
      };

  factory SClassTypeAlias.fromJson(Map<String, dynamic> json) {
    return SClassTypeAlias(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      abstractKeyword: json['abstract'] != null
          ? SToken.fromJson(json['abstract'] as Map<String, dynamic>)
          : null,
      sealedKeyword: json['sealed'] != null
          ? SToken.fromJson(json['sealed'] as Map<String, dynamic>)
          : null,
      baseKeyword: json['base'] != null
          ? SToken.fromJson(json['base'] as Map<String, dynamic>)
          : null,
      interfaceKeyword: json['interface'] != null
          ? SToken.fromJson(json['interface'] as Map<String, dynamic>)
          : null,
      finalKeyword: json['final'] != null
          ? SToken.fromJson(json['final'] as Map<String, dynamic>)
          : null,
      mixinKeyword: json['mixin'] != null
          ? SToken.fromJson(json['mixin'] as Map<String, dynamic>)
          : null,
      typedefKeyword: SToken.fromJson(json['typedef'] as Map<String, dynamic>),
      name: SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>),
      typeParameters: json['typeParams'] != null
          ? STypeParameterList.fromJson(
              json['typeParams'] as Map<String, dynamic>)
          : null,
      equals: SToken.fromJson(json['eq'] as Map<String, dynamic>),
      superclass:
          SNamedType.fromJson(json['superclass'] as Map<String, dynamic>),
      withClause:
          SWithClause.fromJson(json['with'] as Map<String, dynamic>),
      implementsClause: json['implements'] != null
          ? SImplementsClause.fromJson(
              json['implements'] as Map<String, dynamic>)
          : null,
      semicolon: SToken.fromJson(json['semi'] as Map<String, dynamic>),
    );
  }
}

/// A function type alias declaration (old-style typedef).
///
/// Example: `typedef int Compare(Object a, Object b);`
final class SFunctionTypeAlias extends SDeclaration {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// The 'typedef' keyword.
  final SToken typedefKeyword;

  /// The return type, if any.
  final STypeAnnotation? returnType;

  /// The name.
  final SSimpleIdentifier name;

  /// The type parameters, if any.
  final STypeParameterList? typeParameters;

  /// The parameters.
  final SFormalParameterList parameters;

  /// The semicolon.
  final SToken semicolon;

  @override
  int get offset => metadata.firstOrNull?.offset ?? typedefKeyword.offset;

  @override
  int get end => semicolon.end;

  const SFunctionTypeAlias({
    required this.metadata,
    required this.typedefKeyword,
    this.returnType,
    required this.name,
    this.typeParameters,
    required this.parameters,
    required this.semicolon,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitFunctionTypeAlias(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'FunctionTypeAlias',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        'typedef': typedefKeyword.toJson(),
        if (returnType != null) 'returnType': returnType!.toJson(),
        'name': name.toJson(),
        if (typeParameters != null) 'typeParams': typeParameters!.toJson(),
        'params': parameters.toJson(),
        'semi': semicolon.toJson(),
      };

  factory SFunctionTypeAlias.fromJson(Map<String, dynamic> json) {
    return SFunctionTypeAlias(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      typedefKeyword: SToken.fromJson(json['typedef'] as Map<String, dynamic>),
      returnType: json['returnType'] != null
          ? _typeFromJson(json['returnType'] as Map<String, dynamic>)
          : null,
      name: SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>),
      typeParameters: json['typeParams'] != null
          ? STypeParameterList.fromJson(
              json['typeParams'] as Map<String, dynamic>)
          : null,
      parameters: SFormalParameterList.fromJson(
          json['params'] as Map<String, dynamic>),
      semicolon: SToken.fromJson(json['semi'] as Map<String, dynamic>),
    );
  }
}

/// A generic type alias declaration.
///
/// Example: `typedef F<T> = T Function(T);`
final class SGenericTypeAlias extends SDeclaration {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// The 'typedef' keyword.
  final SToken typedefKeyword;

  /// The name.
  final SSimpleIdentifier name;

  /// The type parameters, if any.
  final STypeParameterList? typeParameters;

  /// The '=' token.
  final SToken equals;

  /// The aliased type.
  final STypeAnnotation type;

  /// The semicolon.
  final SToken semicolon;

  /// The function type (convenience accessor, returns type if it's a GenericFunctionType).
  SGenericFunctionType? get functionType =>
      type is SGenericFunctionType ? type as SGenericFunctionType : null;

  @override
  int get offset => metadata.firstOrNull?.offset ?? typedefKeyword.offset;

  @override
  int get end => semicolon.end;

  const SGenericTypeAlias({
    required this.metadata,
    required this.typedefKeyword,
    required this.name,
    this.typeParameters,
    required this.equals,
    required this.type,
    required this.semicolon,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitGenericTypeAlias(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'GenericTypeAlias',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        'typedef': typedefKeyword.toJson(),
        'name': name.toJson(),
        if (typeParameters != null) 'typeParams': typeParameters!.toJson(),
        'eq': equals.toJson(),
        'aliasType': type.toJson(),
        'semi': semicolon.toJson(),
      };

  factory SGenericTypeAlias.fromJson(Map<String, dynamic> json) {
    return SGenericTypeAlias(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      typedefKeyword: SToken.fromJson(json['typedef'] as Map<String, dynamic>),
      name: SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>),
      typeParameters: json['typeParams'] != null
          ? STypeParameterList.fromJson(
              json['typeParams'] as Map<String, dynamic>)
          : null,
      equals: SToken.fromJson(json['eq'] as Map<String, dynamic>),
      type: _typeFromJson(json['aliasType'] as Map<String, dynamic>),
      semicolon: SToken.fromJson(json['semi'] as Map<String, dynamic>),
    );
  }
}

/// An extension type declaration.
///
/// Example: `extension type IntBox(int i) implements int { }`
final class SExtensionTypeDeclaration extends SDeclaration {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// The 'extension' keyword.
  final SToken extensionKeyword;

  /// The 'type' keyword.
  final SToken typeKeyword;

  /// The 'const' keyword, if any.
  final SToken? constKeyword;

  /// The name.
  final SSimpleIdentifier name;

  /// The type parameters, if any.
  final STypeParameterList? typeParameters;

  /// The representation declaration.
  final SRepresentationDeclaration representation;

  /// The implements clause, if any.
  final SImplementsClause? implementsClause;

  /// The left brace.
  final SToken leftBrace;

  /// The members.
  final List<SClassMember> members;

  /// The right brace.
  final SToken rightBrace;

  @override
  int get offset => metadata.firstOrNull?.offset ?? extensionKeyword.offset;

  @override
  int get end => rightBrace.end;

  const SExtensionTypeDeclaration({
    required this.metadata,
    required this.extensionKeyword,
    required this.typeKeyword,
    this.constKeyword,
    required this.name,
    this.typeParameters,
    required this.representation,
    this.implementsClause,
    required this.leftBrace,
    required this.members,
    required this.rightBrace,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitExtensionTypeDeclaration(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ExtensionTypeDeclaration',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        'extension': extensionKeyword.toJson(),
        'typeKw': typeKeyword.toJson(),
        if (constKeyword != null) 'const': constKeyword!.toJson(),
        'name': name.toJson(),
        if (typeParameters != null) 'typeParams': typeParameters!.toJson(),
        'repr': representation.toJson(),
        if (implementsClause != null) 'implements': implementsClause!.toJson(),
        'lb': leftBrace.toJson(),
        'members': members.map((m) => m.toJson()).toList(),
        'rb': rightBrace.toJson(),
      };

  factory SExtensionTypeDeclaration.fromJson(Map<String, dynamic> json) {
    return SExtensionTypeDeclaration(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      extensionKeyword:
          SToken.fromJson(json['extension'] as Map<String, dynamic>),
      typeKeyword: SToken.fromJson(json['typeKw'] as Map<String, dynamic>),
      constKeyword: json['const'] != null
          ? SToken.fromJson(json['const'] as Map<String, dynamic>)
          : null,
      name: SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>),
      typeParameters: json['typeParams'] != null
          ? STypeParameterList.fromJson(
              json['typeParams'] as Map<String, dynamic>)
          : null,
      representation: SRepresentationDeclaration.fromJson(
          json['repr'] as Map<String, dynamic>),
      implementsClause: json['implements'] != null
          ? SImplementsClause.fromJson(
              json['implements'] as Map<String, dynamic>)
          : null,
      leftBrace: SToken.fromJson(json['lb'] as Map<String, dynamic>),
      members: (json['members'] as List)
          .map((m) => _classMemberFromJson(m as Map<String, dynamic>))
          .toList(),
      rightBrace: SToken.fromJson(json['rb'] as Map<String, dynamic>),
    );
  }
}

/// A representation declaration in an extension type.
///
/// Example: `(int i)` in `extension type IntBox(int i) { }`
final class SRepresentationDeclaration extends SAstNode {
  /// The left parenthesis.
  final SToken leftParenthesis;

  /// The type of the representation field.
  final STypeAnnotation fieldType;

  /// The name of the representation field.
  final SSimpleIdentifier fieldName;

  /// The right parenthesis.
  final SToken rightParenthesis;

  @override
  int get offset => leftParenthesis.offset;

  @override
  int get end => rightParenthesis.end;

  const SRepresentationDeclaration({
    required this.leftParenthesis,
    required this.fieldType,
    required this.fieldName,
    required this.rightParenthesis,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitRepresentationDeclaration(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'RepresentationDeclaration',
        'lp': leftParenthesis.toJson(),
        'fieldType': fieldType.toJson(),
        'fieldName': fieldName.toJson(),
        'rp': rightParenthesis.toJson(),
      };

  factory SRepresentationDeclaration.fromJson(Map<String, dynamic> json) {
    return SRepresentationDeclaration(
      leftParenthesis: SToken.fromJson(json['lp'] as Map<String, dynamic>),
      fieldType:
          _typeFromJson(json['fieldType'] as Map<String, dynamic>),
      fieldName:
          SSimpleIdentifier.fromJson(json['fieldName'] as Map<String, dynamic>),
      rightParenthesis: SToken.fromJson(json['rp'] as Map<String, dynamic>),
    );
  }
}

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/// A class body (base class).
abstract class SClassBody extends SAstNode {
  /// The members of the class body.
  List<SClassMember> get members;

  const SClassBody();
}

/// A block class body with members.
///
/// Example: `{ void foo() {} }`
final class SBlockClassBody extends SClassBody {
  /// The left bracket.
  final SToken leftBracket;

  /// The members of the class.
  @override
  final List<SClassMember> members;

  /// The right bracket.
  final SToken rightBracket;

  @override
  int get offset => leftBracket.offset;

  @override
  int get end => rightBracket.end;

  const SBlockClassBody({
    required this.leftBracket,
    required this.members,
    required this.rightBracket,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitBlockClassBody(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'BlockClassBody',
        'lb': leftBracket.toJson(),
        'members': members.map((m) => m.toJson()).toList(),
        'rb': rightBracket.toJson(),
      };

  factory SBlockClassBody.fromJson(Map<String, dynamic> json) {
    return SBlockClassBody(
      leftBracket: SToken.fromJson(json['lb'] as Map<String, dynamic>),
      members: (json['members'] as List)
          .map((m) => _classMemberFromJson(m as Map<String, dynamic>))
          .toList(),
      rightBracket: SToken.fromJson(json['rb'] as Map<String, dynamic>),
    );
  }
}

/// An empty class body (just a semicolon).
///
/// Example: `;` in `class C = Base with Mixin;`
final class SEmptyClassBody extends SClassBody {
  /// The semicolon.
  final SToken semicolon;

  @override
  List<SClassMember> get members => const [];

  @override
  int get offset => semicolon.offset;

  @override
  int get end => semicolon.end;

  const SEmptyClassBody({required this.semicolon});

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitEmptyClassBody(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'EmptyClassBody',
        'semi': semicolon.toJson(),
      };

  factory SEmptyClassBody.fromJson(Map<String, dynamic> json) {
    return SEmptyClassBody(
      semicolon: SToken.fromJson(json['semi'] as Map<String, dynamic>),
    );
  }
}

/// An enum body.
///
/// Example: `{ a, b; void foo() {} }`
final class SEnumBody extends SAstNode {
  /// The left bracket.
  final SToken leftBracket;

  /// The enum constants.
  final List<SEnumConstantDeclaration> constants;

  /// The semicolon after constants (optional).
  final SToken? semicolon;

  /// The members of the enum.
  final List<SClassMember> members;

  /// The right bracket.
  final SToken rightBracket;

  @override
  int get offset => leftBracket.offset;

  @override
  int get end => rightBracket.end;

  const SEnumBody({
    required this.leftBracket,
    required this.constants,
    this.semicolon,
    required this.members,
    required this.rightBracket,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitEnumBody(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'EnumBody',
        'lb': leftBracket.toJson(),
        'constants': constants.map((c) => c.toJson()).toList(),
        if (semicolon != null) 'semi': semicolon!.toJson(),
        'members': members.map((m) => m.toJson()).toList(),
        'rb': rightBracket.toJson(),
      };

  factory SEnumBody.fromJson(Map<String, dynamic> json) {
    return SEnumBody(
      leftBracket: SToken.fromJson(json['lb'] as Map<String, dynamic>),
      constants: (json['constants'] as List)
          .map((c) =>
              SEnumConstantDeclaration.fromJson(c as Map<String, dynamic>))
          .toList(),
      semicolon: json['semi'] != null
          ? SToken.fromJson(json['semi'] as Map<String, dynamic>)
          : null,
      members: (json['members'] as List)
          .map((m) => _classMemberFromJson(m as Map<String, dynamic>))
          .toList(),
      rightBracket: SToken.fromJson(json['rb'] as Map<String, dynamic>),
    );
  }
}

/// A name with type parameters (for primary constructors).
///
/// Example: `MyClass<T>`
final class SNameWithTypeParameters extends SAstNode {
  /// The type name.
  final SToken typeName;

  /// The type parameters.
  final STypeParameterList? typeParameters;

  @override
  int get offset => typeName.offset;

  @override
  int get end => typeParameters?.end ?? typeName.end;

  const SNameWithTypeParameters({
    required this.typeName,
    this.typeParameters,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitNameWithTypeParameters(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'NameWithTypeParameters',
        'name': typeName.toJson(),
        if (typeParameters != null) 'typeParams': typeParameters!.toJson(),
      };

  factory SNameWithTypeParameters.fromJson(Map<String, dynamic> json) {
    return SNameWithTypeParameters(
      typeName: SToken.fromJson(json['name'] as Map<String, dynamic>),
      typeParameters: json['typeParams'] != null
          ? STypeParameterList.fromJson(
              json['typeParams'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// A primary constructor name.
///
/// Example: `.named` in `class C.named(int x) {}`
final class SPrimaryConstructorName extends SAstNode {
  /// The period before the name.
  final SToken period;

  /// The name of the constructor.
  final SToken name;

  @override
  int get offset => period.offset;

  @override
  int get end => name.end;

  const SPrimaryConstructorName({
    required this.period,
    required this.name,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitPrimaryConstructorName(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'PrimaryConstructorName',
        'period': period.toJson(),
        'name': name.toJson(),
      };

  factory SPrimaryConstructorName.fromJson(Map<String, dynamic> json) {
    return SPrimaryConstructorName(
      period: SToken.fromJson(json['period'] as Map<String, dynamic>),
      name: SToken.fromJson(json['name'] as Map<String, dynamic>),
    );
  }
}

/// A primary constructor declaration.
///
/// Example: `C(int x)` or `C.named(int x)`
final class SPrimaryConstructorDeclaration extends SAstNode {
  /// The 'const' keyword, if any.
  final SToken? constKeyword;

  /// The type name.
  final SToken typeName;

  /// The type parameters.
  final STypeParameterList? typeParameters;

  /// The constructor name, if any.
  final SPrimaryConstructorName? constructorName;

  /// The formal parameters.
  final SFormalParameterList formalParameters;

  @override
  int get offset => constKeyword?.offset ?? typeName.offset;

  @override
  int get end => formalParameters.end;

  const SPrimaryConstructorDeclaration({
    this.constKeyword,
    required this.typeName,
    this.typeParameters,
    this.constructorName,
    required this.formalParameters,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitPrimaryConstructorDeclaration(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'PrimaryConstructorDeclaration',
        if (constKeyword != null) 'const': constKeyword!.toJson(),
        'typeName': typeName.toJson(),
        if (typeParameters != null) 'typeParams': typeParameters!.toJson(),
        if (constructorName != null) 'ctorName': constructorName!.toJson(),
        'params': formalParameters.toJson(),
      };

  factory SPrimaryConstructorDeclaration.fromJson(Map<String, dynamic> json) {
    return SPrimaryConstructorDeclaration(
      constKeyword: json['const'] != null
          ? SToken.fromJson(json['const'] as Map<String, dynamic>)
          : null,
      typeName: SToken.fromJson(json['typeName'] as Map<String, dynamic>),
      typeParameters: json['typeParams'] != null
          ? STypeParameterList.fromJson(
              json['typeParams'] as Map<String, dynamic>)
          : null,
      constructorName: json['ctorName'] != null
          ? SPrimaryConstructorName.fromJson(
              json['ctorName'] as Map<String, dynamic>)
          : null,
      formalParameters: SFormalParameterList.fromJson(
          json['params'] as Map<String, dynamic>),
    );
  }
}

/// A primary constructor body.
///
/// Example: `this : _x = x {}`
final class SPrimaryConstructorBody extends SAstNode {
  /// The 'this' keyword.
  final SToken thisKeyword;

  /// The colon before initializers, if any.
  final SToken? colon;

  /// The constructor initializers.
  final List<SConstructorInitializer> initializers;

  /// The function body.
  final SFunctionBody body;

  @override
  int get offset => thisKeyword.offset;

  @override
  int get end => body.end;

  const SPrimaryConstructorBody({
    required this.thisKeyword,
    this.colon,
    required this.initializers,
    required this.body,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitPrimaryConstructorBody(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'PrimaryConstructorBody',
        'this': thisKeyword.toJson(),
        if (colon != null) 'colon': colon!.toJson(),
        'initializers': initializers.map((i) => i.toJson()).toList(),
        'body': body.toJson(),
      };

  factory SPrimaryConstructorBody.fromJson(Map<String, dynamic> json) {
    return SPrimaryConstructorBody(
      thisKeyword: SToken.fromJson(json['this'] as Map<String, dynamic>),
      colon: json['colon'] != null
          ? SToken.fromJson(json['colon'] as Map<String, dynamic>)
          : null,
      initializers: (json['initializers'] as List)
          .map((i) =>
              _constructorInitializerFromJson(i as Map<String, dynamic>))
          .toList(),
      body: _functionBodyFromJson(json['body'] as Map<String, dynamic>),
    );
  }
}

/// A representation constructor name (for extension types).
///
/// Example: `.named` in `extension type E.named(int i) {}`
final class SRepresentationConstructorName extends SAstNode {
  /// The period before the name.
  final SToken period;

  /// The name of the constructor.
  final SToken name;

  @override
  int get offset => period.offset;

  @override
  int get end => name.end;

  const SRepresentationConstructorName({
    required this.period,
    required this.name,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitRepresentationConstructorName(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'RepresentationConstructorName',
        'period': period.toJson(),
        'name': name.toJson(),
      };

  factory SRepresentationConstructorName.fromJson(Map<String, dynamic> json) {
    return SRepresentationConstructorName(
      period: SToken.fromJson(json['period'] as Map<String, dynamic>),
      name: SToken.fromJson(json['name'] as Map<String, dynamic>),
    );
  }
}

/// Parses a class member from JSON.
SClassMember _classMemberFromJson(Map<String, dynamic> json) {
  final type = json['type'] as String;
  return switch (type) {
    'MethodDeclaration' => SMethodDeclaration.fromJson(json),
    'ConstructorDeclaration' => SConstructorDeclaration.fromJson(json),
    'FieldDeclaration' => SFieldDeclaration.fromJson(json),
    _ => throw FormatException('Unknown class member type: $type'),
  };
}

/// Parses a constructor initializer from JSON.
SConstructorInitializer _constructorInitializerFromJson(
    Map<String, dynamic> json) {
  final type = json['type'] as String;
  return switch (type) {
    'SuperConstructorInvocation' => SSuperConstructorInvocation.fromJson(json),
    'RedirectingConstructorInvocation' =>
      SRedirectingConstructorInvocation.fromJson(json),
    'ConstructorFieldInitializer' => SConstructorFieldInitializer.fromJson(json),
    'AssertInitializer' => SAssertInitializer.fromJson(json),
    _ => throw FormatException('Unknown constructor initializer type: $type'),
  };
}
