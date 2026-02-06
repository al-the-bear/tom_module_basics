// Serializable AST model for D4rt interpretation
// This is a complete, self-contained serializable AST independent of the analyzer package.
// ignore_for_file: constant_identifier_names

import 'dart:convert';

part 'ast_declarations.dart';
part 'ast_statements.dart';
part 'ast_expressions.dart';
part 'ast_literals.dart';
part 'ast_types.dart';
part 'ast_directives.dart';
part 'ast_misc.dart';

/// Base class for all serializable AST nodes
abstract class SAstNode {
  /// Unique node type identifier for serialization
  String get nodeType;

  /// Source offset of the node
  int get offset;

  /// Length of the source text
  int get length;

  /// Convert to JSON-serializable map
  Map<String, dynamic> toJson();

  /// Serialize to JSON string
  String toJsonString({bool pretty = false}) {
    final encoder =
        pretty ? const JsonEncoder.withIndent('  ') : const JsonEncoder();
    return encoder.convert(toJson());
  }

  /// Get the end offset
  int get end => offset + length;
}

/// Serializable token representation
class SToken {
  final int offset;
  final int length;
  final String lexeme;
  final String tokenType;

  const SToken({
    required this.offset,
    required this.length,
    required this.lexeme,
    required this.tokenType,
  });

  Map<String, dynamic> toJson() => {
        'offset': offset,
        'length': length,
        'lexeme': lexeme,
        'tokenType': tokenType,
      };

  factory SToken.fromJson(Map<String, dynamic> json) {
    return SToken(
      offset: json['offset'] as int,
      length: json['length'] as int,
      lexeme: json['lexeme'] as String,
      tokenType: json['tokenType'] as String,
    );
  }

  @override
  String toString() => 'SToken($lexeme)';
}

/// Factory for deserializing AST nodes
class SAstNodeFactory {
  static final Map<String, SAstNode Function(Map<String, dynamic>)> _factories =
      {};
  static bool _initialized = false;

  /// Register a factory for a node type
  static void register(
      String nodeType, SAstNode Function(Map<String, dynamic>) factory) {
    _factories[nodeType] = factory;
  }

  /// Initialize all factories (called automatically on first use)
  static void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    _registerAllFactories();
  }

  /// Deserialize a node from JSON
  static SAstNode? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    _ensureInitialized();
    final nodeType = json['nodeType'] as String?;
    if (nodeType == null) return null;
    final factory = _factories[nodeType];
    if (factory == null) {
      // Return a generic node for unknown types
      return _SUnknownNode(json);
    }
    return factory(json);
  }

  /// Deserialize a list of nodes from JSON
  static List<T> listFromJson<T extends SAstNode>(List<dynamic>? jsonList) {
    if (jsonList == null) return [];
    return jsonList
        .cast<Map<String, dynamic>>()
        .map((json) => fromJson(json))
        .whereType<T>()
        .toList();
  }
}

/// Placeholder for unknown node types
class _SUnknownNode extends SAstNode {
  final Map<String, dynamic> _json;

  _SUnknownNode(this._json);

  @override
  String get nodeType => _json['nodeType'] as String? ?? 'Unknown';

  @override
  int get offset => _json['offset'] as int? ?? 0;

  @override
  int get length => _json['length'] as int? ?? 0;

  @override
  Map<String, dynamic> toJson() => _json;
}

/// Register all node type factories
void _registerAllFactories() {
  // Compilation unit
  SAstNodeFactory.register('CompilationUnit', SCompilationUnit.fromJson);

  // Declarations
  SAstNodeFactory.register('FunctionDeclaration', SFunctionDeclaration.fromJson);
  SAstNodeFactory.register('MethodDeclaration', SMethodDeclaration.fromJson);
  SAstNodeFactory.register('ClassDeclaration', SClassDeclaration.fromJson);
  SAstNodeFactory.register('MixinDeclaration', SMixinDeclaration.fromJson);
  SAstNodeFactory.register('EnumDeclaration', SEnumDeclaration.fromJson);
  SAstNodeFactory.register('ExtensionDeclaration', SExtensionDeclaration.fromJson);
  SAstNodeFactory.register('VariableDeclaration', SVariableDeclaration.fromJson);
  SAstNodeFactory.register('VariableDeclarationList', SVariableDeclarationList.fromJson);
  SAstNodeFactory.register('FieldDeclaration', SFieldDeclaration.fromJson);
  SAstNodeFactory.register('ConstructorDeclaration', SConstructorDeclaration.fromJson);
  SAstNodeFactory.register('TopLevelVariableDeclaration', STopLevelVariableDeclaration.fromJson);
  SAstNodeFactory.register('TypedefDeclaration', STypedefDeclaration.fromJson);
  SAstNodeFactory.register('EnumConstantDeclaration', SEnumConstantDeclaration.fromJson);

  // Statements
  SAstNodeFactory.register('Block', SBlock.fromJson);
  SAstNodeFactory.register('VariableDeclarationStatement', SVariableDeclarationStatement.fromJson);
  SAstNodeFactory.register('ExpressionStatement', SExpressionStatement.fromJson);
  SAstNodeFactory.register('ReturnStatement', SReturnStatement.fromJson);
  SAstNodeFactory.register('IfStatement', SIfStatement.fromJson);
  SAstNodeFactory.register('ForStatement', SForStatement.fromJson);
  SAstNodeFactory.register('ForPartsWithDeclarations', SForPartsWithDeclarations.fromJson);
  SAstNodeFactory.register('ForPartsWithExpression', SForPartsWithExpression.fromJson);
  SAstNodeFactory.register('ForEachStatement', SForEachStatement.fromJson);
  SAstNodeFactory.register('ForEachPartsWithDeclaration', SForEachPartsWithDeclaration.fromJson);
  SAstNodeFactory.register('ForEachPartsWithIdentifier', SForEachPartsWithIdentifier.fromJson);
  SAstNodeFactory.register('DeclaredIdentifier', SDeclaredIdentifier.fromJson);
  SAstNodeFactory.register('WhileStatement', SWhileStatement.fromJson);
  SAstNodeFactory.register('DoStatement', SDoStatement.fromJson);
  SAstNodeFactory.register('SwitchStatement', SSwitchStatement.fromJson);
  SAstNodeFactory.register('SwitchCase', SSwitchCase.fromJson);
  SAstNodeFactory.register('SwitchDefault', SSwitchDefault.fromJson);
  SAstNodeFactory.register('TryStatement', STryStatement.fromJson);
  SAstNodeFactory.register('CatchClause', SCatchClause.fromJson);
  SAstNodeFactory.register('BreakStatement', SBreakStatement.fromJson);
  SAstNodeFactory.register('ContinueStatement', SContinueStatement.fromJson);
  SAstNodeFactory.register('AssertStatement', SAssertStatement.fromJson);
  SAstNodeFactory.register('YieldStatement', SYieldStatement.fromJson);
  SAstNodeFactory.register('LabeledStatement', SLabeledStatement.fromJson);
  SAstNodeFactory.register('EmptyStatement', SEmptyStatement.fromJson);

  // Expressions
  SAstNodeFactory.register('BinaryExpression', SBinaryExpression.fromJson);
  SAstNodeFactory.register('PrefixExpression', SPrefixExpression.fromJson);
  SAstNodeFactory.register('PostfixExpression', SPostfixExpression.fromJson);
  SAstNodeFactory.register('ConditionalExpression', SConditionalExpression.fromJson);
  SAstNodeFactory.register('AssignmentExpression', SAssignmentExpression.fromJson);
  SAstNodeFactory.register('MethodInvocation', SMethodInvocation.fromJson);
  SAstNodeFactory.register('FunctionExpressionInvocation', SFunctionExpressionInvocation.fromJson);
  SAstNodeFactory.register('IndexExpression', SIndexExpression.fromJson);
  SAstNodeFactory.register('PropertyAccess', SPropertyAccess.fromJson);
  SAstNodeFactory.register('PrefixedIdentifier', SPrefixedIdentifier.fromJson);
  SAstNodeFactory.register('SimpleIdentifier', SSimpleIdentifier.fromJson);
  SAstNodeFactory.register('ParenthesizedExpression', SParenthesizedExpression.fromJson);
  SAstNodeFactory.register('FunctionExpression', SFunctionExpression.fromJson);
  SAstNodeFactory.register('InstanceCreationExpression', SInstanceCreationExpression.fromJson);
  SAstNodeFactory.register('ThisExpression', SThisExpression.fromJson);
  SAstNodeFactory.register('SuperExpression', SSuperExpression.fromJson);
  SAstNodeFactory.register('ThrowExpression', SThrowExpression.fromJson);
  SAstNodeFactory.register('AwaitExpression', SAwaitExpression.fromJson);
  SAstNodeFactory.register('AsExpression', SAsExpression.fromJson);
  SAstNodeFactory.register('IsExpression', SIsExpression.fromJson);
  SAstNodeFactory.register('CascadeExpression', SCascadeExpression.fromJson);
  SAstNodeFactory.register('RethrowExpression', SRethrowExpression.fromJson);
  SAstNodeFactory.register('NamedExpression', SNamedExpression.fromJson);
  SAstNodeFactory.register('SpreadElement', SSpreadElement.fromJson);
  SAstNodeFactory.register('IfElement', SIfElement.fromJson);
  SAstNodeFactory.register('ForElement', SForElement.fromJson);

  // Literals
  SAstNodeFactory.register('IntegerLiteral', SIntegerLiteral.fromJson);
  SAstNodeFactory.register('DoubleLiteral', SDoubleLiteral.fromJson);
  SAstNodeFactory.register('BooleanLiteral', SBooleanLiteral.fromJson);
  SAstNodeFactory.register('SimpleStringLiteral', SSimpleStringLiteral.fromJson);
  SAstNodeFactory.register('StringInterpolation', SStringInterpolation.fromJson);
  SAstNodeFactory.register('AdjacentStrings', SAdjacentStrings.fromJson);
  SAstNodeFactory.register('NullLiteral', SNullLiteral.fromJson);
  SAstNodeFactory.register('ListLiteral', SListLiteral.fromJson);
  SAstNodeFactory.register('SetOrMapLiteral', SSetOrMapLiteral.fromJson);
  SAstNodeFactory.register('MapLiteralEntry', SMapLiteralEntry.fromJson);
  SAstNodeFactory.register('SymbolLiteral', SSymbolLiteral.fromJson);
  SAstNodeFactory.register('InterpolationExpression', SInterpolationExpression.fromJson);
  SAstNodeFactory.register('InterpolationString', SInterpolationString.fromJson);
  SAstNodeFactory.register('RecordLiteral', SRecordLiteral.fromJson);

  // Types
  SAstNodeFactory.register('NamedType', SNamedType.fromJson);
  SAstNodeFactory.register('GenericFunctionType', SGenericFunctionType.fromJson);
  SAstNodeFactory.register('TypeArgumentList', STypeArgumentList.fromJson);
  SAstNodeFactory.register('TypeParameterList', STypeParameterList.fromJson);
  SAstNodeFactory.register('TypeParameter', STypeParameter.fromJson);
  SAstNodeFactory.register('RecordTypeAnnotation', SRecordTypeAnnotation.fromJson);

  // Function-related
  SAstNodeFactory.register('FormalParameterList', SFormalParameterList.fromJson);
  SAstNodeFactory.register('SimpleFormalParameter', SSimpleFormalParameter.fromJson);
  SAstNodeFactory.register('DefaultFormalParameter', SDefaultFormalParameter.fromJson);
  SAstNodeFactory.register('FieldFormalParameter', SFieldFormalParameter.fromJson);
  SAstNodeFactory.register('FunctionTypedFormalParameter', SFunctionTypedFormalParameter.fromJson);
  SAstNodeFactory.register('SuperFormalParameter', SSuperFormalParameter.fromJson);
  SAstNodeFactory.register('BlockFunctionBody', SBlockFunctionBody.fromJson);
  SAstNodeFactory.register('ExpressionFunctionBody', SExpressionFunctionBody.fromJson);
  SAstNodeFactory.register('EmptyFunctionBody', SEmptyFunctionBody.fromJson);
  SAstNodeFactory.register('NativeFunctionBody', SNativeFunctionBody.fromJson);

  // Constructor-related
  SAstNodeFactory.register('ConstructorName', SConstructorName.fromJson);
  SAstNodeFactory.register('SuperConstructorInvocation', SSuperConstructorInvocation.fromJson);
  SAstNodeFactory.register('RedirectingConstructorInvocation', SRedirectingConstructorInvocation.fromJson);
  SAstNodeFactory.register('ConstructorFieldInitializer', SConstructorFieldInitializer.fromJson);
  SAstNodeFactory.register('AssertInitializer', SAssertInitializer.fromJson);

  // Directives
  SAstNodeFactory.register('ImportDirective', SImportDirective.fromJson);
  SAstNodeFactory.register('ExportDirective', SExportDirective.fromJson);
  SAstNodeFactory.register('PartDirective', SPartDirective.fromJson);
  SAstNodeFactory.register('PartOfDirective', SPartOfDirective.fromJson);
  SAstNodeFactory.register('LibraryDirective', SLibraryDirective.fromJson);

  // Misc
  SAstNodeFactory.register('ArgumentList', SArgumentList.fromJson);
  SAstNodeFactory.register('Annotation', SAnnotation.fromJson);
  SAstNodeFactory.register('Comment', SComment.fromJson);
  SAstNodeFactory.register('ShowCombinator', SShowCombinator.fromJson);
  SAstNodeFactory.register('HideCombinator', SHideCombinator.fromJson);
  SAstNodeFactory.register('Label', SLabel.fromJson);
  SAstNodeFactory.register('ExtendsClause', SExtendsClause.fromJson);
  SAstNodeFactory.register('ImplementsClause', SImplementsClause.fromJson);
  SAstNodeFactory.register('WithClause', SWithClause.fromJson);
  SAstNodeFactory.register('OnClause', SOnClause.fromJson);
}

// ============================================================================
// Compilation Unit
// ============================================================================

/// A complete Dart compilation unit (file)
class SCompilationUnit extends SAstNode {
  @override
  final int offset;
  @override
  final int length;

  /// Script tag (e.g., #!/usr/bin/env dart)
  final String? scriptTag;

  /// Directives (imports, exports, parts, library)
  final List<SAstNode> directives;

  /// Declarations (classes, functions, variables, etc.)
  final List<SAstNode> declarations;

  /// Comments in the file
  final List<SComment> comments;

  SCompilationUnit({
    required this.offset,
    required this.length,
    this.scriptTag,
    this.directives = const [],
    this.declarations = const [],
    this.comments = const [],
  });

  @override
  String get nodeType => 'CompilationUnit';

  @override
  Map<String, dynamic> toJson() => {
        'nodeType': nodeType,
        'offset': offset,
        'length': length,
        if (scriptTag != null) 'scriptTag': scriptTag,
        'directives': directives.map((d) => d.toJson()).toList(),
        'declarations': declarations.map((d) => d.toJson()).toList(),
        'comments': comments.map((c) => c.toJson()).toList(),
      };

  factory SCompilationUnit.fromJson(Map<String, dynamic> json) {
    return SCompilationUnit(
      offset: json['offset'] as int,
      length: json['length'] as int,
      scriptTag: json['scriptTag'] as String?,
      directives: SAstNodeFactory.listFromJson(json['directives'] as List?),
      declarations: SAstNodeFactory.listFromJson(json['declarations'] as List?),
      comments: (json['comments'] as List?)
              ?.map((c) => SComment.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
