/// Reflection code generator.
///
/// Generates `.r.dart` files containing reflection data structures,
/// invokers, and the `reflectionApi` entry point based on configuration.
library;

// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:path/path.dart' as p;

import 'entry_point_analyzer.dart';
import 'reflection_config.dart';

/// Generates reflection code for a Dart project.
///
/// The generator:
/// 1. Parses configuration from `tom_analyzer.yaml`
/// 2. Analyzes entry points to discover types
/// 3. Applies filters to determine what to include
/// 4. Generates `.r.dart` file with reflection data
class ReflectionGenerator {
  /// The configuration for generation.
  final ReflectionConfig config;

  /// Analysis result (populated after analyze()).
  ReflectionAnalysisResult? _analysisResult;

  /// Import prefix counter.
  int _prefixCounter = 0;

  /// Type to import prefix mapping.
  final Map<String, String> _importPrefixes = {};

  /// Library URI to import prefix mapping.
  final Map<String, String> _libraryPrefixes = {};

  /// Invoker index counter.
  int _invokerCounter = 0;

  /// Declaration index counter (for future use).
  // ignore: unused_field
  int _declarationCounter = 0;

  /// Type index counter.
  int _typeCounter = 0;

  /// Parameter index counter (for future member data arrays).
  // ignore: unused_field
  int _parameterCounter = 0;

  /// Maps type elements to their indices.
  final Map<Element, int> _typeIndices = {};

  /// Set of types that are declarations-only (no invokers generated).
  /// Uses negative indices to indicate this.
  final Set<Element> _declarationsOnlyTypes = {};

  /// Maps members to their invoker indices.
  final Map<Element, int> _memberInvokerIndices = {};

  /// Maps fields to their getter invoker indices.
  final Map<Element, int> _fieldGetterInvokerIndices = {};

  /// Maps fields to their setter invoker indices.
  final Map<Element, int> _fieldSetterInvokerIndices = {};

  /// Maps constructors to their invoker indices.
  final Map<Element, int> _constructorInvokerIndices = {};

  /// Maps extensions to their indices.
  final Map<Element, int> _extensionIndices = {};

  /// Maps class elements to the list of extension indices that apply to them.
  final Map<Element, List<int>> _classExtensions = {};

  /// Maps extension method elements to their invoker indices.
  final Map<Element, int> _extensionMethodInvokerIndices = {};

  ReflectionGenerator(this.config);

  /// Create a generator from a configuration file.
  factory ReflectionGenerator.fromFile(String path) {
    return ReflectionGenerator(ReflectionConfig.load(path: path));
  }

  /// Create a generator from a YAML map.
  factory ReflectionGenerator.fromMap(Map<String, dynamic> map) {
    return ReflectionGenerator(ReflectionConfig.fromMap(map));
  }

  /// Analyze entry points and discover types.
  Future<ReflectionAnalysisResult> analyze() async {
    final analyzer = EntryPointAnalyzer(config);
    _analysisResult = await analyzer.analyze();
    return _analysisResult!;
  }

  /// Generate the reflection file.
  ///
  /// Returns the generated code as a string.
  Future<String> generate() async {
    if (_analysisResult == null) {
      await analyze();
    }
    return generateFromResult(_analysisResult!);
  }

  /// Generate reflection code from a pre-analyzed result.
  ///
  /// This is useful for multi-entry-point generation where results
  /// from multiple analyses are merged before code generation.
  Future<String> generateFromResult(ReflectionAnalysisResult result) async {
    _analysisResult = result;

    // Reset counters
    _prefixCounter = 0;
    _importPrefixes.clear();
    _libraryPrefixes.clear();
    _invokerCounter = 0;
    _declarationCounter = 0;
    _typeCounter = 0;
    _parameterCounter = 0;
    _typeIndices.clear();
    _declarationsOnlyTypes.clear();
    _memberInvokerIndices.clear();
    _fieldGetterInvokerIndices.clear();
    _fieldSetterInvokerIndices.clear();
    _constructorInvokerIndices.clear();
    _extensionIndices.clear();
    _classExtensions.clear();
    _extensionMethodInvokerIndices.clear();

    // Pre-compute type indices and declarations-only status
    _computeTypeIndices(result);

    // Pre-compute extension indices and which classes they apply to
    _computeExtensionIndices(result);

    final buffer = StringBuffer();

    // Header
    _writeHeader(buffer);

    // Imports
    _writeImports(buffer, result);

    // Bit flag constants
    _writeFlagConstants(buffer);

    // Package and library structure
    _writePackageStructure(buffer, result);

    // Invokers array
    _writeInvokers(buffer, result);

    // Reflection data structure
    _writeReflectionData(buffer, result);

    // API initialization
    _writeInitialization(buffer);

    return buffer.toString();
  }

  /// Generate and write to the output file.
  Future<void> generateToFile() async {
    final code = await generate();
    final outputPath = config.getOutputPath();

    // Ensure directory exists
    final dir = Directory(p.dirname(outputPath));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    // Write file
    File(outputPath).writeAsStringSync(code);
  }

  void _writeHeader(StringBuffer buffer) {
    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// Generated by tom_analyzer reflection generator');
    buffer.writeln('// ignore_for_file: type=lint');
    buffer.writeln();
  }

  void _writeImports(StringBuffer buffer, ReflectionAnalysisResult result) {
    // Runtime import
    buffer.writeln("import 'package:tom_analyzer/reflection_runtime.dart' as r;");
    buffer.writeln();

    // Collect all library URIs that need imports
    final libraryUris = <String>{};

    for (final cls in result.classes) {
      libraryUris.add(cls.library.source.uri.toString());
    }
    for (final enm in result.enums) {
      libraryUris.add(enm.library.source.uri.toString());
    }
    for (final mixin in result.mixins) {
      libraryUris.add(mixin.library.source.uri.toString());
    }
    for (final extType in result.extensionTypes) {
      libraryUris.add(extType.library.source.uri.toString());
    }
    for (final func in result.globalFunctions) {
      libraryUris.add(func.library.source.uri.toString());
    }
    for (final variable in result.globalVariables) {
      libraryUris.add(variable.library.source.uri.toString());
    }

    // Generate imports with prefixes
    for (final uri in libraryUris.toList()..sort()) {
      // Skip dart: imports for now (handled separately)
      if (uri.startsWith('dart:')) continue;

      final prefix = 'p${_prefixCounter++}';
      _libraryPrefixes[uri] = prefix;
      buffer.writeln("import '$uri' as $prefix;");
    }

    buffer.writeln();
  }

  void _writeFlagConstants(StringBuffer buffer) {
    buffer.writeln('// ═══════════════════════════════════════════════════════════════════');
    buffer.writeln('// Bit flag constants for element descriptors');
    buffer.writeln('// ═══════════════════════════════════════════════════════════════════');
    buffer.writeln();

    // Class flags
    buffer.writeln('// Class flags');
    buffer.writeln('const _abstract = 1 << 0;');
    buffer.writeln('const _mixin = 1 << 1;');
    buffer.writeln('const _sealed = 1 << 2;');
    buffer.writeln('const _final = 1 << 3;');
    buffer.writeln('const _interface = 1 << 4;');
    buffer.writeln('const _base = 1 << 5;');
    buffer.writeln();

    // Member flags
    buffer.writeln('// Member flags');
    buffer.writeln('const _static = 1 << 0;');
    buffer.writeln('const _finalMember = 1 << 1;');
    buffer.writeln('const _const = 1 << 2;');
    buffer.writeln('const _late = 1 << 3;');
    buffer.writeln('const _getter = 1 << 4;');
    buffer.writeln('const _setter = 1 << 5;');
    buffer.writeln('const _method = 1 << 6;');
    buffer.writeln('const _constructor = 1 << 7;');
    buffer.writeln('const _factory = 1 << 8;');
    buffer.writeln('const _extension = 1 << 9;');
    buffer.writeln('const _async = 1 << 10;');
    buffer.writeln('const _generator = 1 << 11;');
    buffer.writeln();
  }

  void _writePackageStructure(StringBuffer buffer, ReflectionAnalysisResult result) {
    buffer.writeln('// ═══════════════════════════════════════════════════════════════════');
    buffer.writeln('// Package and Library Structure');
    buffer.writeln('// ═══════════════════════════════════════════════════════════════════');
    buffer.writeln();

    // Packages array
    buffer.writeln('const _packages = <r.PackageData>[');
    var packageIndex = 0;
    final packageIndices = <String, int>{};
    final libraryIndices = <String, int>{};
    var libraryIndex = 0;

    for (final packageName in result.packageLibraries.keys.toList()..sort()) {
      final libraries = result.packageLibraries[packageName]!;
      final libIndices = <int>[];

      for (final libUri in libraries) {
        libraryIndices[libUri] = libraryIndex;
        libIndices.add(libraryIndex);
        libraryIndex++;
      }

      packageIndices[packageName] = packageIndex;
      buffer.writeln(
          "  r.PackageData('$packageName', const ${libIndices.toString()}),  // Index $packageIndex");
      packageIndex++;
    }
    buffer.writeln('];');
    buffer.writeln();

    // Libraries array
    buffer.writeln('const _libraries = <r.LibraryData>[');
    for (final libUri in libraryIndices.keys.toList()..sort()) {
      final packageName = _getPackageFromUri(libUri);
      final pkgIdx = packageIndices[packageName] ?? 0;

      // Get type indices for this library
      final types = result.libraryTypes[libUri] ?? [];
      final typeIndices =
          types.map((t) => _getTypeIndex(t)).where((i) => i >= 0).toList();

      buffer.writeln("  r.LibraryData(");
      buffer.writeln("    '$libUri',");
      buffer.writeln("    $pkgIdx,  // package index");
      buffer.writeln("    const $typeIndices,  // type indices");
      buffer.writeln("    const [],  // declaration indices");
      buffer.writeln("  ),");
    }
    buffer.writeln('];');
    buffer.writeln();
  }

  void _writeInvokers(StringBuffer buffer, ReflectionAnalysisResult result) {
    buffer.writeln('// ═══════════════════════════════════════════════════════════════════');
    buffer.writeln('// Invokers Array');
    buffer.writeln('// ═══════════════════════════════════════════════════════════════════');
    buffer.writeln();
    buffer.writeln('const _invokers = <Function>[');

    // Generate invokers for each class
    for (final cls in result.classes) {
      _writeClassInvokers(buffer, cls);
    }

    // Generate invokers for global functions
    for (final func in result.globalFunctions) {
      _writeGlobalFunctionInvoker(buffer, func);
    }

    // Generate invokers for global variables
    for (final variable in result.globalVariables) {
      _writeGlobalVariableInvokers(buffer, variable);
    }

    // Generate invokers for extensions
    for (final ext in result.extensions) {
      _writeExtensionInvokers(buffer, ext);
    }

    buffer.writeln('];');
    buffer.writeln();
  }

  void _writeClassInvokers(StringBuffer buffer, ClassElement cls) {
    final prefix = _getPrefix(cls);

    // Skip declarations-only types (but track them)
    final isDeclarationsOnly = _declarationsOnlyTypes.contains(cls);

    // Skip abstract classes for constructor invokers
    if (!cls.isAbstract && !isDeclarationsOnly) {
      // Constructor invokers
      for (final ctor in cls.constructors) {
        if (ctor.isPrivate) continue;
        if (!_shouldGenerateInvoker(ctor)) continue;

        final ctorName = ctor.name.isEmpty ? 'new' : ctor.name;
        _constructorInvokerIndices[ctor] = _invokerCounter;
        buffer.writeln(
            "  // ${cls.name}.$ctorName constructor - Index ${_invokerCounter++}");
        if (ctor.name.isEmpty) {
          buffer.writeln(
              "  (List args, Map<Symbol, dynamic> named) => Function.apply($prefix.${cls.name}.new, args, named),");
        } else {
          buffer.writeln(
              "  (List args, Map<Symbol, dynamic> named) => Function.apply($prefix.${cls.name}.${ctor.name}, args, named),");
        }
      }
    }

    // Skip member invokers for declarations-only types
    if (isDeclarationsOnly) return;

    // Instance method invokers
    for (final method in cls.methods) {
      if (method.isPrivate || method.isStatic) continue;
      if (!_shouldGenerateInvoker(method)) continue;

      _memberInvokerIndices[method] = _invokerCounter;
      buffer.writeln(
          "  // ${cls.name}.${method.name} method - Index ${_invokerCounter++}");
      buffer.writeln(
          "  (dynamic i, List args, Map<Symbol, dynamic> named) => Function.apply(i.${method.name}, args, named),");
    }

    // Instance field getters
    for (final field in cls.fields) {
      if (field.isPrivate || field.isStatic) continue;

      _fieldGetterInvokerIndices[field] = _invokerCounter;
      buffer.writeln(
          "  // ${cls.name}.${field.name} getter - Index ${_invokerCounter++}");
      buffer.writeln("  (dynamic i) => i.${field.name},");

      // Field setter (if not final/const)
      if (!field.isFinal && !field.isConst) {
        _fieldSetterInvokerIndices[field] = _invokerCounter;
        buffer.writeln(
            "  // ${cls.name}.${field.name} setter - Index ${_invokerCounter++}");
        buffer.writeln("  (dynamic i, dynamic v) => i.${field.name} = v,");
      }
    }

    // Static method invokers
    for (final method in cls.methods) {
      if (method.isPrivate || !method.isStatic) continue;
      if (!_shouldGenerateInvoker(method)) continue;

      _memberInvokerIndices[method] = _invokerCounter;
      buffer.writeln(
          "  // ${cls.name}.${method.name} static - Index ${_invokerCounter++}");
      buffer.writeln(
          "  (List args, Map<Symbol, dynamic> named) => Function.apply($prefix.${cls.name}.${method.name}, args, named),");
    }

    // Static field accessors
    for (final field in cls.fields) {
      if (field.isPrivate || !field.isStatic) continue;

      _fieldGetterInvokerIndices[field] = _invokerCounter;
      buffer.writeln(
          "  // ${cls.name}.${field.name} static getter - Index ${_invokerCounter++}");
      buffer.writeln("  () => $prefix.${cls.name}.${field.name},");

      if (!field.isFinal && !field.isConst) {
        _fieldSetterInvokerIndices[field] = _invokerCounter;
        buffer.writeln(
            "  // ${cls.name}.${field.name} static setter - Index ${_invokerCounter++}");
        buffer.writeln("  (dynamic v) => $prefix.${cls.name}.${field.name} = v,");
      }
    }
  }

  void _writeGlobalFunctionInvoker(StringBuffer buffer, FunctionElement func) {
    if (func.isPrivate) return;

    final prefix = _getPrefix(func);
    buffer.writeln("  // ${func.name} global function - Index ${_invokerCounter++}");
    buffer.writeln(
        "  (List args, Map<Symbol, dynamic> named) => Function.apply($prefix.${func.name}, args, named),");
  }

  void _writeGlobalVariableInvokers(
      StringBuffer buffer, TopLevelVariableElement variable) {
    if (variable.isPrivate) return;

    final prefix = _getPrefix(variable);
    _fieldGetterInvokerIndices[variable] = _invokerCounter;
    buffer.writeln(
        "  // ${variable.name} global getter - Index ${_invokerCounter++}");
    buffer.writeln("  () => $prefix.${variable.name},");

    if (!variable.isFinal && !variable.isConst) {
      _fieldSetterInvokerIndices[variable] = _invokerCounter;
      buffer.writeln(
          "  // ${variable.name} global setter - Index ${_invokerCounter++}");
      buffer.writeln("  (dynamic v) => $prefix.${variable.name} = v,");
    }
  }

  void _writeExtensionInvokers(StringBuffer buffer, ExtensionElement ext) {
    // Extensions without names are anonymous
    final extName = ext.name ?? '<anonymous>';
    final prefix = _getPrefix(ext);

    // Extension method invokers
    for (final method in ext.methods) {
      if (method.isPrivate) continue;
      if (!_shouldGenerateInvoker(method)) continue;

      _extensionMethodInvokerIndices[method] = _invokerCounter;
      buffer.writeln(
          "  // $extName.${method.name} extension method - Index ${_invokerCounter++}");
      // Extension methods need to be called with the extended object as first arg
      if (ext.name != null) {
        buffer.writeln(
            "  (dynamic target, List args, Map<Symbol, dynamic> named) => "
            "Function.apply($prefix.${ext.name}(target).${method.name}, args, named),");
      } else {
        // Anonymous extensions - generate a direct call
        buffer.writeln(
            "  (dynamic target, List args, Map<Symbol, dynamic> named) => "
            "Function.apply(target.${method.name}, args, named),");
      }
    }

    // Extension getter/setter invokers
    for (final accessor in ext.accessors) {
      if (accessor.isPrivate) continue;

      if (accessor.isGetter) {
        _extensionMethodInvokerIndices[accessor] = _invokerCounter;
        buffer.writeln(
            "  // $extName.${accessor.name} extension getter - Index ${_invokerCounter++}");
        if (ext.name != null) {
          buffer.writeln("  (dynamic target) => $prefix.${ext.name}(target).${accessor.name},");
        } else {
          buffer.writeln("  (dynamic target) => target.${accessor.name},");
        }
      } else if (accessor.isSetter) {
        _extensionMethodInvokerIndices[accessor] = _invokerCounter;
        final propName = accessor.name.replaceAll('=', '');
        buffer.writeln(
            "  // $extName.$propName extension setter - Index ${_invokerCounter++}");
        if (ext.name != null) {
          buffer.writeln("  (dynamic target, dynamic v) => $prefix.${ext.name}(target).$propName = v,");
        } else {
          buffer.writeln("  (dynamic target, dynamic v) => target.$propName = v,");
        }
      }
    }
  }

  void _writeReflectionData(StringBuffer buffer, ReflectionAnalysisResult result) {
    buffer.writeln('// ═══════════════════════════════════════════════════════════════════');
    buffer.writeln('// Reflection Data Structure');
    buffer.writeln('// ═══════════════════════════════════════════════════════════════════');
    buffer.writeln();
    buffer.writeln('final _reflectionData = r.ReflectionData(');
    buffer.writeln('  packages: _packages,');
    buffer.writeln('  libraries: _libraries,');
    buffer.writeln('  invokers: _invokers,');
    buffer.writeln();

    // Types array
    buffer.writeln('  types: <r.TypeMirrorData>[');
    for (final cls in result.classes) {
      _writeClassMirrorData(buffer, cls);
    }
    for (final enm in result.enums) {
      _writeEnumMirrorData(buffer, enm);
    }
    for (final mixin in result.mixins) {
      _writeMixinMirrorData(buffer, mixin);
    }
    buffer.writeln('  ],');
    buffer.writeln();

    // Declarations array
    buffer.writeln('  declarations: <r.DeclarationMirrorData>[');
    _writeDeclarations(buffer, result);
    buffer.writeln('  ],');
    buffer.writeln();

    // Parameters array
    buffer.writeln('  parameters: <r.ParameterMirrorData>[');
    _writeParameters(buffer, result);
    buffer.writeln('  ],');
    buffer.writeln();

    // Type refs array
    buffer.writeln('  typeRefs: <Type>[');
    for (final cls in result.classes) {
      final prefix = _getPrefix(cls);
      buffer.writeln('    $prefix.${cls.name},');
    }
    for (final enm in result.enums) {
      final prefix = _getPrefix(enm);
      buffer.writeln('    $prefix.${enm.name},');
    }
    for (final mixin in result.mixins) {
      final prefix = _getPrefix(mixin);
      buffer.writeln('    $prefix.${mixin.name},');
    }
    buffer.writeln('  ],');
    buffer.writeln(');');
    buffer.writeln();
  }

  void _writeDeclarations(StringBuffer buffer, ReflectionAnalysisResult result) {
    // Generate declaration data for all class members
    for (final cls in result.classes) {
      _writeClassDeclarations(buffer, cls);
    }

    // Generate declaration data for mixins
    for (final mixin in result.mixins) {
      _writeMixinDeclarations(buffer, mixin);
    }

    // Generate declaration data for extensions
    for (final ext in result.extensions) {
      _writeExtensionDeclarations(buffer, ext);
    }

    // Generate declaration data for global members
    _writeGlobalDeclarations(buffer, result);
  }

  void _writeClassDeclarations(StringBuffer buffer, ClassElement cls) {
    final ownerIndex = _typeIndices[cls] ?? -1;
    final isDeclarationsOnly = _declarationsOnlyTypes.contains(cls);

    // Constructors
    for (final ctor in cls.constructors) {
      if (ctor.isPrivate) continue;

      final invokerIndex = isDeclarationsOnly 
          ? -1 
          : (_constructorInvokerIndices[ctor] ?? -1);
      final flags = _computeConstructorFlags(ctor);
      final name = ctor.name.isEmpty ? '' : ctor.name;

      buffer.writeln("    // Constructor: ${cls.name}.${ctor.name.isEmpty ? 'new' : ctor.name}");
      buffer.writeln('    r.ConstructorMirrorData(');
      buffer.writeln("      '$name',  // name");
      buffer.writeln('      $flags,  // flags');
      buffer.writeln('      $ownerIndex,  // owner index');
      buffer.writeln('      $invokerIndex,  // invoker index');
      buffer.writeln('      const [],  // parameter indices');
      buffer.writeln('      const [],  // type parameter indices');
      buffer.writeln('      const [],  // annotation indices');
      buffer.writeln('    ),');
    }

    // Methods
    for (final method in cls.methods) {
      if (method.isPrivate) continue;

      final invokerIndex = isDeclarationsOnly
          ? -1
          : (_memberInvokerIndices[method] ?? -1);
      final flags = _computeMethodFlags(method);

      buffer.writeln("    // Method: ${cls.name}.${method.name}");
      buffer.writeln('    r.MethodMirrorData(');
      buffer.writeln("      '${method.name}',  // name");
      buffer.writeln('      $flags,  // flags');
      buffer.writeln('      $ownerIndex,  // owner index');
      buffer.writeln('      -1,  // return type ref index');
      buffer.writeln('      $invokerIndex,  // invoker index');
      buffer.writeln('      const [],  // parameter indices');
      buffer.writeln('      const [],  // type parameter indices');
      buffer.writeln('      const [],  // annotation indices');
      buffer.writeln('    ),');
    }

    // Fields
    for (final field in cls.fields) {
      if (field.isPrivate) continue;

      final getterIndex = isDeclarationsOnly
          ? -1
          : (_fieldGetterInvokerIndices[field] ?? -1);
      final setterIndex = (field.isFinal || field.isConst || isDeclarationsOnly)
          ? -1
          : (_fieldSetterInvokerIndices[field] ?? -1);
      final flags = _computeFieldFlags(field);

      buffer.writeln("    // Field: ${cls.name}.${field.name}");
      buffer.writeln('    r.FieldMirrorData(');
      buffer.writeln("      '${field.name}',  // name");
      buffer.writeln('      $flags,  // flags');
      buffer.writeln('      $ownerIndex,  // owner index');
      buffer.writeln('      -1,  // type ref index');
      buffer.writeln('      $getterIndex,  // getter invoker index');
      buffer.writeln('      $setterIndex,  // setter invoker index');
      buffer.writeln('      const [],  // annotation indices');
      buffer.writeln('    ),');
    }
  }

  void _writeMixinDeclarations(StringBuffer buffer, MixinElement mixin) {
    final ownerIndex = _typeIndices[mixin] ?? -1;

    // Mixin methods
    for (final method in mixin.methods) {
      if (method.isPrivate) continue;

      final flags = _computeMethodFlags(method);

      buffer.writeln("    // Method: ${mixin.name}.${method.name}");
      buffer.writeln('    r.MethodMirrorData(');
      buffer.writeln("      '${method.name}',  // name");
      buffer.writeln('      $flags,  // flags');
      buffer.writeln('      $ownerIndex,  // owner index');
      buffer.writeln('      -1,  // return type ref index');
      buffer.writeln('      -1,  // invoker index (mixin)');
      buffer.writeln('      const [],  // parameter indices');
      buffer.writeln('      const [],  // type parameter indices');
      buffer.writeln('      const [],  // annotation indices');
      buffer.writeln('    ),');
    }

    // Mixin fields
    for (final field in mixin.fields) {
      if (field.isPrivate) continue;

      final flags = _computeFieldFlags(field);

      buffer.writeln("    // Field: ${mixin.name}.${field.name}");
      buffer.writeln('    r.FieldMirrorData(');
      buffer.writeln("      '${field.name}',  // name");
      buffer.writeln('      $flags,  // flags');
      buffer.writeln('      $ownerIndex,  // owner index');
      buffer.writeln('      -1,  // type ref index');
      buffer.writeln('      -1,  // getter invoker index (mixin)');
      buffer.writeln('      -1,  // setter invoker index (mixin)');
      buffer.writeln('      const [],  // annotation indices');
      buffer.writeln('    ),');
    }
  }

  void _writeExtensionDeclarations(StringBuffer buffer, ExtensionElement ext) {
    final extName = ext.name ?? '<anonymous>';
    final extIndex = _extensionIndices[ext] ?? -1;

    // Extension methods - these get added to the applicable classes' available methods
    for (final method in ext.methods) {
      if (method.isPrivate) continue;

      final invokerIndex = _extensionMethodInvokerIndices[method] ?? -1;
      var flags = 1 << 6; // method flag
      flags |= 1 << 9; // extension flag
      if (method.isAsynchronous) flags |= 1 << 10;
      if (method.isGenerator) flags |= 1 << 11;

      buffer.writeln("    // Extension method: $extName.${method.name}");
      buffer.writeln('    r.MethodMirrorData(');
      buffer.writeln("      '${method.name}',  // name");
      buffer.writeln('      $flags,  // flags (includes extension flag)');
      buffer.writeln('      $extIndex,  // owner index (extension index)');
      buffer.writeln('      -1,  // return type ref index');
      buffer.writeln('      $invokerIndex,  // invoker index');
      buffer.writeln('      const [],  // parameter indices');
      buffer.writeln('      const [],  // type parameter indices');
      buffer.writeln('      const [],  // annotation indices');
      buffer.writeln('    ),');
    }

    // Extension getters/setters
    for (final accessor in ext.accessors) {
      if (accessor.isPrivate) continue;

      final invokerIndex = _extensionMethodInvokerIndices[accessor] ?? -1;

      if (accessor.isGetter) {
        var flags = 1 << 4; // getter flag
        flags |= 1 << 9; // extension flag

        buffer.writeln("    // Extension getter: $extName.${accessor.name}");
        buffer.writeln('    r.GetterMirrorData(');
        buffer.writeln("      '${accessor.name}',  // name");
        buffer.writeln('      $flags,  // flags');
        buffer.writeln('      $extIndex,  // owner index (extension index)');
        buffer.writeln('      -1,  // return type ref index');
        buffer.writeln('      $invokerIndex,  // invoker index');
        buffer.writeln('      const [],  // annotation indices');
        buffer.writeln('    ),');
      } else if (accessor.isSetter) {
        final propName = accessor.name.replaceAll('=', '');
        var flags = 1 << 5; // setter flag
        flags |= 1 << 9; // extension flag

        buffer.writeln("    // Extension setter: $extName.$propName");
        buffer.writeln('    r.SetterMirrorData(');
        buffer.writeln("      '$propName',  // name");
        buffer.writeln('      $flags,  // flags');
        buffer.writeln('      $extIndex,  // owner index (extension index)');
        buffer.writeln('      -1,  // parameter type ref index');
        buffer.writeln('      $invokerIndex,  // invoker index');
        buffer.writeln('      const [],  // annotation indices');
        buffer.writeln('    ),');
      }
    }
  }

  void _writeGlobalDeclarations(StringBuffer buffer, ReflectionAnalysisResult result) {
    // Global functions
    for (final func in result.globalFunctions) {
      if (func.isPrivate) continue;

      final invokerIndex = _memberInvokerIndices[func] ?? -1;
      var flags = 0;
      if (func.isAsynchronous) flags |= 1 << 10;
      if (func.isGenerator) flags |= 1 << 11;

      buffer.writeln("    // Global function: ${func.name}");
      buffer.writeln('    r.MethodMirrorData(');
      buffer.writeln("      '${func.name}',  // name");
      buffer.writeln('      $flags,  // flags');
      buffer.writeln('      -1,  // owner index (global)');
      buffer.writeln('      -1,  // return type ref index');
      buffer.writeln('      $invokerIndex,  // invoker index');
      buffer.writeln('      const [],  // parameter indices');
      buffer.writeln('      const [],  // type parameter indices');
      buffer.writeln('      const [],  // annotation indices');
      buffer.writeln('    ),');
    }

    // Global variables
    for (final variable in result.globalVariables) {
      if (variable.isPrivate) continue;

      final getterIndex = _fieldGetterInvokerIndices[variable] ?? -1;
      final setterIndex = (variable.isFinal || variable.isConst)
          ? -1
          : (_fieldSetterInvokerIndices[variable] ?? -1);
      var flags = 0;
      if (variable.isFinal) flags |= 1 << 1;
      if (variable.isConst) flags |= 1 << 2;
      if (variable.isLate) flags |= 1 << 3;

      buffer.writeln("    // Global variable: ${variable.name}");
      buffer.writeln('    r.FieldMirrorData(');
      buffer.writeln("      '${variable.name}',  // name");
      buffer.writeln('      $flags,  // flags');
      buffer.writeln('      -1,  // owner index (global)');
      buffer.writeln('      -1,  // type ref index');
      buffer.writeln('      $getterIndex,  // getter invoker index');
      buffer.writeln('      $setterIndex,  // setter invoker index');
      buffer.writeln('      const [],  // annotation indices');
      buffer.writeln('    ),');
    }
  }

  void _writeParameters(StringBuffer buffer, ReflectionAnalysisResult result) {
    // Generate parameters for constructors and methods
    for (final cls in result.classes) {
      for (final ctor in cls.constructors) {
        if (ctor.isPrivate) continue;
        for (final param in ctor.parameters) {
          _writeParameterData(buffer, param);
        }
      }
      for (final method in cls.methods) {
        if (method.isPrivate) continue;
        for (final param in method.parameters) {
          _writeParameterData(buffer, param);
        }
      }
    }

    // Generate parameters for global functions
    for (final func in result.globalFunctions) {
      if (func.isPrivate) continue;
      for (final param in func.parameters) {
        _writeParameterData(buffer, param);
      }
    }
  }

  void _writeParameterData(StringBuffer buffer, ParameterElement param) {
    var flags = 0;
    if (param.isRequired) flags |= 1 << 0;
    if (param.isNamed) flags |= 1 << 1;
    if (param.isOptional) flags |= 1 << 2;
    if (param.isRequiredNamed) flags |= 1 << 3;
    if (param.isOptionalPositional) flags |= 1 << 4;

    buffer.writeln('    r.ParameterMirrorData(');
    buffer.writeln("      '${param.name}',  // name");
    buffer.writeln('      $flags,  // flags');
    buffer.writeln('      -1,  // owner index');
    buffer.writeln('      -1,  // type ref index');
    buffer.writeln('      null,  // default value');
    buffer.writeln('    ),');
    _parameterCounter++;
  }

  int _computeConstructorFlags(ConstructorElement ctor) {
    var flags = 1 << 7; // constructor flag
    if (ctor.isFactory) flags |= 1 << 8;
    if (ctor.isConst) flags |= 1 << 2;
    return flags;
  }

  int _computeMethodFlags(MethodElement method) {
    var flags = 1 << 6; // method flag
    if (method.isStatic) flags |= 1 << 0;
    if (method.isAsynchronous) flags |= 1 << 10;
    if (method.isGenerator) flags |= 1 << 11;
    return flags;
  }

  int _computeFieldFlags(FieldElement field) {
    var flags = 0;
    if (field.isStatic) flags |= 1 << 0;
    if (field.isFinal) flags |= 1 << 1;
    if (field.isConst) flags |= 1 << 2;
    if (field.isLate) flags |= 1 << 3;
    return flags;
  }

  void _writeClassMirrorData(StringBuffer buffer, ClassElement cls) {
    final prefix = _getPrefix(cls);
    final typeIndex = _typeIndices[cls] ?? _typeCounter++;
    final flags = _computeClassFlags(cls);
    final isDeclarationsOnly = _declarationsOnlyTypes.contains(cls);

    // Compute superclass index
    final superclassIndex = _getSuperclassIndex(cls);

    // Compute interface indices
    final interfaceIndices = cls.interfaces
        .map((i) => _typeIndices[i.element] ?? -1)
        .where((i) => i >= 0)
        .toList();

    // Compute mixin indices
    final mixinIndices = cls.mixins
        .map((m) => _typeIndices[m.element] ?? -1)
        .where((i) => i >= 0)
        .toList();

    // Compute constructor invoker indices
    final constructorInvokerIndices = <int>[];
    if (!isDeclarationsOnly) {
      for (final ctor in cls.constructors) {
        if (ctor.isPrivate) continue;
        final idx = _constructorInvokerIndices[ctor];
        if (idx != null) {
          constructorInvokerIndices.add(idx);
        }
      }
    }

    // Get applicable extension indices
    final extensionIndices = _classExtensions[cls] ?? [];

    buffer.writeln('    // Index $typeIndex: ${cls.name}${isDeclarationsOnly ? " (declarations-only)" : ""}');
    buffer.writeln('    r.ClassMirrorData<$prefix.${cls.name}>(');
    buffer.writeln("      '${cls.name}',  // name");
    buffer.writeln('      $flags,  // flags');
    buffer.writeln('      0,  // library index');
    buffer.writeln('      const [],  // own declaration indices');
    buffer.writeln('      const [],  // all instance members');
    buffer.writeln('      const [],  // static member indices');
    buffer.writeln('      $superclassIndex,  // superclass type index');
    buffer.writeln('      const $interfaceIndices,  // interface type indices');
    buffer.writeln('      const $mixinIndices,  // mixin type indices');
    buffer.writeln('      const $extensionIndices,  // applicable extension indices');
    buffer.writeln('      const [],  // annotation indices');
    buffer.writeln('      const $constructorInvokerIndices,  // constructor invoker indices');
    buffer.writeln('    ),');
  }

  /// Gets the type index for a class's superclass.
  int _getSuperclassIndex(ClassElement cls) {
    final supertype = cls.supertype;
    if (supertype == null) return -1;
    final superElement = supertype.element;
    // Object has no meaningful superclass
    if (superElement.name == 'Object' &&
        superElement.library.source.uri.toString() == 'dart:core') {
      return -1;
    }
    return _typeIndices[superElement] ?? -1;
  }

  void _writeEnumMirrorData(StringBuffer buffer, EnumElement enm) {
    final prefix = _getPrefix(enm);
    final typeIndex = _typeIndices[enm] ?? _typeCounter++;

    // Collect enum value names
    final valueNames = enm.fields
        .where((f) => f.isEnumConstant)
        .map((f) => "'${f.name}'")
        .toList();

    buffer.writeln('    // Index $typeIndex: ${enm.name}');
    buffer.writeln('    r.EnumMirrorData<$prefix.${enm.name}>(');
    buffer.writeln("      '${enm.name}',  // name");
    buffer.writeln('      0,  // flags');
    buffer.writeln('      0,  // library index');
    buffer.writeln('      const [$valueNames],  // value names');
    buffer.writeln('      const [],  // annotation indices');
    buffer.writeln('    ),');
  }

  void _writeMixinMirrorData(StringBuffer buffer, MixinElement mixin) {
    final prefix = _getPrefix(mixin);
    final typeIndex = _typeIndices[mixin] ?? _typeCounter++;

    // Compute superclass constraint indices
    final constraintIndices = mixin.superclassConstraints
        .map((c) => _typeIndices[c.element] ?? -1)
        .where((i) => i >= 0)
        .toList();

    buffer.writeln('    // Index $typeIndex: ${mixin.name} (declarations-only)');
    buffer.writeln('    r.MixinMirrorData<$prefix.${mixin.name}>(');
    buffer.writeln("      '${mixin.name}',  // name");
    buffer.writeln('      0,  // flags');
    buffer.writeln('      0,  // library index');
    buffer.writeln('      const $constraintIndices,  // superclass constraints');
    buffer.writeln('      const [],  // declaration indices');
    buffer.writeln('      const [],  // annotation indices');
    buffer.writeln('    ),');
  }

  void _writeInitialization(StringBuffer buffer) {
    buffer.writeln('// ═══════════════════════════════════════════════════════════════════');
    buffer.writeln('// Runtime API Initialization');
    buffer.writeln('// ═══════════════════════════════════════════════════════════════════');
    buffer.writeln();
    buffer.writeln('void initializeReflection() {');
    buffer.writeln('  r.registerReflectionData(_reflectionData);');
    buffer.writeln('}');
    buffer.writeln();
    buffer.writeln('final reflectionApi = r.ReflectionApi.fromData(_reflectionData);');
  }

  /// Pre-computes type indices and determines which types are declarations-only.
  ///
  /// A type is "declarations-only" if:
  /// - It's from an external package with limited depth
  /// - It's explicitly excluded from coverage
  /// - It's abstract (no constructor invokers needed)
  void _computeTypeIndices(ReflectionAnalysisResult result) {
    var index = 0;

    // Index all classes
    for (final cls in result.classes) {
      _typeIndices[cls] = index++;
      if (_isDeclarationsOnly(cls)) {
        _declarationsOnlyTypes.add(cls);
      }
    }

    // Index all enums
    for (final enm in result.enums) {
      _typeIndices[enm] = index++;
      // Enums are never declarations-only
    }

    // Index all mixins
    for (final mixin in result.mixins) {
      _typeIndices[mixin] = index++;
      // Mixins are declarations-only (cannot be instantiated)
      _declarationsOnlyTypes.add(mixin);
    }

    // Index extension types
    for (final extType in result.extensionTypes) {
      _typeIndices[extType] = index++;
      if (_isDeclarationsOnly(extType)) {
        _declarationsOnlyTypes.add(extType);
      }
    }
  }

  /// Determines if a type should be treated as declarations-only.
  ///
  /// Types that are declarations-only have negative invoker indices,
  /// meaning their members can be queried but not invoked at runtime.
  bool _isDeclarationsOnly(InterfaceElement element) {
    // Abstract classes are declarations-only (no constructors)
    if (element is ClassElement && element.isAbstract) {
      return true;
    }

    // Check if this type's package is excluded from coverage
    final uri = element.library.source.uri.toString();
    if (uri.startsWith('dart:')) {
      return true; // Dart SDK types are declarations-only
    }

    // Check external package depth limits
    if (uri.startsWith('package:')) {
      final packageName = _getPackageFromUri(uri);
      // Determine entry packages from entry point analysis
      final entryPackages = <String>{};
      if (_analysisResult != null) {
        for (final pkg in _analysisResult!.packageLibraries.keys) {
          entryPackages.add(pkg);
        }
      }

      if (!entryPackages.contains(packageName)) {
        // External package - check depth limit
        // For now, mark as declarations-only if external
        // TODO: Implement proper depth tracking
        return false; // Allow external packages with full coverage by default
      }
    }

    return false;
  }

  /// Pre-computes extension indices and maps them to applicable classes.
  void _computeExtensionIndices(ReflectionAnalysisResult result) {
    var index = 0;

    for (final ext in result.extensions) {
      _extensionIndices[ext] = index++;

      // Determine which classes this extension applies to
      final extendedType = ext.extendedType;
      if (extendedType is InterfaceType) {
        final extendedElement = extendedType.element;
        // Find all classes that are subtypes of the extended type
        for (final cls in result.classes) {
          if (_extendsOrImplements(cls, extendedElement)) {
            _classExtensions.putIfAbsent(cls, () => []).add(index - 1);
          }
        }
      }
    }
  }

  /// Checks if a class extends or implements a given type.
  bool _extendsOrImplements(ClassElement cls, InterfaceElement target) {
    if (cls == target) return true;

    // Check superclass chain
    var supertype = cls.supertype;
    while (supertype != null) {
      if (supertype.element == target) return true;
      supertype = supertype.element.supertype;
    }

    // Check interfaces
    for (final interface in cls.allSupertypes) {
      if (interface.element == target) return true;
    }

    return false;
  }

  int _computeClassFlags(ClassElement cls) {
    var flags = 0;
    if (cls.isAbstract) flags |= 1 << 0;
    if (cls.isMixinClass) flags |= 1 << 1;
    if (cls.isSealed) flags |= 1 << 2;
    if (cls.isFinal) flags |= 1 << 3;
    if (cls.isInterface) flags |= 1 << 4;
    if (cls.isBase) flags |= 1 << 5;
    return flags;
  }

  String _getPrefix(Element element) {
    final uri = element.library?.source.uri.toString();
    if (uri == null) return '';
    return _libraryPrefixes[uri] ?? '';
  }

  String _getPackageFromUri(String uri) {
    if (uri.startsWith('package:')) {
      final path = uri.substring('package:'.length);
      final slashIndex = path.indexOf('/');
      return slashIndex > 0 ? path.substring(0, slashIndex) : path;
    }
    if (uri.startsWith('dart:')) {
      return uri;
    }
    return 'unknown';
  }

  int _getTypeIndex(InterfaceElement element) {
    return _typeIndices[element] ?? -1;
  }

  bool _shouldGenerateInvoker(Element element) {
    // Check coverage config
    if (element is ConstructorElement) {
      if (!config.coverageConfig.constructors.enabled) return false;
      final pattern = config.coverageConfig.constructors.pattern;
      if (pattern != null && pattern.isNotEmpty) {
        final name = element.name;
        if (name.isEmpty) {
          return config.coverageConfig.constructors.unnamed;
        }
        return GlobMatcher(pattern).matches(name);
      }
      return true;
    }

    if (element is MethodElement) {
      if (element.isStatic) {
        return config.coverageConfig.staticMembers.enabled;
      } else {
        if (!config.coverageConfig.instanceMembers.enabled) return false;
        final pattern = config.coverageConfig.instanceMembers.pattern;
        if (pattern != null && pattern.isNotEmpty) {
          return GlobMatcher(pattern).matches(element.name);
        }
        return true;
      }
    }

    return true;
  }
}

/// Simple glob pattern matcher (duplicated from filter_matcher.dart for independence).
class GlobMatcher {
  final String pattern;
  late final RegExp _regex;

  GlobMatcher(this.pattern) {
    _regex = _compileGlob(pattern);
  }

  bool matches(String input) {
    return _regex.hasMatch(input);
  }

  static RegExp _compileGlob(String pattern) {
    final buffer = StringBuffer('^');
    var i = 0;
    while (i < pattern.length) {
      final c = pattern[i];
      if (c == '*') {
        if (i + 1 < pattern.length && pattern[i + 1] == '*') {
          buffer.write('.*');
          i += 2;
        } else {
          buffer.write('[^/]*');
          i++;
        }
      } else if (c == '?') {
        buffer.write('.');
        i++;
      } else if (r'\.+[]{}()^$|'.contains(c)) {
        buffer.write('\\$c');
        i++;
      } else {
        buffer.write(c);
        i++;
      }
    }
    buffer.write(r'$');
    return RegExp(buffer.toString());
  }
}
