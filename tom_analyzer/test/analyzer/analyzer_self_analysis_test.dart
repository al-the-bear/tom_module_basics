// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart' as analysis_results;
import 'package:analyzer/dart/element/element.dart' as analyzer_elements;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tom_analyzer/tom_analyzer.dart';

void main() {
  group('TomAnalyzer', () {
    group('self analysis json', () {
      late AnalysisResult analysisResult;
      late String rootPath;

      setUpAll(() {
        final cwd = p.normalize(p.absolute(Directory.current.path));
        rootPath = p.basename(cwd) == 'test' ? p.dirname(cwd) : cwd;
        final jsonFile = File(p.join(rootPath, 'doc', 'analyzer_analysis.json'));
        final content = jsonFile.readAsStringSync();
        analysisResult = JsonDeserializer.decode(content);
      });

      test('should contain all analyzer elements from the package', () async {
        final contextBuilder = AnalyzerContextBuilder();
        final collection = contextBuilder.build(
          rootPath: rootPath,
          includedPaths: [rootPath],
        );

        final entryPath = p.join(rootPath, 'lib', 'tom_analyzer.dart');
        final context = collection.contextFor(entryPath);
        final session = context.currentSession;
        final analyzedFiles = context.contextRoot.analyzedFiles();

        final classNames = analysisResult.allClasses.map((c) => c.qualifiedName).toSet();
        final enumNames = analysisResult.allEnums.map((e) => e.qualifiedName).toSet();
        final mixinNames = analysisResult.allMixins.map((m) => m.qualifiedName).toSet();
        final extensionNames = analysisResult.allExtensions.map((e) => e.qualifiedName).toSet();
        final extensionTypeNames =
            analysisResult.allExtensionTypes.map((e) => e.qualifiedName).toSet();
        final typeAliasNames = analysisResult.allTypeAliases.map((t) => t.qualifiedName).toSet();
        final functionNames = analysisResult.allFunctions.map((f) => f.qualifiedName).toSet();

        expect(classNames, isNotEmpty, reason: 'Expected classes in analysis result.');

        for (final path in analyzedFiles) {
          if (!path.endsWith('.dart')) {
            continue;
          }
          final result = await session.getResolvedLibrary(path);
          if (result is! analysis_results.ResolvedLibraryResult) {
            continue;
          }

          final libraryUri = result.element.source.uri;
          if (!_isInPackage(libraryUri, rootPath, 'tom_analyzer')) {
            continue;
          }

          for (final element in result.element.topLevelElements) {
            final name = element.displayName;
            if (name.isEmpty) {
              continue;
            }
            final qualifiedName = _qualifiedName(element);

            if (element is analyzer_elements.ClassElement) {
              expect(
                classNames,
                contains(qualifiedName),
                reason: 'Missing class $qualifiedName in JSON analysis.',
              );
            } else if (element is analyzer_elements.EnumElement) {
              expect(
                enumNames,
                contains(qualifiedName),
                reason: 'Missing enum $qualifiedName in JSON analysis.',
              );
            } else if (element is analyzer_elements.MixinElement) {
              expect(
                mixinNames,
                contains(qualifiedName),
                reason: 'Missing mixin $qualifiedName in JSON analysis.',
              );
            } else if (element is analyzer_elements.ExtensionElement) {
              expect(
                extensionNames,
                contains(qualifiedName),
                reason: 'Missing extension $qualifiedName in JSON analysis.',
              );
            } else if (element is analyzer_elements.ExtensionTypeElement) {
              expect(
                extensionTypeNames,
                contains(qualifiedName),
                reason: 'Missing extension type $qualifiedName in JSON analysis.',
              );
            } else if (element is analyzer_elements.TypeAliasElement) {
              expect(
                typeAliasNames,
                contains(qualifiedName),
                reason: 'Missing type alias $qualifiedName in JSON analysis.',
              );
            } else if (element is analyzer_elements.FunctionElement) {
              expect(
                functionNames,
                contains(qualifiedName),
                reason: 'Missing function $qualifiedName in JSON analysis.',
              );
            }
          }
        }
      });
    });
  });
}

String _qualifiedName(analyzer_elements.Element element) {
  final libraryUri = element.librarySource?.uri.toString() ?? '';
  final name = element.displayName;
  return '$libraryUri.$name';
}

bool _isInPackage(Uri uri, String rootPath, String packageName) {
  if (uri.scheme == 'package') {
    if (uri.pathSegments.isEmpty) return false;
    return uri.pathSegments.first == packageName;
  }
  if (uri.scheme == 'file') {
    final filePath = uri.toFilePath();
    return p.isWithin(rootPath, filePath);
  }
  return false;
}
