/// tom_analyzer CLI - Dart code analysis tool
///
/// Configuration is read from buildkit.yaml (tom_analyzer: section).
/// Run `analyzer help` or `--help` for full usage information.
library;

import 'dart:io';

import 'package:tom_build_base/tom_build_base_v2.dart';

import 'package:tom_analyzer/src/v2/analyzer_tool.dart';
import 'package:tom_analyzer/src/v2/analyzer_executor.dart';

void main(List<String> args) async {
  final runner = ToolRunner(
    tool: analyzerTool,
    executors: createAnalyzerExecutors(),
  );

  final result = await runner.run(args);

  if (!result.success) {
    exitCode = 1;
  }
}
