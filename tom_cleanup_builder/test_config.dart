import 'package:tom_build_base/tom_build_base.dart';

void main() {
  final config = TomBuildConfig.load(dir: '.', toolKey: 'cleanup');
  print('Config found: ${config != null}');
  if (config != null) {
    print('toolOptions keys: ${config.toolOptions.keys.toList()}');
    print('cleanup key exists: ${config.toolOptions.containsKey('cleanup')}');
    if (config.toolOptions.containsKey('cleanup')) {
      print('cleanup value: ${config.toolOptions['cleanup']}');
    }
  }
}
