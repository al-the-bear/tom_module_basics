/// Tom Issue Kit CLI — issue tracking tool using v2 framework.
///
/// This is the entry point that uses tom_build_base v2 for CLI handling.
/// Run `issuekit --help` for usage information.
library;

import 'dart:io';

import 'package:tom_build_base/tom_build_base_v2.dart';
import 'package:tom_issue_kit/src/v2/issuekit_executors.dart';
import 'package:tom_issue_kit/src/v2/issuekit_tool.dart';

void main(List<String> args) async {
  // Create runner with all executors
  final runner = ToolRunner(
    tool: issuekitTool,
    executors: createIssuekitExecutors(),
  );

  // Run the tool
  final result = await runner.run(args);

  // Set exit code based on result
  if (!result.success) {
    exitCode = 1;
  }
}
