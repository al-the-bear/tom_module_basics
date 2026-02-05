/// Verification script that reads the generated analysis YAML
/// and compares it with AST generation results and direct analyzer results.
library;
import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart' as analyzer_results;
import 'package:analyzer/dart/ast/ast.dart' as analyzer_ast;
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:tom_analyzer/tom_analyzer.dart' as tom;
import 'package:tom_d4rt_ast/ast_converter.dart';

void main() async {
  final analysisFile = File('lib/main.analysis.yaml');

  if (!analysisFile.existsSync()) {
    print('ERROR: Analysis file not found!');
    print('');
    print('Run: dart run build_runner build');
    print('');
    exit(1);
  }

  // Deserialize the YAML into the AnalysisResult object model
  final content = analysisFile.readAsStringSync();
  final tom.AnalysisResult result = tom.YamlDeserializer.decode(content);

  print('═══════════════════════════════════════════════════════════════════');
  print('  TOM ANALYZER - VERIFICATION & COMPARISON REPORT');
  print('  Target: dart analyzer package');
  print('═══════════════════════════════════════════════════════════════════');
  print('');

  // =========================================================================
  // SECTION 1: Tom Analyzer Results (from build_runner)
  // =========================================================================
  print('┌─────────────────────────────────────────────────────────────────┐');
  print('│  SECTION 1: TOM ANALYZER (build_runner generated)              │');
  print('└─────────────────────────────────────────────────────────────────┘');
  print('');

  // Metadata from the AnalysisResult API
  print('ANALYSIS METADATA:');
  print('  Analysis ID:      ${result.id}');
  print('  Timestamp:        ${result.timestamp.toIso8601String()}');
  print('  Dart SDK:         ${result.dartSdkVersion}');
  print('  Analyzer Version: ${result.analyzerVersion}');
  print('  Schema Version:   ${result.schemaVersion}');
  print('');

  // Packages from the API
  print('PACKAGES: ${result.packages.length}');
  for (final pkg in result.packages.values) {
    final isRoot = pkg.name == result.rootPackage.name;
    print('  - ${pkg.name} ${isRoot ? "(root)" : ""} - ${pkg.libraries.length} libraries');
  }
  print('');

  // Libraries from the API
  print('LIBRARIES: ${result.libraries.length}');
  print('');

  // Type definitions using the API convenience getters
  final analyzerStats = _AnalyzerStats(
    classes: result.allClasses.length,
    enums: result.allEnums.length,
    mixins: result.allMixins.length,
    extensions: result.allExtensions.length,
    typeAliases: result.allTypeAliases.length,
    functions: result.allFunctions.length,
    constructors: 0,
    methods: 0,
    fields: 0,
  );

  // Count members
  for (final cls in result.allClasses) {
    analyzerStats.constructors += cls.constructors.length;
    analyzerStats.methods += cls.methods.length;
    analyzerStats.fields += cls.fields.length;
  }
  for (final enm in result.allEnums) {
    analyzerStats.constructors += enm.constructors.length;
    analyzerStats.methods += enm.methods.length;
    analyzerStats.fields += enm.fields.length;
  }
  for (final mix in result.allMixins) {
    analyzerStats.methods += mix.methods.length;
    analyzerStats.fields += mix.fields.length;
  }
  for (final ext in result.allExtensions) {
    analyzerStats.methods += ext.methods.length;
  }

  print('TYPE DEFINITIONS:');
  print('  Classes:       ${analyzerStats.classes}');
  print('  Enums:         ${analyzerStats.enums}');
  print('  Mixins:        ${analyzerStats.mixins}');
  print('  Extensions:    ${analyzerStats.extensions}');
  print('  Type Aliases:  ${analyzerStats.typeAliases}');
  print('');

  print('MEMBERS:');
  print('  Constructors:  ${analyzerStats.constructors}');
  print('  Methods:       ${analyzerStats.methods}');
  print('  Fields:        ${analyzerStats.fields}');
  print('  Functions:     ${analyzerStats.functions}');
  print('');

  // =========================================================================
  // SECTION 2: Dart Analyzer Results (direct analysis)
  // =========================================================================
  print('┌─────────────────────────────────────────────────────────────────┐');
  print('│  SECTION 2: DART ANALYZER (direct analysis)                   │');
  print('└─────────────────────────────────────────────────────────────────┘');
  print('');

  final dartAnalyzerStats = await _scanWithDartAnalyzer();

  print('FILES SCANNED: ${dartAnalyzerStats.filesScanned}');
  print('');

  print('ANALYZER NODE COUNTS:');
  print('  ClassDeclaration:       ${dartAnalyzerStats.classes}');
  print('  EnumDeclaration:        ${dartAnalyzerStats.enums}');
  print('  MixinDeclaration:       ${dartAnalyzerStats.mixins}');
  print('  ExtensionDeclaration:   ${dartAnalyzerStats.extensions}');
  print('  TypeAlias:              ${dartAnalyzerStats.typeAliases}');
  print('');

  print('ANALYZER MEMBER COUNTS:');
  print('  ConstructorDeclaration: ${dartAnalyzerStats.constructors}');
  print('  MethodDeclaration:      ${dartAnalyzerStats.methods}');
  print('  FieldDeclaration:       ${dartAnalyzerStats.fields}');
  print('  FunctionDeclaration:    ${dartAnalyzerStats.functions}');
  print('');

  // =========================================================================
  // SECTION 3: AST Generator Results
  // =========================================================================
  print('┌─────────────────────────────────────────────────────────────────┐');
  print('│  SECTION 3: AST GENERATOR (direct parsing)                     │');
  print('└─────────────────────────────────────────────────────────────────┘');
  print('');

  // Find all Dart files in the analyzer package
  final astStats = await _scanWithAstGenerator(result);

  print('FILES SCANNED: ${astStats.filesScanned}');
  print('');

  print('AST NODE COUNTS:');
  print('  ClassDeclaration:       ${astStats.classes}');
  print('  EnumDeclaration:        ${astStats.enums}');
  print('  MixinDeclaration:       ${astStats.mixins}');
  print('  ExtensionDeclaration:   ${astStats.extensions}');
  print('  TypeAlias:              ${astStats.typeAliases}');
  print('');

  print('AST MEMBER COUNTS:');
  print('  ConstructorDeclaration: ${astStats.constructors}');
  print('  MethodDeclaration:      ${astStats.methods}');
  print('  FieldDeclaration:       ${astStats.fields}');
  print('  FunctionDeclaration:    ${astStats.functions}');
  print('');

  // =========================================================================
  // SECTION 4: Comparison
  // =========================================================================
  print('┌─────────────────────────────────────────────────────────────────┐');
  print('│  SECTION 4: COMPARISON                                         │');
  print('└─────────────────────────────────────────────────────────────────┘');
  print('');

  print('  (Tom Analyzer is the baseline)');
  print('');
  _printComparison3('Classes', analyzerStats.classes, dartAnalyzerStats.classes, astStats.classes);
  _printComparison3('Enums', analyzerStats.enums, dartAnalyzerStats.enums, astStats.enums);
  _printComparison3('Mixins', analyzerStats.mixins, dartAnalyzerStats.mixins, astStats.mixins);
  _printComparison3('Extensions', analyzerStats.extensions, dartAnalyzerStats.extensions, astStats.extensions);
  _printComparison3('Type Aliases', analyzerStats.typeAliases, dartAnalyzerStats.typeAliases, astStats.typeAliases);
  print('');
  _printComparison3('Constructors', analyzerStats.constructors, dartAnalyzerStats.constructors, astStats.constructors);
  _printComparison3('Methods', analyzerStats.methods, dartAnalyzerStats.methods, astStats.methods);
  _printComparison3('Fields', analyzerStats.fields, dartAnalyzerStats.fields, astStats.fields);
  _printComparison3('Functions', analyzerStats.functions, dartAnalyzerStats.functions, astStats.functions);
  print('');

  final analyzerTotal = analyzerStats.total;
  final dartAnalyzerTotal = dartAnalyzerStats.total;
  final astTotal = astStats.total;

  print('═══════════════════════════════════════════════════════════════════');
  print('  TOTALS:');
  print('    Tom Analyzer:   $analyzerTotal elements');
  print('    Dart Analyzer:  $dartAnalyzerTotal elements (${_percentage(dartAnalyzerTotal, analyzerTotal)})');
  print('    AST Generator:  $astTotal elements (${_percentage(astTotal, analyzerTotal)})');
  print('═══════════════════════════════════════════════════════════════════');
  print('');

  print('✓ Verification complete!');
}

void _printComparison3(String label, int tomAnalyzer, int dartAnalyzer, int ast) {
  final diffDart = dartAnalyzer - tomAnalyzer;
  final diffAst = ast - tomAnalyzer;
  final diffDartStr = diffDart >= 0 ? '+$diffDart' : '$diffDart';
  final diffAstStr = diffAst >= 0 ? '+$diffAst' : '$diffAst';
  final pctDart = _percentage(dartAnalyzer, tomAnalyzer);
  final pctAst = _percentage(ast, tomAnalyzer);
  final labelText = label.padRight(16);
  final tomText = tomAnalyzer.toString().padLeft(8);
  final dartText = dartAnalyzer.toString().padLeft(8);
  final astText = ast.toString().padLeft(8);
  print('  $labelText');
  print('    Tom:  $tomText');
  print('    Dart: $dartText  ($diffDartStr, $pctDart)');
  print('    AST:  $astText  ($diffAstStr, $pctAst)');
}

String _percentage(int ast, int analyzer) {
  if (analyzer == 0) return ast == 0 ? '0%' : '+∞%';
  final pct = ((ast - analyzer) / analyzer * 100).toStringAsFixed(1);
  return '$pct%';
}

/// Scan Dart files using the Dart analyzer directly and collect statistics
Future<_DartAnalyzerStats> _scanWithDartAnalyzer() async {
  final stats = _DartAnalyzerStats();
  final analyzerRoot = _findAnalyzerRoot();
  if (analyzerRoot == null) {
    print('  Warning: Could not locate analyzer package root.');
    return stats;
  }

  final libDir = Directory('$analyzerRoot/lib');
  if (!libDir.existsSync()) {
    print('  Warning: Analyzer lib directory not found: ${libDir.path}');
    return stats;
  }

  final collection = AnalysisContextCollection(
    includedPaths: [libDir.path],
    resourceProvider: PhysicalResourceProvider.INSTANCE,
  );

  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.dart')) continue;

    stats.filesScanned++;

    final context = collection.contextFor(entity.path);
    final session = context.currentSession;
    final resolved = await session.getResolvedUnit(entity.path);

    if (resolved is! analyzer_results.ResolvedUnitResult) continue;
    final unit = resolved.unit;

    for (final decl in unit.declarations) {
      _countAnalyzerDeclaration(decl, stats);
    }
  }

  return stats;
}

void _countAnalyzerDeclaration(
  analyzer_ast.CompilationUnitMember decl,
  _DartAnalyzerStats stats,
) {
  if (decl is analyzer_ast.ClassDeclaration) {
    stats.classes++;
    for (final member in decl.members) {
      _countAnalyzerMember(member, stats);
    }
    return;
  }
  if (decl is analyzer_ast.EnumDeclaration) {
    stats.enums++;
    for (final member in decl.members) {
      _countAnalyzerMember(member, stats);
    }
    return;
  }
  if (decl is analyzer_ast.MixinDeclaration) {
    stats.mixins++;
    for (final member in decl.members) {
      _countAnalyzerMember(member, stats);
    }
    return;
  }
  if (decl is analyzer_ast.ExtensionDeclaration) {
    stats.extensions++;
    for (final member in decl.members) {
      _countAnalyzerMember(member, stats);
    }
    return;
  }
  if (decl is analyzer_ast.GenericTypeAlias) {
    stats.typeAliases++;
    return;
  }
  if (decl is analyzer_ast.FunctionDeclaration) {
    stats.functions++;
    return;
  }
  if (decl is analyzer_ast.TopLevelVariableDeclaration) {
    stats.fields++;
  }
}

void _countAnalyzerMember(
  analyzer_ast.ClassMember member,
  _DartAnalyzerStats stats,
) {
  if (member is analyzer_ast.ConstructorDeclaration) {
    stats.constructors++;
    return;
  }
  if (member is analyzer_ast.MethodDeclaration) {
    stats.methods++;
    return;
  }
  if (member is analyzer_ast.FieldDeclaration) {
    stats.fields++;
  }
}

/// Scan Dart files using the AST generator and collect statistics
Future<_AstStats> _scanWithAstGenerator(tom.AnalysisResult result) async {
  final stats = _AstStats();
  final converter = AstConverter();

  // Get the library paths from the analysis result
  for (final library in result.libraries.values) {
    final uriString = library.uri.toString();
    
    // Skip dart: libraries - we can't read those directly
    if (uriString.startsWith('dart:')) continue;
    
    // Convert package URI to file path
    String? filePath;
    if (uriString.startsWith('package:analyzer/')) {
      // Find the analyzer package location
      filePath = _resolvePackageUri(uriString);
    }
    
    if (filePath == null || !File(filePath).existsSync()) {
      continue;
    }

    try {
      final content = File(filePath).readAsStringSync();
      final parseResult = parseString(content: content, path: filePath);
      final ast = converter.convertCompilationUnit(parseResult.unit);
      
      stats.filesScanned++;
      
      // Count declarations from the AST
      for (final decl in ast.declarations) {
        _countDeclaration(decl, stats);
      }
    } catch (e) {
      // Skip files that can't be parsed
      print('  Warning: Could not parse $filePath: $e');
    }
  }

  return stats;
}

void _countDeclaration(SAstNode decl, _AstStats stats) {
  switch (decl.nodeType) {
    case 'ClassDeclaration':
      stats.classes++;
      final cls = decl as SClassDeclaration;
      for (final member in cls.members) {
        _countMember(member, stats);
      }
    case 'EnumDeclaration':
      stats.enums++;
      final enm = decl as SEnumDeclaration;
      for (final member in enm.members) {
        _countMember(member, stats);
      }
    case 'MixinDeclaration':
      stats.mixins++;
      final mix = decl as SMixinDeclaration;
      for (final member in mix.members) {
        _countMember(member, stats);
      }
    case 'ExtensionDeclaration':
      stats.extensions++;
      final ext = decl as SExtensionDeclaration;
      for (final member in ext.members) {
        _countMember(member, stats);
      }
    case 'TypedefDeclaration':
    case 'FunctionTypeAlias':
    case 'GenericTypeAlias':
      stats.typeAliases++;
    case 'FunctionDeclaration':
      stats.functions++;
    case 'TopLevelVariableDeclaration':
      // Top-level variables are counted as fields for comparison purposes
      stats.fields++;
  }
}

void _countMember(SAstNode member, _AstStats stats) {
  switch (member.nodeType) {
    case 'ConstructorDeclaration':
      stats.constructors++;
    case 'MethodDeclaration':
      stats.methods++;
    case 'FieldDeclaration':
      stats.fields++;
  }
}

String? _resolvePackageUri(String uri) {
  // Parse package:analyzer/path/to/file.dart
  if (!uri.startsWith('package:analyzer/')) return null;
  
  final relativePath = uri.substring('package:analyzer/'.length);
  
  // Try common locations for the analyzer package
  final possiblePaths = [
    // From pubspec.lock, find the cached package
    '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev/analyzer-8.4.1/lib/$relativePath',
    '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev/analyzer-8.4.0/lib/$relativePath',
    // Add more versions as needed
  ];
  
  // Also check via .dart_tool/package_config.json
  final packageConfig = File('.dart_tool/package_config.json');
  if (packageConfig.existsSync()) {
    try {
      final content = packageConfig.readAsStringSync();
      // Simple regex to find analyzer path
      final match = RegExp(r'"name":\s*"analyzer"[^}]*"rootUri":\s*"([^"]+)"').firstMatch(content);
      if (match != null) {
        var rootUri = match.group(1)!;
        if (rootUri.startsWith('file://')) {
          rootUri = rootUri.substring(7);
        }
        final path = '$rootUri/lib/$relativePath';
        if (File(path).existsSync()) {
          return path;
        }
      }
    } catch (_) {}
  }
  
  for (final path in possiblePaths) {
    if (File(path).existsSync()) {
      return path;
    }
  }
  
  return null;
}

String? _findAnalyzerRoot() {
  final packageConfig = File('.dart_tool/package_config.json');
  if (!packageConfig.existsSync()) return null;

  try {
    final content = packageConfig.readAsStringSync();
    final match = RegExp(r'"name":\s*"analyzer"[^}]*"rootUri":\s*"([^"]+)"')
        .firstMatch(content);
    if (match == null) return null;

    var rootUri = match.group(1)!;
    if (rootUri.startsWith('file://')) {
      rootUri = rootUri.substring(7);
      return rootUri.endsWith('/') ? rootUri.substring(0, rootUri.length - 1) : rootUri;
    }

    final resolved = packageConfig.parent.uri.resolve(rootUri).toFilePath();
    return resolved.endsWith('/') ? resolved.substring(0, resolved.length - 1) : resolved;
  } catch (_) {
    return null;
  }
}

class _AnalyzerStats {
  int classes;
  int enums;
  int mixins;
  int extensions;
  int typeAliases;
  int constructors;
  int methods;
  int fields;
  int functions;

  _AnalyzerStats({
    required this.classes,
    required this.enums,
    required this.mixins,
    required this.extensions,
    required this.typeAliases,
    required this.constructors,
    required this.methods,
    required this.fields,
    required this.functions,
  });

  int get total =>
      classes +
      enums +
      mixins +
      extensions +
      typeAliases +
      constructors +
      methods +
      fields +
      functions;
}

class _DartAnalyzerStats {
  int filesScanned = 0;
  int classes = 0;
  int enums = 0;
  int mixins = 0;
  int extensions = 0;
  int typeAliases = 0;
  int constructors = 0;
  int methods = 0;
  int fields = 0;
  int functions = 0;

  int get total =>
      classes +
      enums +
      mixins +
      extensions +
      typeAliases +
      constructors +
      methods +
      fields +
      functions;
}

class _AstStats {
  int filesScanned = 0;
  int classes = 0;
  int enums = 0;
  int mixins = 0;
  int extensions = 0;
  int typeAliases = 0;
  int constructors = 0;
  int methods = 0;
  int fields = 0;
  int functions = 0;

  int get total =>
      classes +
      enums +
      mixins +
      extensions +
      typeAliases +
      constructors +
      methods +
      fields +
      functions;
}
