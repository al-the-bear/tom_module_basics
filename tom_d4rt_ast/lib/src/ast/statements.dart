part of '../ast.dart';

// =============================================================================
// STATEMENT NODES
// =============================================================================

/// A block of statements.
///
/// Example: `{ statement1; statement2; }`
final class SBlock extends SStatement {
  /// The left brace.
  final SToken leftBrace;

  /// The statements in the block.
  final List<SStatement> statements;

  /// The right brace.
  final SToken rightBrace;

  @override
  int get offset => leftBrace.offset;

  @override
  int get end => rightBrace.end;

  const SBlock({
    required this.leftBrace,
    required this.statements,
    required this.rightBrace,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitBlock(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'Block',
        'lb': leftBrace.toJson(),
        'stmts': statements.map((s) => s.toJson()).toList(),
        'rb': rightBrace.toJson(),
      };

  factory SBlock.fromJson(Map<String, dynamic> json) {
    return SBlock(
      leftBrace: SToken.fromJson(json['lb'] as Map<String, dynamic>),
      statements: (json['stmts'] as List)
          .map((s) => _statementFromJson(s as Map<String, dynamic>))
          .toList(),
      rightBrace: SToken.fromJson(json['rb'] as Map<String, dynamic>),
    );
  }
}

/// An assert statement.
///
/// Example: `assert(condition);`, `assert(condition, message);`
final class SAssertStatement extends SStatement {
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

  /// The semicolon.
  final SToken semicolon;

  @override
  int get offset => assertKeyword.offset;

  @override
  int get end => semicolon.end;

  const SAssertStatement({
    required this.assertKeyword,
    required this.leftParenthesis,
    required this.condition,
    this.comma,
    this.message,
    required this.rightParenthesis,
    required this.semicolon,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitAssertStatement(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'AssertStatement',
        'assert': assertKeyword.toJson(),
        'lp': leftParenthesis.toJson(),
        'cond': condition.toJson(),
        if (comma != null) 'comma': comma!.toJson(),
        if (message != null) 'msg': message!.toJson(),
        'rp': rightParenthesis.toJson(),
        'semi': semicolon.toJson(),
      };

  factory SAssertStatement.fromJson(Map<String, dynamic> json) {
    return SAssertStatement(
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
      semicolon: SToken.fromJson(json['semi'] as Map<String, dynamic>),
    );
  }
}

/// A break statement.
///
/// Example: `break;`, `break label;`
final class SBreakStatement extends SStatement {
  /// The 'break' keyword.
  final SToken breakKeyword;

  /// The label, if any.
  final SSimpleIdentifier? label;

  /// The semicolon.
  final SToken semicolon;

  @override
  int get offset => breakKeyword.offset;

  @override
  int get end => semicolon.end;

  const SBreakStatement({
    required this.breakKeyword,
    this.label,
    required this.semicolon,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitBreakStatement(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'BreakStatement',
        'break': breakKeyword.toJson(),
        if (label != null) 'label': label!.toJson(),
        'semi': semicolon.toJson(),
      };

  factory SBreakStatement.fromJson(Map<String, dynamic> json) {
    return SBreakStatement(
      breakKeyword: SToken.fromJson(json['break'] as Map<String, dynamic>),
      label: json['label'] != null
          ? SSimpleIdentifier.fromJson(json['label'] as Map<String, dynamic>)
          : null,
      semicolon: SToken.fromJson(json['semi'] as Map<String, dynamic>),
    );
  }
}

/// A continue statement.
///
/// Example: `continue;`, `continue label;`
final class SContinueStatement extends SStatement {
  /// The 'continue' keyword.
  final SToken continueKeyword;

  /// The label, if any.
  final SSimpleIdentifier? label;

  /// The semicolon.
  final SToken semicolon;

  @override
  int get offset => continueKeyword.offset;

  @override
  int get end => semicolon.end;

  const SContinueStatement({
    required this.continueKeyword,
    this.label,
    required this.semicolon,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitContinueStatement(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ContinueStatement',
        'continue': continueKeyword.toJson(),
        if (label != null) 'label': label!.toJson(),
        'semi': semicolon.toJson(),
      };

  factory SContinueStatement.fromJson(Map<String, dynamic> json) {
    return SContinueStatement(
      continueKeyword:
          SToken.fromJson(json['continue'] as Map<String, dynamic>),
      label: json['label'] != null
          ? SSimpleIdentifier.fromJson(json['label'] as Map<String, dynamic>)
          : null,
      semicolon: SToken.fromJson(json['semi'] as Map<String, dynamic>),
    );
  }
}

/// A do-while statement.
///
/// Example: `do { ... } while (condition);`
final class SDoStatement extends SStatement {
  /// The 'do' keyword.
  final SToken doKeyword;

  /// The body.
  final SStatement body;

  /// The 'while' keyword.
  final SToken whileKeyword;

  /// The left parenthesis.
  final SToken leftParenthesis;

  /// The condition.
  final SExpression condition;

  /// The right parenthesis.
  final SToken rightParenthesis;

  /// The semicolon.
  final SToken semicolon;

  @override
  int get offset => doKeyword.offset;

  @override
  int get end => semicolon.end;

  const SDoStatement({
    required this.doKeyword,
    required this.body,
    required this.whileKeyword,
    required this.leftParenthesis,
    required this.condition,
    required this.rightParenthesis,
    required this.semicolon,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitDoStatement(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'DoStatement',
        'do': doKeyword.toJson(),
        'body': body.toJson(),
        'while': whileKeyword.toJson(),
        'lp': leftParenthesis.toJson(),
        'cond': condition.toJson(),
        'rp': rightParenthesis.toJson(),
        'semi': semicolon.toJson(),
      };

  factory SDoStatement.fromJson(Map<String, dynamic> json) {
    return SDoStatement(
      doKeyword: SToken.fromJson(json['do'] as Map<String, dynamic>),
      body: _statementFromJson(json['body'] as Map<String, dynamic>),
      whileKeyword: SToken.fromJson(json['while'] as Map<String, dynamic>),
      leftParenthesis: SToken.fromJson(json['lp'] as Map<String, dynamic>),
      condition: _expressionFromJson(json['cond'] as Map<String, dynamic>),
      rightParenthesis: SToken.fromJson(json['rp'] as Map<String, dynamic>),
      semicolon: SToken.fromJson(json['semi'] as Map<String, dynamic>),
    );
  }
}

/// An empty statement (just a semicolon).
///
/// Example: `;`
final class SEmptyStatement extends SStatement {
  /// The semicolon.
  final SToken semicolon;

  @override
  int get offset => semicolon.offset;

  @override
  int get end => semicolon.end;

  const SEmptyStatement({required this.semicolon});

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitEmptyStatement(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'EmptyStatement',
        'semi': semicolon.toJson(),
      };

  factory SEmptyStatement.fromJson(Map<String, dynamic> json) {
    return SEmptyStatement(
      semicolon: SToken.fromJson(json['semi'] as Map<String, dynamic>),
    );
  }
}

/// An expression statement.
///
/// Example: `print('hello');`, `x = 5;`
final class SExpressionStatement extends SStatement {
  /// The expression.
  final SExpression expression;

  /// The semicolon.
  final SToken? semicolon;

  @override
  int get offset => expression.offset;

  @override
  int get end => semicolon?.end ?? expression.end;

  const SExpressionStatement({
    required this.expression,
    this.semicolon,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitExpressionStatement(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ExpressionStatement',
        'expr': expression.toJson(),
        if (semicolon != null) 'semi': semicolon!.toJson(),
      };

  factory SExpressionStatement.fromJson(Map<String, dynamic> json) {
    return SExpressionStatement(
      expression: _expressionFromJson(json['expr'] as Map<String, dynamic>),
      semicolon: json['semi'] != null
          ? SToken.fromJson(json['semi'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// A for statement (including for-in).
///
/// Examples:
/// - `for (var i = 0; i < 10; i++) { }`
/// - `for (var item in items) { }`
/// - `await for (var event in stream) { }`
final class SForStatement extends SStatement {
  /// The 'await' keyword for async for-in, if any.
  final SToken? awaitKeyword;

  /// The 'for' keyword.
  final SToken forKeyword;

  /// The left parenthesis.
  final SToken leftParenthesis;

  /// The loop parts (initialization, condition, update OR variable, iterable).
  final SForLoopParts forLoopParts;

  /// The right parenthesis.
  final SToken rightParenthesis;

  /// The body.
  final SStatement body;

  @override
  int get offset => awaitKeyword?.offset ?? forKeyword.offset;

  @override
  int get end => body.end;

  const SForStatement({
    this.awaitKeyword,
    required this.forKeyword,
    required this.leftParenthesis,
    required this.forLoopParts,
    required this.rightParenthesis,
    required this.body,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitForStatement(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ForStatement',
        if (awaitKeyword != null) 'await': awaitKeyword!.toJson(),
        'for': forKeyword.toJson(),
        'lp': leftParenthesis.toJson(),
        'parts': forLoopParts.toJson(),
        'rp': rightParenthesis.toJson(),
        'body': body.toJson(),
      };

  factory SForStatement.fromJson(Map<String, dynamic> json) {
    return SForStatement(
      awaitKeyword: json['await'] != null
          ? SToken.fromJson(json['await'] as Map<String, dynamic>)
          : null,
      forKeyword: SToken.fromJson(json['for'] as Map<String, dynamic>),
      leftParenthesis: SToken.fromJson(json['lp'] as Map<String, dynamic>),
      forLoopParts:
          _forLoopPartsFromJson(json['parts'] as Map<String, dynamic>),
      rightParenthesis: SToken.fromJson(json['rp'] as Map<String, dynamic>),
      body: _statementFromJson(json['body'] as Map<String, dynamic>),
    );
  }
}

/// Base class for for-loop parts.
sealed class SForLoopParts extends SAstNode {
  const SForLoopParts();
}

/// Base class for traditional for-loop parts (init; condition; update).
sealed class SForParts extends SForLoopParts {
  /// The first semicolon.
  SToken get leftSeparator;

  /// The condition.
  SExpression? get condition;

  /// The second semicolon.
  SToken get rightSeparator;

  /// The update expressions.
  List<SExpression> get updaters;

  const SForParts();
}

/// Traditional for-loop parts with variable declarations.
///
/// Example: `for (var i = 0; i < 10; i++)`
final class SForPartsWithDeclarations extends SForParts {
  /// The declaration of the loop variables.
  final SVariableDeclarationList variables;

  @override
  final SToken leftSeparator;

  @override
  final SExpression? condition;

  @override
  final SToken rightSeparator;

  @override
  final List<SExpression> updaters;

  @override
  int get offset => variables.offset;

  @override
  int get end => updaters.lastOrNull?.end ?? rightSeparator.end;

  const SForPartsWithDeclarations({
    required this.variables,
    required this.leftSeparator,
    this.condition,
    required this.rightSeparator,
    required this.updaters,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitForPartsWithDeclarations(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ForPartsWithDeclarations',
        'vars': variables.toJson(),
        'ls': leftSeparator.toJson(),
        if (condition != null) 'cond': condition!.toJson(),
        'rs': rightSeparator.toJson(),
        'updaters': updaters.map((u) => u.toJson()).toList(),
      };

  factory SForPartsWithDeclarations.fromJson(Map<String, dynamic> json) {
    return SForPartsWithDeclarations(
      variables: SVariableDeclarationList.fromJson(
          json['vars'] as Map<String, dynamic>),
      leftSeparator: SToken.fromJson(json['ls'] as Map<String, dynamic>),
      condition: json['cond'] != null
          ? _expressionFromJson(json['cond'] as Map<String, dynamic>)
          : null,
      rightSeparator: SToken.fromJson(json['rs'] as Map<String, dynamic>),
      updaters: (json['updaters'] as List)
          .map((u) => _expressionFromJson(u as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Traditional for-loop parts with an initialization expression.
///
/// Example: `for (i = 0; i < 10; i++)`
final class SForPartsWithExpression extends SForParts {
  /// The initialization expression, or `null` if there's no initialization.
  final SExpression? initialization;

  @override
  final SToken leftSeparator;

  @override
  final SExpression? condition;

  @override
  final SToken rightSeparator;

  @override
  final List<SExpression> updaters;

  @override
  int get offset => initialization?.offset ?? leftSeparator.offset;

  @override
  int get end => updaters.lastOrNull?.end ?? rightSeparator.end;

  const SForPartsWithExpression({
    this.initialization,
    required this.leftSeparator,
    this.condition,
    required this.rightSeparator,
    required this.updaters,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitForPartsWithExpression(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ForPartsWithExpression',
        if (initialization != null) 'init': initialization!.toJson(),
        'ls': leftSeparator.toJson(),
        if (condition != null) 'cond': condition!.toJson(),
        'rs': rightSeparator.toJson(),
        'updaters': updaters.map((u) => u.toJson()).toList(),
      };

  factory SForPartsWithExpression.fromJson(Map<String, dynamic> json) {
    return SForPartsWithExpression(
      initialization: json['init'] != null
          ? _expressionFromJson(json['init'] as Map<String, dynamic>)
          : null,
      leftSeparator: SToken.fromJson(json['ls'] as Map<String, dynamic>),
      condition: json['cond'] != null
          ? _expressionFromJson(json['cond'] as Map<String, dynamic>)
          : null,
      rightSeparator: SToken.fromJson(json['rs'] as Map<String, dynamic>),
      updaters: (json['updaters'] as List)
          .map((u) => _expressionFromJson(u as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Traditional for-loop parts with a pattern variable declaration.
///
/// Example: `for (var (a, b) = init; condition; update)`
final class SForPartsWithPattern extends SForParts {
  /// The declaration of the loop variables.
  final SPatternVariableDeclaration variables;

  @override
  final SToken leftSeparator;

  @override
  final SExpression? condition;

  @override
  final SToken rightSeparator;

  @override
  final List<SExpression> updaters;

  @override
  int get offset => variables.offset;

  @override
  int get end => updaters.lastOrNull?.end ?? rightSeparator.end;

  const SForPartsWithPattern({
    required this.variables,
    required this.leftSeparator,
    this.condition,
    required this.rightSeparator,
    required this.updaters,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitForPartsWithPattern(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ForPartsWithPattern',
        'vars': variables.toJson(),
        'ls': leftSeparator.toJson(),
        if (condition != null) 'cond': condition!.toJson(),
        'rs': rightSeparator.toJson(),
        'updaters': updaters.map((u) => u.toJson()).toList(),
      };

  factory SForPartsWithPattern.fromJson(Map<String, dynamic> json) {
    return SForPartsWithPattern(
      variables: SPatternVariableDeclaration.fromJson(
          json['vars'] as Map<String, dynamic>),
      leftSeparator: SToken.fromJson(json['ls'] as Map<String, dynamic>),
      condition: json['cond'] != null
          ? _expressionFromJson(json['cond'] as Map<String, dynamic>)
          : null,
      rightSeparator: SToken.fromJson(json['rs'] as Map<String, dynamic>),
      updaters: (json['updaters'] as List)
          .map((u) => _expressionFromJson(u as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Base class for for-each loop parts (variable in iterable).
sealed class SForEachParts extends SForLoopParts {
  /// The 'in' keyword.
  SToken get inKeyword;

  /// The iterable expression.
  SExpression get iterable;

  const SForEachParts();
}

/// For-each loop parts with a declared identifier.
///
/// Example: `for (var x in list)`
final class SForEachPartsWithDeclaration extends SForEachParts {
  /// The declaration of the loop variable.
  final SDeclaredIdentifier loopVariable;

  @override
  final SToken inKeyword;

  @override
  final SExpression iterable;

  @override
  int get offset => loopVariable.offset;

  @override
  int get end => iterable.end;

  const SForEachPartsWithDeclaration({
    required this.loopVariable,
    required this.inKeyword,
    required this.iterable,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitForEachPartsWithDeclaration(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ForEachPartsWithDeclaration',
        'loopVar': loopVariable.toJson(),
        'in': inKeyword.toJson(),
        'iter': iterable.toJson(),
      };

  factory SForEachPartsWithDeclaration.fromJson(Map<String, dynamic> json) {
    return SForEachPartsWithDeclaration(
      loopVariable: SDeclaredIdentifier.fromJson(
          json['loopVar'] as Map<String, dynamic>),
      inKeyword: SToken.fromJson(json['in'] as Map<String, dynamic>),
      iterable: _expressionFromJson(json['iter'] as Map<String, dynamic>),
    );
  }
}

/// For-each loop parts with a simple identifier.
///
/// Example: `for (x in list)` (where x is already declared)
final class SForEachPartsWithIdentifier extends SForEachParts {
  /// The loop variable identifier.
  final SSimpleIdentifier identifier;

  @override
  final SToken inKeyword;

  @override
  final SExpression iterable;

  @override
  int get offset => identifier.offset;

  @override
  int get end => iterable.end;

  const SForEachPartsWithIdentifier({
    required this.identifier,
    required this.inKeyword,
    required this.iterable,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitForEachPartsWithIdentifier(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ForEachPartsWithIdentifier',
        'id': identifier.toJson(),
        'in': inKeyword.toJson(),
        'iter': iterable.toJson(),
      };

  factory SForEachPartsWithIdentifier.fromJson(Map<String, dynamic> json) {
    return SForEachPartsWithIdentifier(
      identifier:
          SSimpleIdentifier.fromJson(json['id'] as Map<String, dynamic>),
      inKeyword: SToken.fromJson(json['in'] as Map<String, dynamic>),
      iterable: _expressionFromJson(json['iter'] as Map<String, dynamic>),
    );
  }
}

/// For-each loop parts with a pattern.
///
/// Example: `for (var (a, b) in list)`
final class SForEachPartsWithPattern extends SForEachParts {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// The 'var' or 'final' keyword.
  final SToken keyword;

  /// The pattern used to match elements.
  final SDartPattern pattern;

  @override
  final SToken inKeyword;

  @override
  final SExpression iterable;

  @override
  int get offset => metadata.firstOrNull?.offset ?? keyword.offset;

  @override
  int get end => iterable.end;

  const SForEachPartsWithPattern({
    required this.metadata,
    required this.keyword,
    required this.pattern,
    required this.inKeyword,
    required this.iterable,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitForEachPartsWithPattern(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ForEachPartsWithPattern',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        'keyword': keyword.toJson(),
        'pattern': pattern.toJson(),
        'in': inKeyword.toJson(),
        'iter': iterable.toJson(),
      };

  factory SForEachPartsWithPattern.fromJson(Map<String, dynamic> json) {
    return SForEachPartsWithPattern(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      keyword: SToken.fromJson(json['keyword'] as Map<String, dynamic>),
      pattern: _patternFromJson(json['pattern'] as Map<String, dynamic>),
      inKeyword: SToken.fromJson(json['in'] as Map<String, dynamic>),
      iterable: _expressionFromJson(json['iter'] as Map<String, dynamic>),
    );
  }
}

/// An if statement.
///
/// Example: `if (cond) { } else { }`
final class SIfStatement extends SStatement {
  /// The 'if' keyword.
  final SToken ifKeyword;

  /// The left parenthesis.
  final SToken leftParenthesis;

  /// The expression (for expression-based if).
  final SExpression? expression;

  /// The case clause (for pattern-based if).
  final SCaseClause? caseClause;

  /// The right parenthesis.
  final SToken rightParenthesis;

  /// The then statement.
  final SStatement thenStatement;

  /// The 'else' keyword, if present.
  final SToken? elseKeyword;

  /// The else statement, if present.
  final SStatement? elseStatement;

  @override
  int get offset => ifKeyword.offset;

  @override
  int get end => elseStatement?.end ?? thenStatement.end;

  const SIfStatement({
    required this.ifKeyword,
    required this.leftParenthesis,
    this.expression,
    this.caseClause,
    required this.rightParenthesis,
    required this.thenStatement,
    this.elseKeyword,
    this.elseStatement,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitIfStatement(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'IfStatement',
        'if': ifKeyword.toJson(),
        'lp': leftParenthesis.toJson(),
        if (expression != null) 'expr': expression!.toJson(),
        if (caseClause != null) 'case': caseClause!.toJson(),
        'rp': rightParenthesis.toJson(),
        'then': thenStatement.toJson(),
        if (elseKeyword != null) 'elseKw': elseKeyword!.toJson(),
        if (elseStatement != null) 'else': elseStatement!.toJson(),
      };

  factory SIfStatement.fromJson(Map<String, dynamic> json) {
    return SIfStatement(
      ifKeyword: SToken.fromJson(json['if'] as Map<String, dynamic>),
      leftParenthesis: SToken.fromJson(json['lp'] as Map<String, dynamic>),
      expression: json['expr'] != null
          ? _expressionFromJson(json['expr'] as Map<String, dynamic>)
          : null,
      caseClause: json['case'] != null
          ? SCaseClause.fromJson(json['case'] as Map<String, dynamic>)
          : null,
      rightParenthesis: SToken.fromJson(json['rp'] as Map<String, dynamic>),
      thenStatement:
          _statementFromJson(json['then'] as Map<String, dynamic>),
      elseKeyword: json['elseKw'] != null
          ? SToken.fromJson(json['elseKw'] as Map<String, dynamic>)
          : null,
      elseStatement: json['else'] != null
          ? _statementFromJson(json['else'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// A case clause in an if-case statement.
final class SCaseClause extends SAstNode {
  /// The 'case' keyword.
  final SToken caseKeyword;

  /// The guarded pattern.
  final SGuardedPattern guardedPattern;

  @override
  int get offset => caseKeyword.offset;

  @override
  int get end => guardedPattern.end;

  const SCaseClause({
    required this.caseKeyword,
    required this.guardedPattern,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitCaseClause(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'CaseClause',
        'case': caseKeyword.toJson(),
        'pattern': guardedPattern.toJson(),
      };

  factory SCaseClause.fromJson(Map<String, dynamic> json) {
    return SCaseClause(
      caseKeyword: SToken.fromJson(json['case'] as Map<String, dynamic>),
      guardedPattern:
          SGuardedPattern.fromJson(json['pattern'] as Map<String, dynamic>),
    );
  }
}

/// A labeled statement.
///
/// Example: `myLabel: statement;`
final class SLabeledStatement extends SStatement {
  /// The labels.
  final List<SLabel> labels;

  /// The statement.
  final SStatement statement;

  @override
  int get offset => labels.first.offset;

  @override
  int get end => statement.end;

  const SLabeledStatement({
    required this.labels,
    required this.statement,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitLabeledStatement(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'LabeledStatement',
        'labels': labels.map((l) => l.toJson()).toList(),
        'stmt': statement.toJson(),
      };

  factory SLabeledStatement.fromJson(Map<String, dynamic> json) {
    return SLabeledStatement(
      labels: (json['labels'] as List)
          .map((l) => SLabel.fromJson(l as Map<String, dynamic>))
          .toList(),
      statement: _statementFromJson(json['stmt'] as Map<String, dynamic>),
    );
  }
}

/// A return statement.
///
/// Example: `return;`, `return value;`
final class SReturnStatement extends SStatement {
  /// The 'return' keyword.
  final SToken returnKeyword;

  /// The expression, if any.
  final SExpression? expression;

  /// The semicolon.
  final SToken semicolon;

  @override
  int get offset => returnKeyword.offset;

  @override
  int get end => semicolon.end;

  const SReturnStatement({
    required this.returnKeyword,
    this.expression,
    required this.semicolon,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitReturnStatement(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ReturnStatement',
        'return': returnKeyword.toJson(),
        if (expression != null) 'expr': expression!.toJson(),
        'semi': semicolon.toJson(),
      };

  factory SReturnStatement.fromJson(Map<String, dynamic> json) {
    return SReturnStatement(
      returnKeyword: SToken.fromJson(json['return'] as Map<String, dynamic>),
      expression: json['expr'] != null
          ? _expressionFromJson(json['expr'] as Map<String, dynamic>)
          : null,
      semicolon: SToken.fromJson(json['semi'] as Map<String, dynamic>),
    );
  }
}

/// A switch statement.
///
/// Example: `switch (x) { case 1: ... default: ... }`
final class SSwitchStatement extends SStatement {
  /// The 'switch' keyword.
  final SToken switchKeyword;

  /// The left parenthesis.
  final SToken leftParenthesis;

  /// The expression being switched on.
  final SExpression expression;

  /// The right parenthesis.
  final SToken rightParenthesis;

  /// The left brace.
  final SToken leftBrace;

  /// The switch members (cases and default).
  final List<SSwitchMember> members;

  /// The right brace.
  final SToken rightBrace;

  @override
  int get offset => switchKeyword.offset;

  @override
  int get end => rightBrace.end;

  const SSwitchStatement({
    required this.switchKeyword,
    required this.leftParenthesis,
    required this.expression,
    required this.rightParenthesis,
    required this.leftBrace,
    required this.members,
    required this.rightBrace,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitSwitchStatement(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'SwitchStatement',
        'switch': switchKeyword.toJson(),
        'lp': leftParenthesis.toJson(),
        'expr': expression.toJson(),
        'rp': rightParenthesis.toJson(),
        'lb': leftBrace.toJson(),
        'members': members.map((m) => m.toJson()).toList(),
        'rb': rightBrace.toJson(),
      };

  factory SSwitchStatement.fromJson(Map<String, dynamic> json) {
    return SSwitchStatement(
      switchKeyword: SToken.fromJson(json['switch'] as Map<String, dynamic>),
      leftParenthesis: SToken.fromJson(json['lp'] as Map<String, dynamic>),
      expression: _expressionFromJson(json['expr'] as Map<String, dynamic>),
      rightParenthesis: SToken.fromJson(json['rp'] as Map<String, dynamic>),
      leftBrace: SToken.fromJson(json['lb'] as Map<String, dynamic>),
      members: (json['members'] as List)
          .map((m) => _switchMemberFromJson(m as Map<String, dynamic>))
          .toList(),
      rightBrace: SToken.fromJson(json['rb'] as Map<String, dynamic>),
    );
  }
}

/// Base class for switch members.
abstract class SSwitchMember extends SAstNode {
  /// The labels for this member.
  List<SLabel> get labels;

  /// The statements in this member.
  List<SStatement> get statements;

  const SSwitchMember();
}

/// A case in a switch statement (Dart 3 pattern-based).
final class SSwitchPatternCase extends SSwitchMember {
  @override
  final List<SLabel> labels;

  /// The 'case' keyword.
  final SToken keyword;

  /// The guarded pattern.
  final SGuardedPattern guardedPattern;

  /// The colon.
  final SToken colon;

  @override
  final List<SStatement> statements;

  @override
  int get offset => labels.firstOrNull?.offset ?? keyword.offset;

  @override
  int get end => statements.lastOrNull?.end ?? colon.end;

  const SSwitchPatternCase({
    required this.labels,
    required this.keyword,
    required this.guardedPattern,
    required this.colon,
    required this.statements,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitSwitchPatternCase(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'SwitchPatternCase',
        'labels': labels.map((l) => l.toJson()).toList(),
        'case': keyword.toJson(),
        'pattern': guardedPattern.toJson(),
        'colon': colon.toJson(),
        'stmts': statements.map((s) => s.toJson()).toList(),
      };

  factory SSwitchPatternCase.fromJson(Map<String, dynamic> json) {
    return SSwitchPatternCase(
      labels: (json['labels'] as List)
          .map((l) => SLabel.fromJson(l as Map<String, dynamic>))
          .toList(),
      keyword: SToken.fromJson(json['case'] as Map<String, dynamic>),
      guardedPattern:
          SGuardedPattern.fromJson(json['pattern'] as Map<String, dynamic>),
      colon: SToken.fromJson(json['colon'] as Map<String, dynamic>),
      statements: (json['stmts'] as List)
          .map((s) => _statementFromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A case in a switch statement (old-style, pre-Dart 3).
///
/// Example: `case 1: statements;`
final class SSwitchCase extends SSwitchMember {
  @override
  final List<SLabel> labels;

  /// The 'case' keyword.
  final SToken keyword;

  /// The expression.
  final SExpression expression;

  /// The colon.
  final SToken colon;

  @override
  final List<SStatement> statements;

  @override
  int get offset => labels.firstOrNull?.offset ?? keyword.offset;

  @override
  int get end => statements.lastOrNull?.end ?? colon.end;

  const SSwitchCase({
    required this.labels,
    required this.keyword,
    required this.expression,
    required this.colon,
    required this.statements,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitSwitchCase(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'SwitchCase',
        'labels': labels.map((l) => l.toJson()).toList(),
        'case': keyword.toJson(),
        'expr': expression.toJson(),
        'colon': colon.toJson(),
        'stmts': statements.map((s) => s.toJson()).toList(),
      };

  factory SSwitchCase.fromJson(Map<String, dynamic> json) {
    return SSwitchCase(
      labels: (json['labels'] as List)
          .map((l) => SLabel.fromJson(l as Map<String, dynamic>))
          .toList(),
      keyword: SToken.fromJson(json['case'] as Map<String, dynamic>),
      expression: _expressionFromJson(json['expr'] as Map<String, dynamic>),
      colon: SToken.fromJson(json['colon'] as Map<String, dynamic>),
      statements: (json['stmts'] as List)
          .map((s) => _statementFromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A when clause in a switch case or if-case statement.
///
/// Example: `when x > 0` in `case int x when x > 0:`
final class SWhenClause extends SAstNode {
  /// The 'when' keyword.
  final SToken whenKeyword;

  /// The guard expression.
  final SExpression expression;

  @override
  int get offset => whenKeyword.offset;

  @override
  int get end => expression.end;

  const SWhenClause({
    required this.whenKeyword,
    required this.expression,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitWhenClause(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'WhenClause',
        'when': whenKeyword.toJson(),
        'expr': expression.toJson(),
      };

  factory SWhenClause.fromJson(Map<String, dynamic> json) {
    return SWhenClause(
      whenKeyword: SToken.fromJson(json['when'] as Map<String, dynamic>),
      expression: _expressionFromJson(json['expr'] as Map<String, dynamic>),
    );
  }
}

/// A default case in a switch statement.
final class SSwitchDefault extends SSwitchMember {
  @override
  final List<SLabel> labels;

  /// The 'default' keyword.
  final SToken keyword;

  /// The colon.
  final SToken colon;

  @override
  final List<SStatement> statements;

  @override
  int get offset => labels.firstOrNull?.offset ?? keyword.offset;

  @override
  int get end => statements.lastOrNull?.end ?? colon.end;

  const SSwitchDefault({
    required this.labels,
    required this.keyword,
    required this.colon,
    required this.statements,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitSwitchDefault(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'SwitchDefault',
        'labels': labels.map((l) => l.toJson()).toList(),
        'default': keyword.toJson(),
        'colon': colon.toJson(),
        'stmts': statements.map((s) => s.toJson()).toList(),
      };

  factory SSwitchDefault.fromJson(Map<String, dynamic> json) {
    return SSwitchDefault(
      labels: (json['labels'] as List)
          .map((l) => SLabel.fromJson(l as Map<String, dynamic>))
          .toList(),
      keyword: SToken.fromJson(json['default'] as Map<String, dynamic>),
      colon: SToken.fromJson(json['colon'] as Map<String, dynamic>),
      statements: (json['stmts'] as List)
          .map((s) => _statementFromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A try statement.
///
/// Example: `try { } catch (e) { } finally { }`
final class STryStatement extends SStatement {
  /// The 'try' keyword.
  final SToken tryKeyword;

  /// The try block.
  final SBlock body;

  /// The catch clauses.
  final List<SCatchClause> catchClauses;

  /// The 'finally' keyword, if present.
  final SToken? finallyKeyword;

  /// The finally block, if present.
  final SBlock? finallyBlock;

  @override
  int get offset => tryKeyword.offset;

  @override
  int get end =>
      finallyBlock?.end ?? catchClauses.lastOrNull?.end ?? body.end;

  const STryStatement({
    required this.tryKeyword,
    required this.body,
    required this.catchClauses,
    this.finallyKeyword,
    this.finallyBlock,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitTryStatement(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'TryStatement',
        'try': tryKeyword.toJson(),
        'body': body.toJson(),
        'catches': catchClauses.map((c) => c.toJson()).toList(),
        if (finallyKeyword != null) 'finallyKw': finallyKeyword!.toJson(),
        if (finallyBlock != null) 'finally': finallyBlock!.toJson(),
      };

  factory STryStatement.fromJson(Map<String, dynamic> json) {
    return STryStatement(
      tryKeyword: SToken.fromJson(json['try'] as Map<String, dynamic>),
      body: SBlock.fromJson(json['body'] as Map<String, dynamic>),
      catchClauses: (json['catches'] as List)
          .map((c) => SCatchClause.fromJson(c as Map<String, dynamic>))
          .toList(),
      finallyKeyword: json['finallyKw'] != null
          ? SToken.fromJson(json['finallyKw'] as Map<String, dynamic>)
          : null,
      finallyBlock: json['finally'] != null
          ? SBlock.fromJson(json['finally'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// A variable declaration statement.
///
/// Example: `var x = 1;`, `final y = 'hello';`
final class SVariableDeclarationStatement extends SStatement {
  /// The variable declaration list.
  final SVariableDeclarationList variables;

  /// The semicolon.
  final SToken semicolon;

  @override
  int get offset => variables.offset;

  @override
  int get end => semicolon.end;

  const SVariableDeclarationStatement({
    required this.variables,
    required this.semicolon,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitVariableDeclarationStatement(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'VariableDeclarationStatement',
        'vars': variables.toJson(),
        'semi': semicolon.toJson(),
      };

  factory SVariableDeclarationStatement.fromJson(Map<String, dynamic> json) {
    return SVariableDeclarationStatement(
      variables: SVariableDeclarationList.fromJson(
          json['vars'] as Map<String, dynamic>),
      semicolon: SToken.fromJson(json['semi'] as Map<String, dynamic>),
    );
  }
}

/// A while statement.
///
/// Example: `while (condition) { }`
final class SWhileStatement extends SStatement {
  /// The 'while' keyword.
  final SToken whileKeyword;

  /// The left parenthesis.
  final SToken leftParenthesis;

  /// The condition.
  final SExpression condition;

  /// The right parenthesis.
  final SToken rightParenthesis;

  /// The body.
  final SStatement body;

  @override
  int get offset => whileKeyword.offset;

  @override
  int get end => body.end;

  const SWhileStatement({
    required this.whileKeyword,
    required this.leftParenthesis,
    required this.condition,
    required this.rightParenthesis,
    required this.body,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitWhileStatement(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'WhileStatement',
        'while': whileKeyword.toJson(),
        'lp': leftParenthesis.toJson(),
        'cond': condition.toJson(),
        'rp': rightParenthesis.toJson(),
        'body': body.toJson(),
      };

  factory SWhileStatement.fromJson(Map<String, dynamic> json) {
    return SWhileStatement(
      whileKeyword: SToken.fromJson(json['while'] as Map<String, dynamic>),
      leftParenthesis: SToken.fromJson(json['lp'] as Map<String, dynamic>),
      condition: _expressionFromJson(json['cond'] as Map<String, dynamic>),
      rightParenthesis: SToken.fromJson(json['rp'] as Map<String, dynamic>),
      body: _statementFromJson(json['body'] as Map<String, dynamic>),
    );
  }
}

/// A yield statement.
///
/// Example: `yield value;`, `yield* stream;`
final class SYieldStatement extends SStatement {
  /// The 'yield' keyword.
  final SToken yieldKeyword;

  /// The star for yield*, if present.
  final SToken? star;

  /// The expression being yielded.
  final SExpression expression;

  /// The semicolon.
  final SToken semicolon;

  @override
  int get offset => yieldKeyword.offset;

  @override
  int get end => semicolon.end;

  const SYieldStatement({
    required this.yieldKeyword,
    this.star,
    required this.expression,
    required this.semicolon,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitYieldStatement(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'YieldStatement',
        'yield': yieldKeyword.toJson(),
        if (star != null) 'star': star!.toJson(),
        'expr': expression.toJson(),
        'semi': semicolon.toJson(),
      };

  factory SYieldStatement.fromJson(Map<String, dynamic> json) {
    return SYieldStatement(
      yieldKeyword: SToken.fromJson(json['yield'] as Map<String, dynamic>),
      star: json['star'] != null
          ? SToken.fromJson(json['star'] as Map<String, dynamic>)
          : null,
      expression: _expressionFromJson(json['expr'] as Map<String, dynamic>),
      semicolon: SToken.fromJson(json['semi'] as Map<String, dynamic>),
    );
  }
}

/// A pattern variable declaration statement.
///
/// Example: `var (x, y) = point;`
final class SPatternVariableDeclarationStatement extends SStatement {
  /// The declaration.
  final SPatternVariableDeclaration declaration;

  /// The semicolon.
  final SToken semicolon;

  @override
  int get offset => declaration.offset;

  @override
  int get end => semicolon.end;

  const SPatternVariableDeclarationStatement({
    required this.declaration,
    required this.semicolon,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitPatternVariableDeclarationStatement(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'PatternVariableDeclarationStatement',
        'decl': declaration.toJson(),
        'semi': semicolon.toJson(),
      };

  factory SPatternVariableDeclarationStatement.fromJson(
      Map<String, dynamic> json) {
    return SPatternVariableDeclarationStatement(
      declaration: SPatternVariableDeclaration.fromJson(
          json['decl'] as Map<String, dynamic>),
      semicolon: SToken.fromJson(json['semi'] as Map<String, dynamic>),
    );
  }
}

/// A pattern variable declaration.
final class SPatternVariableDeclaration extends SAstNode {
  /// The 'var', 'final', or 'const' keyword.
  final SToken keyword;

  /// The pattern.
  final SDartPattern pattern;

  /// The equals sign.
  final SToken equals;

  /// The expression.
  final SExpression expression;

  @override
  int get offset => keyword.offset;

  @override
  int get end => expression.end;

  const SPatternVariableDeclaration({
    required this.keyword,
    required this.pattern,
    required this.equals,
    required this.expression,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitPatternVariableDeclaration(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'PatternVariableDeclaration',
        'kw': keyword.toJson(),
        'pattern': pattern.toJson(),
        'eq': equals.toJson(),
        'expr': expression.toJson(),
      };

  factory SPatternVariableDeclaration.fromJson(Map<String, dynamic> json) {
    return SPatternVariableDeclaration(
      keyword: SToken.fromJson(json['kw'] as Map<String, dynamic>),
      pattern: _patternFromJson(json['pattern'] as Map<String, dynamic>),
      equals: SToken.fromJson(json['eq'] as Map<String, dynamic>),
      expression: _expressionFromJson(json['expr'] as Map<String, dynamic>),
    );
  }
}

/// A function declaration statement (local function).
///
/// Example: `void helper() { ... }`
final class SFunctionDeclarationStatement extends SStatement {
  /// The function declaration.
  final SFunctionDeclaration functionDeclaration;

  @override
  int get offset => functionDeclaration.offset;

  @override
  int get end => functionDeclaration.end;

  const SFunctionDeclarationStatement({
    required this.functionDeclaration,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitFunctionDeclarationStatement(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'FunctionDeclarationStatement',
        'decl': functionDeclaration.toJson(),
      };

  factory SFunctionDeclarationStatement.fromJson(Map<String, dynamic> json) {
    return SFunctionDeclarationStatement(
      functionDeclaration: SFunctionDeclaration.fromJson(
          json['decl'] as Map<String, dynamic>),
    );
  }
}

/// A pattern assignment (expression).
///
/// Example: `(x, y) = swap(y, x)`
final class SPatternAssignment extends SExpression {
  /// The pattern.
  final SDartPattern pattern;

  /// The equals sign.
  final SToken equals;

  /// The expression.
  final SExpression expression;

  @override
  int get offset => pattern.offset;

  @override
  int get end => expression.end;

  const SPatternAssignment({
    required this.pattern,
    required this.equals,
    required this.expression,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitPatternAssignment(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'PatternAssignment',
        'pattern': pattern.toJson(),
        'eq': equals.toJson(),
        'expr': expression.toJson(),
      };

  factory SPatternAssignment.fromJson(Map<String, dynamic> json) {
    return SPatternAssignment(
      pattern: _patternFromJson(json['pattern'] as Map<String, dynamic>),
      equals: SToken.fromJson(json['eq'] as Map<String, dynamic>),
      expression: _expressionFromJson(json['expr'] as Map<String, dynamic>),
    );
  }
}

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/// Parses for loop parts from JSON.
SForLoopParts _forLoopPartsFromJson(Map<String, dynamic> json) {
  final type = json['type'] as String;
  return switch (type) {
    'ForPartsWithDeclarations' => SForPartsWithDeclarations.fromJson(json),
    'ForPartsWithExpression' => SForPartsWithExpression.fromJson(json),
    'ForPartsWithPattern' => SForPartsWithPattern.fromJson(json),
    'ForEachPartsWithDeclaration' => SForEachPartsWithDeclaration.fromJson(json),
    'ForEachPartsWithIdentifier' => SForEachPartsWithIdentifier.fromJson(json),
    'ForEachPartsWithPattern' => SForEachPartsWithPattern.fromJson(json),
    _ => throw FormatException('Unknown for loop parts type: $type'),
  };
}

/// Parses a switch member from JSON.
SSwitchMember _switchMemberFromJson(Map<String, dynamic> json) {
  final type = json['type'] as String;
  return switch (type) {
    'SwitchPatternCase' => SSwitchPatternCase.fromJson(json),
    'SwitchCase' => SSwitchCase.fromJson(json),
    'SwitchDefault' => SSwitchDefault.fromJson(json),
    _ => throw FormatException('Unknown switch member type: $type'),
  };
}
