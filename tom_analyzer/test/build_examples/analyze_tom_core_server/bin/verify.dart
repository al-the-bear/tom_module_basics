/// Verification script that reads the generated analysis YAML
/// and prints statistics using the tom_analyzer object model.
import 'dart:io';
import 'package:tom_analyzer/tom_analyzer.dart';

void main() {
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
  final result = YamlDeserializer.decode(content);

  print('═══════════════════════════════════════════════════════════════════');
  print('  TOM ANALYZER - VERIFICATION REPORT');
  print('  Target: tom_core_server');
  print('═══════════════════════════════════════════════════════════════════');
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
  print('TYPE DEFINITIONS:');
  print('  Classes:       ${result.allClasses.length}');
  print('  Enums:         ${result.allEnums.length}');
  print('  Mixins:        ${result.allMixins.length}');
  print('  Extensions:    ${result.allExtensions.length}');
  print('  Type Aliases:  ${result.allTypeAliases.length}');
  print('');

  // Count members
  var totalConstructors = 0;
  var totalMethods = 0;
  var totalFields = 0;

  for (final cls in result.allClasses) {
    totalConstructors += cls.constructors.length;
    totalMethods += cls.methods.length;
    totalFields += cls.fields.length;
  }
  for (final enm in result.allEnums) {
    totalConstructors += enm.constructors.length;
    totalMethods += enm.methods.length;
    totalFields += enm.fields.length;
  }
  for (final mix in result.allMixins) {
    totalMethods += mix.methods.length;
    totalFields += mix.fields.length;
  }
  for (final ext in result.allExtensions) {
    totalMethods += ext.methods.length;
  }

  print('MEMBERS:');
  print('  Constructors:  $totalConstructors');
  print('  Methods:       $totalMethods');
  print('  Fields:        $totalFields');
  print('  Functions:     ${result.allFunctions.length}');
  print('');

  final total = result.allClasses.length +
      result.allEnums.length +
      result.allMixins.length +
      result.allExtensions.length +
      result.allTypeAliases.length +
      totalConstructors +
      totalMethods +
      totalFields +
      result.allFunctions.length;

  print('═══════════════════════════════════════════════════════════════════');
  print('  TOTAL ANALYZED ELEMENTS: $total');
  print('═══════════════════════════════════════════════════════════════════');
  print('');

  // Sample class names using the API
  if (result.allClasses.isNotEmpty) {
    print('SAMPLE CLASSES:');
    for (final cls in result.allClasses.take(10)) {
      print('  - ${cls.name} (${cls.methods.length} methods, ${cls.fields.length} fields)');
    }
    print('');
  }

  // File stats
  final fileLines = content.split('\n').length;
  print('OUTPUT FILE:');
  print('  Lines: $fileLines');
  print('');

  print('✓ Verification complete!');
}
