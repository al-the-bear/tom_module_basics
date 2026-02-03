import 'dart:async';

import 'package:build/build.dart';

import '../analyzer/analyzer_runner.dart';
import '../serialization/json_serializer.dart';
import '../serialization/yaml_serializer.dart';

class AnalyzerBuilder implements Builder {
  final BuilderOptions options;

  AnalyzerBuilder(this.options);

  @override
  Map<String, List<String>> get buildExtensions => const {
        '.dart': ['.analysis.yaml'],
      };

  @override
  Future<void> build(BuildStep buildStep) async {
    final config = options.config;
    final barrels = (config['barrels'] as List?)?.cast<String>() ?? [];
    final outputFormat = (config['output_format'] as String?) ?? 'yaml';

    if (barrels.isNotEmpty && !barrels.contains(buildStep.inputId.path)) {
      return;
    }

    final analyzer = TomAnalyzer();
    final result = await analyzer.analyzeBarrel(
      barrelPath: buildStep.inputId.path,
      workspaceRoot: buildStep.inputId.package,
    );

    final outputId = buildStep.inputId.changeExtension('.analysis.yaml');
    final content = outputFormat == 'json'
        ? JsonSerializer.encode(result)
        : YamlSerializer.encode(result);

    await buildStep.writeAsString(outputId, content);
  }
}
