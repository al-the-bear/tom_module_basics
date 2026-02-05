// ignore_for_file: avoid_print
/// Generates AST model classes from the analysis YAML file.
///
/// This script reads main.analysis.yaml and generates stub class implementations
/// mirroring the analyzer package's AST object model.
///
/// Usage:
///   dart run bin/generate_ast_model.dart [--all | --exported]
///
/// Options:
///   --all       Include all classes from package:analyzer/
///   --exported  Include only classes exported from public API (default)
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Controls which classes to include in the generated model.
enum IncludeMode {
  /// Include all classes from package:analyzer/ (including /src/)
  all,

  /// Include only classes exported from public API libraries (skip /src/)
  exported,
}

void main(List<String> args) async {
  // Parse command-line arguments
  var mode = IncludeMode.exported; // default
  for (final arg in args) {
    if (arg == '--all') {
      mode = IncludeMode.all;
    } else if (arg == '--exported') {
      mode = IncludeMode.exported;
    } else if (arg == '--help' || arg == '-h') {
      print('Usage: dart run bin/generate_ast_model.dart [--all | --exported]');
      print('');
      print('Options:');
      print('  --all       Include all classes from package:analyzer/');
      print('  --exported  Include only classes exported from public API (default)');
      exit(0);
    }
  }

  final projectRoot = p.dirname(p.dirname(Platform.script.toFilePath()));
  final yamlPath = p.join(projectRoot, 'lib', 'main.analysis.yaml');
  final outputDir = p.join(projectRoot, 'lib', 'src', 'analyzer');
  final barrelPath = p.join(projectRoot, 'lib', 'analyzer_model.dart');

  print('Loading analysis from: $yamlPath');
  print('Include mode: ${mode.name}');

  final yamlContent = File(yamlPath).readAsStringSync();
  final yaml = loadYaml(yamlContent) as YamlMap;

  final generator = AstModelGenerator(yaml, includeMode: mode);
  final files = generator.generate();

  // Ensure output directory exists
  Directory(outputDir).createSync(recursive: true);

  // Write generated files
  for (final entry in files.entries) {
    final filePath = p.join(outputDir, entry.key);
    File(filePath).writeAsStringSync(entry.value);
    print('Generated: ${entry.key}');
  }

  // Generate barrel file
  final barrelContent = generator.generateBarrel(files.keys.toList());
  File(barrelPath).writeAsStringSync(barrelContent);
  print('Generated: analyzer_model.dart');

  print('\nDone! Generated ${files.length} files.');
}

/// Generates AST model classes from analysis data.
class AstModelGenerator {
  final YamlMap analysis;
  final IncludeMode includeMode;
  final Map<String, ClassData> _classMap = {};
  final Set<String> _knownTypes = {};
  final Set<String> _exportedClassNames = {};

  // Core Dart types that don't need stubs
  static const _coreTypes = {
    'Object',
    'String',
    'int',
    'double',
    'bool',
    'num',
    'List',
    'Map',
    'Set',
    'Iterable',
    'Iterator',
    'Future',
    'Stream',
    'dynamic',
    'void',
    'Never',
    'Null',
    'Function',
    'Type',
    'Uri',
    'DateTime',
    'Duration',
    'Comparable',
    'Pattern',
    'RegExp',
  };

  AstModelGenerator(this.analysis, {this.includeMode = IncludeMode.exported}) {
    _parseAnalysis();
  }

  void _parseAnalysis() {
    final libraries = analysis['libraries'] as YamlList? ?? [];

    // First pass: collect all exported class names from public API libraries
    if (includeMode == IncludeMode.exported) {
      for (final lib in libraries) {
        final libMap = lib as YamlMap;
        final uri = libMap['uri'] as String? ?? '';

        // Only look at public API libraries (not /src/)
        if (!uri.startsWith('package:analyzer/')) continue;
        if (uri.contains('/src/')) continue;

        // Collect class names exported from this library
        final exports = libMap['exports'] as YamlList? ?? [];
        for (final export in exports) {
          final exportMap = export as YamlMap;
          final showNames = exportMap['show'] as YamlList? ?? [];
          for (final name in showNames) {
            _exportedClassNames.add(name as String);
          }
          // If no 'show' clause, we'd need to track all classes from that export
          // For now, we'll also check classes directly in public libraries
        }

        // Classes defined directly in public libraries are exported
        final classes = libMap['classes'] as YamlList? ?? [];
        for (final cls in classes) {
          final clsMap = cls as YamlMap;
          final name = clsMap['name'] as String? ?? '';
          _exportedClassNames.add(name);
        }
      }
    }

    // Second pass: parse all classes based on include mode
    for (final lib in libraries) {
      final libMap = lib as YamlMap;
      final uri = libMap['uri'] as String? ?? '';

      // Only process analyzer package classes
      if (!uri.startsWith('package:analyzer/')) continue;

      // In exported mode, skip /src/ libraries (they'll be included via exports)
      // In all mode, include everything
      if (includeMode == IncludeMode.exported && uri.contains('/src/')) continue;

      // Parse classes
      final classes = libMap['classes'] as YamlList? ?? [];
      for (final cls in classes) {
        final clsMap = cls as YamlMap;
        final classData = ClassData.fromYaml(clsMap, uri);
        _classMap[classData.qualifiedName] = classData;
        _knownTypes.add(classData.name);
      }
    }
  }

  /// Generate all files.
  Map<String, String> generate() {
    final files = <String, String>{};

    // Collect all classes to include
    final allClasses = <ClassData>[];

    for (final cls in _classMap.values) {
      // Only include abstract/interface classes (the public API)
      if (!cls.isAbstract && !cls.isInterface && !cls.isSealed) continue;
      allClasses.add(cls);
    }

    // Get the set of generated class names (to exclude from stubs)
    final generatedClassNames = allClasses.map((c) => c.name).toSet();

    // Generate stub types file first (excluding types that are generated)
    files['_stub_types.dart'] = _generateStubTypes(generatedClassNames);

    // Generate all classes into a single file
    files['ast_model.dart'] = _generateCombinedFile(allClasses);

    return files;
  }

  String _generateCombinedFile(List<ClassData> classes) {
    final buffer = StringBuffer();

    buffer.writeln('// Generated AST model stub classes');
    buffer.writeln('// Contains the public API model from the analyzer package');
    buffer.writeln(
      '// ignore_for_file: unused_element, unused_field, annotate_overrides',
    );
    buffer.writeln(
      '// ignore_for_file: constant_identifier_names, unused_element_parameter',
    );
    buffer.writeln(
      '// ignore_for_file: non_constant_identifier_names, dangling_library_doc_comments',
    );
    buffer.writeln('// ignore_for_file: one_member_abstracts');
    buffer.writeln('// ignore_for_file: invalid_override, inconsistent_inheritance');
    buffer.writeln('// ignore_for_file: duplicate_definition');
    buffer.writeln();
    buffer.writeln("import '_stub_types.dart';");
    buffer.writeln();

    // Sort classes by name for deterministic output
    classes.sort((a, b) => a.name.compareTo(b.name));

    // Generate classes
    for (final cls in classes) {
      buffer.writeln(_generateClass(cls));
      buffer.writeln();
    }

    var content = buffer.toString();
    
    // Post-process: fix nullable return types for Fragment hierarchy
    // The issue is that Fragment/TypeDefiningFragment/TypeParameterizedFragment
    // define non-nullable nextFragment/previousFragment, but implementations
    // need to return nullable. We make all fragment types nullable.
    content = content.replaceAll(
      'Fragment get nextFragment;',
      'Fragment? get nextFragment;',
    );
    content = content.replaceAll(
      'Fragment get previousFragment;',
      'Fragment? get previousFragment;',
    );
    content = content.replaceAll(
      'TypeDefiningFragment get nextFragment;',
      'TypeDefiningFragment? get nextFragment;',
    );
    content = content.replaceAll(
      'TypeDefiningFragment get previousFragment;',
      'TypeDefiningFragment? get previousFragment;',
    );
    content = content.replaceAll(
      'TypeParameterizedFragment get nextFragment;',
      'TypeParameterizedFragment? get nextFragment;',
    );
    content = content.replaceAll(
      'TypeParameterizedFragment get previousFragment;',
      'TypeParameterizedFragment? get previousFragment;',
    );

    return content;
  }

  String _generateStubTypes(Set<String> generatedClassNames) {
    // Only include stubs for types that are NOT generated in ast_model.dart
    // These are truly external types from the analyzer package
    final buffer = StringBuffer();
    
    buffer.writeln('// Generated stub types for external dependencies');
    buffer.writeln('// ignore_for_file: unused_element, camel_case_types, one_member_abstracts');
    buffer.writeln('// ignore_for_file: duplicate_definition, constant_identifier_names');
    buffer.writeln();

    // Token is always needed and never generated
    if (!generatedClassNames.contains('Token')) {
      buffer.writeln('''
/// Stub for analyzer Token type
class Token {
  Token? get next => null;
  Token? get previous => null;
  int get offset => 0;
  int get length => 0;
  String get lexeme => '';
}
''');
    }

    if (!generatedClassNames.contains('SyntacticEntity')) {
      buffer.writeln('''
/// Stub for analyzer SyntacticEntity type
abstract class SyntacticEntity {
  int get offset;
  int get length;
  int get end;
}
''');
    }

    if (!generatedClassNames.contains('Precedence')) {
      buffer.writeln('''
/// Stub for analyzer Precedence type
class Precedence implements Comparable<Precedence> {
  final int value;
  const Precedence._(this.value);
  static const Precedence none = Precedence._(0);
  static const Precedence assignment = Precedence._(1);
  @override
  int compareTo(Precedence other) => value.compareTo(other.value);
}
''');
    }

    if (!generatedClassNames.contains('NodeList')) {
      buffer.writeln('''
/// Stub for NodeList type
class NodeList<E> extends Iterable<E> {
  final List<E> _nodes = [];
  @override
  Iterator<E> get iterator => _nodes.iterator;
  Token? get beginToken => null;
  Token? get endToken => null;
}
''');
    }

    if (!generatedClassNames.contains('ChildEntities')) {
      buffer.writeln('''
/// Stub for ChildEntities
class ChildEntities extends Iterable<SyntacticEntity> {
  @override
  Iterator<SyntacticEntity> get iterator => <SyntacticEntity>[].iterator;
}
''');
    }

    if (!generatedClassNames.contains('LineInfo')) {
      buffer.writeln('''
/// Stub for LineInfo
class LineInfo {
  const LineInfo.fromContent(String content);
  int getOffsetOfLine(int line) => 0;
  int getLocation(int offset) => 0;
}
''');
    }

    if (!generatedClassNames.contains('FeatureSet')) {
      buffer.writeln('''
/// Stub for FeatureSet
abstract class FeatureSet {}
''');
    }

    if (!generatedClassNames.contains('LanguageVersion')) {
      buffer.writeln('''
/// Stub for LanguageVersion
abstract class LanguageVersion {
  int get major;
  int get minor;
}
''');
    }

    if (!generatedClassNames.contains('LibraryLanguageVersion')) {
      buffer.writeln('''
/// Stub for LibraryLanguageVersion
abstract class LibraryLanguageVersion extends LanguageVersion {}
''');
    }

    if (!generatedClassNames.contains('Comment')) {
      buffer.writeln('''
/// Stub for Comment
abstract class Comment extends Token {}
''');
    }

    if (!generatedClassNames.contains('AstVisitor')) {
      buffer.writeln('''
/// Stub for AstVisitor
abstract class AstVisitor<R> {}
''');
    }

    if (!generatedClassNames.contains('AnalysisSession')) {
      buffer.writeln('''
/// Stub for AnalysisSession
abstract class AnalysisSession {}
''');
    }

    if (!generatedClassNames.contains('Source')) {
      buffer.writeln('''
/// Stub for Source
abstract class Source {}
''');
    }

    if (!generatedClassNames.contains('SourceRange')) {
      buffer.writeln('''
/// Stub for SourceRange
class SourceRange {
  final int offset;
  final int length;
  const SourceRange(this.offset, this.length);
}
''');
    }

    if (!generatedClassNames.contains('TypeProvider')) {
      buffer.writeln('''
/// Stub for TypeProvider
abstract class TypeProvider {}
''');
    }

    if (!generatedClassNames.contains('NullabilitySuffix')) {
      buffer.writeln('''
/// Stub for NullabilitySuffix
enum NullabilitySuffix { question, star, none }
''');
    }

    if (!generatedClassNames.contains('ElementKind')) {
      buffer.writeln('''
/// Stub for ElementKind
enum ElementKind {
  CLASS, CONSTRUCTOR, EXTENSION, EXTENSION_TYPE, FIELD, FUNCTION,
  GETTER, IMPORT, LIBRARY, LOCAL_VARIABLE, METHOD, MIXIN,
  PARAMETER, PREFIX, SETTER, TOP_LEVEL_VARIABLE, TYPE_ALIAS, TYPE_PARAMETER, ENUM,
}
''');
    }

    // Internal implementation types that appear in method signatures
    // These are *Impl classes from the analyzer's internal implementation
    if (!generatedClassNames.contains('NodeListImpl')) {
      buffer.writeln('''
/// Stub for NodeListImpl (internal implementation)
class NodeListImpl<E> extends Iterable<E> {
  final List<E> _nodes = [];
  @override
  Iterator<E> get iterator => _nodes.iterator;
  Token? get beginToken => null;
  Token? get endToken => null;
}
''');
    }

    if (!generatedClassNames.contains('ArgumentListImpl')) {
      buffer.writeln('''
/// Stub for ArgumentListImpl (internal implementation)
abstract class ArgumentListImpl {}
''');
    }

    if (!generatedClassNames.contains('TypeArgumentListImpl')) {
      buffer.writeln('''
/// Stub for TypeArgumentListImpl (internal implementation)
abstract class TypeArgumentListImpl {}
''');
    }

    if (!generatedClassNames.contains('GuardedPatternImpl')) {
      buffer.writeln('''
/// Stub for GuardedPatternImpl (internal implementation)
abstract class GuardedPatternImpl {}
''');
    }

    if (!generatedClassNames.contains('CaseClauseImpl')) {
      buffer.writeln('''
/// Stub for CaseClauseImpl (internal implementation)
abstract class CaseClauseImpl {}
''');
    }

    if (!generatedClassNames.contains('PatternFieldNameImpl')) {
      buffer.writeln('''
/// Stub for PatternFieldNameImpl (internal implementation)
abstract class PatternFieldNameImpl {}
''');
    }

    if (!generatedClassNames.contains('AttemptedConstantEvaluationResult')) {
      buffer.writeln('''
/// Stub for AttemptedConstantEvaluationResult
abstract class AttemptedConstantEvaluationResult {}
''');
    }

    if (!generatedClassNames.contains('LocalVariableInfo')) {
      buffer.writeln('''
/// Stub for LocalVariableInfo
abstract class LocalVariableInfo {}
''');
    }

    if (!generatedClassNames.contains('Name')) {
      buffer.writeln('''
/// Stub for Name (internal type for member resolution)
abstract class Name {
  String get name;
  bool get isPrivate;
  bool get isPublic;
}
''');
    }

    return buffer.toString();
  }

  String _generateClass(ClassData cls) {
    final buffer = StringBuffer();

    // Documentation
    if (cls.documentation != null && cls.documentation!.isNotEmpty) {
      buffer.writeln(cls.documentation);
    }

    // Class modifiers - always abstract for interfaces
    buffer.write('abstract class ${cls.name}');

    // Type parameters
    if (cls.typeParameters.isNotEmpty) {
      buffer.write(
        '<${cls.typeParameters.map((t) => _formatTypeParam(t)).join(', ')}>',
      );
    }

    // Superclass and interfaces
    final clauses = <String>[];

    if (cls.superclass != null) {
      final superName = _simplifyTypeName(cls.superclass!);
      if (superName != 'Object' && _isKnownType(superName)) {
        clauses.add('extends $superName');
      }
    }

    final validInterfaces =
        cls.interfaces.map(_simplifyTypeName).where(_isKnownType).toList();
    if (validInterfaces.isNotEmpty) {
      clauses.add('implements ${validInterfaces.join(', ')}');
    }

    if (clauses.isNotEmpty) {
      buffer.write(' ${clauses.join(' ')}');
    }

    buffer.writeln(' {');

    // Generate abstract getters for fields (properties)
    for (final field in cls.fields) {
      if (field.isStatic) continue; // Skip static fields
      final typeName = _simplifyTypeName(field.type);
      if (!_isValidType(typeName)) continue;
      // Skip fields with Null type - they cause override issues
      if (typeName == 'Null') continue;
      buffer.writeln('  $typeName get ${field.name};');
    }

    if (cls.fields.isNotEmpty) buffer.writeln();

    // Generate abstract method signatures
    for (final method in cls.methods) {
      if (method.isStatic) continue; // Skip static methods

      final returnType = _simplifyTypeName(method.returnType);
      if (!_isValidType(returnType)) continue;
      // Skip methods with Null return type - they cause override issues
      if (returnType == 'Null') continue;

      // Skip methods with invalid parameter types
      var hasInvalidParams = false;
      for (final param in method.parameters) {
        if (!_isValidType(_simplifyTypeName(param.type))) {
          hasInvalidParams = true;
          break;
        }
      }
      if (hasInvalidParams) continue;

      // Type parameters
      final typeParams =
          method.typeParameters.isNotEmpty
              ? '<${method.typeParameters.map((t) => _formatTypeParam(t)).join(', ')}>'
              : '';

      // Parameters
      final params = _formatParameters(method.parameters);

      buffer.writeln('  $returnType ${method.name}$typeParams($params);');
    }

    buffer.writeln('}');

    return buffer.toString();
  }

  String _formatTypeParam(TypeParamData param) {
    if (param.bound != null) {
      final boundName = _simplifyTypeName(param.bound!);
      if (boundName != 'Object' && _isKnownType(boundName)) {
        return '${param.name} extends $boundName';
      }
    }
    return param.name;
  }

  String _formatParameters(List<ParameterData> params) {
    if (params.isEmpty) return '';

    final positional =
        params.where((p) => !p.isNamed && !p.isOptionalPositional).toList();
    final optionalPositional =
        params.where((p) => p.isOptionalPositional).toList();
    final named = params.where((p) => p.isNamed).toList();

    final parts = <String>[];

    for (final p in positional) {
      parts.add('${_simplifyTypeName(p.type)} ${p.name}');
    }

    if (optionalPositional.isNotEmpty) {
      final optParts = optionalPositional.map(
        (p) => '${_simplifyTypeName(p.type)} ${p.name}',
      );
      parts.add('[${optParts.join(', ')}]');
    }

    if (named.isNotEmpty) {
      final namedParts = named.map((p) {
        final req = p.isRequired ? 'required ' : '';
        return '$req${_simplifyTypeName(p.type)} ${p.name}';
      });
      parts.add('{${namedParts.join(', ')}}');
    }

    return parts.join(', ');
  }

  bool _isKnownType(String typeName) {
    // Remove generic parameters and nullability
    final baseName = typeName.replaceAll(RegExp(r'<.*>|\?'), '');
    return _knownTypes.contains(baseName) ||
        _coreTypes.contains(baseName) ||
        _stubTypes.contains(baseName);
  }

  bool _isValidType(String typeName) {
    // Handle generic types
    final genericMatch = RegExp(r'^(\w+)<(.+)>(\?)?$').firstMatch(typeName);
    if (genericMatch != null) {
      final base = genericMatch.group(1)!;
      if (!_isKnownType(base)) return false;
      // Check type arguments recursively
      final args = genericMatch.group(2)!;
      for (final arg in _splitTypeArgs(args)) {
        if (!_isValidType(arg.trim())) return false;
      }
      return true;
    }

    // Handle nullable
    if (typeName.endsWith('?')) {
      return _isKnownType(typeName.substring(0, typeName.length - 1));
    }

    return _isKnownType(typeName);
  }

  List<String> _splitTypeArgs(String args) {
    final parts = <String>[];
    var depth = 0;
    var current = StringBuffer();

    for (var i = 0; i < args.length; i++) {
      final char = args[i];
      if (char == '<') {
        depth++;
        current.write(char);
      } else if (char == '>') {
        depth--;
        current.write(char);
      } else if (char == ',' && depth == 0) {
        parts.add(current.toString().trim());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }

    if (current.isNotEmpty) {
      parts.add(current.toString().trim());
    }

    return parts;
  }

  static const _stubTypes = {
    'Token',
    'SyntacticEntity',
    'Precedence',
    'NodeList',
    'ChildEntities',
    'LineInfo',
    'FeatureSet',
    'LanguageVersion',
    'LibraryLanguageVersion',
    'Comment',
    'AstVisitor',
    'AnalysisSession',
    'Source',
    'SourceRange',
    'TypeProvider',
    'NullabilitySuffix',
    'ElementKind',
    'Fragment',
    'TypeDefiningFragment',
    'TypeParameterizedFragment',
    'LibraryFragment',
  };

  String _simplifyTypeName(String qualifiedName) {
    // Handle generic types
    final genericMatch =
        RegExp(r'^(.+?)<(.+)>(\?)?$').firstMatch(qualifiedName);
    if (genericMatch != null) {
      final baseName = _simplifyTypeName(genericMatch.group(1)!);
      final typeArgs = genericMatch.group(2)!;
      final nullable = genericMatch.group(3) ?? '';
      final simplifiedArgs =
          _splitTypeArgs(typeArgs).map(_simplifyTypeName).join(', ');
      return '$baseName<$simplifiedArgs>$nullable';
    }

    // Handle nullable types
    if (qualifiedName.endsWith('?')) {
      return '${_simplifyTypeName(qualifiedName.substring(0, qualifiedName.length - 1))}?';
    }

    // Extract simple name
    final lastDot = qualifiedName.lastIndexOf('.');
    if (lastDot >= 0) {
      return qualifiedName.substring(lastDot + 1);
    }

    return qualifiedName;
  }

  String generateBarrel(List<String> fileNames) {
    final buffer = StringBuffer();

    buffer.writeln('/// Generated AST model barrel file.');
    buffer.writeln('/// Exports all generated AST model classes.');
    buffer.writeln('library;');
    buffer.writeln();

    // Export stub types first (needed by ast_model)
    buffer.writeln("export 'src/analyzer/_stub_types.dart';");
    
    // Export the main AST model file
    for (final fileName in fileNames..sort()) {
      // Skip stub types as we already exported it
      if (fileName == '_stub_types.dart') continue;
      buffer.writeln("export 'src/analyzer/$fileName';");
    }

    return buffer.toString();
  }
}

/// Represents a parsed class from the analysis.
class ClassData {
  final String name;
  final String qualifiedName;
  final String libraryUri;
  final String? documentation;
  final bool isAbstract;
  final bool isSealed;
  final bool isFinal;
  final bool isBase;
  final bool isInterface;
  final bool isMixin;
  final String? superclass;
  final List<String> interfaces;
  final List<String> mixins;
  final List<TypeParamData> typeParameters;
  final List<FieldData> fields;
  final List<MethodData> methods;

  ClassData({
    required this.name,
    required this.qualifiedName,
    required this.libraryUri,
    this.documentation,
    this.isAbstract = false,
    this.isSealed = false,
    this.isFinal = false,
    this.isBase = false,
    this.isInterface = false,
    this.isMixin = false,
    this.superclass,
    this.interfaces = const [],
    this.mixins = const [],
    this.typeParameters = const [],
    this.fields = const [],
    this.methods = const [],
  });

  factory ClassData.fromYaml(YamlMap yaml, String libraryUri) {
    final superclassMap = yaml['superclass'] as YamlMap?;
    final superclassName = superclassMap?['qualifiedName'] as String?;

    return ClassData(
      name: yaml['name'] as String? ?? '',
      qualifiedName: yaml['qualifiedName'] as String? ?? '',
      libraryUri: libraryUri,
      documentation: yaml['documentation'] as String?,
      isAbstract: yaml['isAbstract'] as bool? ?? false,
      isSealed: yaml['isSealed'] as bool? ?? false,
      isFinal: yaml['isFinal'] as bool? ?? false,
      isBase: yaml['isBase'] as bool? ?? false,
      isInterface: yaml['isInterface'] as bool? ?? false,
      isMixin: yaml['isMixin'] as bool? ?? false,
      superclass: superclassName,
      interfaces: _parseTypeRefList(yaml['interfaces']),
      mixins: _parseTypeRefList(yaml['mixins']),
      typeParameters: _parseTypeParams(yaml['typeParameters']),
      fields: _parseFields(yaml['fields']),
      methods: _parseMethods(yaml['methods']),
    );
  }
}

/// Represents a type parameter.
class TypeParamData {
  final String name;
  final String? bound;

  TypeParamData({required this.name, this.bound});
}

/// Represents a field.
class FieldData {
  final String name;
  final String type;
  final bool isStatic;
  final bool isFinal;
  final bool isConst;
  final bool isLate;
  final bool hasInitializer;

  FieldData({
    required this.name,
    required this.type,
    this.isStatic = false,
    this.isFinal = false,
    this.isConst = false,
    this.isLate = false,
    this.hasInitializer = false,
  });
}

/// Represents a method.
class MethodData {
  final String name;
  final String returnType;
  final bool isStatic;
  final bool isAbstract;
  final bool isOperator;
  final List<TypeParamData> typeParameters;
  final List<ParameterData> parameters;

  MethodData({
    required this.name,
    required this.returnType,
    this.isStatic = false,
    this.isAbstract = false,
    this.isOperator = false,
    this.typeParameters = const [],
    this.parameters = const [],
  });
}

/// Represents a parameter.
class ParameterData {
  final String name;
  final String type;
  final bool isNamed;
  final bool isRequired;
  final bool isOptionalPositional;

  ParameterData({
    required this.name,
    required this.type,
    this.isNamed = false,
    this.isRequired = false,
    this.isOptionalPositional = false,
  });
}

// Helper functions

List<String> _parseTypeRefList(dynamic yaml) {
  if (yaml == null) return [];
  final list = yaml as YamlList;
  return list
      .map((t) {
        final typeMap = t as YamlMap;
        return typeMap['qualifiedName'] as String? ?? '';
      })
      .where((s) => s.isNotEmpty)
      .toList();
}

List<TypeParamData> _parseTypeParams(dynamic yaml) {
  if (yaml == null) return [];
  final list = yaml as YamlList;
  return list.map((t) {
    final paramMap = t as YamlMap;
    final boundMap = paramMap['bound'] as YamlMap?;
    return TypeParamData(
      name: paramMap['name'] as String? ?? '',
      bound: boundMap?['qualifiedName'] as String?,
    );
  }).toList();
}

List<FieldData> _parseFields(dynamic yaml) {
  if (yaml == null) return [];
  final list = yaml as YamlList;
  return list.map((f) {
    final fieldMap = f as YamlMap;
    final typeMap = fieldMap['type'] as YamlMap?;
    return FieldData(
      name: fieldMap['name'] as String? ?? '',
      type: typeMap?['qualifiedName'] as String? ?? 'dynamic',
      isStatic: fieldMap['isStatic'] as bool? ?? false,
      isFinal: fieldMap['isFinal'] as bool? ?? false,
      isConst: fieldMap['isConst'] as bool? ?? false,
      isLate: fieldMap['isLate'] as bool? ?? false,
      hasInitializer: fieldMap['hasInitializer'] as bool? ?? false,
    );
  }).toList();
}

List<MethodData> _parseMethods(dynamic yaml) {
  if (yaml == null) return [];
  final list = yaml as YamlList;
  return list.map((m) {
    final methodMap = m as YamlMap;
    final returnTypeMap = methodMap['returnType'] as YamlMap?;
    return MethodData(
      name: methodMap['name'] as String? ?? '',
      returnType: returnTypeMap?['qualifiedName'] as String? ?? 'void',
      isStatic: methodMap['isStatic'] as bool? ?? false,
      isAbstract: methodMap['isAbstract'] as bool? ?? false,
      isOperator: methodMap['isOperator'] as bool? ?? false,
      typeParameters: _parseTypeParams(methodMap['typeParameters']),
      parameters: _parseParameters(methodMap['parameters']),
    );
  }).toList();
}

List<ParameterData> _parseParameters(dynamic yaml) {
  if (yaml == null) return [];
  final list = yaml as YamlList;
  return list.map((p) {
    final paramMap = p as YamlMap;
    final typeMap = paramMap['type'] as YamlMap?;
    return ParameterData(
      name: paramMap['name'] as String? ?? '',
      type: typeMap?['qualifiedName'] as String? ?? 'dynamic',
      isNamed: paramMap['isNamed'] as bool? ?? false,
      isRequired: paramMap['isRequired'] as bool? ?? false,
      isOptionalPositional: paramMap['isOptionalPositional'] as bool? ?? false,
    );
  }).toList();
}
