/// Standalone version bump tool entry point.
///
/// This is a thin wrapper that delegates to VersionBumperTool.
/// Can be run as: `dart run tom_build_kit:versionbumper [options]`
library;

import 'dart:io';

import 'package:tom_build_kit/src/commands/versionbumper_tool.dart';

Future<void> main(List<String> args) async {
  final tool = VersionBumperTool();
  final success = await tool.run(args);
  exit(success ? 0 : 1);
}
