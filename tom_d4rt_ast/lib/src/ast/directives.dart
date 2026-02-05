part of '../ast.dart';

// =============================================================================
// DIRECTIVE NODES
// =============================================================================

/// An import directive.
///
/// Example: `import 'dart:core';`, `import 'package:foo/foo.dart' as foo;`
final class SImportDirective extends SDirective {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// The 'import' keyword.
  final SToken importKeyword;

  /// The URI being imported.
  final SStringLiteral uri;

  /// The configurations, if any.
  final List<SConfiguration> configurations;

  /// The 'deferred' keyword, if deferred.
  final SToken? deferredKeyword;

  /// The 'as' keyword, if prefixed.
  final SToken? asKeyword;

  /// The prefix, if any.
  final SSimpleIdentifier? prefix;

  /// The combinators (show/hide).
  final List<SCombinator> combinators;

  /// The semicolon.
  final SToken semicolon;

  @override
  int get offset => metadata.firstOrNull?.offset ?? importKeyword.offset;

  @override
  int get end => semicolon.end;

  const SImportDirective({
    required this.metadata,
    required this.importKeyword,
    required this.uri,
    required this.configurations,
    this.deferredKeyword,
    this.asKeyword,
    this.prefix,
    required this.combinators,
    required this.semicolon,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitImportDirective(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ImportDirective',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        'import': importKeyword.toJson(),
        'uri': uri.toJson(),
        'configs': configurations.map((c) => c.toJson()).toList(),
        if (deferredKeyword != null) 'deferred': deferredKeyword!.toJson(),
        if (asKeyword != null) 'as': asKeyword!.toJson(),
        if (prefix != null) 'prefix': prefix!.toJson(),
        'combinators': combinators.map((c) => c.toJson()).toList(),
        'semi': semicolon.toJson(),
      };

  factory SImportDirective.fromJson(Map<String, dynamic> json) {
    return SImportDirective(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      importKeyword: SToken.fromJson(json['import'] as Map<String, dynamic>),
      uri: _stringLiteralFromJson(json['uri'] as Map<String, dynamic>),
      configurations: (json['configs'] as List)
          .map((c) => SConfiguration.fromJson(c as Map<String, dynamic>))
          .toList(),
      deferredKeyword: json['deferred'] != null
          ? SToken.fromJson(json['deferred'] as Map<String, dynamic>)
          : null,
      asKeyword: json['as'] != null
          ? SToken.fromJson(json['as'] as Map<String, dynamic>)
          : null,
      prefix: json['prefix'] != null
          ? SSimpleIdentifier.fromJson(json['prefix'] as Map<String, dynamic>)
          : null,
      combinators: (json['combinators'] as List)
          .map((c) => _combinatorFromJson(c as Map<String, dynamic>))
          .toList(),
      semicolon: SToken.fromJson(json['semi'] as Map<String, dynamic>),
    );
  }
}

/// An export directive.
///
/// Example: `export 'src/foo.dart';`, `export 'bar.dart' show Bar;`
final class SExportDirective extends SDirective {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// The 'export' keyword.
  final SToken exportKeyword;

  /// The URI being exported.
  final SStringLiteral uri;

  /// The configurations, if any.
  final List<SConfiguration> configurations;

  /// The combinators (show/hide).
  final List<SCombinator> combinators;

  /// The semicolon.
  final SToken semicolon;

  @override
  int get offset => metadata.firstOrNull?.offset ?? exportKeyword.offset;

  @override
  int get end => semicolon.end;

  const SExportDirective({
    required this.metadata,
    required this.exportKeyword,
    required this.uri,
    required this.configurations,
    required this.combinators,
    required this.semicolon,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitExportDirective(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ExportDirective',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        'export': exportKeyword.toJson(),
        'uri': uri.toJson(),
        'configs': configurations.map((c) => c.toJson()).toList(),
        'combinators': combinators.map((c) => c.toJson()).toList(),
        'semi': semicolon.toJson(),
      };

  factory SExportDirective.fromJson(Map<String, dynamic> json) {
    return SExportDirective(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      exportKeyword: SToken.fromJson(json['export'] as Map<String, dynamic>),
      uri: _stringLiteralFromJson(json['uri'] as Map<String, dynamic>),
      configurations: (json['configs'] as List)
          .map((c) => SConfiguration.fromJson(c as Map<String, dynamic>))
          .toList(),
      combinators: (json['combinators'] as List)
          .map((c) => _combinatorFromJson(c as Map<String, dynamic>))
          .toList(),
      semicolon: SToken.fromJson(json['semi'] as Map<String, dynamic>),
    );
  }
}

/// A library directive.
///
/// Example: `library my.library;`
final class SLibraryDirective extends SDirective {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// The 'library' keyword.
  final SToken libraryKeyword;

  /// The library name, if any.
  final SLibraryIdentifier? name;

  /// The semicolon.
  final SToken semicolon;

  @override
  int get offset => metadata.firstOrNull?.offset ?? libraryKeyword.offset;

  @override
  int get end => semicolon.end;

  const SLibraryDirective({
    required this.metadata,
    required this.libraryKeyword,
    this.name,
    required this.semicolon,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitLibraryDirective(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'LibraryDirective',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        'library': libraryKeyword.toJson(),
        if (name != null) 'name': name!.toJson(),
        'semi': semicolon.toJson(),
      };

  factory SLibraryDirective.fromJson(Map<String, dynamic> json) {
    return SLibraryDirective(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      libraryKeyword: SToken.fromJson(json['library'] as Map<String, dynamic>),
      name: json['name'] != null
          ? SLibraryIdentifier.fromJson(json['name'] as Map<String, dynamic>)
          : null,
      semicolon: SToken.fromJson(json['semi'] as Map<String, dynamic>),
    );
  }
}

/// A library identifier (dotted name).
final class SLibraryIdentifier extends SAstNode {
  /// The components of the library name.
  final List<SSimpleIdentifier> components;

  @override
  int get offset => components.first.offset;

  @override
  int get end => components.last.end;

  const SLibraryIdentifier({required this.components});

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitLibraryIdentifier(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'LibraryIdentifier',
        'components': components.map((c) => c.toJson()).toList(),
      };

  factory SLibraryIdentifier.fromJson(Map<String, dynamic> json) {
    return SLibraryIdentifier(
      components: (json['components'] as List)
          .map((c) => SSimpleIdentifier.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A part directive.
///
/// Example: `part 'src/part.dart';`
final class SPartDirective extends SDirective {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// The 'part' keyword.
  final SToken partKeyword;

  /// The URI of the part.
  final SStringLiteral uri;

  /// The semicolon.
  final SToken semicolon;

  @override
  int get offset => metadata.firstOrNull?.offset ?? partKeyword.offset;

  @override
  int get end => semicolon.end;

  const SPartDirective({
    required this.metadata,
    required this.partKeyword,
    required this.uri,
    required this.semicolon,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitPartDirective(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'PartDirective',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        'part': partKeyword.toJson(),
        'uri': uri.toJson(),
        'semi': semicolon.toJson(),
      };

  factory SPartDirective.fromJson(Map<String, dynamic> json) {
    return SPartDirective(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      partKeyword: SToken.fromJson(json['part'] as Map<String, dynamic>),
      uri: _stringLiteralFromJson(json['uri'] as Map<String, dynamic>),
      semicolon: SToken.fromJson(json['semi'] as Map<String, dynamic>),
    );
  }
}

/// A part-of directive.
///
/// Example: `part of my.library;`, `part of 'lib.dart';`
final class SPartOfDirective extends SDirective {
  /// The metadata annotations.
  final List<SAnnotation> metadata;

  /// The 'part' keyword.
  final SToken partKeyword;

  /// The 'of' keyword.
  final SToken ofKeyword;

  /// The library name, if using dotted identifier.
  final SLibraryIdentifier? libraryName;

  /// The URI, if using URI reference.
  final SStringLiteral? uri;

  /// The semicolon.
  final SToken semicolon;

  @override
  int get offset => metadata.firstOrNull?.offset ?? partKeyword.offset;

  @override
  int get end => semicolon.end;

  const SPartOfDirective({
    required this.metadata,
    required this.partKeyword,
    required this.ofKeyword,
    this.libraryName,
    this.uri,
    required this.semicolon,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitPartOfDirective(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'PartOfDirective',
        'metadata': metadata.map((m) => m.toJson()).toList(),
        'part': partKeyword.toJson(),
        'of': ofKeyword.toJson(),
        if (libraryName != null) 'libName': libraryName!.toJson(),
        if (uri != null) 'uri': uri!.toJson(),
        'semi': semicolon.toJson(),
      };

  factory SPartOfDirective.fromJson(Map<String, dynamic> json) {
    return SPartOfDirective(
      metadata: (json['metadata'] as List)
          .map((m) => SAnnotation.fromJson(m as Map<String, dynamic>))
          .toList(),
      partKeyword: SToken.fromJson(json['part'] as Map<String, dynamic>),
      ofKeyword: SToken.fromJson(json['of'] as Map<String, dynamic>),
      libraryName: json['libName'] != null
          ? SLibraryIdentifier.fromJson(json['libName'] as Map<String, dynamic>)
          : null,
      uri: json['uri'] != null
          ? _stringLiteralFromJson(json['uri'] as Map<String, dynamic>)
          : null,
      semicolon: SToken.fromJson(json['semi'] as Map<String, dynamic>),
    );
  }
}

/// A configuration clause.
///
/// Example: `if (dart.library.io) 'io_impl.dart'`
final class SConfiguration extends SAstNode {
  /// The 'if' keyword.
  final SToken ifKeyword;

  /// The left parenthesis.
  final SToken leftParenthesis;

  /// The dotted name.
  final SDottedName name;

  /// The equals operator, if any.
  final SToken? equalToken;

  /// The value, if any.
  final SStringLiteral? value;

  /// The right parenthesis.
  final SToken rightParenthesis;

  /// The URI to use if the condition is true.
  final SStringLiteral uri;

  @override
  int get offset => ifKeyword.offset;

  @override
  int get end => uri.end;

  const SConfiguration({
    required this.ifKeyword,
    required this.leftParenthesis,
    required this.name,
    this.equalToken,
    this.value,
    required this.rightParenthesis,
    required this.uri,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitConfiguration(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'Configuration',
        'if': ifKeyword.toJson(),
        'lp': leftParenthesis.toJson(),
        'name': name.toJson(),
        if (equalToken != null) 'eq': equalToken!.toJson(),
        if (value != null) 'val': value!.toJson(),
        'rp': rightParenthesis.toJson(),
        'uri': uri.toJson(),
      };

  factory SConfiguration.fromJson(Map<String, dynamic> json) {
    return SConfiguration(
      ifKeyword: SToken.fromJson(json['if'] as Map<String, dynamic>),
      leftParenthesis: SToken.fromJson(json['lp'] as Map<String, dynamic>),
      name: SDottedName.fromJson(json['name'] as Map<String, dynamic>),
      equalToken: json['eq'] != null
          ? SToken.fromJson(json['eq'] as Map<String, dynamic>)
          : null,
      value: json['val'] != null
          ? _stringLiteralFromJson(json['val'] as Map<String, dynamic>)
          : null,
      rightParenthesis: SToken.fromJson(json['rp'] as Map<String, dynamic>),
      uri: _stringLiteralFromJson(json['uri'] as Map<String, dynamic>),
    );
  }
}

/// A dotted name (used in configurations).
final class SDottedName extends SAstNode {
  /// The components.
  final List<SSimpleIdentifier> components;

  @override
  int get offset => components.first.offset;

  @override
  int get end => components.last.end;

  const SDottedName({required this.components});

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitDottedName(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'DottedName',
        'components': components.map((c) => c.toJson()).toList(),
      };

  factory SDottedName.fromJson(Map<String, dynamic> json) {
    return SDottedName(
      components: (json['components'] as List)
          .map((c) => SSimpleIdentifier.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}

// =============================================================================
// COMBINATOR NODES
// =============================================================================

/// Base class for show/hide combinators.
abstract class SCombinator extends SAstNode {
  const SCombinator();
}

/// A show combinator.
///
/// Example: `show Foo, Bar`
final class SShowCombinator extends SCombinator {
  /// The 'show' keyword.
  final SToken keyword;

  /// The names being shown.
  final List<SSimpleIdentifier> shownNames;

  @override
  int get offset => keyword.offset;

  @override
  int get end => shownNames.last.end;

  const SShowCombinator({
    required this.keyword,
    required this.shownNames,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitShowCombinator(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ShowCombinator',
        'kw': keyword.toJson(),
        'names': shownNames.map((n) => n.toJson()).toList(),
      };

  factory SShowCombinator.fromJson(Map<String, dynamic> json) {
    return SShowCombinator(
      keyword: SToken.fromJson(json['kw'] as Map<String, dynamic>),
      shownNames: (json['names'] as List)
          .map((n) => SSimpleIdentifier.fromJson(n as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A hide combinator.
///
/// Example: `hide Baz`
final class SHideCombinator extends SCombinator {
  /// The 'hide' keyword.
  final SToken keyword;

  /// The names being hidden.
  final List<SSimpleIdentifier> hiddenNames;

  @override
  int get offset => keyword.offset;

  @override
  int get end => hiddenNames.last.end;

  const SHideCombinator({
    required this.keyword,
    required this.hiddenNames,
  });

  @override
  R? accept<R>(SAstVisitor<R> visitor) => visitor.visitHideCombinator(this);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'HideCombinator',
        'kw': keyword.toJson(),
        'names': hiddenNames.map((n) => n.toJson()).toList(),
      };

  factory SHideCombinator.fromJson(Map<String, dynamic> json) {
    return SHideCombinator(
      keyword: SToken.fromJson(json['kw'] as Map<String, dynamic>),
      hiddenNames: (json['names'] as List)
          .map((n) => SSimpleIdentifier.fromJson(n as Map<String, dynamic>))
          .toList(),
    );
  }
}

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/// Parses a combinator from JSON.
SCombinator _combinatorFromJson(Map<String, dynamic> json) {
  final type = json['type'] as String;
  return switch (type) {
    'ShowCombinator' => SShowCombinator.fromJson(json),
    'HideCombinator' => SHideCombinator.fromJson(json),
    _ => throw FormatException('Unknown combinator type: $type'),
  };
}
