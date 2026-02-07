/// Standalone runner tool entry point.
///
/// This is a thin wrapper that delegates to RunnerTool.
/// Can be run as: `dart run tom_build_kit:runner [options]`
library;

import 'dart:io';

import 'package:tom_build_kit/src/commands/runner_tool.dart';

Future<void> main(List<String> args) async {
  final tool = RunnerTool();
  final success = await tool.run(args);
  exit(success ? 0 : 1);
}
