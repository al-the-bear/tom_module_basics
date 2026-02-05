/// Serializable token representation.
///
/// Replaces the analyzer's `Token` class with a simple data class
/// that can be serialized.
library;

/// Token type enumeration matching analyzer's TokenType.
///
/// Each token type has a [lexeme] property containing the textual
/// representation (for keywords and operators) or empty string
/// (for identifiers and literals).
enum STokenType {
  // Keywords - use $ prefix to avoid reserved word conflicts
  $abstract('abstract'),
  $as('as'),
  $assert('assert'),
  $async('async'),
  $augment('augment'),
  $await('await'),
  $base('base'),
  $break('break'),
  $case('case'),
  $catch('catch'),
  $class('class'),
  $const('const'),
  $continue('continue'),
  $covariant('covariant'),
  $default('default'),
  $deferred('deferred'),
  $do('do'),
  $dynamic('dynamic'),
  $else('else'),
  $enum('enum'),
  $export('export'),
  $extends('extends'),
  $extension('extension'),
  $external('external'),
  $factory('factory'),
  $false('false'),
  $final('final'),
  $finally('finally'),
  $for('for'),
  $Function('Function'),
  $get('get'),
  $hide('hide'),
  $if('if'),
  $implements('implements'),
  $import('import'),
  $in('in'),
  $inline('inline'),
  $interface('interface'),
  $is('is'),
  $late('late'),
  $library('library'),
  $macro('macro'),
  $mixin('mixin'),
  $native('native'),
  $new('new'),
  $null('null'),
  $of('of'),
  $on('on'),
  $operator('operator'),
  $part('part'),
  $patch('patch'),
  $required('required'),
  $rethrow('rethrow'),
  $return('return'),
  $sealed('sealed'),
  $set('set'),
  $show('show'),
  $static('static'),
  $super('super'),
  $switch('switch'),
  $sync('sync'),
  $this('this'),
  $throw('throw'),
  $true('true'),
  $try('try'),
  $type('type'),
  $typedef('typedef'),
  $var('var'),
  $void('void'),
  $when('when'),
  $while('while'),
  $with('with'),
  $yield('yield'),

  // Operators and punctuation
  ampersand('&'),
  ampersandAmpersand('&&'),
  ampersandAmpersandEq('&&='),
  ampersandEq('&='),
  at('@'),
  bang('!'),
  bangEq('!='),
  bangEqEq('!=='),
  bar('|'),
  barBar('||'),
  barBarEq('||='),
  barEq('|='),
  caret('^'),
  caretEq('^='),
  closeBrace('}'),
  closeBracket(']'),
  closeParen(')'),
  colon(':'),
  comma(','),
  eq('='),
  eqEq('=='),
  eqEqEq('==='),
  gt('>'),
  gtEq('>='),
  gtGt('>>'),
  gtGtEq('>>='),
  gtGtGt('>>>'),
  gtGtGtEq('>>>='),
  hash('#'),
  lt('<'),
  ltEq('<='),
  ltLt('<<'),
  ltLtEq('<<='),
  minus('-'),
  minusEq('-='),
  minusMinus('--'),
  openBrace('{'),
  openBracket('['),
  openParen('('),
  percent('%'),
  percentEq('%='),
  period('.'),
  periodPeriod('..'),
  periodPeriodPeriod('...'),
  periodPeriodPeriodQuestion('...?'),
  plus('+'),
  plusEq('+='),
  plusPlus('++'),
  question('?'),
  questionPeriod('?.'),
  questionQuestion('??'),
  questionQuestionEq('??='),
  semicolon(';'),
  slash('/'),
  slashEq('/='),
  star('*'),
  starEq('*='),
  tilde('~'),
  tildeSlash('~/'),
  tildeSlashEq('~/='),
  arrow('=>'),
  function('Function'),
  indexToken('[]'),
  indexEq('[]='),

  // Literals and identifiers
  identifier(''),
  integerLiteral(''),
  hexLiteral(''),
  doubleLiteral(''),
  stringLiteral(''),
  multiLineStringLiteral(''),

  // Comments
  singleLineComment(''),
  multiLineComment(''),
  documentationComment(''),

  // Special
  eof(''),
  stringInterpolationExpression(r'${'),
  stringInterpolationIdentifier(r'$');

  /// The textual representation of this token type.
  final String lexeme;
  const STokenType(this.lexeme);

  /// Returns true if this is a keyword token type.
  bool get isKeyword => name.startsWith(r'$') && lexeme.isNotEmpty;

  /// Gets the token type from an operator lexeme.
  static STokenType? fromOperator(String lexeme) {
    for (final type in STokenType.values) {
      if (type.lexeme == lexeme && type.lexeme.isNotEmpty && !type.isKeyword) {
        return type;
      }
    }
    return null;
  }

  /// Gets the keyword token type from a lexeme.
  static STokenType? fromKeyword(String lexeme) {
    for (final type in STokenType.values) {
      if (type.isKeyword && type.lexeme == lexeme) {
        return type;
      }
    }
    return null;
  }
}

/// A serializable representation of a token.
///
/// This replaces the analyzer's `Token` class which has linked-list
/// structure and cannot be easily serialized.
final class SToken {
  /// The type of this token.
  final STokenType type;

  /// The lexeme (source text) of this token.
  final String lexeme;

  /// The offset of the first character of this token within the source.
  final int offset;

  /// The length of this token's lexeme.
  int get length => lexeme.length;

  /// The offset after the last character of this token.
  int get end => offset + length;

  const SToken({
    required this.type,
    required this.lexeme,
    required this.offset,
  });

  /// Creates a synthetic token with no source location.
  const SToken.synthetic(this.type, this.lexeme) : offset = -1;

  /// Converts this token to a JSON-serializable map.
  Map<String, dynamic> toJson() => {
        't': type.index,
        'l': lexeme,
        'o': offset,
      };

  /// Creates a token from a JSON map.
  factory SToken.fromJson(Map<String, dynamic> json) {
    return SToken(
      type: STokenType.values[json['t'] as int],
      lexeme: json['l'] as String,
      offset: json['o'] as int,
    );
  }

  @override
  String toString() => lexeme;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SToken &&
          type == other.type &&
          lexeme == other.lexeme &&
          offset == other.offset;

  @override
  int get hashCode => Object.hash(type, lexeme, offset);
}

/// Extension to get keyword from lexeme.
extension KeywordLookup on String {
  /// Converts a keyword lexeme to its token type.
  STokenType? get keywordType => STokenType.fromKeyword(this);
}
