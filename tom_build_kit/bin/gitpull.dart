/// Standalone gitpull tool entry point.
///
/// Pulls latest from all repositories.
/// The standalone binary automatically uses --outer-first-git.
library;

import 'dart:io';

import 'package:tom_build_kit/src/commands/gitpull_tool.dart';

Future<void> main(List<String> args) async {
  final tool = GitPullTool()
    ..autoOuterFirst = true;
  final success = await tool.run(args);
  exit(success ? 0 : 1);
}
