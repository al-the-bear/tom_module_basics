/// Tom Issue Kit CLI — issue tracking tool using v2 framework.
///
/// This is the entry point that uses tom_build_base v2 for CLI handling.
/// Run `issuekit --help` for usage information.
library;

import 'dart:io';

import 'package:tom_build_base/tom_build_base_v2.dart';
import 'package:tom_github_api/tom_github_api.dart';
import 'package:tom_issue_kit/src/config/issuekit_config.dart';
import 'package:tom_issue_kit/src/services/issue_service.dart';
import 'package:tom_issue_kit/src/v2/issuekit_executors.dart';
import 'package:tom_issue_kit/src/v2/issuekit_tool.dart';

void main(List<String> args) async {
  final normalizedArgs = _normalizeHelpArgs(args);

  final preParser = CliArgParser(toolDefinition: issuekitTool);
  final preArgs = preParser.parse(normalizedArgs);
  final hasHelpFlag = normalizedArgs.contains('--help') ||
      normalizedArgs.contains('-h') ||
      normalizedArgs.contains('-help');
  if (preArgs.help || preArgs.version || hasHelpFlag) {
    final preRunner = ToolRunner(
      tool: issuekitTool,
      executors: const <String, CommandExecutor>{},
    );
    final preResult = await preRunner.run(normalizedArgs);
    if (!preResult.success) {
      exitCode = 1;
    }
    return;
  }

  // Load configuration from workspace root (current directory by default)
  final workspaceRoot = Platform.environment['TOM_WORKSPACE_ROOT'] ??
      Directory.current.path;
  final config = await IssueKitConfig.load(workspaceRoot);

  // Resolve GitHub token
  final token = config.token;
  if (token == null) {
    stderr.writeln('Error: No GitHub token configured.');
    stderr.writeln('Set GITHUB_TOKEN environment variable or configure '
        'token_file in tom_workspace.yaml');
    exitCode = 1;
    return;
  }

  // Verify issue tracking is configured
  if (!config.isValid) {
    stderr.writeln('Error: issue_tracking not configured in tom_workspace.yaml');
    exitCode = 1;
    return;
  }

  // Create GitHub API client and Issue Service
  final client = GitHubApiClient(token: token);
  final service = IssueService(
    client: client,
    issuesRepo: config.issueTracking!.issuesRepo,
    testsRepo: config.issueTracking!.testsRepo,
  );

  try {
    // Create runner with all executors
    final runner = ToolRunner(
      tool: issuekitTool,
      executors: createIssuekitExecutors(
        service: service,
      ),
    );

    // Run the tool
    final result = await runner.run(normalizedArgs);

    // Set exit code based on result
    if (!result.success) {
      exitCode = 1;
    }
  } finally {
    service.close();
  }
}

List<String> _normalizeHelpArgs(List<String> args) {
  if (args.isEmpty) return args;

  final first = args.first.trim();
  if (first == 'help' || first == '-help') {
    final rest = args.skip(1).toList();
    if (!rest.contains('--help') && !rest.contains('-h')) {
      return ['--help', ...rest];
    }
  }

  return args;
}
