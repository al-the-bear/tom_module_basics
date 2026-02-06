import 'dart:io';
import 'package:yaml/yaml.dart';

void main() {
  final file = File('tom_build.yaml');
  final content = file.readAsStringSync();
  print('File content length: ${content.length}');
  final yaml = loadYaml(content) as YamlMap;
  print('YAML keys: ${yaml.keys.toList()}');
  print('cleanup key exists: ${yaml.containsKey('cleanup')}');
  if (yaml.containsKey('cleanup')) {
    print('cleanup type: ${yaml['cleanup'].runtimeType}');
    print('cleanup value: ${yaml['cleanup']}');
  }
}
