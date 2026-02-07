/// Standalone version bump tool entry point.
///
/// This is a thin wrapper that delegates to VersionBumpTool.
/// Can be run as: `dart run tom_build_kit:versionbump [options]`
library;

import 'dart:io';

import 'package:tom_build_kit/src/commands/versionbump_tool.dart';

Future<void> main(List<String> args) async {
  final tool = VersionBumpTool();
  final success = await tool.run(args);
  exit(success ? 0 : 1);
}
