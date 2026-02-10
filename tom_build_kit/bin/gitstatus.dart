/// Standalone gitstatus tool entry point.
///
/// This is a thin wrapper that delegates to GitStatusTool.
/// Can be run as: `dart run tom_build_kit:gitstatus [options]`
///
/// The standalone binary automatically uses --inner-first-git.
library;

import 'dart:io';

import 'package:tom_build_kit/src/commands/gitstatus_tool.dart';

Future<void> main(List<String> args) async {
  final tool = GitStatusTool()
    ..autoInnerFirst = true;
  final success = await tool.run(args);
  exit(success ? 0 : 1);
}
