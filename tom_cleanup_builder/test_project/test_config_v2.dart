import 'dart:io';
import 'package:tom_build_base/tom_build_base.dart';
import 'package:yaml/yaml.dart';

void main() {
  // Test 1: TomBuildConfig.load()
  final config = TomBuildConfig.load(dir: '.', toolKey: 'cleanup');
  print('TomBuildConfig.load() found: ${config != null}');
  if (config != null) {
    print('Tool options: ${config.toolOptions}');
  }
  
  // Test 2: Load YAML directly
  final file = File('tom_build.yaml');
  final content = file.readAsStringSync();
  final rootYaml = loadYaml(content) as YamlMap;
  print('\nYAML keys: ${rootYaml.keys.toList()}');
  print('cleanup exists: ${rootYaml.containsKey('cleanup')}');
  print('cleanup type: ${rootYaml['cleanup'].runtimeType}');
  
  // Test 3: Try casting to YamlMap
  final asMap = rootYaml['cleanup'] as YamlMap?;
  print('cleanup as YamlMap?: ${asMap != null}');
}
