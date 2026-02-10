/// Standalone gitcommit tool entry point.
///
/// This is a thin wrapper that delegates to GitCommitTool.
/// Can be run as: `dart run tom_build_kit:gitcommit [options]`
///
/// The standalone binary automatically uses --inner-first-git.
library;

import 'dart:io';

import 'package:tom_build_kit/src/commands/gitcommit_tool.dart';

Future<void> main(List<String> args) async {
  final tool = GitCommitTool()
    ..autoInnerFirst = true;
  final success = await tool.run(args);
  exit(success ? 0 : 1);
}
