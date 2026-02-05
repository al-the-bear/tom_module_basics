part of '../ast.dart';

// =============================================================================
// BASE CLASSES
// =============================================================================

/// Base class for all AST nodes.
///
/// Each node has:
/// - [offset] and [end] for source location
/// - [accept] method for visitor pattern
/// - [toJson] for serialization
abstract class SAstNode {
  /// The offset of the first character of this node in the source.
  int get offset;

  /// The offset after the last character of this node in the source.
  int get end;

  /// The length of this node in characters.
  int get length => end - offset;

  /// Accepts a visitor and returns the result.
  R? accept<R>(SAstVisitor<R> visitor);

  /// Converts this node to a JSON-serializable map.
  Map<String, dynamic> toJson();

  /// Allows subclasses to implement const constructors.
  const SAstNode();

  /// Parses a node from JSON, dispatching to the appropriate factory.
  static SAstNode fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    return _nodeFromType(type, json);
  }
}

/// Base class for expression nodes.
abstract class SExpression extends SAstNode {
  const SExpression();
}

/// Base class for statement nodes.
abstract class SStatement extends SAstNode {
  const SStatement();
}

/// Base class for declaration nodes.
abstract class SDeclaration extends SAstNode {
  const SDeclaration();
}

/// Base class for directive nodes (import, export, library, part).
abstract class SDirective extends SAstNode {
  const SDirective();
}

/// Base class for type annotation nodes.
abstract class STypeAnnotation extends SAstNode {
  const STypeAnnotation();
}

// =============================================================================
// IDENTIFIER NODES
// =============================================================================

/// Base class for identifier nodes.
abstract class SIdentifier extends SExpression {
  /// The name of the identifier.
  String get name;

  const SIdentifier();
}

/// A simple (unqualified) identifier.
///
/// Examples: `x`, `foo`, `myVariable`
final class SSimpleIdentifier extends SIdentifier {
  /// The token representing the identifier.
  final SToken token;

  @override
  String get name => token.lexeme;

  @override
  int get offset => token.offset;

  @override
  int get end => token.end;

  /// Whether this identifier is being used as a declaration.
  final bool isDeclaration;

  const SSimpleIdentifier({
    required this.token,
    this.isDeclaration = false,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitSimpleIdentifier(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'SimpleIdentifier',
        'token': token.toJson(),
        if (isDeclaration) 'isDecl': true,
      };

  factory SSimpleIdentifier.fromJson(Map<String, dynamic> json) {
    return SSimpleIdentifier(
      token: SToken.fromJson(json['token'] as Map<String, dynamic>),
      isDeclaration: json['isDecl'] as bool? ?? false,
    );
  }
}

/// A prefixed identifier (library.identifier or type.identifier).
///
/// Examples: `math.pi`, `MyClass.staticField`
final class SPrefixedIdentifier extends SIdentifier {
  /// The prefix before the period.
  final SSimpleIdentifier prefix;

  /// The period token.
  final SToken period;

  /// The identifier after the period.
  final SSimpleIdentifier identifier;

  @override
  String get name => '${prefix.name}.${identifier.name}';

  @override
  int get offset => prefix.offset;

  @override
  int get end => identifier.end;

  const SPrefixedIdentifier({
    required this.prefix,
    required this.period,
    required this.identifier,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitPrefixedIdentifier(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'PrefixedIdentifier',
        'prefix': prefix.toJson(),
        'period': period.toJson(),
        'identifier': identifier.toJson(),
      };

  factory SPrefixedIdentifier.fromJson(Map<String, dynamic> json) {
    return SPrefixedIdentifier(
      prefix:
          SSimpleIdentifier.fromJson(json['prefix'] as Map<String, dynamic>),
      period: SToken.fromJson(json['period'] as Map<String, dynamic>),
      identifier: SSimpleIdentifier.fromJson(
          json['identifier'] as Map<String, dynamic>),
    );
  }
}

// =============================================================================
// ANNOTATION
// =============================================================================

/// An annotation that can be attached to declarations.
///
/// Examples: `@override`, `@deprecated`, `@MyAnnotation(42)`
final class SAnnotation extends SAstNode {
  /// The '@' token.
  final SToken atSign;

  /// The name of the annotation (can be simple or prefixed).
  final SIdentifier name;

  /// The type arguments, if any.
  final STypeArgumentList? typeArguments;

  /// The constructor name, if this is a constructor invocation.
  final SSimpleIdentifier? constructorName;

  /// The arguments to the annotation, if any.
  final SArgumentList? arguments;

  @override
  int get offset => atSign.offset;

  @override
  int get end {
    if (arguments != null) return arguments!.end;
    if (constructorName != null) return constructorName!.end;
    if (typeArguments != null) return typeArguments!.end;
    return name.end;
  }

  const SAnnotation({
    required this.atSign,
    required this.name,
    this.typeArguments,
    this.constructorName,
    this.arguments,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitAnnotation(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'Annotation',
        'atSign': atSign.toJson(),
        'name': name.toJson(),
        if (typeArguments != null) 'typeArgs': typeArguments!.toJson(),
        if (constructorName != null) 'ctor': constructorName!.toJson(),
        if (arguments != null) 'args': arguments!.toJson(),
      };

  factory SAnnotation.fromJson(Map<String, dynamic> json) {
    return SAnnotation(
      atSign: SToken.fromJson(json['atSign'] as Map<String, dynamic>),
      name: _identifierFromJson(json['name'] as Map<String, dynamic>),
      typeArguments: json['typeArgs'] != null
          ? STypeArgumentList.fromJson(json['typeArgs'] as Map<String, dynamic>)
          : null,
      constructorName: json['ctor'] != null
          ? SSimpleIdentifier.fromJson(json['ctor'] as Map<String, dynamic>)
          : null,
      arguments: json['args'] != null
          ? SArgumentList.fromJson(json['args'] as Map<String, dynamic>)
          : null,
    );
  }
}

// =============================================================================
// COMMENT
// =============================================================================

/// A comment in the source code.
final class SComment extends SAstNode {
  /// The tokens that make up this comment.
  final List<SToken> tokens;

  @override
  int get offset => tokens.first.offset;

  @override
  int get end => tokens.last.end;

  /// The text of the comment.
  String get text => tokens.map((t) => t.lexeme).join('\n');

  /// Whether this is a documentation comment.
  bool get isDocumentation =>
      tokens.isNotEmpty &&
      tokens.first.type == STokenType.documentationComment;

  const SComment({required this.tokens});

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitComment(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'Comment',
        'tokens': tokens.map((t) => t.toJson()).toList(),
      };

  factory SComment.fromJson(Map<String, dynamic> json) {
    return SComment(
      tokens: (json['tokens'] as List)
          .map((t) => SToken.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }
}

// =============================================================================
// COMPILATION UNIT
// =============================================================================

/// A complete Dart compilation unit (file).
///
/// This is the root of the AST for any Dart file.
final class SCompilationUnit extends SAstNode {
  /// The script tag at the beginning, if any.
  final SScriptTag? scriptTag;

  /// The directives (imports, exports, library, part).
  final List<SDirective> directives;

  /// The declarations in this compilation unit.
  final List<SDeclaration> declarations;

  /// The end-of-file token.
  final SToken endToken;

  @override
  int get offset => scriptTag?.offset ?? directives.firstOrNull?.offset ?? 
      declarations.firstOrNull?.offset ?? endToken.offset;

  @override
  int get end => endToken.end;

  const SCompilationUnit({
    this.scriptTag,
    required this.directives,
    required this.declarations,
    required this.endToken,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitCompilationUnit(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'CompilationUnit',
        if (scriptTag != null) 'scriptTag': scriptTag!.toJson(),
        'directives': directives.map((d) => d.toJson()).toList(),
        'declarations': declarations.map((d) => d.toJson()).toList(),
        'endToken': endToken.toJson(),
      };

  factory SCompilationUnit.fromJson(Map<String, dynamic> json) {
    return SCompilationUnit(
      scriptTag: json['scriptTag'] != null
          ? SScriptTag.fromJson(json['scriptTag'] as Map<String, dynamic>)
          : null,
      directives: (json['directives'] as List)
          .map((d) => _directiveFromJson(d as Map<String, dynamic>))
          .toList(),
      declarations: (json['declarations'] as List)
          .map((d) => _declarationFromJson(d as Map<String, dynamic>))
          .toList(),
      endToken: SToken.fromJson(json['endToken'] as Map<String, dynamic>),
    );
  }
}

/// A script tag (#!) at the beginning of a file.
final class SScriptTag extends SAstNode {
  /// The script tag token.
  final SToken token;

  @override
  int get offset => token.offset;

  @override
  int get end => token.end;

  const SScriptTag({required this.token});

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitScriptTag(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ScriptTag',
        'token': token.toJson(),
      };

  factory SScriptTag.fromJson(Map<String, dynamic> json) {
    return SScriptTag(
      token: SToken.fromJson(json['token'] as Map<String, dynamic>),
    );
  }
}

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/// Parses an identifier from JSON.
SIdentifier _identifierFromJson(Map<String, dynamic> json) {
  final type = json['type'] as String;
  return switch (type) {
    'SimpleIdentifier' => SSimpleIdentifier.fromJson(json),
    'PrefixedIdentifier' => SPrefixedIdentifier.fromJson(json),
    _ => throw FormatException('Unknown identifier type: $type'),
  };
}

/// Parses an expression from JSON.
SExpression _expressionFromJson(Map<String, dynamic> json) {
  return _nodeFromType(json['type'] as String, json) as SExpression;
}

/// Parses a statement from JSON.
SStatement _statementFromJson(Map<String, dynamic> json) {
  return _nodeFromType(json['type'] as String, json) as SStatement;
}

/// Parses a declaration from JSON.
SDeclaration _declarationFromJson(Map<String, dynamic> json) {
  return _nodeFromType(json['type'] as String, json) as SDeclaration;
}

/// Parses a directive from JSON.
SDirective _directiveFromJson(Map<String, dynamic> json) {
  return _nodeFromType(json['type'] as String, json) as SDirective;
}

/// Parses a type annotation from JSON.
STypeAnnotation _typeFromJson(Map<String, dynamic> json) {
  return _nodeFromType(json['type'] as String, json) as STypeAnnotation;
}

/// Master factory for all node types.
SAstNode _nodeFromType(String type, Map<String, dynamic> json) {
  return switch (type) {
    // Identifiers
    'SimpleIdentifier' => SSimpleIdentifier.fromJson(json),
    'PrefixedIdentifier' => SPrefixedIdentifier.fromJson(json),
    // Base nodes
    'Annotation' => SAnnotation.fromJson(json),
    'Comment' => SComment.fromJson(json),
    'CompilationUnit' => SCompilationUnit.fromJson(json),
    'ScriptTag' => SScriptTag.fromJson(json),
    // Expressions - defined in expressions.dart
    'AssignmentExpression' => SAssignmentExpression.fromJson(json),
    'AwaitExpression' => SAwaitExpression.fromJson(json),
    'BinaryExpression' => SBinaryExpression.fromJson(json),
    'CascadeExpression' => SCascadeExpression.fromJson(json),
    'ConditionalExpression' => SConditionalExpression.fromJson(json),
    'FunctionExpression' => SFunctionExpression.fromJson(json),
    'FunctionExpressionInvocation' => SFunctionExpressionInvocation.fromJson(json),
    'IndexExpression' => SIndexExpression.fromJson(json),
    'InstanceCreationExpression' => SInstanceCreationExpression.fromJson(json),
    'IsExpression' => SIsExpression.fromJson(json),
    'AsExpression' => SAsExpression.fromJson(json),
    'MethodInvocation' => SMethodInvocation.fromJson(json),
    'NamedExpression' => SNamedExpression.fromJson(json),
    'ParenthesizedExpression' => SParenthesizedExpression.fromJson(json),
    'PostfixExpression' => SPostfixExpression.fromJson(json),
    'PrefixExpression' => SPrefixExpression.fromJson(json),
    'PropertyAccess' => SPropertyAccess.fromJson(json),
    'RethrowExpression' => SRethrowExpression.fromJson(json),
    'SuperExpression' => SSuperExpression.fromJson(json),
    'ThisExpression' => SThisExpression.fromJson(json),
    'ThrowExpression' => SThrowExpression.fromJson(json),
    'ConstructorReference' => SConstructorReference.fromJson(json),
    'FunctionReference' => SFunctionReference.fromJson(json),
    'DotShorthandInvocation' => SDotShorthandInvocation.fromJson(json),
    'DotShorthandPropertyAccess' => SDotShorthandPropertyAccess.fromJson(json),
    'DotShorthandConstructorInvocation' =>
        SDotShorthandConstructorInvocation.fromJson(json),
    'ExtensionOverride' => SExtensionOverride.fromJson(json),
    'ImplicitCallReference' => SImplicitCallReference.fromJson(json),
    'TypeLiteral' => STypeLiteral.fromJson(json),
    'SwitchExpression' => SSwitchExpression.fromJson(json),
    // Literals - defined in literals.dart
    'IntegerLiteral' => SIntegerLiteral.fromJson(json),
    'DoubleLiteral' => SDoubleLiteral.fromJson(json),
    'BooleanLiteral' => SBooleanLiteral.fromJson(json),
    'NullLiteral' => SNullLiteral.fromJson(json),
    'SimpleStringLiteral' => SSimpleStringLiteral.fromJson(json),
    'AdjacentStrings' => SAdjacentStrings.fromJson(json),
    'StringInterpolation' => SStringInterpolation.fromJson(json),
    'SymbolLiteral' => SSymbolLiteral.fromJson(json),
    'ListLiteral' => SListLiteral.fromJson(json),
    'SetOrMapLiteral' => SSetOrMapLiteral.fromJson(json),
    'RecordLiteral' => SRecordLiteral.fromJson(json),
    // Statements - defined in statements.dart
    'Block' => SBlock.fromJson(json),
    'AssertStatement' => SAssertStatement.fromJson(json),
    'BreakStatement' => SBreakStatement.fromJson(json),
    'ContinueStatement' => SContinueStatement.fromJson(json),
    'DoStatement' => SDoStatement.fromJson(json),
    'EmptyStatement' => SEmptyStatement.fromJson(json),
    'ExpressionStatement' => SExpressionStatement.fromJson(json),
    'ForStatement' => SForStatement.fromJson(json),
    'FunctionDeclarationStatement' => SFunctionDeclarationStatement.fromJson(json),
    'IfStatement' => SIfStatement.fromJson(json),
    'LabeledStatement' => SLabeledStatement.fromJson(json),
    'ReturnStatement' => SReturnStatement.fromJson(json),
    'SwitchStatement' => SSwitchStatement.fromJson(json),
    'TryStatement' => STryStatement.fromJson(json),
    'VariableDeclarationStatement' => SVariableDeclarationStatement.fromJson(json),
    'WhileStatement' => SWhileStatement.fromJson(json),
    'YieldStatement' => SYieldStatement.fromJson(json),
    'PatternVariableDeclarationStatement' => SPatternVariableDeclarationStatement.fromJson(json),
    'PatternAssignment' => SPatternAssignment.fromJson(json),
    // Declarations - defined in declarations.dart
    'ClassDeclaration' => SClassDeclaration.fromJson(json),
    'EnumDeclaration' => SEnumDeclaration.fromJson(json),
    'ExtensionDeclaration' => SExtensionDeclaration.fromJson(json),
    'MixinDeclaration' => SMixinDeclaration.fromJson(json),
    'FunctionDeclaration' => SFunctionDeclaration.fromJson(json),
    'TopLevelVariableDeclaration' => STopLevelVariableDeclaration.fromJson(json),
    'MethodDeclaration' => SMethodDeclaration.fromJson(json),
    'ConstructorDeclaration' => SConstructorDeclaration.fromJson(json),
    'FieldDeclaration' => SFieldDeclaration.fromJson(json),
    'VariableDeclaration' => SVariableDeclaration.fromJson(json),
    'VariableDeclarationList' => SVariableDeclarationList.fromJson(json),
    'TypeAlias' => STypeAlias.fromJson(json),
    'ClassTypeAlias' => SClassTypeAlias.fromJson(json),
    'FunctionTypeAlias' => SFunctionTypeAlias.fromJson(json),
    'GenericTypeAlias' => SGenericTypeAlias.fromJson(json),
    'ExtensionTypeDeclaration' => SExtensionTypeDeclaration.fromJson(json),
    'RepresentationDeclaration' => SRepresentationDeclaration.fromJson(json),
    // Directives - defined in directives.dart
    'ImportDirective' => SImportDirective.fromJson(json),
    'ExportDirective' => SExportDirective.fromJson(json),
    'LibraryDirective' => SLibraryDirective.fromJson(json),
    'PartDirective' => SPartDirective.fromJson(json),
    'PartOfDirective' => SPartOfDirective.fromJson(json),
    // Types - defined in types.dart
    'NamedType' => SNamedType.fromJson(json),
    'GenericFunctionType' => SGenericFunctionType.fromJson(json),
    'RecordTypeAnnotation' => SRecordTypeAnnotation.fromJson(json),
    'TypeArgumentList' => STypeArgumentList.fromJson(json),
    'TypeParameter' => STypeParameter.fromJson(json),
    'TypeParameterList' => STypeParameterList.fromJson(json),
    // Function bodies - defined in function_body.dart
    'BlockFunctionBody' => SBlockFunctionBody.fromJson(json),
    'ExpressionFunctionBody' => SExpressionFunctionBody.fromJson(json),
    'EmptyFunctionBody' => SEmptyFunctionBody.fromJson(json),
    'NativeFunctionBody' => SNativeFunctionBody.fromJson(json),
    // Parameters - defined in parameters.dart
    'FormalParameterList' => SFormalParameterList.fromJson(json),
    'SimpleFormalParameter' => SSimpleFormalParameter.fromJson(json),
    'DefaultFormalParameter' => SDefaultFormalParameter.fromJson(json),
    'FieldFormalParameter' => SFieldFormalParameter.fromJson(json),
    'FunctionTypedFormalParameter' => SFunctionTypedFormalParameter.fromJson(json),
    'SuperFormalParameter' => SSuperFormalParameter.fromJson(json),
    'ArgumentList' => SArgumentList.fromJson(json),
    // Clauses - defined in clauses.dart
    'ExtendsClause' => SExtendsClause.fromJson(json),
    'ImplementsClause' => SImplementsClause.fromJson(json),
    'WithClause' => SWithClause.fromJson(json),
    'OnClause' => SOnClause.fromJson(json),
    'CatchClause' => SCatchClause.fromJson(json),
    'ShowCombinator' => SShowCombinator.fromJson(json),
    'HideCombinator' => SHideCombinator.fromJson(json),
    // Collection elements - defined in collection_elements.dart
    'ForElement' => SForElement.fromJson(json),
    'IfElement' => SIfElement.fromJson(json),
    'SpreadElement' => SSpreadElement.fromJson(json),
    'MapLiteralEntry' => SMapLiteralEntry.fromJson(json),
    'RecordField' => SRecordField.fromJson(json),
    'ExpressionElement' => SExpressionElement.fromJson(json),
    'NullAwareElement' => SNullAwareElement.fromJson(json),
    // Clauses additional - defined in clauses.dart
    'FinallyClause' => SFinallyClause.fromJson(json),
    'NativeClause' => SNativeClause.fromJson(json),
    'CatchClauseParameter' => SCatchClauseParameter.fromJson(json),
    // Directives additional - defined in directives.dart
    'LibraryIdentifier' => SLibraryIdentifier.fromJson(json),
    'Configuration' => SConfiguration.fromJson(json),
    'DottedName' => SDottedName.fromJson(json),
    // Declarations additional - defined in declarations.dart
    'EnumConstantDeclaration' => SEnumConstantDeclaration.fromJson(json),
    'ExtensionTypeRepresentation' => SExtensionTypeRepresentation.fromJson(json),
    'SuperConstructorInvocation' => SSuperConstructorInvocation.fromJson(json),
    'RedirectingConstructorInvocation' => SRedirectingConstructorInvocation.fromJson(json),
    'ConstructorFieldInitializer' => SConstructorFieldInitializer.fromJson(json),
    'AssertInitializer' => SAssertInitializer.fromJson(json),
    // Types additional - defined in types.dart
    'RecordTypeAnnotationPositionalField' => SRecordTypeAnnotationPositionalField.fromJson(json),
    'RecordTypeAnnotationNamedFields' => SRecordTypeAnnotationNamedFields.fromJson(json),
    'RecordTypeAnnotationNamedField' => SRecordTypeAnnotationNamedField.fromJson(json),
    // Expressions additional - defined in expressions.dart
    'ConstructorName' => SConstructorName.fromJson(json),
    'Label' => SLabel.fromJson(json),
    'SwitchExpressionCase' => SSwitchExpressionCase.fromJson(json),
    'GuardedPattern' => SGuardedPattern.fromJson(json),
    // Statements additional - defined in statements.dart
    'CaseClause' => SCaseClause.fromJson(json),
    'ForPartsWithDeclarations' => SForPartsWithDeclarations.fromJson(json),
    'ForPartsWithExpression' => SForPartsWithExpression.fromJson(json),
    'ForPartsWithPattern' => SForPartsWithPattern.fromJson(json),
    'ForEachPartsWithDeclaration' => SForEachPartsWithDeclaration.fromJson(json),
    'ForEachPartsWithIdentifier' => SForEachPartsWithIdentifier.fromJson(json),
    'ForEachPartsWithPattern' => SForEachPartsWithPattern.fromJson(json),
    'SwitchPatternCase' => SSwitchPatternCase.fromJson(json),
    'SwitchCase' => SSwitchCase.fromJson(json),
    'SwitchDefault' => SSwitchDefault.fromJson(json),
    'WhenClause' => SWhenClause.fromJson(json),
    'PatternVariableDeclaration' => SPatternVariableDeclaration.fromJson(json),
    // Literals additional - defined in literals.dart
    'InterpolationString' => SInterpolationString.fromJson(json),
    'InterpolationExpression' => SInterpolationExpression.fromJson(json),
    // Patterns - defined in patterns.dart
    'AssignedVariablePattern' => SAssignedVariablePattern.fromJson(json),
    'DeclaredIdentifier' => SDeclaredIdentifier.fromJson(json),
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
    'DeclaredVariablePattern' => SDeclaredVariablePattern.fromJson(json),
    // New clauses
    'ExtensionOnClause' => SExtensionOnClause.fromJson(json),
    'MixinOnClause' => SMixinOnClause.fromJson(json),
    // New declarations
    'BlockClassBody' => SBlockClassBody.fromJson(json),
    'EmptyClassBody' => SEmptyClassBody.fromJson(json),
    'EnumBody' => SEnumBody.fromJson(json),
    'NameWithTypeParameters' => SNameWithTypeParameters.fromJson(json),
    'PrimaryConstructorName' => SPrimaryConstructorName.fromJson(json),
    'PrimaryConstructorDeclaration' => SPrimaryConstructorDeclaration.fromJson(json),
    'PrimaryConstructorBody' => SPrimaryConstructorBody.fromJson(json),
    'RepresentationConstructorName' => SRepresentationConstructorName.fromJson(json),
    // New expressions
    'CommentReference' => SCommentReference.fromJson(json),
    'ConstantContextForExpression' => SConstantContextForExpression.fromJson(json),
    'ConstructorSelector' => SConstructorSelector.fromJson(json),
    'EnumConstantArguments' => SEnumConstantArguments.fromJson(json),
    'ImportPrefixReference' => SImportPrefixReference.fromJson(json),
    _ => throw FormatException('Unknown node type: $type'),
  };
}
