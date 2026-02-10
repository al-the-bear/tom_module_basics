/// Standalone gitreset tool entry point.
///
/// Reset all repositories to a specific state.
/// The standalone binary automatically uses --outer-first-git.
library;

import 'dart:io';

import 'package:tom_build_kit/src/commands/gitreset_tool.dart';

Future<void> main(List<String> args) async {
  final tool = GitResetTool()
    ..autoOuterFirst = true;
  final success = await tool.run(args);
  exit(success ? 0 : 1);
}
