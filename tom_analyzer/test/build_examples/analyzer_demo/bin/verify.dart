/// Verification script that reads the generated analysis YAML
/// and prints statistics to prove the analyzer ran correctly.
import 'dart:io';
import 'package:yaml/yaml.dart';

void main() {
  final analysisFile = File('lib/sample_code.analysis.yaml');

  if (!analysisFile.existsSync()) {
    print('ERROR: Analysis file not found!');
    print('');
    print('Run: dart run build_runner build');
    print('');
    exit(1);
  }

  final content = analysisFile.readAsStringSync();
  final yaml = loadYaml(content) as YamlMap;

  print('═══════════════════════════════════════════════════════════════════');
  print('  TOM ANALYZER - VERIFICATION REPORT');
  print('═══════════════════════════════════════════════════════════════════');
  print('');

  // Metadata
  final analysisId = yaml['id'];
  final timestamp = yaml['timestamp'];
  final analyzerVersion = yaml['analyzerVersion'];
  final schemaVersion = yaml['schemaVersion'];

  print('ANALYSIS METADATA:');
  print('  Analysis ID:      $analysisId');
  print('  Timestamp:        $timestamp');
  print('  Analyzer Version: $analyzerVersion');
  print('  Schema Version:   $schemaVersion');
  print('');

  // Count packages
  final packages = yaml['packages'] as YamlList? ?? [];
  print('PACKAGES: ${packages.length}');
  for (final pkg in packages) {
    final name = pkg['name'];
    final isRoot = pkg['isRoot'] == true;
    final libCount = (pkg['libraries'] as YamlList?)?.length ?? 0;
    print('  - $name ${isRoot ? "(root)" : ""} - $libCount libraries');
  }
  print('');

  // Gather statistics from libraries
  final libraries = yaml['libraries'] as YamlList? ?? [];
  var totalClasses = 0;
  var totalEnums = 0;
  var totalMixins = 0;
  var totalExtensions = 0;
  var totalTypeAliases = 0;
  var totalFunctions = 0;
  var totalMethods = 0;
  var totalFields = 0;
  var totalGetters = 0;
  var totalSetters = 0;
  var totalConstructors = 0;

  for (final lib in libraries) {
    final classes = lib['classes'] as YamlList? ?? [];
    final enums = lib['enums'] as YamlList? ?? [];
    final mixins = lib['mixins'] as YamlList? ?? [];
    final extensions = lib['extensions'] as YamlList? ?? [];
    final typeAliases = lib['typeAliases'] as YamlList? ?? [];
    final functions = lib['functions'] as YamlList? ?? [];
    final getters = lib['getters'] as YamlList? ?? [];
    final setters = lib['setters'] as YamlList? ?? [];

    totalClasses += classes.length;
    totalEnums += enums.length;
    totalMixins += mixins.length;
    totalExtensions += extensions.length;
    totalTypeAliases += typeAliases.length;
    totalFunctions += functions.length;
    totalGetters += getters.length;
    totalSetters += setters.length;

    // Count methods, fields, constructors inside classes
    for (final cls in classes) {
      totalMethods += (cls['methods'] as YamlList?)?.length ?? 0;
      totalFields += (cls['fields'] as YamlList?)?.length ?? 0;
      totalGetters += (cls['getters'] as YamlList?)?.length ?? 0;
      totalSetters += (cls['setters'] as YamlList?)?.length ?? 0;
      totalConstructors += (cls['constructors'] as YamlList?)?.length ?? 0;
    }

    // Count methods, fields inside enums
    for (final enm in enums) {
      totalMethods += (enm['methods'] as YamlList?)?.length ?? 0;
      totalFields += (enm['fields'] as YamlList?)?.length ?? 0;
      totalGetters += (enm['getters'] as YamlList?)?.length ?? 0;
      totalSetters += (enm['setters'] as YamlList?)?.length ?? 0;
      totalConstructors += (enm['constructors'] as YamlList?)?.length ?? 0;
    }

    // Count methods inside mixins
    for (final mix in mixins) {
      totalMethods += (mix['methods'] as YamlList?)?.length ?? 0;
      totalFields += (mix['fields'] as YamlList?)?.length ?? 0;
      totalGetters += (mix['getters'] as YamlList?)?.length ?? 0;
      totalSetters += (mix['setters'] as YamlList?)?.length ?? 0;
    }

    // Count methods inside extensions
    for (final ext in extensions) {
      totalMethods += (ext['methods'] as YamlList?)?.length ?? 0;
      totalGetters += (ext['getters'] as YamlList?)?.length ?? 0;
      totalSetters += (ext['setters'] as YamlList?)?.length ?? 0;
    }
  }

  print('LIBRARIES: ${libraries.length}');
  for (final lib in libraries) {
    final uri = lib['uri'];
    print('  - $uri');
  }
  print('');

  print('TYPE DEFINITIONS:');
  print('  Classes:       $totalClasses');
  print('  Enums:         $totalEnums');
  print('  Mixins:        $totalMixins');
  print('  Extensions:    $totalExtensions');
  print('  Type Aliases:  $totalTypeAliases');
  print('');

  print('MEMBERS:');
  print('  Constructors:  $totalConstructors');
  print('  Methods:       $totalMethods');
  print('  Fields:        $totalFields');
  print('  Getters:       $totalGetters');
  print('  Setters:       $totalSetters');
  print('  Functions:     $totalFunctions');
  print('');

  final total = totalClasses +
      totalEnums +
      totalMixins +
      totalExtensions +
      totalTypeAliases +
      totalConstructors +
      totalMethods +
      totalFields +
      totalGetters +
      totalSetters +
      totalFunctions;

  print('═══════════════════════════════════════════════════════════════════');
  print('  TOTAL ANALYZED ELEMENTS: $total');
  print('═══════════════════════════════════════════════════════════════════');
  print('');

  // Check reflection file
  final reflectionFile = File('lib/sample_code.r.dart');
  if (reflectionFile.existsSync()) {
    final reflectionContent = reflectionFile.readAsStringSync();
    final lines = reflectionContent.split('\n').length;
    final classDescriptorCount =
        RegExp(r'ClassDescriptor\(').allMatches(reflectionContent).length;
    final methodDescriptorCount =
        RegExp(r'MethodDescriptor\(').allMatches(reflectionContent).length;
    final fieldDescriptorCount =
        RegExp(r'FieldDescriptor\(').allMatches(reflectionContent).length;

    print('REFLECTION FILE:');
    print('  Lines:             $lines');
    print('  ClassDescriptors:  $classDescriptorCount');
    print('  MethodDescriptors: $methodDescriptorCount');
    print('  FieldDescriptors:  $fieldDescriptorCount');
    print('');
  } else {
    print('REFLECTION FILE: Not generated');
    print('');
  }

  print('✓ Verification complete!');
}
