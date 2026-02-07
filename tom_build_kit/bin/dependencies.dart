/// Standalone dependencies tool entry point.
///
/// This is a thin wrapper that delegates to DependenciesTool.
/// Can be run as: `dart run tom_build_kit:dependencies [options]`
library;

import 'dart:io';

import 'package:tom_build_kit/src/commands/dependencies_tool.dart';

Future<void> main(List<String> args) async {
  final tool = DependenciesTool();
  final success = await tool.run(args);
  exit(success ? 0 : 1);
}
