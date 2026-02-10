/// Standalone gitclean tool entry point.
///
/// Cleans untracked files across all repositories.
/// The standalone binary automatically uses --inner-first-git.
library;

import 'dart:io';

import 'package:tom_build_kit/src/commands/gitclean_tool.dart';

Future<void> main(List<String> args) async {
  final tool = GitCleanTool()
    ..autoInnerFirst = true;
  final success = await tool.run(args);
  exit(success ? 0 : 1);
}
