/// Entry point analyzer for reflection generation.
///
/// Analyzes Dart entry points to discover types and members that should
/// be included in reflection output based on reachability and filters.
library;

// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:path/path.dart' as p;

import 'filter_matcher.dart';
import 'reflection_config.dart';

/// Result of entry point analysis.
///
/// Contains all types and members discovered from entry points,
/// categorized by kind and filtered according to configuration.
class AnalysisResult {
  /// All discovered classes.
  final List<ClassElement> classes;

  /// All discovered enums.
  final List<EnumElement> enums;

  /// All discovered mixins.
  final List<MixinElement> mixins;

  /// All discovered extension types.
  final List<ExtensionTypeElement> extensionTypes;

  /// All discovered extensions.
  final List<ExtensionElement> extensions;

  /// All discovered type aliases.
  final List<TypeAliasElement> typeAliases;

  /// All discovered global (top-level) functions.
  final List<FunctionElement> globalFunctions;

  /// All discovered global (top-level) variables.
  final List<TopLevelVariableElement> globalVariables;

  /// Package to library URI mapping.
  final Map<String, List<String>> packageLibraries;

  /// Library URI to types mapping.
  final Map<String, List<InterfaceElement>> libraryTypes;

  const AnalysisResult({
    this.classes = const [],
    this.enums = const [],
    this.mixins = const [],
    this.extensionTypes = const [],
    this.extensions = const [],
    this.typeAliases = const [],
    this.globalFunctions = const [],
    this.globalVariables = const [],
    this.packageLibraries = const {},
    this.libraryTypes = const {},
  });

  /// Total number of types discovered.
  int get typeCount =>
      classes.length +
      enums.length +
      mixins.length +
      extensionTypes.length +
      typeAliases.length;

  /// Total number of global members discovered.
  int get globalMemberCount => globalFunctions.length + globalVariables.length;
}

/// Analyzes entry points to discover types for reflection.
class EntryPointAnalyzer {
  /// The configuration for reflection generation.
  final ReflectionConfig config;

  /// The inclusion resolver for filtering.
  late final InclusionResolver _inclusionResolver;

  /// Visited libraries (to avoid re-processing).
  final Set<String> _visitedLibraries = {};

  /// Collected classes.
  final List<ClassElement> _classes = [];

  /// Collected enums.
  final List<EnumElement> _enums = [];

  /// Collected mixins.
  final List<MixinElement> _mixins = [];

  /// Collected extension types.
  final List<ExtensionTypeElement> _extensionTypes = [];

  /// Collected extensions.
  final List<ExtensionElement> _extensions = [];

  /// Collected type aliases.
  final List<TypeAliasElement> _typeAliases = [];

  /// Collected global functions.
  final List<FunctionElement> _globalFunctions = [];

  /// Collected global variables.
  final List<TopLevelVariableElement> _globalVariables = [];

  /// Package to libraries mapping.
  final Map<String, List<String>> _packageLibraries = {};

  /// Library to types mapping.
  final Map<String, List<InterfaceElement>> _libraryTypes = {};

  /// Types pending dependency resolution.
  final Set<InterfaceElement> _pendingDependencies = {};

  EntryPointAnalyzer(this.config) {
    _inclusionResolver = InclusionResolver(
      defaultsConfig: config.defaults,
      filterConfigs: config.filters,
    );
  }

  /// Analyze entry points and return discovered types.
  Future<AnalysisResult> analyze() async {
    if (config.entryPoints.isEmpty) {
      return const AnalysisResult();
    }

    // Resolve entry points to absolute paths
    final absolutePaths = config.entryPoints.map((ep) {
      return p.isAbsolute(ep) ? ep : p.absolute(ep);
    }).toList();

    // Create analysis context
    final collection = AnalysisContextCollection(
      includedPaths: absolutePaths,
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    );

    // Analyze each entry point
    for (final entryPoint in absolutePaths) {
      final context = collection.contextFor(entryPoint);
      final result = await context.currentSession.getResolvedLibrary(entryPoint);
      if (result is ResolvedLibraryResult) {
        await _processLibrary(result.element);
      }
    }

    // Resolve transitive dependencies
    await _resolveDependencies();

    return AnalysisResult(
      classes: List.unmodifiable(_classes),
      enums: List.unmodifiable(_enums),
      mixins: List.unmodifiable(_mixins),
      extensionTypes: List.unmodifiable(_extensionTypes),
      extensions: List.unmodifiable(_extensions),
      typeAliases: List.unmodifiable(_typeAliases),
      globalFunctions: List.unmodifiable(_globalFunctions),
      globalVariables: List.unmodifiable(_globalVariables),
      packageLibraries: Map.unmodifiable(_packageLibraries),
      libraryTypes: Map.unmodifiable(_libraryTypes),
    );
  }

  Future<void> _processLibrary(LibraryElement library) async {
    final uri = library.source.uri.toString();
    if (_visitedLibraries.contains(uri)) return;
    _visitedLibraries.add(uri);

    // Track package
    final packageName = _getPackageName(library);
    if (packageName != null) {
      _packageLibraries.putIfAbsent(packageName, () => []).add(uri);
    }

    // Process top-level declarations
    for (final unit in library.units) {
      for (final cls in unit.classes) {
        if (_shouldInclude(cls)) {
          _addClass(cls, uri);
        }
      }

      for (final enm in unit.enums) {
        if (_shouldInclude(enm)) {
          _addEnum(enm, uri);
        }
      }

      for (final mixin in unit.mixins) {
        if (_shouldInclude(mixin)) {
          _addMixin(mixin, uri);
        }
      }

      for (final extType in unit.extensionTypes) {
        if (_shouldInclude(extType)) {
          _addExtensionType(extType, uri);
        }
      }

      for (final ext in unit.extensions) {
        if (_shouldIncludeExtension(ext)) {
          _addExtension(ext);
        }
      }

      for (final alias in unit.typeAliases) {
        if (_shouldInclude(alias)) {
          _addTypeAlias(alias);
        }
      }

      for (final func in unit.functions) {
        if (_shouldInclude(func)) {
          _addGlobalFunction(func);
        }
      }

      for (final variable in unit.topLevelVariables) {
        if (_shouldInclude(variable)) {
          _addGlobalVariable(variable);
        }
      }
    }

    // Follow exports/imports
    for (final export in library.exportedLibraries) {
      await _processLibrary(export);
    }
  }

  void _addClass(ClassElement cls, String libraryUri) {
    if (_classes.any((c) => c.name == cls.name && c.library == cls.library)) {
      return;
    }
    _classes.add(cls);
    _libraryTypes.putIfAbsent(libraryUri, () => []).add(cls);
    _pendingDependencies.add(cls);
  }

  void _addEnum(EnumElement enm, String libraryUri) {
    if (_enums.any((e) => e.name == enm.name && e.library == enm.library)) {
      return;
    }
    _enums.add(enm);
    _libraryTypes.putIfAbsent(libraryUri, () => []).add(enm);
    _pendingDependencies.add(enm);
  }

  void _addMixin(MixinElement mixin, String libraryUri) {
    if (_mixins.any((m) => m.name == mixin.name && m.library == mixin.library)) {
      return;
    }
    _mixins.add(mixin);
    _libraryTypes.putIfAbsent(libraryUri, () => []).add(mixin);
    _pendingDependencies.add(mixin);
  }

  void _addExtensionType(ExtensionTypeElement extType, String libraryUri) {
    if (_extensionTypes
        .any((e) => e.name == extType.name && e.library == extType.library)) {
      return;
    }
    _extensionTypes.add(extType);
    _libraryTypes.putIfAbsent(libraryUri, () => []).add(extType);
    _pendingDependencies.add(extType);
  }

  void _addExtension(ExtensionElement ext) {
    if (_extensions.any((e) => e.name == ext.name && e.library == ext.library)) {
      return;
    }
    _extensions.add(ext);
  }

  void _addTypeAlias(TypeAliasElement alias) {
    if (_typeAliases
        .any((a) => a.name == alias.name && a.library == alias.library)) {
      return;
    }
    _typeAliases.add(alias);
  }

  void _addGlobalFunction(FunctionElement func) {
    if (_globalFunctions
        .any((f) => f.name == func.name && f.library == func.library)) {
      return;
    }
    _globalFunctions.add(func);
  }

  void _addGlobalVariable(TopLevelVariableElement variable) {
    if (_globalVariables
        .any((v) => v.name == variable.name && v.library == variable.library)) {
      return;
    }
    _globalVariables.add(variable);
  }

  Future<void> _resolveDependencies() async {
    final depConfig = config.dependencyConfig;
    final processed = <InterfaceElement>{};

    while (_pendingDependencies.isNotEmpty) {
      final current = _pendingDependencies.first;
      _pendingDependencies.remove(current);

      if (processed.contains(current)) continue;
      processed.add(current);

      // Process superclasses
      if (depConfig.superclasses.enabled && current is ClassElement) {
        _processSuperclasses(current);
      }

      // Process interfaces
      if (depConfig.interfaces.enabled) {
        _processInterfaces(current);
      }

      // Process mixins
      if (depConfig.mixins.enabled && current is ClassElement) {
        _processMixins(current);
      }

      // Process type arguments
      if (depConfig.typeArguments.enabled) {
        _processTypeArguments(current);
      }
    }
  }

  void _processSuperclasses(ClassElement cls) {
    final depConfig = config.dependencyConfig.superclasses;
    final excludeTypes = depConfig.excludeTypes.toSet();

    var depth = 0;
    var externalDepth = 0;
    var current = cls.supertype?.element;
    final currentPackage = _getPackageName(cls);

    while (current != null) {
      // Check depth limits
      if (depConfig.depth >= 0 && depth >= depConfig.depth) break;

      final superPackage = _getPackageName(current);
      final isExternal = superPackage != currentPackage;

      if (isExternal) {
        externalDepth++;
        if (depConfig.externalDepth >= 0 &&
            externalDepth > depConfig.externalDepth) {
          break;
        }
      }

      // Check exclude types
      if (excludeTypes.contains(current.name)) break;

      // Add the superclass
      if (current is ClassElement) {
        final uri = current.library.source.uri.toString();
        _addClass(current, uri);
      }

      depth++;
      current = (current as ClassElement?)?.supertype?.element;
    }
  }

  void _processInterfaces(InterfaceElement element) {
    final depConfig = config.dependencyConfig.interfaces;
    final currentPackage = _getPackageName(element);

    for (final interface in element.interfaces) {
      final interfaceElement = interface.element;

      // Check if external
      final interfacePackage = _getPackageName(interfaceElement);
      final isExternal = interfacePackage != currentPackage;

      if (isExternal && !depConfig.external) continue;

      // Add interface
      if (interfaceElement is ClassElement) {
        final uri = interfaceElement.library.source.uri.toString();
        _addClass(interfaceElement, uri);
      }
    }
  }

  void _processMixins(ClassElement cls) {
    final depConfig = config.dependencyConfig.mixins;
    final currentPackage = _getPackageName(cls);

    for (final mixin in cls.mixins) {
      final mixinElement = mixin.element;

      // Check if external
      final mixinPackage = _getPackageName(mixinElement);
      final isExternal = mixinPackage != currentPackage;

      if (isExternal && !depConfig.external) continue;

      // Add mixin
      if (mixinElement is MixinElement) {
        final uri = mixinElement.library.source.uri.toString();
        _addMixin(mixinElement, uri);
      }
    }
  }

  void _processTypeArguments(InterfaceElement element) {
    final depConfig = config.dependencyConfig.typeArguments;
    final currentPackage = _getPackageName(element);

    // Process fields
    for (final field in element.fields) {
      _processTypeForArguments(field.type, currentPackage, depConfig.external);
    }

    // Process methods
    for (final method in element.methods) {
      _processTypeForArguments(
          method.returnType, currentPackage, depConfig.external);
      for (final param in method.parameters) {
        _processTypeForArguments(
            param.type, currentPackage, depConfig.external);
      }
    }
  }

  void _processTypeForArguments(
      DartType type, String? currentPackage, bool includeExternal) {
    if (type is InterfaceType) {
      // Check if external
      final typePackage = _getPackageName(type.element);
      final isExternal = typePackage != currentPackage;

      if (!isExternal || includeExternal) {
        final element = type.element;
        if (element is ClassElement) {
          final uri = element.library.source.uri.toString();
          _addClass(element, uri);
        } else if (element is EnumElement) {
          final uri = element.library.source.uri.toString();
          _addEnum(element, uri);
        }
      }

      // Process type arguments recursively
      for (final typeArg in type.typeArguments) {
        _processTypeForArguments(typeArg, currentPackage, includeExternal);
      }
    }
  }

  bool _shouldInclude(Element element) {
    // Check private
    if (!config.includePrivate && (element.name?.startsWith('_') ?? false)) {
      return false;
    }

    // Check inclusion resolver
    final result = _inclusionResolver.shouldInclude(element);
    if (result != null) return result;

    // Default: include if reachable
    return true;
  }

  bool _shouldIncludeExtension(ExtensionElement ext) {
    // Extensions without names are anonymous and might be less useful
    if (ext.name == null && !config.includePrivate) {
      return false;
    }

    return _shouldInclude(ext);
  }

  String? _getPackageName(Element element) {
    final uri = element.library?.source.uri;
    if (uri == null) return null;
    if (uri.scheme == 'package') {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }
    if (uri.scheme == 'dart') {
      return 'dart:${uri.path}';
    }
    return null;
  }
}
