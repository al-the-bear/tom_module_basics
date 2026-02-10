/// Standalone gitbranch tool entry point.
///
/// Manages branches across all repositories.
/// The standalone binary automatically uses --inner-first-git.
library;

import 'dart:io';

import 'package:tom_build_kit/src/commands/gitbranch_tool.dart';

Future<void> main(List<String> args) async {
  final tool = GitBranchTool()
    ..autoInnerFirst = true;
  final success = await tool.run(args);
  exit(success ? 0 : 1);
}
