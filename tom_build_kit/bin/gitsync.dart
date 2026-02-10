/// Standalone gitsync tool entry point.
///
/// Sync all repositories with remote (fetch + merge/rebase).
/// The standalone binary automatically uses --outer-first-git.
library;

import 'dart:io';

import 'package:tom_build_kit/src/commands/gitsync_tool.dart';

Future<void> main(List<String> args) async {
  final tool = GitSyncTool()
    ..autoOuterFirst = true;
  final success = await tool.run(args);
  exit(success ? 0 : 1);
}
