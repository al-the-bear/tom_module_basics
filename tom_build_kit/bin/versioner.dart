/// Standalone versioner tool entry point.
///
/// This is a thin wrapper that delegates to VersionerTool.
/// Can be run as: `dart run tom_build_kit:versioner [options]`
library;

import 'dart:io';

import 'package:tom_build_kit/src/commands/versioner_tool.dart';

Future<void> main(List<String> args) async {
  final tool = VersionerTool();
  final success = await tool.run(args);
  exit(success ? 0 : 1);
}
