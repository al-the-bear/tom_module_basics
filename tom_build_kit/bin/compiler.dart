/// Standalone compiler tool entry point.
///
/// This is a thin wrapper that delegates to CompilerTool.
/// Can be run as: `dart run tom_build_kit:compiler [options]`
library;

import 'dart:io';

import 'package:tom_build_kit/src/commands/compiler_tool.dart';

Future<void> main(List<String> args) async {
  final tool = CompilerTool();
  final success = await tool.run(args);
  exit(success ? 0 : 1);
}
