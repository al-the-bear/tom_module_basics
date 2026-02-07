/// Standalone cleanup tool entry point.
///
/// This is a thin wrapper that delegates to CleanupTool.
/// Can be run as: `dart run tom_build_kit:cleanup [options]`
library;

import 'dart:io';

import 'package:tom_build_kit/src/commands/cleanup_tool.dart';

Future<void> main(List<String> args) async {
  final tool = CleanupTool();
  final success = await tool.run(args);
  exit(success ? 0 : 1);
}
