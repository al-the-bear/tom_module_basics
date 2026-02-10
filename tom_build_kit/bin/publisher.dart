/// Standalone publisher tool entry point.
///
/// This is a thin wrapper that delegates to PublisherTool.
/// Can be run as: `dart run tom_build_kit:publisher [options]`
library;

import 'dart:io';

import 'package:tom_build_kit/src/commands/publisher_tool.dart';

Future<void> main(List<String> args) async {
  final tool = PublisherTool();
  final success = await tool.run(args);
  exit(success ? 0 : 1);
}
