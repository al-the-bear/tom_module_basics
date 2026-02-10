/// Git tool - runs arbitrary git commands across all repositories.
///
/// Usage:
///   git -i -- log --oneline -5      # Inner repos first
///   git -o -- stash list            # Outer repos first
///
/// Running via buildkit:
///   bk :git -i -- `<git-command>`
library;

import 'package:tom_build_kit/tom_build_kit.dart';

Future<void> main(List<String> args) async {
  final result = await GitTool().run(args);
  if (!result) {
    throw Exception('git command failed');
  }
}
