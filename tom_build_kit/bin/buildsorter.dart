/// Standalone build sorter tool entry point.
///
/// This is a thin wrapper that delegates to BuildSorterTool.
/// Can be run as: `dart run tom_build_kit:buildsorter [options]`
library;

import 'dart:io';

import 'package:tom_build_kit/src/commands/buildsorter_tool.dart';

Future<void> main(List<String> args) async {
  final tool = BuildSorterTool();
  final success = await tool.run(args);
  exit(success ? 0 : 1);
}
