/// Verification script that reads the generated analysis YAML
/// and compares it with AST generation results and direct analyzer results.
library;
import 'dart:convert';
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

  final libraryFiles = _collectLibraryFilePaths(result);

  // =========================================================================
  // SECTION 2: Dart Analyzer Results (direct analysis)
  // =========================================================================
  print('┌─────────────────────────────────────────────────────────────────┐');
  print('│  SECTION 2: DART ANALYZER (direct analysis)                   │');
  print('└─────────────────────────────────────────────────────────────────┘');
  print('');

  final dartAnalyzerStats = await _scanWithDartAnalyzer(libraryFiles.files);

  print('LIBRARIES TOTAL: ${libraryFiles.totalLibraries}');
  print('LIBRARIES SKIPPED (dart:): ${libraryFiles.skippedDart}');
  if (libraryFiles.unresolved.isNotEmpty) {
    print('LIBRARIES UNRESOLVED: ${libraryFiles.unresolved.length}');
  }
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
  final astStats = await _scanWithAstGenerator(libraryFiles.files);

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

  // =========================================================================
  // SECTION 5: Detailed AST vs Dart AST comparison
  // =========================================================================
  print('┌─────────────────────────────────────────────────────────────────┐');
  print('│  SECTION 5: AST DETAIL COMPARISON                             │');
  print('└─────────────────────────────────────────────────────────────────┘');
  print('');

  final detailLog = <String>[];
  final detailSummary = await _compareAstDetails(
    libraryFiles.files,
    detailLog,
    maxDiffs: 200,
  );

  print('FILES COMPARED: ${detailSummary.filesCompared}');
  print('FILES WITH DIFFS: ${detailSummary.filesWithDiffs}');
  print('DIFF COUNT (capped): ${detailLog.length}');
  if (detailLog.isNotEmpty) {
    print('');
    print('SAMPLE DIFFS:');
    for (final line in detailLog) {
      print('  - $line');
    }
  }
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

class _CompareSummary {
  int filesCompared = 0;
  int filesWithDiffs = 0;
}

Future<_CompareSummary> _compareAstDetails(
  List<String> filePaths,
  List<String> log, {
  int maxDiffs = 200,
}) async {
  final summary = _CompareSummary();
  final converter = AstConverter();

  for (final filePath in filePaths) {
    if (log.length >= maxDiffs) break;
    if (!File(filePath).existsSync()) continue;

    try {
      final content = File(filePath).readAsStringSync();
      final parsed = parseString(content: content, path: filePath);
      final analyzerRoot = parsed.unit;
      final astRoot = converter.convertCompilationUnit(parsed.unit);

      final before = log.length;
      _compareAst(
        analyzerRoot,
        astRoot,
        converter,
        filePath,
        log,
        maxDiffs,
      );

      summary.filesCompared++;
      if (log.length > before) {
        summary.filesWithDiffs++;
      }
    } catch (e) {
      if (log.length < maxDiffs) {
        log.add('$filePath: ERROR $e');
      }
    }
  }

  return summary;
}

class _VisitEntry<T> {
  final String type;
  final int offset;
  final int length;
  final T node;
  final String path;

  _VisitEntry({
    required this.type,
    required this.offset,
    required this.length,
    required this.node,
    required this.path,
  });
}

void _compareAst(
  analyzer_ast.AstNode analyzerRoot,
  SAstNode astRoot,
  AstConverter converter,
  String filePath,
  List<String> log,
  int maxDiffs,
) {
  final analyzerVisits = <_VisitEntry<analyzer_ast.AstNode>>[];
  final astVisits = <_VisitEntry<Map<String, dynamic>>>[];

  _collectAnalyzerVisits(analyzerRoot, analyzerVisits, filePath);
  _collectAstJsonVisitsSorted(astRoot.toJson(), astVisits, filePath);

  final astByKey = <String, List<Map<String, dynamic>>>{};
  for (final entry in astVisits) {
    final key = _nodeKey(entry.type, entry.offset);
    (astByKey[key] ??= <Map<String, dynamic>>[]).add(entry.node);
  }

  final analyzerKeys = <String>[];
  final analyzerFilteredVisits = <_VisitEntry<analyzer_ast.AstNode>>[];
  for (final entry in analyzerVisits) {
    final converted = _convertAnalyzerNode(entry.node, converter);
    if (converted == null || converted.nodeType == 'Unknown') {
      continue;
    }
    final key = _nodeKey(converted.nodeType, converted.offset);
    if (!astByKey.containsKey(key)) {
      continue;
    }
    analyzerKeys.add(key);
    analyzerFilteredVisits.add(entry);
  }

  final keyCounts = <String, int>{};
  for (final key in analyzerKeys) {
    keyCounts[key] = (keyCounts[key] ?? 0) + 1;
  }

  final filteredAstVisits = <_VisitEntry<Map<String, dynamic>>>[];
  for (final entry in astVisits) {
    final key = _nodeKey(entry.type, entry.offset);
    final remaining = keyCounts[key] ?? 0;
    if (remaining > 0) {
      filteredAstVisits.add(entry);
      keyCounts[key] = remaining - 1;
    }
  }

  if (analyzerKeys.length != filteredAstVisits.length) {
    log.add(
      '$filePath: visitCount ${analyzerKeys.length} != ${filteredAstVisits.length}',
    );
    if (log.length >= maxDiffs) return;
  }

  final minLen = analyzerKeys.length < filteredAstVisits.length
      ? analyzerKeys.length
      : filteredAstVisits.length;

  for (var i = 0; i < minLen; i++) {
    if (log.length >= maxDiffs) return;

    final analyzerEntry = analyzerFilteredVisits[i];
    final astEntry = filteredAstVisits[i];
    final converted = _convertAnalyzerNode(analyzerEntry.node, converter);

    if (converted == null) {
      log.add('${analyzerEntry.path}: converter returned null');
      continue;
    }
    if (converted.nodeType == 'Unknown') {
      log.add('${analyzerEntry.path}: unsupported analyzer node');
      continue;
    }

    // Traversal order check (filtered)
    final convertedKey = _nodeKey(converted.nodeType, converted.offset);
    final astKey = _nodeKey(astEntry.type, astEntry.offset);
    if (convertedKey != astKey) {
      final convertedDetail = _nodeKeyDetail(
        converted.nodeType,
        converted.offset,
        converted.length,
      );
      final astDetail = _nodeKeyDetail(
        astEntry.type,
        astEntry.offset,
        astEntry.length,
      );
      log.add('${analyzerEntry.path}: order mismatch $convertedDetail != $astDetail');
      if (log.length >= maxDiffs) return;
    }

    // Detailed comparison by key to avoid cascade diffs
    final bucket = astByKey[convertedKey];
    if (bucket == null || bucket.isEmpty) {
      final convertedDetail = _nodeKeyDetail(
        converted.nodeType,
        converted.offset,
        converted.length,
      );
      log.add('${analyzerEntry.path}: missing node $convertedDetail');
      continue;
    }

    final expected = SAstNodeFactory.fromJson(bucket.first);
    if (expected == null) {
      log.add('${analyzerEntry.path}: unable to deserialize expected node');
      continue;
    }

    final detailLog = <String>[];
    if (!converted.equals(expected, detailLog)) {
      for (final line in detailLog) {
        if (log.length >= maxDiffs) break;
        log.add('${analyzerEntry.path}: $line');
      }
    }
  }
}

SAstNode? _convertAnalyzerNode(
  analyzer_ast.AstNode node,
  AstConverter converter,
) {
  if (node is analyzer_ast.CompilationUnit) {
    return converter.convertCompilationUnit(node);
  }
  return converter.convert(node);
}

String _nodeKey(String type, int offset) {
  return '$type@$offset';
}

String _nodeKeyDetail(String type, int offset, int length) {
  return '$type@$offset:$length';
}

void _collectAnalyzerVisits(
  analyzer_ast.AstNode node,
  List<_VisitEntry<analyzer_ast.AstNode>> visits,
  String path,
) {
  if (_shouldSkipAnalyzerNode(node)) {
    return;
  }

  visits.add(
    _VisitEntry(
      type: node.runtimeType.toString(),
      offset: node.offset,
      length: node.length,
      node: node,
      path: path,
    ),
  );

  final children = <analyzer_ast.AstNode>[];
  for (final entity in node.childEntities) {
    if (entity is analyzer_ast.AstNode) {
      children.add(entity);
    }
  }

  var index = 0;
  for (final child in children) {
    _collectAnalyzerVisits(child, visits, '$path/$index:${child.runtimeType}');
    index++;
  }
}

void _collectAstJsonVisitsSorted(
  Map<String, dynamic> json,
  List<_VisitEntry<Map<String, dynamic>>> visits,
  String path,
) {
  final nodeType = json['nodeType'] as String?;
  if (nodeType == null || _shouldSkipAstNodeType(nodeType)) {
    return;
  }

  visits.add(
    _VisitEntry(
      type: nodeType,
      offset: json['offset'] as int? ?? -1,
      length: json['length'] as int? ?? -1,
      node: json,
      path: path,
    ),
  );

  final childNodes = _extractAstJsonChildren(json);

  var index = 0;
  for (final child in childNodes) {
    _collectAstJsonVisitsSorted(
      child,
      visits,
      '$path/$index:${child['nodeType']}',
    );
    index++;
  }
}

List<Map<String, dynamic>> _extractAstJsonChildren(Map<String, dynamic> json) {
  final children = <Map<String, dynamic>>[];
  for (final value in json.values) {
    if (value is Map && value['nodeType'] is String) {
      children.add(value.cast<String, dynamic>());
    } else if (value is List) {
      for (final item in value) {
        if (item is Map && item['nodeType'] is String) {
          children.add(item.cast<String, dynamic>());
        }
      }
    }
  }
  return children;
}

bool _shouldSkipAnalyzerNode(analyzer_ast.AstNode node) {
  return node is analyzer_ast.Comment ||
      node is analyzer_ast.CommentReference;
}

bool _shouldSkipAstNodeType(String nodeType) {
  return nodeType == 'Comment';
}

/// Scan Dart files using the Dart analyzer directly and collect statistics
Future<_DartAnalyzerStats> _scanWithDartAnalyzer(List<String> filePaths) async {
  final stats = _DartAnalyzerStats();
  if (filePaths.isEmpty) {
    return stats;
  }

  final directories = <String>{};
  for (final filePath in filePaths) {
    directories.add(_normalizePath(File(filePath).parent.path));
  }

  final collection = AnalysisContextCollection(
    includedPaths: directories.toList(),
    resourceProvider: PhysicalResourceProvider.INSTANCE,
  );

  for (final filePath in filePaths) {
    if (!File(filePath).existsSync()) continue;
    stats.filesScanned++;

    final context = collection.contextFor(filePath);
    final session = context.currentSession;
    final resolved = await session.getResolvedUnit(filePath);

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
Future<_AstStats> _scanWithAstGenerator(List<String> filePaths) async {
  final stats = _AstStats();
  final converter = AstConverter();

  for (final filePath in filePaths) {
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

_LibraryFiles _collectLibraryFilePaths(tom.AnalysisResult result) {
  final files = <String>{};
  final unresolved = <String>[];
  var skippedDart = 0;
  final packageRoots = _loadPackageRoots();

  for (final library in result.libraries.values) {
    final uriString = library.uri.toString();
    if (uriString.startsWith('dart:')) {
      skippedDart++;
      continue;
    }

    String? filePath;
    if (uriString.startsWith('package:')) {
      filePath = _resolvePackageUri(uriString, packageRoots);
    } else if (uriString.startsWith('file:')) {
      filePath = Uri.parse(uriString).toFilePath();
    } else if (uriString.startsWith('/')) {
      filePath = uriString;
    } else {
      filePath = uriString;
    }

    if (filePath == null || !File(filePath).existsSync()) {
      unresolved.add(uriString);
      continue;
    }

    files.add(_normalizePath(File(filePath).absolute.path));
  }

  return _LibraryFiles(
    files: files.toList()..sort(),
    totalLibraries: result.libraries.length,
    skippedDart: skippedDart,
    unresolved: unresolved,
  );
}

Map<String, String> _loadPackageRoots() {
  final packageConfig = File('.dart_tool/package_config.json');
  if (!packageConfig.existsSync()) return {};

  try {
    final content = packageConfig.readAsStringSync();
    final data = jsonDecode(content) as Map<String, dynamic>;
    final packages = data['packages'] as List<dynamic>? ?? [];
    final root = packageConfig.parent.uri;

    final map = <String, String>{};
    for (final entry in packages) {
      final pkg = entry as Map<String, dynamic>;
      final name = pkg['name'] as String?;
      final rootUri = pkg['rootUri'] as String?;
      if (name == null || rootUri == null) continue;

      final resolved = root.resolve(rootUri).toFilePath();
      map[name] = resolved.endsWith('/')
          ? resolved.substring(0, resolved.length - 1)
          : resolved;
    }

    return map;
  } catch (_) {
    return {};
  }
}

String? _resolvePackageUri(String uri, Map<String, String> packageRoots) {
  if (!uri.startsWith('package:')) return null;
  final rest = uri.substring('package:'.length);
  final slashIndex = rest.indexOf('/');
  if (slashIndex == -1) return null;
  final packageName = rest.substring(0, slashIndex);
  final relativePath = rest.substring(slashIndex + 1);
  final root = packageRoots[packageName];
  if (root == null) return null;
  final base = root.endsWith('/lib') ? root : '$root/lib';
  return _normalizePath(File('$base/$relativePath').absolute.path);
}

String _normalizePath(String path) {
  return Uri.file(path).normalizePath().toFilePath();
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

class _LibraryFiles {
  final List<String> files;
  final int totalLibraries;
  final int skippedDart;
  final List<String> unresolved;

  _LibraryFiles({
    required this.files,
    required this.totalLibraries,
    required this.skippedDart,
    required this.unresolved,
  });
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
