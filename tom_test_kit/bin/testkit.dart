/// Tom Test Kit CLI — test result tracking tool.
///
/// Run `testkit --help` for usage information.
library;

import 'dart:io';

import 'package:tom_build_base/tom_build_base_v2.dart';
import 'package:utopia_tui/utopia_tui.dart';
import 'package:tom_test_kit/src/v2/testkit_executors.dart';
import 'package:tom_test_kit/src/v2/testkit_tool.dart';
import 'package:tom_test_kit/src/tui/app/test_kit_tui_app.dart';
import 'package:tom_test_kit/src/tui/tui_command_registry.dart';
import 'package:tom_test_kit/src/tui/commands/baseline_tui_command.dart';
import 'package:tom_test_kit/src/tui/commands/test_tui_command.dart';

void main(List<String> args) async {
  final normalizedArgs = _normalizeHelpArgs(args);

  // Parse args to check for TUI mode first
  final parser = CliArgParser(toolDefinition: testkitTool);
  final cliArgs = parser.parse(normalizedArgs);

  // Check for --tui mode
  if (cliArgs.extraOptions['tui'] == true) {
    await _runTuiMode(cliArgs);
    return;
  }

  // Create runner with all executors
  final runner = ToolRunner(
    tool: testkitTool,
    executors: createTestkitExecutors(),
  );

  // Run the tool
  final result = await runner.run(normalizedArgs);

  // Set exit code based on result
  if (!result.success) {
    exitCode = 1;
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

/// Run TUI mode with the existing TUI implementation.
Future<void> _runTuiMode(CliArgs args) async {
  // Resolve project path from navigation args
  final projectPath = args.root ?? Directory.current.path;

  // Build command registry with built-in commands
  final registry = TuiCommandRegistry()
    ..registerCommand(BaselineTuiCommand())
    ..registerCommand(TestTuiCommand());

  // Launch TUI
  final app = TestKitTuiApp(
    registry: registry,
    projectPath: projectPath,
  );
  await TuiRunner(app).run();

  // Restore terminal line discipline after TUI exits.
  await Process.run('stty', ['sane'], runInShell: true);
}
