part of '../ast.dart';

// =============================================================================
// AST VISITOR
// =============================================================================

/// A visitor for AST nodes.
///
/// Clients can extend this class and override specific visit methods
/// to implement custom behavior for different node types.
abstract class SAstVisitor<R> {
  const SAstVisitor();

  // =========================================================================
  // DEFAULT VISITORS
  // =========================================================================

  /// Visits the given [node].
  R? visit(SAstNode node) => node.accept(this);

  /// Visits each of the given [nodes].
  void visitAll(Iterable<SAstNode> nodes) {
    for (final node in nodes) {
      node.accept(this);
    }
  }

  // =========================================================================
  // COMPILATION UNIT
  // =========================================================================

  R? visitCompilationUnit(SCompilationUnit node);

  // =========================================================================
  // DIRECTIVES
  // =========================================================================

  R? visitImportDirective(SImportDirective node);
  R? visitExportDirective(SExportDirective node);
  R? visitLibraryDirective(SLibraryDirective node);
  R? visitLibraryIdentifier(SLibraryIdentifier node);
  R? visitPartDirective(SPartDirective node);
  R? visitPartOfDirective(SPartOfDirective node);
  R? visitConfiguration(SConfiguration node);
  R? visitDottedName(SDottedName node);
  R? visitShowCombinator(SShowCombinator node);
  R? visitHideCombinator(SHideCombinator node);

  // =========================================================================
  // DECLARATIONS
  // =========================================================================

  R? visitClassDeclaration(SClassDeclaration node);
  R? visitEnumDeclaration(SEnumDeclaration node);
  R? visitEnumConstantDeclaration(SEnumConstantDeclaration node);
  R? visitExtensionDeclaration(SExtensionDeclaration node);
  R? visitExtensionTypeRepresentation(SExtensionTypeRepresentation node);
  R? visitMixinDeclaration(SMixinDeclaration node);
  R? visitFunctionDeclaration(SFunctionDeclaration node);
  R? visitTopLevelVariableDeclaration(STopLevelVariableDeclaration node);
  R? visitMethodDeclaration(SMethodDeclaration node);
  R? visitConstructorDeclaration(SConstructorDeclaration node);
  R? visitSuperConstructorInvocation(SSuperConstructorInvocation node);
  R? visitRedirectingConstructorInvocation(
      SRedirectingConstructorInvocation node);
  R? visitConstructorFieldInitializer(SConstructorFieldInitializer node);
  R? visitAssertInitializer(SAssertInitializer node);
  R? visitFieldDeclaration(SFieldDeclaration node);
  R? visitVariableDeclaration(SVariableDeclaration node);
  R? visitVariableDeclarationList(SVariableDeclarationList node);
  R? visitTypeAlias(STypeAlias node);
  R? visitClassTypeAlias(SClassTypeAlias node);
  R? visitFunctionTypeAlias(SFunctionTypeAlias node);
  R? visitGenericTypeAlias(SGenericTypeAlias node);
  R? visitExtensionTypeDeclaration(SExtensionTypeDeclaration node);
  R? visitRepresentationDeclaration(SRepresentationDeclaration node);
  R? visitBlockClassBody(SBlockClassBody node);
  R? visitEmptyClassBody(SEmptyClassBody node);
  R? visitEnumBody(SEnumBody node);
  R? visitNameWithTypeParameters(SNameWithTypeParameters node);
  R? visitPrimaryConstructorName(SPrimaryConstructorName node);
  R? visitPrimaryConstructorDeclaration(SPrimaryConstructorDeclaration node);
  R? visitPrimaryConstructorBody(SPrimaryConstructorBody node);
  R? visitRepresentationConstructorName(SRepresentationConstructorName node);

  // =========================================================================
  // EXPRESSIONS
  // =========================================================================

  R? visitAssignmentExpression(SAssignmentExpression node);
  R? visitAwaitExpression(SAwaitExpression node);
  R? visitBinaryExpression(SBinaryExpression node);
  R? visitCascadeExpression(SCascadeExpression node);
  R? visitConditionalExpression(SConditionalExpression node);
  R? visitFunctionExpression(SFunctionExpression node);
  R? visitFunctionExpressionInvocation(SFunctionExpressionInvocation node);
  R? visitIndexExpression(SIndexExpression node);
  R? visitInstanceCreationExpression(SInstanceCreationExpression node);
  R? visitConstructorName(SConstructorName node);
  R? visitIsExpression(SIsExpression node);
  R? visitAsExpression(SAsExpression node);
  R? visitMethodInvocation(SMethodInvocation node);
  R? visitNamedExpression(SNamedExpression node);
  R? visitLabel(SLabel node);
  R? visitParenthesizedExpression(SParenthesizedExpression node);
  R? visitPostfixExpression(SPostfixExpression node);
  R? visitPrefixExpression(SPrefixExpression node);
  R? visitPropertyAccess(SPropertyAccess node);
  R? visitRethrowExpression(SRethrowExpression node);
  R? visitSuperExpression(SSuperExpression node);
  R? visitThisExpression(SThisExpression node);
  R? visitThrowExpression(SThrowExpression node);
  R? visitConstructorReference(SConstructorReference node);
  R? visitFunctionReference(SFunctionReference node);
  R? visitDotShorthandInvocation(SDotShorthandInvocation node);
  R? visitDotShorthandPropertyAccess(SDotShorthandPropertyAccess node);
  R? visitDotShorthandConstructorInvocation(
      SDotShorthandConstructorInvocation node);
  R? visitExtensionOverride(SExtensionOverride node);
  R? visitImplicitCallReference(SImplicitCallReference node);
  R? visitTypeLiteral(STypeLiteral node);
  R? visitCommentReference(SCommentReference node);
  R? visitConstantContextForExpression(SConstantContextForExpression node);
  R? visitConstructorSelector(SConstructorSelector node);
  R? visitEnumConstantArguments(SEnumConstantArguments node);
  R? visitImportPrefixReference(SImportPrefixReference node);
  R? visitSwitchExpression(SSwitchExpression node);
  R? visitSwitchExpressionCase(SSwitchExpressionCase node);
  R? visitGuardedPattern(SGuardedPattern node);

  // =========================================================================
  // IDENTIFIERS
  // =========================================================================

  R? visitSimpleIdentifier(SSimpleIdentifier node);
  R? visitPrefixedIdentifier(SPrefixedIdentifier node);

  // =========================================================================
  // LITERALS
  // =========================================================================

  R? visitIntegerLiteral(SIntegerLiteral node);
  R? visitDoubleLiteral(SDoubleLiteral node);
  R? visitBooleanLiteral(SBooleanLiteral node);
  R? visitNullLiteral(SNullLiteral node);
  R? visitSimpleStringLiteral(SSimpleStringLiteral node);
  R? visitAdjacentStrings(SAdjacentStrings node);
  R? visitStringInterpolation(SStringInterpolation node);
  R? visitInterpolationString(SInterpolationString node);
  R? visitInterpolationExpression(SInterpolationExpression node);
  R? visitSymbolLiteral(SSymbolLiteral node);
  R? visitListLiteral(SListLiteral node);
  R? visitSetOrMapLiteral(SSetOrMapLiteral node);
  R? visitRecordLiteral(SRecordLiteral node);

  // =========================================================================
  // STATEMENTS
  // =========================================================================

  R? visitBlock(SBlock node);
  R? visitAssertStatement(SAssertStatement node);
  R? visitBreakStatement(SBreakStatement node);
  R? visitContinueStatement(SContinueStatement node);
  R? visitDoStatement(SDoStatement node);
  R? visitEmptyStatement(SEmptyStatement node);
  R? visitExpressionStatement(SExpressionStatement node);
  R? visitForStatement(SForStatement node);
  R? visitForPartsWithDeclarations(SForPartsWithDeclarations node);
  R? visitForPartsWithExpression(SForPartsWithExpression node);
  R? visitForPartsWithPattern(SForPartsWithPattern node);
  R? visitForEachPartsWithDeclaration(SForEachPartsWithDeclaration node);
  R? visitForEachPartsWithIdentifier(SForEachPartsWithIdentifier node);
  R? visitForEachPartsWithPattern(SForEachPartsWithPattern node);
  R? visitFunctionDeclarationStatement(SFunctionDeclarationStatement node);
  R? visitIfStatement(SIfStatement node);
  R? visitCaseClause(SCaseClause node);
  R? visitLabeledStatement(SLabeledStatement node);
  R? visitReturnStatement(SReturnStatement node);
  R? visitSwitchStatement(SSwitchStatement node);
  R? visitSwitchPatternCase(SSwitchPatternCase node);
  R? visitSwitchCase(SSwitchCase node);
  R? visitSwitchDefault(SSwitchDefault node);
  R? visitWhenClause(SWhenClause node);
  R? visitTryStatement(STryStatement node);
  R? visitVariableDeclarationStatement(SVariableDeclarationStatement node);
  R? visitWhileStatement(SWhileStatement node);
  R? visitYieldStatement(SYieldStatement node);
  R? visitPatternVariableDeclarationStatement(
      SPatternVariableDeclarationStatement node);
  R? visitPatternVariableDeclaration(SPatternVariableDeclaration node);
  R? visitPatternAssignment(SPatternAssignment node);

  // =========================================================================
  // TYPES
  // =========================================================================

  R? visitNamedType(SNamedType node);
  R? visitGenericFunctionType(SGenericFunctionType node);
  R? visitRecordTypeAnnotation(SRecordTypeAnnotation node);
  R? visitRecordTypeAnnotationPositionalField(
      SRecordTypeAnnotationPositionalField node);
  R? visitRecordTypeAnnotationNamedFields(SRecordTypeAnnotationNamedFields node);
  R? visitRecordTypeAnnotationNamedField(SRecordTypeAnnotationNamedField node);
  R? visitTypeArgumentList(STypeArgumentList node);
  R? visitTypeParameter(STypeParameter node);
  R? visitTypeParameterList(STypeParameterList node);

  // =========================================================================
  // FUNCTION BODIES
  // =========================================================================

  R? visitBlockFunctionBody(SBlockFunctionBody node);
  R? visitExpressionFunctionBody(SExpressionFunctionBody node);
  R? visitEmptyFunctionBody(SEmptyFunctionBody node);
  R? visitNativeFunctionBody(SNativeFunctionBody node);

  // =========================================================================
  // PARAMETERS
  // =========================================================================

  R? visitFormalParameterList(SFormalParameterList node);
  R? visitSimpleFormalParameter(SSimpleFormalParameter node);
  R? visitDefaultFormalParameter(SDefaultFormalParameter node);
  R? visitFieldFormalParameter(SFieldFormalParameter node);
  R? visitFunctionTypedFormalParameter(SFunctionTypedFormalParameter node);
  R? visitSuperFormalParameter(SSuperFormalParameter node);
  R? visitArgumentList(SArgumentList node);

  // =========================================================================
  // CLAUSES
  // =========================================================================

  R? visitExtendsClause(SExtendsClause node);
  R? visitImplementsClause(SImplementsClause node);
  R? visitWithClause(SWithClause node);
  R? visitOnClause(SOnClause node);
  R? visitExtensionOnClause(SExtensionOnClause node);
  R? visitMixinOnClause(SMixinOnClause node);
  R? visitCatchClause(SCatchClause node);
  R? visitCatchClauseParameter(SCatchClauseParameter node);
  R? visitFinallyClause(SFinallyClause node);
  R? visitNativeClause(SNativeClause node);

  // =========================================================================
  // COLLECTION ELEMENTS
  // =========================================================================

  R? visitForElement(SForElement node);
  R? visitIfElement(SIfElement node);
  R? visitSpreadElement(SSpreadElement node);
  R? visitMapLiteralEntry(SMapLiteralEntry node);
  R? visitRecordField(SRecordField node);
  R? visitExpressionElement(SExpressionElement node);
  R? visitNullAwareElement(SNullAwareElement node);

  // =========================================================================
  // PATTERNS
  // =========================================================================

  R? visitAssignedVariablePattern(SAssignedVariablePattern node);
  R? visitDeclaredVariablePattern(SDeclaredVariablePattern node);
  R? visitDeclaredIdentifier(SDeclaredIdentifier node);
  R? visitWildcardPattern(SWildcardPattern node);
  R? visitConstantPattern(SConstantPattern node);
  R? visitVariablePattern(SVariablePattern node);
  R? visitListPattern(SListPattern node);
  R? visitPatternElement(SPatternElement node);
  R? visitRestPatternElement(SRestPatternElement node);
  R? visitMapPattern(SMapPattern node);
  R? visitMapPatternKeyValue(SMapPatternKeyValue node);
  R? visitMapPatternEntry(SMapPatternEntry node);
  R? visitMapPatternRest(SMapPatternRest node);
  R? visitRecordPattern(SRecordPattern node);
  R? visitPatternField(SPatternField node);
  R? visitPatternFieldName(SPatternFieldName node);
  R? visitObjectPattern(SObjectPattern node);
  R? visitLogicalAndPattern(SLogicalAndPattern node);
  R? visitLogicalOrPattern(SLogicalOrPattern node);
  R? visitCastPattern(SCastPattern node);
  R? visitNullCheckPattern(SNullCheckPattern node);
  R? visitNullAssertPattern(SNullAssertPattern node);
  R? visitParenthesizedPattern(SParenthesizedPattern node);
  R? visitRelationalPattern(SRelationalPattern node);

  // =========================================================================
  // MISCELLANEOUS
  // =========================================================================

  R? visitAnnotation(SAnnotation node);
  R? visitComment(SComment node);
  R? visitScriptTag(SScriptTag node);
}

// =============================================================================
// SIMPLE AST VISITOR (with default null returns)
// =============================================================================

/// A visitor that returns null for all nodes by default.
///
/// Clients can extend this class and override only the visit methods
/// they need.
class SimpleAstVisitor<R> extends SAstVisitor<R> {
  const SimpleAstVisitor();

  @override
  R? visitCompilationUnit(SCompilationUnit node) => null;

  // Directives
  @override
  R? visitImportDirective(SImportDirective node) => null;
  @override
  R? visitExportDirective(SExportDirective node) => null;
  @override
  R? visitLibraryDirective(SLibraryDirective node) => null;
  @override
  R? visitLibraryIdentifier(SLibraryIdentifier node) => null;
  @override
  R? visitPartDirective(SPartDirective node) => null;
  @override
  R? visitPartOfDirective(SPartOfDirective node) => null;
  @override
  R? visitConfiguration(SConfiguration node) => null;
  @override
  R? visitDottedName(SDottedName node) => null;
  @override
  R? visitShowCombinator(SShowCombinator node) => null;
  @override
  R? visitHideCombinator(SHideCombinator node) => null;

  // Declarations
  @override
  R? visitClassDeclaration(SClassDeclaration node) => null;
  @override
  R? visitEnumDeclaration(SEnumDeclaration node) => null;
  @override
  R? visitEnumConstantDeclaration(SEnumConstantDeclaration node) => null;
  @override
  R? visitExtensionDeclaration(SExtensionDeclaration node) => null;
  @override
  R? visitExtensionTypeRepresentation(SExtensionTypeRepresentation node) =>
      null;
  @override
  R? visitMixinDeclaration(SMixinDeclaration node) => null;
  @override
  R? visitFunctionDeclaration(SFunctionDeclaration node) => null;
  @override
  R? visitTopLevelVariableDeclaration(STopLevelVariableDeclaration node) =>
      null;
  @override
  R? visitMethodDeclaration(SMethodDeclaration node) => null;
  @override
  R? visitConstructorDeclaration(SConstructorDeclaration node) => null;
  @override
  R? visitSuperConstructorInvocation(SSuperConstructorInvocation node) => null;
  @override
  R? visitRedirectingConstructorInvocation(
          SRedirectingConstructorInvocation node) =>
      null;
  @override
  R? visitConstructorFieldInitializer(SConstructorFieldInitializer node) =>
      null;
  @override
  R? visitAssertInitializer(SAssertInitializer node) => null;
  @override
  R? visitFieldDeclaration(SFieldDeclaration node) => null;
  @override
  R? visitVariableDeclaration(SVariableDeclaration node) => null;
  @override
  R? visitVariableDeclarationList(SVariableDeclarationList node) => null;
  @override
  R? visitTypeAlias(STypeAlias node) => null;
  @override
  R? visitClassTypeAlias(SClassTypeAlias node) => null;
  @override
  R? visitFunctionTypeAlias(SFunctionTypeAlias node) => null;
  @override
  R? visitGenericTypeAlias(SGenericTypeAlias node) => null;
  @override
  R? visitExtensionTypeDeclaration(SExtensionTypeDeclaration node) => null;
  @override
  R? visitRepresentationDeclaration(SRepresentationDeclaration node) => null;
  @override
  R? visitBlockClassBody(SBlockClassBody node) => null;
  @override
  R? visitEmptyClassBody(SEmptyClassBody node) => null;
  @override
  R? visitEnumBody(SEnumBody node) => null;
  @override
  R? visitNameWithTypeParameters(SNameWithTypeParameters node) => null;
  @override
  R? visitPrimaryConstructorName(SPrimaryConstructorName node) => null;
  @override
  R? visitPrimaryConstructorDeclaration(SPrimaryConstructorDeclaration node) =>
      null;
  @override
  R? visitPrimaryConstructorBody(SPrimaryConstructorBody node) => null;
  @override
  R? visitRepresentationConstructorName(SRepresentationConstructorName node) =>
      null;

  // Expressions
  @override
  R? visitAssignmentExpression(SAssignmentExpression node) => null;
  @override
  R? visitAwaitExpression(SAwaitExpression node) => null;
  @override
  R? visitBinaryExpression(SBinaryExpression node) => null;
  @override
  R? visitCascadeExpression(SCascadeExpression node) => null;
  @override
  R? visitConditionalExpression(SConditionalExpression node) => null;
  @override
  R? visitFunctionExpression(SFunctionExpression node) => null;
  @override
  R? visitFunctionExpressionInvocation(SFunctionExpressionInvocation node) =>
      null;
  @override
  R? visitIndexExpression(SIndexExpression node) => null;
  @override
  R? visitInstanceCreationExpression(SInstanceCreationExpression node) => null;
  @override
  R? visitConstructorName(SConstructorName node) => null;
  @override
  R? visitIsExpression(SIsExpression node) => null;
  @override
  R? visitAsExpression(SAsExpression node) => null;
  @override
  R? visitMethodInvocation(SMethodInvocation node) => null;
  @override
  R? visitNamedExpression(SNamedExpression node) => null;
  @override
  R? visitLabel(SLabel node) => null;
  @override
  R? visitParenthesizedExpression(SParenthesizedExpression node) => null;
  @override
  R? visitPostfixExpression(SPostfixExpression node) => null;
  @override
  R? visitPrefixExpression(SPrefixExpression node) => null;
  @override
  R? visitPropertyAccess(SPropertyAccess node) => null;
  @override
  R? visitRethrowExpression(SRethrowExpression node) => null;
  @override
  R? visitSuperExpression(SSuperExpression node) => null;
  @override
  R? visitThisExpression(SThisExpression node) => null;
  @override
  R? visitThrowExpression(SThrowExpression node) => null;
  @override
  R? visitConstructorReference(SConstructorReference node) => null;
  @override
  R? visitFunctionReference(SFunctionReference node) => null;
  @override
  R? visitDotShorthandInvocation(SDotShorthandInvocation node) => null;
  @override
  R? visitDotShorthandPropertyAccess(SDotShorthandPropertyAccess node) => null;
  @override
  R? visitDotShorthandConstructorInvocation(
          SDotShorthandConstructorInvocation node) =>
      null;
  @override
  R? visitExtensionOverride(SExtensionOverride node) => null;
  @override
  R? visitImplicitCallReference(SImplicitCallReference node) => null;
  @override
  R? visitTypeLiteral(STypeLiteral node) => null;
  @override
  R? visitCommentReference(SCommentReference node) => null;
  @override
  R? visitConstantContextForExpression(
          SConstantContextForExpression node) =>
      null;
  @override
  R? visitConstructorSelector(SConstructorSelector node) => null;
  @override
  R? visitEnumConstantArguments(SEnumConstantArguments node) => null;
  @override
  R? visitImportPrefixReference(SImportPrefixReference node) => null;
  @override
  R? visitSwitchExpression(SSwitchExpression node) => null;
  @override
  R? visitSwitchExpressionCase(SSwitchExpressionCase node) => null;
  @override
  R? visitGuardedPattern(SGuardedPattern node) => null;

  // Identifiers
  @override
  R? visitSimpleIdentifier(SSimpleIdentifier node) => null;
  @override
  R? visitPrefixedIdentifier(SPrefixedIdentifier node) => null;

  // Literals
  @override
  R? visitIntegerLiteral(SIntegerLiteral node) => null;
  @override
  R? visitDoubleLiteral(SDoubleLiteral node) => null;
  @override
  R? visitBooleanLiteral(SBooleanLiteral node) => null;
  @override
  R? visitNullLiteral(SNullLiteral node) => null;
  @override
  R? visitSimpleStringLiteral(SSimpleStringLiteral node) => null;
  @override
  R? visitAdjacentStrings(SAdjacentStrings node) => null;
  @override
  R? visitStringInterpolation(SStringInterpolation node) => null;
  @override
  R? visitInterpolationString(SInterpolationString node) => null;
  @override
  R? visitInterpolationExpression(SInterpolationExpression node) => null;
  @override
  R? visitSymbolLiteral(SSymbolLiteral node) => null;
  @override
  R? visitListLiteral(SListLiteral node) => null;
  @override
  R? visitSetOrMapLiteral(SSetOrMapLiteral node) => null;
  @override
  R? visitRecordLiteral(SRecordLiteral node) => null;

  // Statements
  @override
  R? visitBlock(SBlock node) => null;
  @override
  R? visitAssertStatement(SAssertStatement node) => null;
  @override
  R? visitBreakStatement(SBreakStatement node) => null;
  @override
  R? visitContinueStatement(SContinueStatement node) => null;
  @override
  R? visitDoStatement(SDoStatement node) => null;
  @override
  R? visitEmptyStatement(SEmptyStatement node) => null;
  @override
  R? visitExpressionStatement(SExpressionStatement node) => null;
  @override
  R? visitForStatement(SForStatement node) => null;
  @override
  R? visitForPartsWithDeclarations(SForPartsWithDeclarations node) => null;
  @override
  R? visitForPartsWithExpression(SForPartsWithExpression node) => null;
  @override
  R? visitForPartsWithPattern(SForPartsWithPattern node) => null;
  @override
  R? visitForEachPartsWithDeclaration(SForEachPartsWithDeclaration node) =>
      null;
  @override
  R? visitForEachPartsWithIdentifier(SForEachPartsWithIdentifier node) => null;
  @override
  R? visitForEachPartsWithPattern(SForEachPartsWithPattern node) => null;
  @override
  R? visitFunctionDeclarationStatement(SFunctionDeclarationStatement node) =>
      null;
  @override
  R? visitIfStatement(SIfStatement node) => null;
  @override
  R? visitCaseClause(SCaseClause node) => null;
  @override
  R? visitLabeledStatement(SLabeledStatement node) => null;
  @override
  R? visitReturnStatement(SReturnStatement node) => null;
  @override
  R? visitSwitchStatement(SSwitchStatement node) => null;
  @override
  R? visitSwitchPatternCase(SSwitchPatternCase node) => null;
  @override
  R? visitSwitchCase(SSwitchCase node) => null;
  @override
  R? visitSwitchDefault(SSwitchDefault node) => null;
  @override
  R? visitWhenClause(SWhenClause node) => null;
  @override
  R? visitTryStatement(STryStatement node) => null;
  @override
  R? visitVariableDeclarationStatement(SVariableDeclarationStatement node) =>
      null;
  @override
  R? visitWhileStatement(SWhileStatement node) => null;
  @override
  R? visitYieldStatement(SYieldStatement node) => null;
  @override
  R? visitPatternVariableDeclarationStatement(
          SPatternVariableDeclarationStatement node) =>
      null;
  @override
  R? visitPatternVariableDeclaration(SPatternVariableDeclaration node) => null;
  @override
  R? visitPatternAssignment(SPatternAssignment node) => null;

  // Types
  @override
  R? visitNamedType(SNamedType node) => null;
  @override
  R? visitGenericFunctionType(SGenericFunctionType node) => null;
  @override
  R? visitRecordTypeAnnotation(SRecordTypeAnnotation node) => null;
  @override
  R? visitRecordTypeAnnotationPositionalField(
          SRecordTypeAnnotationPositionalField node) =>
      null;
  @override
  R? visitRecordTypeAnnotationNamedFields(
          SRecordTypeAnnotationNamedFields node) =>
      null;
  @override
  R? visitRecordTypeAnnotationNamedField(
          SRecordTypeAnnotationNamedField node) =>
      null;
  @override
  R? visitTypeArgumentList(STypeArgumentList node) => null;
  @override
  R? visitTypeParameter(STypeParameter node) => null;
  @override
  R? visitTypeParameterList(STypeParameterList node) => null;

  // Function bodies
  @override
  R? visitBlockFunctionBody(SBlockFunctionBody node) => null;
  @override
  R? visitExpressionFunctionBody(SExpressionFunctionBody node) => null;
  @override
  R? visitEmptyFunctionBody(SEmptyFunctionBody node) => null;
  @override
  R? visitNativeFunctionBody(SNativeFunctionBody node) => null;

  // Parameters
  @override
  R? visitFormalParameterList(SFormalParameterList node) => null;
  @override
  R? visitSimpleFormalParameter(SSimpleFormalParameter node) => null;
  @override
  R? visitDefaultFormalParameter(SDefaultFormalParameter node) => null;
  @override
  R? visitFieldFormalParameter(SFieldFormalParameter node) => null;
  @override
  R? visitFunctionTypedFormalParameter(SFunctionTypedFormalParameter node) =>
      null;
  @override
  R? visitSuperFormalParameter(SSuperFormalParameter node) => null;
  @override
  R? visitArgumentList(SArgumentList node) => null;

  // Clauses
  @override
  R? visitExtendsClause(SExtendsClause node) => null;
  @override
  R? visitImplementsClause(SImplementsClause node) => null;
  @override
  R? visitWithClause(SWithClause node) => null;
  @override
  R? visitOnClause(SOnClause node) => null;
  @override
  R? visitExtensionOnClause(SExtensionOnClause node) => null;
  @override
  R? visitMixinOnClause(SMixinOnClause node) => null;
  @override
  R? visitCatchClause(SCatchClause node) => null;
  @override
  R? visitCatchClauseParameter(SCatchClauseParameter node) => null;
  @override
  R? visitFinallyClause(SFinallyClause node) => null;
  @override
  R? visitNativeClause(SNativeClause node) => null;

  // Collection elements
  @override
  R? visitForElement(SForElement node) => null;
  @override
  R? visitIfElement(SIfElement node) => null;
  @override
  R? visitSpreadElement(SSpreadElement node) => null;
  @override
  R? visitMapLiteralEntry(SMapLiteralEntry node) => null;
  @override
  R? visitRecordField(SRecordField node) => null;
  @override
  R? visitExpressionElement(SExpressionElement node) => null;
  @override
  R? visitNullAwareElement(SNullAwareElement node) => null;

  // Patterns
  @override
  R? visitAssignedVariablePattern(SAssignedVariablePattern node) => null;
  @override
  R? visitDeclaredVariablePattern(SDeclaredVariablePattern node) => null;
  @override
  R? visitDeclaredIdentifier(SDeclaredIdentifier node) => null;
  @override
  R? visitWildcardPattern(SWildcardPattern node) => null;
  @override
  R? visitConstantPattern(SConstantPattern node) => null;
  @override
  R? visitVariablePattern(SVariablePattern node) => null;
  @override
  R? visitListPattern(SListPattern node) => null;
  @override
  R? visitPatternElement(SPatternElement node) => null;
  @override
  R? visitRestPatternElement(SRestPatternElement node) => null;
  @override
  R? visitMapPattern(SMapPattern node) => null;
  @override
  R? visitMapPatternKeyValue(SMapPatternKeyValue node) => null;
  @override
  R? visitMapPatternEntry(SMapPatternEntry node) => null;
  @override
  R? visitMapPatternRest(SMapPatternRest node) => null;
  @override
  R? visitRecordPattern(SRecordPattern node) => null;
  @override
  R? visitPatternField(SPatternField node) => null;
  @override
  R? visitPatternFieldName(SPatternFieldName node) => null;
  @override
  R? visitObjectPattern(SObjectPattern node) => null;
  @override
  R? visitLogicalAndPattern(SLogicalAndPattern node) => null;
  @override
  R? visitLogicalOrPattern(SLogicalOrPattern node) => null;
  @override
  R? visitCastPattern(SCastPattern node) => null;
  @override
  R? visitNullCheckPattern(SNullCheckPattern node) => null;
  @override
  R? visitNullAssertPattern(SNullAssertPattern node) => null;
  @override
  R? visitParenthesizedPattern(SParenthesizedPattern node) => null;
  @override
  R? visitRelationalPattern(SRelationalPattern node) => null;

  // Miscellaneous
  @override
  R? visitAnnotation(SAnnotation node) => null;
  @override
  R? visitComment(SComment node) => null;
  @override
  R? visitScriptTag(SScriptTag node) => null;
}

// =============================================================================
// RECURSIVE AST VISITOR
// =============================================================================

/// A visitor that recursively visits all nodes in the AST.
///
/// Subclasses can override visit methods to add custom behavior.
/// Call super.visitXxx(node) to continue the recursive traversal.
class RecursiveAstVisitor<R> extends SAstVisitor<R> {
  const RecursiveAstVisitor();

  @override
  R? visitCompilationUnit(SCompilationUnit node) {
    node.scriptTag?.accept(this);
    visitAll(node.directives);
    visitAll(node.declarations);
    return null;
  }

  // Directives
  @override
  R? visitImportDirective(SImportDirective node) {
    visitAll(node.metadata);
    node.uri.accept(this);
    visitAll(node.configurations);
    node.prefix?.accept(this);
    visitAll(node.combinators);
    return null;
  }

  @override
  R? visitExportDirective(SExportDirective node) {
    visitAll(node.metadata);
    node.uri.accept(this);
    visitAll(node.configurations);
    visitAll(node.combinators);
    return null;
  }

  @override
  R? visitLibraryDirective(SLibraryDirective node) {
    visitAll(node.metadata);
    node.name?.accept(this);
    return null;
  }

  @override
  R? visitLibraryIdentifier(SLibraryIdentifier node) {
    visitAll(node.components);
    return null;
  }

  @override
  R? visitPartDirective(SPartDirective node) {
    visitAll(node.metadata);
    node.uri.accept(this);
    return null;
  }

  @override
  R? visitPartOfDirective(SPartOfDirective node) {
    visitAll(node.metadata);
    node.libraryName?.accept(this);
    node.uri?.accept(this);
    return null;
  }

  @override
  R? visitConfiguration(SConfiguration node) {
    node.name.accept(this);
    node.value?.accept(this);
    node.uri.accept(this);
    return null;
  }

  @override
  R? visitDottedName(SDottedName node) {
    visitAll(node.components);
    return null;
  }

  @override
  R? visitShowCombinator(SShowCombinator node) {
    visitAll(node.shownNames);
    return null;
  }

  @override
  R? visitHideCombinator(SHideCombinator node) {
    visitAll(node.hiddenNames);
    return null;
  }

  // Declarations
  @override
  R? visitClassDeclaration(SClassDeclaration node) {
    visitAll(node.metadata);
    node.name.accept(this);
    node.typeParameters?.accept(this);
    node.extendsClause?.accept(this);
    node.withClause?.accept(this);
    node.implementsClause?.accept(this);
    visitAll(node.members);
    return null;
  }

  @override
  R? visitEnumDeclaration(SEnumDeclaration node) {
    visitAll(node.metadata);
    node.name.accept(this);
    node.typeParameters?.accept(this);
    node.withClause?.accept(this);
    node.implementsClause?.accept(this);
    visitAll(node.constants);
    visitAll(node.members);
    return null;
  }

  @override
  R? visitEnumConstantDeclaration(SEnumConstantDeclaration node) {
    visitAll(node.metadata);
    node.name.accept(this);
    node.typeArguments?.accept(this);
    node.arguments?.accept(this);
    return null;
  }

  @override
  R? visitExtensionDeclaration(SExtensionDeclaration node) {
    visitAll(node.metadata);
    node.name?.accept(this);
    node.typeParameters?.accept(this);
    node.extendedType?.accept(this);
    node.representation?.accept(this);
    node.implementsClause?.accept(this);
    visitAll(node.members);
    return null;
  }

  @override
  R? visitExtensionTypeRepresentation(SExtensionTypeRepresentation node) {
    node.fieldDeclaration.accept(this);
    return null;
  }

  @override
  R? visitMixinDeclaration(SMixinDeclaration node) {
    visitAll(node.metadata);
    node.name.accept(this);
    node.typeParameters?.accept(this);
    node.onClause?.accept(this);
    node.implementsClause?.accept(this);
    visitAll(node.members);
    return null;
  }

  @override
  R? visitFunctionDeclaration(SFunctionDeclaration node) {
    visitAll(node.metadata);
    node.returnType?.accept(this);
    node.name.accept(this);
    node.functionExpression.accept(this);
    return null;
  }

  @override
  R? visitTopLevelVariableDeclaration(STopLevelVariableDeclaration node) {
    visitAll(node.metadata);
    node.variables.accept(this);
    return null;
  }

  @override
  R? visitMethodDeclaration(SMethodDeclaration node) {
    visitAll(node.metadata);
    node.returnType?.accept(this);
    node.name.accept(this);
    node.typeParameters?.accept(this);
    node.parameters?.accept(this);
    node.body.accept(this);
    return null;
  }

  @override
  R? visitConstructorDeclaration(SConstructorDeclaration node) {
    visitAll(node.metadata);
    node.returnType.accept(this);
    node.name?.accept(this);
    node.parameters.accept(this);
    visitAll(node.initializers);
    node.redirectedConstructor?.accept(this);
    node.body.accept(this);
    return null;
  }

  @override
  R? visitSuperConstructorInvocation(SSuperConstructorInvocation node) {
    node.constructorName?.accept(this);
    node.argumentList.accept(this);
    return null;
  }

  @override
  R? visitRedirectingConstructorInvocation(
      SRedirectingConstructorInvocation node) {
    node.constructorName?.accept(this);
    node.argumentList.accept(this);
    return null;
  }

  @override
  R? visitConstructorFieldInitializer(SConstructorFieldInitializer node) {
    node.fieldName.accept(this);
    node.expression.accept(this);
    return null;
  }

  @override
  R? visitAssertInitializer(SAssertInitializer node) {
    node.condition.accept(this);
    node.message?.accept(this);
    return null;
  }

  @override
  R? visitFieldDeclaration(SFieldDeclaration node) {
    visitAll(node.metadata);
    node.fields.accept(this);
    return null;
  }

  @override
  R? visitVariableDeclaration(SVariableDeclaration node) {
    node.name.accept(this);
    node.initializer?.accept(this);
    return null;
  }

  @override
  R? visitVariableDeclarationList(SVariableDeclarationList node) {
    visitAll(node.metadata);
    node.type?.accept(this);
    visitAll(node.variables);
    return null;
  }

  @override
  R? visitTypeAlias(STypeAlias node) {
    visitAll(node.metadata);
    node.name.accept(this);
    node.typeParameters?.accept(this);
    node.type.accept(this);
    return null;
  }

  @override
  R? visitClassTypeAlias(SClassTypeAlias node) {
    visitAll(node.metadata);
    node.name.accept(this);
    node.typeParameters?.accept(this);
    node.superclass.accept(this);
    node.withClause.accept(this);
    node.implementsClause?.accept(this);
    return null;
  }

  @override
  R? visitFunctionTypeAlias(SFunctionTypeAlias node) {
    visitAll(node.metadata);
    node.returnType?.accept(this);
    node.name.accept(this);
    node.typeParameters?.accept(this);
    node.parameters.accept(this);
    return null;
  }

  @override
  R? visitGenericTypeAlias(SGenericTypeAlias node) {
    visitAll(node.metadata);
    node.name.accept(this);
    node.typeParameters?.accept(this);
    node.type.accept(this);
    return null;
  }

  @override
  R? visitExtensionTypeDeclaration(SExtensionTypeDeclaration node) {
    visitAll(node.metadata);
    node.name.accept(this);
    node.typeParameters?.accept(this);
    node.representation.accept(this);
    node.implementsClause?.accept(this);
    visitAll(node.members);
    return null;
  }

  @override
  R? visitRepresentationDeclaration(SRepresentationDeclaration node) {
    node.fieldType.accept(this);
    node.fieldName.accept(this);
    return null;
  }

  @override
  R? visitBlockClassBody(SBlockClassBody node) {
    visitAll(node.members);
    return null;
  }

  @override
  R? visitEmptyClassBody(SEmptyClassBody node) => null;

  @override
  R? visitEnumBody(SEnumBody node) {
    visitAll(node.constants);
    visitAll(node.members);
    return null;
  }

  @override
  R? visitNameWithTypeParameters(SNameWithTypeParameters node) {
    node.typeParameters?.accept(this);
    return null;
  }

  @override
  R? visitPrimaryConstructorName(SPrimaryConstructorName node) => null;

  @override
  R? visitPrimaryConstructorDeclaration(SPrimaryConstructorDeclaration node) {
    node.typeParameters?.accept(this);
    node.constructorName?.accept(this);
    node.formalParameters.accept(this);
    return null;
  }

  @override
  R? visitPrimaryConstructorBody(SPrimaryConstructorBody node) {
    visitAll(node.initializers);
    node.body.accept(this);
    return null;
  }

  @override
  R? visitRepresentationConstructorName(SRepresentationConstructorName node) =>
      null;

  // Expressions
  @override
  R? visitAssignmentExpression(SAssignmentExpression node) {
    node.leftHandSide.accept(this);
    node.rightHandSide.accept(this);
    return null;
  }

  @override
  R? visitAwaitExpression(SAwaitExpression node) {
    node.expression.accept(this);
    return null;
  }

  @override
  R? visitBinaryExpression(SBinaryExpression node) {
    node.leftOperand.accept(this);
    node.rightOperand.accept(this);
    return null;
  }

  @override
  R? visitCascadeExpression(SCascadeExpression node) {
    node.target.accept(this);
    visitAll(node.cascadeSections);
    return null;
  }

  @override
  R? visitConditionalExpression(SConditionalExpression node) {
    node.condition.accept(this);
    node.thenExpression.accept(this);
    node.elseExpression.accept(this);
    return null;
  }

  @override
  R? visitFunctionExpression(SFunctionExpression node) {
    node.typeParameters?.accept(this);
    node.parameters.accept(this);
    node.body.accept(this);
    return null;
  }

  @override
  R? visitFunctionExpressionInvocation(SFunctionExpressionInvocation node) {
    node.function.accept(this);
    node.typeArguments?.accept(this);
    node.argumentList.accept(this);
    return null;
  }

  @override
  R? visitIndexExpression(SIndexExpression node) {
    node.target?.accept(this);
    node.index.accept(this);
    return null;
  }

  @override
  R? visitInstanceCreationExpression(SInstanceCreationExpression node) {
    node.constructorName.accept(this);
    node.argumentList.accept(this);
    return null;
  }

  @override
  R? visitConstructorName(SConstructorName node) {
    node.type.accept(this);
    node.name?.accept(this);
    return null;
  }

  @override
  R? visitIsExpression(SIsExpression node) {
    node.expression.accept(this);
    node.type.accept(this);
    return null;
  }

  @override
  R? visitAsExpression(SAsExpression node) {
    node.expression.accept(this);
    node.type.accept(this);
    return null;
  }

  @override
  R? visitMethodInvocation(SMethodInvocation node) {
    node.target?.accept(this);
    node.methodName.accept(this);
    node.typeArguments?.accept(this);
    node.argumentList.accept(this);
    return null;
  }

  @override
  R? visitNamedExpression(SNamedExpression node) {
    node.name.accept(this);
    node.expression.accept(this);
    return null;
  }

  @override
  R? visitLabel(SLabel node) {
    node.label.accept(this);
    return null;
  }

  @override
  R? visitParenthesizedExpression(SParenthesizedExpression node) {
    node.expression.accept(this);
    return null;
  }

  @override
  R? visitPostfixExpression(SPostfixExpression node) {
    node.operand.accept(this);
    return null;
  }

  @override
  R? visitPrefixExpression(SPrefixExpression node) {
    node.operand.accept(this);
    return null;
  }

  @override
  R? visitPropertyAccess(SPropertyAccess node) {
    node.target?.accept(this);
    node.propertyName.accept(this);
    return null;
  }

  @override
  R? visitRethrowExpression(SRethrowExpression node) => null;

  @override
  R? visitSuperExpression(SSuperExpression node) => null;

  @override
  R? visitThisExpression(SThisExpression node) => null;

  @override
  R? visitThrowExpression(SThrowExpression node) {
    node.expression.accept(this);
    return null;
  }

  @override
  R? visitConstructorReference(SConstructorReference node) {
    node.constructorName.accept(this);
    return null;
  }

  @override
  R? visitFunctionReference(SFunctionReference node) {
    node.function.accept(this);
    node.typeArguments?.accept(this);
    return null;
  }

  @override
  R? visitDotShorthandInvocation(SDotShorthandInvocation node) {
    node.memberName.accept(this);
    node.typeArguments?.accept(this);
    node.argumentList.accept(this);
    return null;
  }

  @override
  R? visitDotShorthandPropertyAccess(SDotShorthandPropertyAccess node) {
    node.propertyName.accept(this);
    return null;
  }

  @override
  R? visitDotShorthandConstructorInvocation(
      SDotShorthandConstructorInvocation node) {
    node.constructorName.accept(this);
    node.typeArguments?.accept(this);
    node.argumentList.accept(this);
    return null;
  }

  @override
  R? visitExtensionOverride(SExtensionOverride node) {
    node.extensionName.accept(this);
    node.typeArguments?.accept(this);
    node.argumentList.accept(this);
    return null;
  }

  @override
  R? visitImplicitCallReference(SImplicitCallReference node) {
    node.expression.accept(this);
    node.typeArguments?.accept(this);
    return null;
  }

  @override
  R? visitTypeLiteral(STypeLiteral node) {
    node.typeName.accept(this);
    return null;
  }

  @override
  R? visitCommentReference(SCommentReference node) {
    node.expression.accept(this);
    return null;
  }

  @override
  R? visitConstantContextForExpression(SConstantContextForExpression node) {
    node.expression.accept(this);
    return null;
  }

  @override
  R? visitConstructorSelector(SConstructorSelector node) {
    node.name.accept(this);
    return null;
  }

  @override
  R? visitEnumConstantArguments(SEnumConstantArguments node) {
    node.typeArguments?.accept(this);
    node.constructorSelector?.accept(this);
    node.argumentList.accept(this);
    return null;
  }

  @override
  R? visitImportPrefixReference(SImportPrefixReference node) => null;

  @override
  R? visitSwitchExpression(SSwitchExpression node) {
    node.expression.accept(this);
    visitAll(node.cases);
    return null;
  }

  @override
  R? visitSwitchExpressionCase(SSwitchExpressionCase node) {
    node.guardedPattern.accept(this);
    node.expression.accept(this);
    return null;
  }

  @override
  R? visitGuardedPattern(SGuardedPattern node) {
    node.pattern.accept(this);
    node.guard?.accept(this);
    return null;
  }

  // Identifiers
  @override
  R? visitSimpleIdentifier(SSimpleIdentifier node) => null;

  @override
  R? visitPrefixedIdentifier(SPrefixedIdentifier node) {
    node.prefix.accept(this);
    node.identifier.accept(this);
    return null;
  }

  // Literals
  @override
  R? visitIntegerLiteral(SIntegerLiteral node) => null;

  @override
  R? visitDoubleLiteral(SDoubleLiteral node) => null;

  @override
  R? visitBooleanLiteral(SBooleanLiteral node) => null;

  @override
  R? visitNullLiteral(SNullLiteral node) => null;

  @override
  R? visitSimpleStringLiteral(SSimpleStringLiteral node) => null;

  @override
  R? visitAdjacentStrings(SAdjacentStrings node) {
    visitAll(node.strings);
    return null;
  }

  @override
  R? visitStringInterpolation(SStringInterpolation node) {
    visitAll(node.elements);
    return null;
  }

  @override
  R? visitInterpolationString(SInterpolationString node) => null;

  @override
  R? visitInterpolationExpression(SInterpolationExpression node) {
    node.expression.accept(this);
    return null;
  }

  @override
  R? visitSymbolLiteral(SSymbolLiteral node) => null;

  @override
  R? visitListLiteral(SListLiteral node) {
    node.typeArguments?.accept(this);
    visitAll(node.elements);
    return null;
  }

  @override
  R? visitSetOrMapLiteral(SSetOrMapLiteral node) {
    node.typeArguments?.accept(this);
    visitAll(node.elements);
    return null;
  }

  @override
  R? visitRecordLiteral(SRecordLiteral node) {
    visitAll(node.fields);
    return null;
  }

  // Statements
  @override
  R? visitBlock(SBlock node) {
    visitAll(node.statements);
    return null;
  }

  @override
  R? visitAssertStatement(SAssertStatement node) {
    node.condition.accept(this);
    node.message?.accept(this);
    return null;
  }

  @override
  R? visitBreakStatement(SBreakStatement node) {
    node.label?.accept(this);
    return null;
  }

  @override
  R? visitContinueStatement(SContinueStatement node) {
    node.label?.accept(this);
    return null;
  }

  @override
  R? visitDoStatement(SDoStatement node) {
    node.body.accept(this);
    node.condition.accept(this);
    return null;
  }

  @override
  R? visitEmptyStatement(SEmptyStatement node) => null;

  @override
  R? visitExpressionStatement(SExpressionStatement node) {
    node.expression.accept(this);
    return null;
  }

  @override
  R? visitForStatement(SForStatement node) {
    node.forLoopParts.accept(this);
    node.body.accept(this);
    return null;
  }

  @override
  R? visitForPartsWithDeclarations(SForPartsWithDeclarations node) {
    node.variables.accept(this);
    node.condition?.accept(this);
    visitAll(node.updaters);
    return null;
  }

  @override
  R? visitForPartsWithExpression(SForPartsWithExpression node) {
    node.initialization?.accept(this);
    node.condition?.accept(this);
    visitAll(node.updaters);
    return null;
  }

  @override
  R? visitForPartsWithPattern(SForPartsWithPattern node) {
    node.variables.accept(this);
    node.condition?.accept(this);
    visitAll(node.updaters);
    return null;
  }

  @override
  R? visitForEachPartsWithDeclaration(SForEachPartsWithDeclaration node) {
    node.loopVariable.accept(this);
    node.iterable.accept(this);
    return null;
  }

  @override
  R? visitForEachPartsWithIdentifier(SForEachPartsWithIdentifier node) {
    node.identifier.accept(this);
    node.iterable.accept(this);
    return null;
  }

  @override
  R? visitForEachPartsWithPattern(SForEachPartsWithPattern node) {
    visitAll(node.metadata);
    node.pattern.accept(this);
    node.iterable.accept(this);
    return null;
  }

  @override
  R? visitFunctionDeclarationStatement(SFunctionDeclarationStatement node) {
    node.functionDeclaration.accept(this);
    return null;
  }

  @override
  R? visitIfStatement(SIfStatement node) {
    node.expression?.accept(this);
    node.caseClause?.accept(this);
    node.thenStatement.accept(this);
    node.elseStatement?.accept(this);
    return null;
  }

  @override
  R? visitCaseClause(SCaseClause node) {
    node.guardedPattern.accept(this);
    return null;
  }

  @override
  R? visitLabeledStatement(SLabeledStatement node) {
    visitAll(node.labels);
    node.statement.accept(this);
    return null;
  }

  @override
  R? visitReturnStatement(SReturnStatement node) {
    node.expression?.accept(this);
    return null;
  }

  @override
  R? visitSwitchStatement(SSwitchStatement node) {
    node.expression.accept(this);
    visitAll(node.members);
    return null;
  }

  @override
  R? visitSwitchPatternCase(SSwitchPatternCase node) {
    visitAll(node.labels);
    node.guardedPattern.accept(this);
    visitAll(node.statements);
    return null;
  }

  @override
  R? visitSwitchCase(SSwitchCase node) {
    visitAll(node.labels);
    node.expression.accept(this);
    visitAll(node.statements);
    return null;
  }

  @override
  R? visitSwitchDefault(SSwitchDefault node) {
    visitAll(node.labels);
    visitAll(node.statements);
    return null;
  }

  @override
  R? visitWhenClause(SWhenClause node) {
    node.expression.accept(this);
    return null;
  }

  @override
  R? visitTryStatement(STryStatement node) {
    node.body.accept(this);
    visitAll(node.catchClauses);
    node.finallyBlock?.accept(this);
    return null;
  }

  @override
  R? visitVariableDeclarationStatement(SVariableDeclarationStatement node) {
    node.variables.accept(this);
    return null;
  }

  @override
  R? visitWhileStatement(SWhileStatement node) {
    node.condition.accept(this);
    node.body.accept(this);
    return null;
  }

  @override
  R? visitYieldStatement(SYieldStatement node) {
    node.expression.accept(this);
    return null;
  }

  @override
  R? visitPatternVariableDeclarationStatement(
      SPatternVariableDeclarationStatement node) {
    node.declaration.accept(this);
    return null;
  }

  @override
  R? visitPatternVariableDeclaration(SPatternVariableDeclaration node) {
    node.pattern.accept(this);
    node.expression.accept(this);
    return null;
  }

  @override
  R? visitPatternAssignment(SPatternAssignment node) {
    node.pattern.accept(this);
    node.expression.accept(this);
    return null;
  }

  // Types
  @override
  R? visitNamedType(SNamedType node) {
    node.importPrefix?.accept(this);
    node.name2.accept(this);
    node.typeArguments?.accept(this);
    return null;
  }

  @override
  R? visitGenericFunctionType(SGenericFunctionType node) {
    node.returnType?.accept(this);
    node.typeParameters?.accept(this);
    node.parameters.accept(this);
    return null;
  }

  @override
  R? visitRecordTypeAnnotation(SRecordTypeAnnotation node) {
    visitAll(node.positionalFields);
    node.namedFields?.accept(this);
    return null;
  }

  @override
  R? visitRecordTypeAnnotationPositionalField(
      SRecordTypeAnnotationPositionalField node) {
    visitAll(node.metadata);
    node.type.accept(this);
    node.name?.accept(this);
    return null;
  }

  @override
  R? visitRecordTypeAnnotationNamedFields(
      SRecordTypeAnnotationNamedFields node) {
    visitAll(node.fields);
    return null;
  }

  @override
  R? visitRecordTypeAnnotationNamedField(SRecordTypeAnnotationNamedField node) {
    visitAll(node.metadata);
    node.type.accept(this);
    node.name.accept(this);
    return null;
  }

  @override
  R? visitTypeArgumentList(STypeArgumentList node) {
    visitAll(node.arguments);
    return null;
  }

  @override
  R? visitTypeParameter(STypeParameter node) {
    visitAll(node.metadata);
    node.name.accept(this);
    node.bound?.accept(this);
    return null;
  }

  @override
  R? visitTypeParameterList(STypeParameterList node) {
    visitAll(node.typeParameters);
    return null;
  }

  // Function bodies
  @override
  R? visitBlockFunctionBody(SBlockFunctionBody node) {
    node.block.accept(this);
    return null;
  }

  @override
  R? visitExpressionFunctionBody(SExpressionFunctionBody node) {
    node.expression.accept(this);
    return null;
  }

  @override
  R? visitEmptyFunctionBody(SEmptyFunctionBody node) => null;

  @override
  R? visitNativeFunctionBody(SNativeFunctionBody node) {
    node.stringLiteral?.accept(this);
    return null;
  }

  // Parameters
  @override
  R? visitFormalParameterList(SFormalParameterList node) {
    visitAll(node.parameters);
    return null;
  }

  @override
  R? visitSimpleFormalParameter(SSimpleFormalParameter node) {
    visitAll(node.metadata);
    node.type?.accept(this);
    node.name?.accept(this);
    return null;
  }

  @override
  R? visitDefaultFormalParameter(SDefaultFormalParameter node) {
    node.parameter.accept(this);
    node.defaultValue?.accept(this);
    return null;
  }

  @override
  R? visitFieldFormalParameter(SFieldFormalParameter node) {
    visitAll(node.metadata);
    node.type?.accept(this);
    node.name.accept(this);
    node.typeParameters?.accept(this);
    node.parameters?.accept(this);
    return null;
  }

  @override
  R? visitFunctionTypedFormalParameter(SFunctionTypedFormalParameter node) {
    visitAll(node.metadata);
    node.returnType?.accept(this);
    node.name.accept(this);
    node.typeParameters?.accept(this);
    node.parameters.accept(this);
    return null;
  }

  @override
  R? visitSuperFormalParameter(SSuperFormalParameter node) {
    visitAll(node.metadata);
    node.type?.accept(this);
    node.name.accept(this);
    node.typeParameters?.accept(this);
    node.parameters?.accept(this);
    return null;
  }

  @override
  R? visitArgumentList(SArgumentList node) {
    visitAll(node.arguments);
    return null;
  }

  // Clauses
  @override
  R? visitExtendsClause(SExtendsClause node) {
    node.superclass.accept(this);
    return null;
  }

  @override
  R? visitImplementsClause(SImplementsClause node) {
    visitAll(node.interfaces);
    return null;
  }

  @override
  R? visitWithClause(SWithClause node) {
    visitAll(node.mixinTypes);
    return null;
  }

  @override
  R? visitOnClause(SOnClause node) {
    visitAll(node.superclassConstraints);
    return null;
  }

  @override
  R? visitExtensionOnClause(SExtensionOnClause node) {
    node.extendedType.accept(this);
    return null;
  }

  @override
  R? visitMixinOnClause(SMixinOnClause node) {
    visitAll(node.superclassConstraints);
    return null;
  }

  @override
  R? visitCatchClause(SCatchClause node) {
    node.exceptionType?.accept(this);
    node.exceptionParameter?.accept(this);
    node.stackTraceParameter?.accept(this);
    node.body.accept(this);
    return null;
  }

  @override
  R? visitCatchClauseParameter(SCatchClauseParameter node) => null;

  @override
  R? visitFinallyClause(SFinallyClause node) {
    node.body.accept(this);
    return null;
  }

  @override
  R? visitNativeClause(SNativeClause node) {
    node.name?.accept(this);
    return null;
  }

  // Collection elements
  @override
  R? visitForElement(SForElement node) {
    node.forLoopParts.accept(this);
    node.body.accept(this);
    return null;
  }

  @override
  R? visitIfElement(SIfElement node) {
    node.expression?.accept(this);
    node.caseClause?.accept(this);
    node.thenElement.accept(this);
    node.elseElement?.accept(this);
    return null;
  }

  @override
  R? visitSpreadElement(SSpreadElement node) {
    node.expression.accept(this);
    return null;
  }

  @override
  R? visitMapLiteralEntry(SMapLiteralEntry node) {
    node.key.accept(this);
    node.value.accept(this);
    return null;
  }

  @override
  R? visitRecordField(SRecordField node) {
    node.name?.accept(this);
    node.expression.accept(this);
    return null;
  }

  @override
  R? visitExpressionElement(SExpressionElement node) {
    node.expression.accept(this);
    return null;
  }

  @override
  R? visitNullAwareElement(SNullAwareElement node) {
    node.value.accept(this);
    return null;
  }

  // Patterns
  @override
  R? visitAssignedVariablePattern(SAssignedVariablePattern node) {
    node.name.accept(this);
    return null;
  }

  @override
  R? visitDeclaredVariablePattern(SDeclaredVariablePattern node) {
    node.type?.accept(this);
    node.name.accept(this);
    return null;
  }

  @override
  R? visitDeclaredIdentifier(SDeclaredIdentifier node) {
    visitAll(node.metadata);
    node.type?.accept(this);
    node.name.accept(this);
    return null;
  }

  @override
  R? visitWildcardPattern(SWildcardPattern node) {
    node.type?.accept(this);
    return null;
  }

  @override
  R? visitConstantPattern(SConstantPattern node) {
    node.expression.accept(this);
    return null;
  }

  @override
  R? visitVariablePattern(SVariablePattern node) {
    node.type?.accept(this);
    node.name.accept(this);
    return null;
  }

  @override
  R? visitListPattern(SListPattern node) {
    node.typeArguments?.accept(this);
    visitAll(node.elements);
    return null;
  }

  @override
  R? visitPatternElement(SPatternElement node) {
    node.pattern.accept(this);
    return null;
  }

  @override
  R? visitRestPatternElement(SRestPatternElement node) {
    node.pattern?.accept(this);
    return null;
  }

  @override
  R? visitMapPattern(SMapPattern node) {
    node.typeArguments?.accept(this);
    visitAll(node.elements);
    return null;
  }

  @override
  R? visitMapPatternKeyValue(SMapPatternKeyValue node) {
    node.key.accept(this);
    node.value.accept(this);
    return null;
  }

  @override
  R? visitMapPatternEntry(SMapPatternEntry node) {
    node.key.accept(this);
    node.value.accept(this);
    return null;
  }

  @override
  R? visitMapPatternRest(SMapPatternRest node) => null;

  @override
  R? visitRecordPattern(SRecordPattern node) {
    visitAll(node.fields);
    return null;
  }

  @override
  R? visitPatternField(SPatternField node) {
    node.name?.accept(this);
    node.pattern.accept(this);
    return null;
  }

  @override
  R? visitPatternFieldName(SPatternFieldName node) {
    node.name?.accept(this);
    return null;
  }

  @override
  R? visitObjectPattern(SObjectPattern node) {
    node.type.accept(this);
    visitAll(node.fields);
    return null;
  }

  @override
  R? visitLogicalAndPattern(SLogicalAndPattern node) {
    node.leftOperand.accept(this);
    node.rightOperand.accept(this);
    return null;
  }

  @override
  R? visitLogicalOrPattern(SLogicalOrPattern node) {
    node.leftOperand.accept(this);
    node.rightOperand.accept(this);
    return null;
  }

  @override
  R? visitCastPattern(SCastPattern node) {
    node.pattern.accept(this);
    node.type.accept(this);
    return null;
  }

  @override
  R? visitNullCheckPattern(SNullCheckPattern node) {
    node.pattern.accept(this);
    return null;
  }

  @override
  R? visitNullAssertPattern(SNullAssertPattern node) {
    node.pattern.accept(this);
    return null;
  }

  @override
  R? visitParenthesizedPattern(SParenthesizedPattern node) {
    node.pattern.accept(this);
    return null;
  }

  @override
  R? visitRelationalPattern(SRelationalPattern node) {
    node.operand.accept(this);
    return null;
  }

  // Miscellaneous
  @override
  R? visitAnnotation(SAnnotation node) {
    node.name.accept(this);
    node.typeArguments?.accept(this);
    node.constructorName?.accept(this);
    node.arguments?.accept(this);
    return null;
  }

  @override
  R? visitComment(SComment node) => null;

  @override
  R? visitScriptTag(SScriptTag node) => null;
}
