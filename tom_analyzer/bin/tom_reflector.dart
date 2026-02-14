/// tom_reflector CLI - Dart code reflection generation tool
///
/// Configuration is read from buildkit.yaml (tom_reflector: section).
/// Run `reflector help` or `--help` for full usage information.
library;

import 'dart:io';

import 'package:tom_build_base/tom_build_base_v2.dart';

import 'package:tom_analyzer/src/v2/reflector_tool.dart';
import 'package:tom_analyzer/src/v2/reflector_executor.dart';

void main(List<String> args) async {
  final runner = ToolRunner(
    tool: reflectorTool,
    executors: createReflectorExecutors(),
  );

  final result = await runner.run(args);

  if (!result.success) {
    exitCode = 1;
  }
}
