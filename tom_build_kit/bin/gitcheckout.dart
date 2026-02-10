/// Standalone gitcheckout tool entry point.
///
/// Checkout branches/tags across all repositories.
/// The standalone binary automatically uses --outer-first-git.
library;

import 'dart:io';

import 'package:tom_build_kit/src/commands/gitcheckout_tool.dart';

Future<void> main(List<String> args) async {
  final tool = GitCheckoutTool()
    ..autoOuterFirst = true;
  final success = await tool.run(args);
  exit(success ? 0 : 1);
}
