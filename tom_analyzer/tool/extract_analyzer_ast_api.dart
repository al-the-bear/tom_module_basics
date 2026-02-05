// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element2.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/file_system/physical_file_system.dart';

/// Extracts the public API from the analyzer's AST library.
Future<void> main(List<String> args) async {
  // Find the analyzer package in pub cache
  final home = Platform.environment['HOME']!;
  final analyzerPath = '$home/.pub-cache/hosted/pub.dev/analyzer-8.4.1';
  final astFile = '$analyzerPath/lib/dart/ast/ast.dart';

  if (!File(astFile).existsSync()) {
    print('Error: Could not find analyzer AST file at $astFile');
    exit(1);
  }

  print('Analyzing: $astFile');

  final collection = AnalysisContextCollection(
    includedPaths: [analyzerPath],
    resourceProvider: PhysicalResourceProvider.INSTANCE,
  );

  final context = collection.contextFor(astFile);
  final result = await context.currentSession.getResolvedLibrary(astFile);

  if (result is! ResolvedLibraryResult) {
    print('Error: Could not resolve library');
    exit(1);
  }

  final library = result.element2;

  // Collect all exported types
  final exportedTypes = <String, Map<String, dynamic>>{};

  // Get library fragment and its exports
  final libraryFragment = library.fragments.first;
  for (final export in libraryFragment.libraryExports) {
    final exportedLibrary = export.exportedLibrary;
    if (exportedLibrary == null) continue;

    // Get all top-level elements from exported library
    final allElements = <InterfaceElement2>[
      ...exportedLibrary.classes,
      ...exportedLibrary.enums,
      ...exportedLibrary.mixins,
    ];

    for (final element in allElements) {
      final name = element.name3;
      if (name == null) continue;

      // Check if it's exported (not hidden)
      final combinators = export.combinators;
      bool isExported = true;

      for (final combinator in combinators) {
        if (combinator is ShowElementCombinator) {
          isExported = combinator.shownNames.contains(name);
          if (!isExported) break;
        } else if (combinator is HideElementCombinator) {
          if (combinator.hiddenNames.contains(name)) {
            isExported = false;
            break;
          }
        }
      }

      if (!isExported) continue;

      // Skip implementation classes
      if (name.endsWith('Impl')) continue;

      exportedTypes[name] = _extractTypeInfo(element);
    }
  }

  // Sort by name
  final sortedTypes = Map.fromEntries(
    exportedTypes.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );

  // Output as JSON
  final output = {
    'totalTypes': sortedTypes.length,
    'types': sortedTypes,
  };

  final outputPath = args.isNotEmpty ? args[0] : '/tmp/analyzer_ast_api.json';
  await File(outputPath).writeAsString(
    const JsonEncoder.withIndent('  ').convert(output),
  );

  print('Extracted ${sortedTypes.length} types to $outputPath');

  // Print summary
  print('\nType counts by kind:');
  final abstractCount =
      sortedTypes.values.where((t) => t['isAbstract'] == true).length;
  final sealedCount =
      sortedTypes.values.where((t) => t['isSealed'] == true).length;
  final concreteCount = sortedTypes.values
      .where((t) => t['isAbstract'] != true && t['isSealed'] != true)
      .length;

  print('  Abstract: $abstractCount');
  print('  Sealed: $sealedCount');
  print('  Concrete: $concreteCount');
}

Map<String, dynamic> _extractTypeInfo(InterfaceElement2 element) {
  final info = <String, dynamic>{
    'name': element.name3,
    'kind': element is ClassElement2
        ? 'class'
        : element is MixinElement2
            ? 'mixin'
            : element is EnumElement2
                ? 'enum'
                : 'interface',
    'isAbstract': element is ClassElement2 && element.isAbstract,
    'isSealed': element is ClassElement2 && element.isSealed,
  };

  // Get superclass
  if (element is ClassElement2 && element.supertype != null) {
    final supertype = element.supertype!;
    final superName = supertype.element3.name3;
    if (superName != null && superName != 'Object') {
      info['superclass'] = superName;
    }
  }

  // Get interfaces
  if (element.interfaces.isNotEmpty) {
    info['interfaces'] = element.interfaces
        .map((i) => i.element3.name3)
        .where((n) => n != null && n != 'Object')
        .toList();
  }

  // Get mixins
  if (element is ClassElement2 && element.mixins.isNotEmpty) {
    info['mixins'] =
        element.mixins.map((m) => m.element3.name3).whereType<String>().toList();
  }

  // Get type parameters
  if (element.typeParameters2.isNotEmpty) {
    info['typeParameters'] = element.typeParameters2.map((tp) {
      final result = <String, dynamic>{'name': tp.name3};
      if (tp.bound != null) {
        result['bound'] = _typeToString(tp.bound!);
      }
      return result;
    }).toList();
  }

  // Get public getters
  final getters = element.getters2
      .where((g) => g.isPublic)
      .map((g) => {
            'name': g.name3,
            'type': _typeToString(g.returnType),
          })
      .toList();
  if (getters.isNotEmpty) {
    info['getters'] = getters;
  }

  // Get public setters
  final setters = element.setters2
      .where((s) => s.isPublic)
      .map((s) => {
            'name': s.name3?.replaceAll('=', ''),
            'type': s.formalParameters.isNotEmpty
                ? _typeToString(s.formalParameters.first.type)
                : 'dynamic',
          })
      .toList();
  if (setters.isNotEmpty) {
    info['setters'] = setters;
  }

  // Get public methods
  final methods = element.methods2
      .where((m) => m.isPublic && !m.isStatic)
      .map((m) => {
            'name': m.name3,
            'returnType': _typeToString(m.returnType),
            'parameters': m.formalParameters.map((p) => {
                  'name': p.name3,
                  'type': _typeToString(p.type),
                  'isRequired': p.isRequired,
                  'isNamed': p.isNamed,
                }).toList(),
          })
      .toList();
  if (methods.isNotEmpty) {
    info['methods'] = methods;
  }

  return info;
}

String _typeToString(DartType type) {
  if (type is InterfaceType) {
    final name = type.element3.name3;
    if (name == null) return 'dynamic';
    if (type.typeArguments.isEmpty) {
      return name;
    }
    final args = type.typeArguments.map(_typeToString).join(', ');
    return '$name<$args>';
  }
  if (type is TypeParameterType) {
    return type.element3.name3 ?? 'T';
  }
  if (type is FunctionType) {
    final params =
        type.formalParameters.map((p) => _typeToString(p.type)).join(', ');
    return '${_typeToString(type.returnType)} Function($params)';
  }
  return type.getDisplayString();
}
