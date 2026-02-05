part of '../ast.dart';

// =============================================================================
// EXPRESSION NODES
// =============================================================================

/// An assignment expression.
///
/// Example: `a = b`, `x += 1`
final class SAssignmentExpression extends SExpression {
  /// The left-hand side of the assignment.
  final SExpression leftHandSide;

  /// The assignment operator.
  final SToken operator;

  /// The right-hand side of the assignment.
  final SExpression rightHandSide;

  @override
  int get offset => leftHandSide.offset;

  @override
  int get end => rightHandSide.end;

  const SAssignmentExpression({
    required this.leftHandSide,
    required this.operator,
    required this.rightHandSide,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitAssignmentExpression(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'AssignmentExpression',
        'lhs': leftHandSide.toJson(),
        'op': operator.toJson(),
        'rhs': rightHandSide.toJson(),
      };

  factory SAssignmentExpression.fromJson(Map<String, dynamic> json) {
    return SAssignmentExpression(
      leftHandSide: _expressionFromJson(json['lhs'] as Map<String, dynamic>),
      operator: SToken.fromJson(json['op'] as Map<String, dynamic>),
      rightHandSide: _expressionFromJson(json['rhs'] as Map<String, dynamic>),
    );
  }
}

/// An await expression.
///
/// Example: `await future`
final class SAwaitExpression extends SExpression {
  /// The 'await' keyword.
  final SToken awaitKeyword;

  /// The expression being awaited.
  final SExpression expression;

  @override
  int get offset => awaitKeyword.offset;

  @override
  int get end => expression.end;

  const SAwaitExpression({
    required this.awaitKeyword,
    required this.expression,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitAwaitExpression(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'AwaitExpression',
        'await': awaitKeyword.toJson(),
        'expr': expression.toJson(),
      };

  factory SAwaitExpression.fromJson(Map<String, dynamic> json) {
    return SAwaitExpression(
      awaitKeyword: SToken.fromJson(json['await'] as Map<String, dynamic>),
      expression: _expressionFromJson(json['expr'] as Map<String, dynamic>),
    );
  }
}

/// A binary expression.
///
/// Examples: `a + b`, `x && y`, `i < 10`
final class SBinaryExpression extends SExpression {
  /// The left operand.
  final SExpression leftOperand;

  /// The binary operator.
  final SToken operator;

  /// The right operand.
  final SExpression rightOperand;

  @override
  int get offset => leftOperand.offset;

  @override
  int get end => rightOperand.end;

  const SBinaryExpression({
    required this.leftOperand,
    required this.operator,
    required this.rightOperand,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitBinaryExpression(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'BinaryExpression',
        'left': leftOperand.toJson(),
        'op': operator.toJson(),
        'right': rightOperand.toJson(),
      };

  factory SBinaryExpression.fromJson(Map<String, dynamic> json) {
    return SBinaryExpression(
      leftOperand: _expressionFromJson(json['left'] as Map<String, dynamic>),
      operator: SToken.fromJson(json['op'] as Map<String, dynamic>),
      rightOperand: _expressionFromJson(json['right'] as Map<String, dynamic>),
    );
  }
}

/// A cascade expression.
///
/// Example: `object..method1()..method2()`
final class SCascadeExpression extends SExpression {
  /// The target of the cascade.
  final SExpression target;

  /// The cascade sections.
  final List<SExpression> cascadeSections;

  @override
  int get offset => target.offset;

  @override
  int get end => cascadeSections.last.end;

  const SCascadeExpression({
    required this.target,
    required this.cascadeSections,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitCascadeExpression(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'CascadeExpression',
        'target': target.toJson(),
        'sections': cascadeSections.map((s) => s.toJson()).toList(),
      };

  factory SCascadeExpression.fromJson(Map<String, dynamic> json) {
    return SCascadeExpression(
      target: _expressionFromJson(json['target'] as Map<String, dynamic>),
      cascadeSections: (json['sections'] as List)
          .map((s) => _expressionFromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A conditional (ternary) expression.
///
/// Example: `condition ? thenExpr : elseExpr`
final class SConditionalExpression extends SExpression {
  /// The condition.
  final SExpression condition;

  /// The question mark token.
  final SToken question;

  /// The expression to evaluate if true.
  final SExpression thenExpression;

  /// The colon token.
  final SToken colon;

  /// The expression to evaluate if false.
  final SExpression elseExpression;

  @override
  int get offset => condition.offset;

  @override
  int get end => elseExpression.end;

  const SConditionalExpression({
    required this.condition,
    required this.question,
    required this.thenExpression,
    required this.colon,
    required this.elseExpression,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitConditionalExpression(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ConditionalExpression',
        'cond': condition.toJson(),
        'q': question.toJson(),
        'then': thenExpression.toJson(),
        'colon': colon.toJson(),
        'else': elseExpression.toJson(),
      };

  factory SConditionalExpression.fromJson(Map<String, dynamic> json) {
    return SConditionalExpression(
      condition: _expressionFromJson(json['cond'] as Map<String, dynamic>),
      question: SToken.fromJson(json['q'] as Map<String, dynamic>),
      thenExpression: _expressionFromJson(json['then'] as Map<String, dynamic>),
      colon: SToken.fromJson(json['colon'] as Map<String, dynamic>),
      elseExpression: _expressionFromJson(json['else'] as Map<String, dynamic>),
    );
  }
}

/// A function expression (closure/lambda).
///
/// Example: `(x) => x * 2`, `() { print('hello'); }`
final class SFunctionExpression extends SExpression {
  /// The type parameters, if any.
  final STypeParameterList? typeParameters;

  /// The parameters.
  final SFormalParameterList parameters;

  /// The function body.
  final SFunctionBody body;

  @override
  int get offset => typeParameters?.offset ?? parameters.offset;

  @override
  int get end => body.end;

  const SFunctionExpression({
    this.typeParameters,
    required this.parameters,
    required this.body,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitFunctionExpression(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'FunctionExpression',
        if (typeParameters != null) 'typeParams': typeParameters!.toJson(),
        'params': parameters.toJson(),
        'body': body.toJson(),
      };

  factory SFunctionExpression.fromJson(Map<String, dynamic> json) {
    return SFunctionExpression(
      typeParameters: json['typeParams'] != null
          ? STypeParameterList.fromJson(
              json['typeParams'] as Map<String, dynamic>)
          : null,
      parameters: SFormalParameterList.fromJson(
          json['params'] as Map<String, dynamic>),
      body: _functionBodyFromJson(json['body'] as Map<String, dynamic>),
    );
  }
}

/// A function expression invocation.
///
/// Example: `(() => 42)()`
final class SFunctionExpressionInvocation extends SExpression {
  /// The function expression being invoked.
  final SExpression function;

  /// The type arguments, if any.
  final STypeArgumentList? typeArguments;

  /// The arguments.
  final SArgumentList argumentList;

  @override
  int get offset => function.offset;

  @override
  int get end => argumentList.end;

  const SFunctionExpressionInvocation({
    required this.function,
    this.typeArguments,
    required this.argumentList,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitFunctionExpressionInvocation(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'FunctionExpressionInvocation',
        'func': function.toJson(),
        if (typeArguments != null) 'typeArgs': typeArguments!.toJson(),
        'args': argumentList.toJson(),
      };

  factory SFunctionExpressionInvocation.fromJson(Map<String, dynamic> json) {
    return SFunctionExpressionInvocation(
      function: _expressionFromJson(json['func'] as Map<String, dynamic>),
      typeArguments: json['typeArgs'] != null
          ? STypeArgumentList.fromJson(json['typeArgs'] as Map<String, dynamic>)
          : null,
      argumentList:
          SArgumentList.fromJson(json['args'] as Map<String, dynamic>),
    );
  }
}

/// An index expression.
///
/// Example: `list[0]`, `map['key']`
final class SIndexExpression extends SExpression {
  /// The target of the index.
  final SExpression? target;

  /// The period for cascade access, if any.
  final SToken? period;

  /// The question mark for null-aware access, if any.
  final SToken? question;

  /// The left bracket.
  final SToken leftBracket;

  /// The index expression.
  final SExpression index;

  /// The right bracket.
  final SToken rightBracket;

  @override
  int get offset => target?.offset ?? period?.offset ?? leftBracket.offset;

  @override
  int get end => rightBracket.end;

  /// Whether this is a cascade index.
  bool get isCascaded => period != null;

  /// Whether this is null-aware.
  bool get isNullAware => question != null;

  const SIndexExpression({
    this.target,
    this.period,
    this.question,
    required this.leftBracket,
    required this.index,
    required this.rightBracket,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitIndexExpression(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'IndexExpression',
        if (target != null) 'target': target!.toJson(),
        if (period != null) 'period': period!.toJson(),
        if (question != null) 'q': question!.toJson(),
        'lb': leftBracket.toJson(),
        'index': index.toJson(),
        'rb': rightBracket.toJson(),
      };

  factory SIndexExpression.fromJson(Map<String, dynamic> json) {
    return SIndexExpression(
      target: json['target'] != null
          ? _expressionFromJson(json['target'] as Map<String, dynamic>)
          : null,
      period: json['period'] != null
          ? SToken.fromJson(json['period'] as Map<String, dynamic>)
          : null,
      question: json['q'] != null
          ? SToken.fromJson(json['q'] as Map<String, dynamic>)
          : null,
      leftBracket: SToken.fromJson(json['lb'] as Map<String, dynamic>),
      index: _expressionFromJson(json['index'] as Map<String, dynamic>),
      rightBracket: SToken.fromJson(json['rb'] as Map<String, dynamic>),
    );
  }
}

/// An instance creation expression (constructor invocation).
///
/// Example: `new Foo()`, `const Bar(42)`, `MyClass.named()`
final class SInstanceCreationExpression extends SExpression {
  /// The 'new' or 'const' keyword, if present.
  final SToken? keyword;

  /// The constructor name.
  final SConstructorName constructorName;

  /// The type arguments, if any.
  final STypeArgumentList? typeArguments;

  /// The arguments.
  final SArgumentList argumentList;

  @override
  int get offset => keyword?.offset ?? constructorName.offset;

  @override
  int get end => argumentList.end;

  /// Whether this is a const expression.
  bool get isConst => keyword?.type == STokenType.$const;

  const SInstanceCreationExpression({
    this.keyword,
    required this.constructorName,
    this.typeArguments,
    required this.argumentList,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitInstanceCreationExpression(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'InstanceCreationExpression',
        if (keyword != null) 'kw': keyword!.toJson(),
        'ctor': constructorName.toJson(),
        if (typeArguments != null) 'typeArgs': typeArguments!.toJson(),
        'args': argumentList.toJson(),
      };

  factory SInstanceCreationExpression.fromJson(Map<String, dynamic> json) {
    return SInstanceCreationExpression(
      keyword: json['kw'] != null
          ? SToken.fromJson(json['kw'] as Map<String, dynamic>)
          : null,
      constructorName: SConstructorName.fromJson(
          json['ctor'] as Map<String, dynamic>),
      typeArguments: json['typeArgs'] != null
          ? STypeArgumentList.fromJson(json['typeArgs'] as Map<String, dynamic>)
          : null,
      argumentList:
          SArgumentList.fromJson(json['args'] as Map<String, dynamic>),
    );
  }
}

/// A constructor name.
final class SConstructorName extends SAstNode {
  /// The type being constructed.
  final SNamedType type;

  /// The period before the constructor name, if named.
  final SToken? period;

  /// The constructor name, if named.
  final SSimpleIdentifier? name;

  @override
  int get offset => type.offset;

  @override
  int get end => name?.end ?? type.end;

  const SConstructorName({
    required this.type,
    this.period,
    this.name,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitConstructorName(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ConstructorName',
        'ctorType': type.toJson(),
        if (period != null) 'period': period!.toJson(),
        if (name != null) 'name': name!.toJson(),
      };

  factory SConstructorName.fromJson(Map<String, dynamic> json) {
    return SConstructorName(
      type: SNamedType.fromJson(json['ctorType'] as Map<String, dynamic>),
      period: json['period'] != null
          ? SToken.fromJson(json['period'] as Map<String, dynamic>)
          : null,
      name: json['name'] != null
          ? SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// An 'is' expression.
///
/// Example: `obj is String`, `x is! int`
final class SIsExpression extends SExpression {
  /// The expression being tested.
  final SExpression expression;

  /// The 'is' keyword.
  final SToken isOperator;

  /// The '!' for negation, if present.
  final SToken? notOperator;

  /// The type being tested against.
  final STypeAnnotation type;

  @override
  int get offset => expression.offset;

  @override
  int get end => type.end;

  const SIsExpression({
    required this.expression,
    required this.isOperator,
    this.notOperator,
    required this.type,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitIsExpression(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'IsExpression',
        'expr': expression.toJson(),
        'is': isOperator.toJson(),
        if (notOperator != null) 'not': notOperator!.toJson(),
        'testType': type.toJson(),
      };

  factory SIsExpression.fromJson(Map<String, dynamic> json) {
    return SIsExpression(
      expression: _expressionFromJson(json['expr'] as Map<String, dynamic>),
      isOperator: SToken.fromJson(json['is'] as Map<String, dynamic>),
      notOperator: json['not'] != null
          ? SToken.fromJson(json['not'] as Map<String, dynamic>)
          : null,
      type: _typeFromJson(json['testType'] as Map<String, dynamic>),
    );
  }
}

/// An 'as' expression.
///
/// Example: `obj as String`
final class SAsExpression extends SExpression {
  /// The expression being cast.
  final SExpression expression;

  /// The 'as' keyword.
  final SToken asOperator;

  /// The type being cast to.
  final STypeAnnotation type;

  @override
  int get offset => expression.offset;

  @override
  int get end => type.end;

  const SAsExpression({
    required this.expression,
    required this.asOperator,
    required this.type,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitAsExpression(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'AsExpression',
        'expr': expression.toJson(),
        'as': asOperator.toJson(),
        'castType': type.toJson(),
      };

  factory SAsExpression.fromJson(Map<String, dynamic> json) {
    return SAsExpression(
      expression: _expressionFromJson(json['expr'] as Map<String, dynamic>),
      asOperator: SToken.fromJson(json['as'] as Map<String, dynamic>),
      type: _typeFromJson(json['castType'] as Map<String, dynamic>),
    );
  }
}

/// A method invocation.
///
/// Example: `obj.method()`, `list.add(item)`
final class SMethodInvocation extends SExpression {
  /// The target of the method, if any.
  final SExpression? target;

  /// The operator (. or ?. or ..).
  final SToken? operator;

  /// The method name.
  final SSimpleIdentifier methodName;

  /// The type arguments, if any.
  final STypeArgumentList? typeArguments;

  /// The arguments.
  final SArgumentList argumentList;

  @override
  int get offset => target?.offset ?? methodName.offset;

  @override
  int get end => argumentList.end;

  /// Whether this is a cascade method invocation.
  bool get isCascaded =>
      operator?.type == STokenType.periodPeriod;

  const SMethodInvocation({
    this.target,
    this.operator,
    required this.methodName,
    this.typeArguments,
    required this.argumentList,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitMethodInvocation(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'MethodInvocation',
        if (target != null) 'target': target!.toJson(),
        if (operator != null) 'op': operator!.toJson(),
        'method': methodName.toJson(),
        if (typeArguments != null) 'typeArgs': typeArguments!.toJson(),
        'args': argumentList.toJson(),
      };

  factory SMethodInvocation.fromJson(Map<String, dynamic> json) {
    return SMethodInvocation(
      target: json['target'] != null
          ? _expressionFromJson(json['target'] as Map<String, dynamic>)
          : null,
      operator: json['op'] != null
          ? SToken.fromJson(json['op'] as Map<String, dynamic>)
          : null,
      methodName:
          SSimpleIdentifier.fromJson(json['method'] as Map<String, dynamic>),
      typeArguments: json['typeArgs'] != null
          ? STypeArgumentList.fromJson(json['typeArgs'] as Map<String, dynamic>)
          : null,
      argumentList:
          SArgumentList.fromJson(json['args'] as Map<String, dynamic>),
    );
  }
}

/// A named expression (named argument in function call).
///
/// Example: `name: value`
final class SNamedExpression extends SExpression {
  /// The name and colon.
  final SLabel name;

  /// The value expression.
  final SExpression expression;

  @override
  int get offset => name.offset;

  @override
  int get end => expression.end;

  const SNamedExpression({
    required this.name,
    required this.expression,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitNamedExpression(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'NamedExpression',
        'name': name.toJson(),
        'expr': expression.toJson(),
      };

  factory SNamedExpression.fromJson(Map<String, dynamic> json) {
    return SNamedExpression(
      name: SLabel.fromJson(json['name'] as Map<String, dynamic>),
      expression: _expressionFromJson(json['expr'] as Map<String, dynamic>),
    );
  }
}

/// A label (name: colon pair).
final class SLabel extends SAstNode {
  /// The label name.
  final SSimpleIdentifier label;

  /// The colon.
  final SToken colon;

  @override
  int get offset => label.offset;

  @override
  int get end => colon.end;

  const SLabel({
    required this.label,
    required this.colon,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitLabel(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'Label',
        'label': label.toJson(),
        'colon': colon.toJson(),
      };

  factory SLabel.fromJson(Map<String, dynamic> json) {
    return SLabel(
      label: SSimpleIdentifier.fromJson(json['label'] as Map<String, dynamic>),
      colon: SToken.fromJson(json['colon'] as Map<String, dynamic>),
    );
  }
}

/// A parenthesized expression.
///
/// Example: `(a + b)`
final class SParenthesizedExpression extends SExpression {
  /// The left parenthesis.
  final SToken leftParenthesis;

  /// The expression.
  final SExpression expression;

  /// The right parenthesis.
  final SToken rightParenthesis;

  @override
  int get offset => leftParenthesis.offset;

  @override
  int get end => rightParenthesis.end;

  const SParenthesizedExpression({
    required this.leftParenthesis,
    required this.expression,
    required this.rightParenthesis,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitParenthesizedExpression(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ParenthesizedExpression',
        'lp': leftParenthesis.toJson(),
        'expr': expression.toJson(),
        'rp': rightParenthesis.toJson(),
      };

  factory SParenthesizedExpression.fromJson(Map<String, dynamic> json) {
    return SParenthesizedExpression(
      leftParenthesis: SToken.fromJson(json['lp'] as Map<String, dynamic>),
      expression: _expressionFromJson(json['expr'] as Map<String, dynamic>),
      rightParenthesis: SToken.fromJson(json['rp'] as Map<String, dynamic>),
    );
  }
}

/// A postfix expression.
///
/// Example: `i++`, `j--`, `obj!`
final class SPostfixExpression extends SExpression {
  /// The operand.
  final SExpression operand;

  /// The operator.
  final SToken operator;

  @override
  int get offset => operand.offset;

  @override
  int get end => operator.end;

  const SPostfixExpression({
    required this.operand,
    required this.operator,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitPostfixExpression(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'PostfixExpression',
        'operand': operand.toJson(),
        'op': operator.toJson(),
      };

  factory SPostfixExpression.fromJson(Map<String, dynamic> json) {
    return SPostfixExpression(
      operand: _expressionFromJson(json['operand'] as Map<String, dynamic>),
      operator: SToken.fromJson(json['op'] as Map<String, dynamic>),
    );
  }
}

/// A prefix expression.
///
/// Example: `-x`, `!flag`, `++i`
final class SPrefixExpression extends SExpression {
  /// The operator.
  final SToken operator;

  /// The operand.
  final SExpression operand;

  @override
  int get offset => operator.offset;

  @override
  int get end => operand.end;

  const SPrefixExpression({
    required this.operator,
    required this.operand,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitPrefixExpression(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'PrefixExpression',
        'op': operator.toJson(),
        'operand': operand.toJson(),
      };

  factory SPrefixExpression.fromJson(Map<String, dynamic> json) {
    return SPrefixExpression(
      operator: SToken.fromJson(json['op'] as Map<String, dynamic>),
      operand: _expressionFromJson(json['operand'] as Map<String, dynamic>),
    );
  }
}

/// A property access expression.
///
/// Example: `obj.property`, `obj?.property`
final class SPropertyAccess extends SExpression {
  /// The target of the property access.
  final SExpression? target;

  /// The operator (. or ?. or ..).
  final SToken operator;

  /// The property name.
  final SSimpleIdentifier propertyName;

  @override
  int get offset => target?.offset ?? operator.offset;

  @override
  int get end => propertyName.end;

  /// Whether this is a cascade property access.
  bool get isCascaded =>
      operator.type == STokenType.periodPeriod;

  const SPropertyAccess({
    this.target,
    required this.operator,
    required this.propertyName,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitPropertyAccess(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'PropertyAccess',
        if (target != null) 'target': target!.toJson(),
        'op': operator.toJson(),
        'property': propertyName.toJson(),
      };

  factory SPropertyAccess.fromJson(Map<String, dynamic> json) {
    return SPropertyAccess(
      target: json['target'] != null
          ? _expressionFromJson(json['target'] as Map<String, dynamic>)
          : null,
      operator: SToken.fromJson(json['op'] as Map<String, dynamic>),
      propertyName:
          SSimpleIdentifier.fromJson(json['property'] as Map<String, dynamic>),
    );
  }
}

/// A rethrow expression.
///
/// Example: `rethrow`
final class SRethrowExpression extends SExpression {
  /// The 'rethrow' keyword.
  final SToken rethrowKeyword;

  @override
  int get offset => rethrowKeyword.offset;

  @override
  int get end => rethrowKeyword.end;

  const SRethrowExpression({required this.rethrowKeyword});

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitRethrowExpression(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'RethrowExpression',
        'rethrow': rethrowKeyword.toJson(),
      };

  factory SRethrowExpression.fromJson(Map<String, dynamic> json) {
    return SRethrowExpression(
      rethrowKeyword: SToken.fromJson(json['rethrow'] as Map<String, dynamic>),
    );
  }
}

/// A 'super' expression.
///
/// Example: `super`
final class SSuperExpression extends SExpression {
  /// The 'super' keyword.
  final SToken superKeyword;

  @override
  int get offset => superKeyword.offset;

  @override
  int get end => superKeyword.end;

  const SSuperExpression({required this.superKeyword});

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitSuperExpression(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'SuperExpression',
        'super': superKeyword.toJson(),
      };

  factory SSuperExpression.fromJson(Map<String, dynamic> json) {
    return SSuperExpression(
      superKeyword: SToken.fromJson(json['super'] as Map<String, dynamic>),
    );
  }
}

/// A 'this' expression.
///
/// Example: `this`
final class SThisExpression extends SExpression {
  /// The 'this' keyword.
  final SToken thisKeyword;

  @override
  int get offset => thisKeyword.offset;

  @override
  int get end => thisKeyword.end;

  const SThisExpression({required this.thisKeyword});

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitThisExpression(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ThisExpression',
        'this': thisKeyword.toJson(),
      };

  factory SThisExpression.fromJson(Map<String, dynamic> json) {
    return SThisExpression(
      thisKeyword: SToken.fromJson(json['this'] as Map<String, dynamic>),
    );
  }
}

/// A throw expression.
///
/// Example: `throw Exception('error')`
final class SThrowExpression extends SExpression {
  /// The 'throw' keyword.
  final SToken throwKeyword;

  /// The expression being thrown.
  final SExpression expression;

  @override
  int get offset => throwKeyword.offset;

  @override
  int get end => expression.end;

  const SThrowExpression({
    required this.throwKeyword,
    required this.expression,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitThrowExpression(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ThrowExpression',
        'throw': throwKeyword.toJson(),
        'expr': expression.toJson(),
      };

  factory SThrowExpression.fromJson(Map<String, dynamic> json) {
    return SThrowExpression(
      throwKeyword: SToken.fromJson(json['throw'] as Map<String, dynamic>),
      expression: _expressionFromJson(json['expr'] as Map<String, dynamic>),
    );
  }
}

/// A constructor reference.
///
/// Example: `MyClass.new`, `MyClass.named`
final class SConstructorReference extends SExpression {
  /// The constructor name.
  final SConstructorName constructorName;

  @override
  int get offset => constructorName.offset;

  @override
  int get end => constructorName.end;

  const SConstructorReference({required this.constructorName});

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitConstructorReference(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ConstructorReference',
        'ctor': constructorName.toJson(),
      };

  factory SConstructorReference.fromJson(Map<String, dynamic> json) {
    return SConstructorReference(
      constructorName:
          SConstructorName.fromJson(json['ctor'] as Map<String, dynamic>),
    );
  }
}

/// A function reference (tear-off).
///
/// Example: `print`, `list.add`
final class SFunctionReference extends SExpression {
  /// The function being referenced.
  final SExpression function;

  /// The type arguments, if any.
  final STypeArgumentList? typeArguments;

  @override
  int get offset => function.offset;

  @override
  int get end => typeArguments?.end ?? function.end;

  const SFunctionReference({
    required this.function,
    this.typeArguments,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitFunctionReference(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'FunctionReference',
        'func': function.toJson(),
        if (typeArguments != null) 'typeArgs': typeArguments!.toJson(),
      };

  factory SFunctionReference.fromJson(Map<String, dynamic> json) {
    return SFunctionReference(
      function: _expressionFromJson(json['func'] as Map<String, dynamic>),
      typeArguments: json['typeArgs'] != null
          ? STypeArgumentList.fromJson(json['typeArgs'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// A switch expression.
///
/// Example: `switch (x) { 1 => 'one', _ => 'other' }`
final class SSwitchExpression extends SExpression {
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

  /// The switch cases.
  final List<SSwitchExpressionCase> cases;

  /// The right brace.
  final SToken rightBrace;

  @override
  int get offset => switchKeyword.offset;

  @override
  int get end => rightBrace.end;

  const SSwitchExpression({
    required this.switchKeyword,
    required this.leftParenthesis,
    required this.expression,
    required this.rightParenthesis,
    required this.leftBrace,
    required this.cases,
    required this.rightBrace,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitSwitchExpression(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'SwitchExpression',
        'switch': switchKeyword.toJson(),
        'lp': leftParenthesis.toJson(),
        'expr': expression.toJson(),
        'rp': rightParenthesis.toJson(),
        'lb': leftBrace.toJson(),
        'cases': cases.map((c) => c.toJson()).toList(),
        'rb': rightBrace.toJson(),
      };

  factory SSwitchExpression.fromJson(Map<String, dynamic> json) {
    return SSwitchExpression(
      switchKeyword: SToken.fromJson(json['switch'] as Map<String, dynamic>),
      leftParenthesis: SToken.fromJson(json['lp'] as Map<String, dynamic>),
      expression: _expressionFromJson(json['expr'] as Map<String, dynamic>),
      rightParenthesis: SToken.fromJson(json['rp'] as Map<String, dynamic>),
      leftBrace: SToken.fromJson(json['lb'] as Map<String, dynamic>),
      cases: (json['cases'] as List)
          .map((c) =>
              SSwitchExpressionCase.fromJson(c as Map<String, dynamic>))
          .toList(),
      rightBrace: SToken.fromJson(json['rb'] as Map<String, dynamic>),
    );
  }
}

/// A case in a switch expression.
final class SSwitchExpressionCase extends SAstNode {
  /// The guard pattern.
  final SGuardedPattern guardedPattern;

  /// The arrow token.
  final SToken arrow;

  /// The expression for this case.
  final SExpression expression;

  @override
  int get offset => guardedPattern.offset;

  @override
  int get end => expression.end;

  const SSwitchExpressionCase({
    required this.guardedPattern,
    required this.arrow,
    required this.expression,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitSwitchExpressionCase(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'SwitchExpressionCase',
        'pattern': guardedPattern.toJson(),
        'arrow': arrow.toJson(),
        'expr': expression.toJson(),
      };

  factory SSwitchExpressionCase.fromJson(Map<String, dynamic> json) {
    return SSwitchExpressionCase(
      guardedPattern:
          SGuardedPattern.fromJson(json['pattern'] as Map<String, dynamic>),
      arrow: SToken.fromJson(json['arrow'] as Map<String, dynamic>),
      expression: _expressionFromJson(json['expr'] as Map<String, dynamic>),
    );
  }
}

/// A guarded pattern (pattern with optional when clause).
final class SGuardedPattern extends SAstNode {
  /// The pattern.
  final SDartPattern pattern;

  /// The 'when' keyword, if present.
  final SToken? whenClause;

  /// The guard expression, if present.
  final SExpression? guard;

  @override
  int get offset => pattern.offset;

  @override
  int get end => guard?.end ?? pattern.end;

  const SGuardedPattern({
    required this.pattern,
    this.whenClause,
    this.guard,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitGuardedPattern(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'GuardedPattern',
        'pattern': pattern.toJson(),
        if (whenClause != null) 'when': whenClause!.toJson(),
        if (guard != null) 'guard': guard!.toJson(),
      };

  factory SGuardedPattern.fromJson(Map<String, dynamic> json) {
    return SGuardedPattern(
      pattern: _patternFromJson(json['pattern'] as Map<String, dynamic>),
      whenClause: json['when'] != null
          ? SToken.fromJson(json['when'] as Map<String, dynamic>)
          : null,
      guard: json['guard'] != null
          ? _expressionFromJson(json['guard'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// A dot shorthand invocation expression.
///
/// Example: `.methodName(args)` in a context where the receiver is implicit.
final class SDotShorthandInvocation extends SExpression {
  /// The token representing the period.
  final SToken period;

  /// The name of the method being invoked.
  final SSimpleIdentifier memberName;

  /// The type arguments, if any.
  final STypeArgumentList? typeArguments;

  /// The argument list.
  final SArgumentList argumentList;

  @override
  int get offset => period.offset;

  @override
  int get end => argumentList.end;

  const SDotShorthandInvocation({
    required this.period,
    required this.memberName,
    this.typeArguments,
    required this.argumentList,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitDotShorthandInvocation(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'DotShorthandInvocation',
        'period': period.toJson(),
        'member': memberName.toJson(),
        if (typeArguments != null) 'typeArgs': typeArguments!.toJson(),
        'args': argumentList.toJson(),
      };

  factory SDotShorthandInvocation.fromJson(Map<String, dynamic> json) {
    return SDotShorthandInvocation(
      period: SToken.fromJson(json['period'] as Map<String, dynamic>),
      memberName:
          SSimpleIdentifier.fromJson(json['member'] as Map<String, dynamic>),
      typeArguments: json['typeArgs'] != null
          ? STypeArgumentList.fromJson(
              json['typeArgs'] as Map<String, dynamic>)
          : null,
      argumentList:
          SArgumentList.fromJson(json['args'] as Map<String, dynamic>),
    );
  }
}

/// A dot shorthand property access expression.
///
/// Example: `.propertyName` in a context where the receiver is implicit.
final class SDotShorthandPropertyAccess extends SExpression {
  /// The token representing the period.
  final SToken period;

  /// The name of the property being accessed.
  final SSimpleIdentifier propertyName;

  @override
  int get offset => period.offset;

  @override
  int get end => propertyName.end;

  const SDotShorthandPropertyAccess({
    required this.period,
    required this.propertyName,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitDotShorthandPropertyAccess(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'DotShorthandPropertyAccess',
        'period': period.toJson(),
        'property': propertyName.toJson(),
      };

  factory SDotShorthandPropertyAccess.fromJson(Map<String, dynamic> json) {
    return SDotShorthandPropertyAccess(
      period: SToken.fromJson(json['period'] as Map<String, dynamic>),
      propertyName:
          SSimpleIdentifier.fromJson(json['property'] as Map<String, dynamic>),
    );
  }
}

/// A dot shorthand constructor invocation.
///
/// Example: `.named(args)` where the type is inferred from context.
final class SDotShorthandConstructorInvocation extends SExpression {
  /// The 'const' keyword, if present.
  final SToken? constKeyword;

  /// The period before the constructor name.
  final SToken period;

  /// The constructor name.
  final SSimpleIdentifier constructorName;

  /// The type arguments, if any.
  final STypeArgumentList? typeArguments;

  /// The argument list.
  final SArgumentList argumentList;

  @override
  int get offset => constKeyword?.offset ?? period.offset;

  @override
  int get end => argumentList.end;

  const SDotShorthandConstructorInvocation({
    this.constKeyword,
    required this.period,
    required this.constructorName,
    this.typeArguments,
    required this.argumentList,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitDotShorthandConstructorInvocation(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'DotShorthandConstructorInvocation',
        if (constKeyword != null) 'const': constKeyword!.toJson(),
        'period': period.toJson(),
        'ctorName': constructorName.toJson(),
        if (typeArguments != null) 'typeArgs': typeArguments!.toJson(),
        'args': argumentList.toJson(),
      };

  factory SDotShorthandConstructorInvocation.fromJson(
      Map<String, dynamic> json) {
    return SDotShorthandConstructorInvocation(
      constKeyword: json['const'] != null
          ? SToken.fromJson(json['const'] as Map<String, dynamic>)
          : null,
      period: SToken.fromJson(json['period'] as Map<String, dynamic>),
      constructorName: SSimpleIdentifier.fromJson(
          json['ctorName'] as Map<String, dynamic>),
      typeArguments: json['typeArgs'] != null
          ? STypeArgumentList.fromJson(
              json['typeArgs'] as Map<String, dynamic>)
          : null,
      argumentList:
          SArgumentList.fromJson(json['args'] as Map<String, dynamic>),
    );
  }
}

/// An extension override expression.
///
/// Example: `E(expr)` where E is an extension.
final class SExtensionOverride extends SExpression {
  /// The name of the extension.
  final SIdentifier extensionName;

  /// The type arguments, if any.
  final STypeArgumentList? typeArguments;

  /// The argument list.
  final SArgumentList argumentList;

  @override
  int get offset => extensionName.offset;

  @override
  int get end => argumentList.end;

  const SExtensionOverride({
    required this.extensionName,
    this.typeArguments,
    required this.argumentList,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitExtensionOverride(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ExtensionOverride',
        'name': extensionName.toJson(),
        if (typeArguments != null) 'typeArgs': typeArguments!.toJson(),
        'args': argumentList.toJson(),
      };

  factory SExtensionOverride.fromJson(Map<String, dynamic> json) {
    return SExtensionOverride(
      extensionName:
          _identifierFromJson(json['name'] as Map<String, dynamic>),
      typeArguments: json['typeArgs'] != null
          ? STypeArgumentList.fromJson(
              json['typeArgs'] as Map<String, dynamic>)
          : null,
      argumentList:
          SArgumentList.fromJson(json['args'] as Map<String, dynamic>),
    );
  }
}

/// An implicit call reference (function reference without call syntax).
///
/// This is used when a callable object is referenced without invoking it.
final class SImplicitCallReference extends SExpression {
  /// The expression.
  final SExpression expression;

  /// The type arguments, if any.
  final STypeArgumentList? typeArguments;

  @override
  int get offset => expression.offset;

  @override
  int get end => typeArguments?.end ?? expression.end;

  const SImplicitCallReference({
    required this.expression,
    this.typeArguments,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitImplicitCallReference(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ImplicitCallReference',
        'expr': expression.toJson(),
        if (typeArguments != null) 'typeArgs': typeArguments!.toJson(),
      };

  factory SImplicitCallReference.fromJson(Map<String, dynamic> json) {
    return SImplicitCallReference(
      expression: _expressionFromJson(json['expr'] as Map<String, dynamic>),
      typeArguments: json['typeArgs'] != null
          ? STypeArgumentList.fromJson(
              json['typeArgs'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// A type literal expression.
///
/// Example: `int` (the type itself, not an instance creation).
final class STypeLiteral extends SExpression {
  /// The type name.
  final SNamedType typeName;

  @override
  int get offset => typeName.offset;

  @override
  int get end => typeName.end;

  const STypeLiteral({
    required this.typeName,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitTypeLiteral(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'TypeLiteral',
        'typeName': typeName.toJson(),
      };

  factory STypeLiteral.fromJson(Map<String, dynamic> json) {
    return STypeLiteral(
      typeName: SNamedType.fromJson(json['typeName'] as Map<String, dynamic>),
    );
  }
}

// =============================================================================
// COMMENT REFERENCE
// =============================================================================

/// A reference to a declaration in a documentation comment.
///
/// Example: `[MyClass]` in a doc comment.
final class SCommentReference extends SAstNode {
  /// The 'new' keyword, if any.
  final SToken? newKeyword;

  /// The expression being referenced.
  final SExpression expression;

  /// Whether this is a synthetic reference.
  final bool isSynthetic;

  @override
  int get offset => newKeyword?.offset ?? expression.offset;

  @override
  int get end => expression.end;

  const SCommentReference({
    this.newKeyword,
    required this.expression,
    this.isSynthetic = false,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitCommentReference(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'CommentReference',
        if (newKeyword != null) 'new': newKeyword!.toJson(),
        'expr': expression.toJson(),
        if (isSynthetic) 'synthetic': true,
      };

  factory SCommentReference.fromJson(Map<String, dynamic> json) {
    return SCommentReference(
      newKeyword: json['new'] != null
          ? SToken.fromJson(json['new'] as Map<String, dynamic>)
          : null,
      expression: _expressionFromJson(json['expr'] as Map<String, dynamic>),
      isSynthetic: json['synthetic'] as bool? ?? false,
    );
  }
}

/// A constant expression context wrapper.
///
/// Used internally to track constant context for expressions.
final class SConstantContextForExpression extends SAstNode {
  /// The expression being wrapped.
  final SExpression expression;

  @override
  int get offset => expression.offset;

  @override
  int get end => expression.end;

  const SConstantContextForExpression({
    required this.expression,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitConstantContextForExpression(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ConstantContextForExpression',
        'expr': expression.toJson(),
      };

  factory SConstantContextForExpression.fromJson(Map<String, dynamic> json) {
    return SConstantContextForExpression(
      expression: _expressionFromJson(json['expr'] as Map<String, dynamic>),
    );
  }
}

/// A constructor selector in enum constant arguments.
///
/// Example: `.named` in `MyEnum.value.named(1, 2)`.
final class SConstructorSelector extends SAstNode {
  /// The period before the constructor name.
  final SToken period;

  /// The constructor name.
  final SSimpleIdentifier name;

  @override
  int get offset => period.offset;

  @override
  int get end => name.end;

  const SConstructorSelector({
    required this.period,
    required this.name,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitConstructorSelector(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ConstructorSelector',
        'period': period.toJson(),
        'name': name.toJson(),
      };

  factory SConstructorSelector.fromJson(Map<String, dynamic> json) {
    return SConstructorSelector(
      period: SToken.fromJson(json['period'] as Map<String, dynamic>),
      name: SSimpleIdentifier.fromJson(json['name'] as Map<String, dynamic>),
    );
  }
}

/// Arguments for an enum constant declaration.
///
/// Example: `<int>.named(1)` in `enum E { v<int>.named(1) }`.
final class SEnumConstantArguments extends SAstNode {
  /// The type arguments.
  final STypeArgumentList? typeArguments;

  /// The constructor selector.
  final SConstructorSelector? constructorSelector;

  /// The argument list.
  final SArgumentList argumentList;

  @override
  int get offset =>
      typeArguments?.offset ??
      constructorSelector?.offset ??
      argumentList.offset;

  @override
  int get end => argumentList.end;

  const SEnumConstantArguments({
    this.typeArguments,
    this.constructorSelector,
    required this.argumentList,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitEnumConstantArguments(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'EnumConstantArguments',
        if (typeArguments != null) 'typeArgs': typeArguments!.toJson(),
        if (constructorSelector != null)
          'ctorSelector': constructorSelector!.toJson(),
        'args': argumentList.toJson(),
      };

  factory SEnumConstantArguments.fromJson(Map<String, dynamic> json) {
    return SEnumConstantArguments(
      typeArguments: json['typeArgs'] != null
          ? STypeArgumentList.fromJson(
              json['typeArgs'] as Map<String, dynamic>)
          : null,
      constructorSelector: json['ctorSelector'] != null
          ? SConstructorSelector.fromJson(
              json['ctorSelector'] as Map<String, dynamic>)
          : null,
      argumentList:
          SArgumentList.fromJson(json['args'] as Map<String, dynamic>),
    );
  }
}

/// A reference to an import prefix.
///
/// Example: `prefix.` in `prefix.someFunction()`.
final class SImportPrefixReference extends SAstNode {
  /// The name of the prefix.
  final SToken name;

  /// The period after the prefix.
  final SToken period;

  @override
  int get offset => name.offset;

  @override
  int get end => period.end;

  const SImportPrefixReference({
    required this.name,
    required this.period,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) =>
      visitor.visitImportPrefixReference(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ImportPrefixReference',
        'name': name.toJson(),
        'period': period.toJson(),
      };

  factory SImportPrefixReference.fromJson(Map<String, dynamic> json) {
    return SImportPrefixReference(
      name: SToken.fromJson(json['name'] as Map<String, dynamic>),
      period: SToken.fromJson(json['period'] as Map<String, dynamic>),
    );
  }
}
