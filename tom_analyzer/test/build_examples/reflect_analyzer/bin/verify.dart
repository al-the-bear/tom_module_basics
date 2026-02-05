import 'package:reflect_analyzer/main.r.dart';

void main() {
  // Use the generated reflectionApi from the .r.dart file
  final api = reflectionApi;

  print('═══════════════════════════════════════════════════════════════════');
  print('  TOM ANALYZER REFLECTION - VERIFICATION REPORT');
  print('  Target: dart analyzer package');
  print('═══════════════════════════════════════════════════════════════════');
  print('');

  // Type definitions using the ReflectionApi
  print('TYPE DEFINITIONS:');
  print('  Classes:         ${api.allClasses.length}');
  print('  Enums:           ${api.allEnums.length}');
  print('  Mixins:          ${api.allMixins.length}');
  print('  Extensions:      ${api.allExtensions.length}');
  print('  Extension Types: ${api.allExtensionTypes.length}');
  print('  Type Aliases:    ${api.allTypeAliases.length}');
  print('');

  // Count members using the API
  var totalConstructors = 0;
  var totalMethods = 0;
  var totalFields = 0;

  for (final cls in api.allClasses) {
    totalConstructors += cls.constructors.length;
    totalMethods += cls.methods.length + cls.staticMethods.length;
    totalFields += cls.fields.length + cls.staticFields.length;
  }
  for (final enm in api.allEnums) {
    totalMethods += enm.methods.length + enm.staticMethods.length;
    totalFields += enm.fields.length + enm.staticFields.length;
  }
  for (final mix in api.allMixins) {
    totalMethods += mix.methods.length + mix.staticMethods.length;
    totalFields += mix.fields.length + mix.staticFields.length;
  }
  for (final ext in api.allExtensions) {
    totalMethods += ext.methods.length + ext.staticMethods.length;
  }

  print('MEMBERS:');
  print('  Constructors:  $totalConstructors');
  print('  Methods:       $totalMethods');
  print('  Fields:        $totalFields');
  print('  Globals:       ${api.allGlobals.length}');
  print('');

  final total = api.allClasses.length +
      api.allEnums.length +
      api.allMixins.length +
      api.allExtensions.length +
      api.allExtensionTypes.length +
      api.allTypeAliases.length +
      totalConstructors +
      totalMethods +
      totalFields +
      api.allGlobals.length;

  print('═══════════════════════════════════════════════════════════════════');
  print('  TOTAL REFLECTED ELEMENTS: $total');
  print('═══════════════════════════════════════════════════════════════════');
  print('');

  // Sample AST class names using the API
  if (api.allClasses.isNotEmpty) {
    print('SAMPLE AST CLASSES:');
    final astClasses = api.allClasses
        .where((c) => c.name.contains('Declaration') || 
                      c.name.contains('Expression') ||
                      c.name.contains('Statement') ||
                      c.name.contains('Literal'))
        .take(15);
    for (final cls in astClasses) {
      final methodCount = cls.methods.length + cls.staticMethods.length;
      final fieldCount = cls.fields.length + cls.staticFields.length;
      print('  - ${cls.name} ($methodCount methods, $fieldCount fields)');
    }
    print('');
  }

  // List packages
  final packages = api.allClasses.map((c) => c.package).toSet();
  if (packages.isNotEmpty) {
    print('PACKAGES:');
    for (final pkg in packages) {
      final classCount = api.getClassesByPackage(pkg).length;
      print('  - $pkg ($classCount classes)');
    }
    print('');
  }

  print('✓ Verification complete using the ReflectionApi!');
}
