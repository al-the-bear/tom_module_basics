import 'dart:io';

import 'cli_arg_parser.dart';
import 'command_definition.dart';
import 'help_generator.dart';
import 'tool_definition.dart';
import 'command_executor.dart';
import '../traversal/traversal_info.dart';
import '../traversal/build_base.dart';

/// Result of running a tool or command.
class ToolResult {
  /// Whether the execution was successful.
  final bool success;

  /// Number of items processed.
  final int processedCount;

  /// Number of items that failed.
  final int failedCount;

  /// Error message if failed.
  final String? errorMessage;

  /// Detailed results per item.
  final List<ItemResult> itemResults;

  const ToolResult({
    this.success = true,
    this.processedCount = 0,
    this.failedCount = 0,
    this.errorMessage,
    this.itemResults = const [],
  });

  /// Create a success result.
  const ToolResult.success({
    this.processedCount = 0,
    this.itemResults = const [],
  })  : success = true,
        failedCount = 0,
        errorMessage = null;

  /// Create a failure result.
  const ToolResult.failure(this.errorMessage)
      : success = false,
        processedCount = 0,
        failedCount = 0,
        itemResults = const [];

  /// Create from aggregated item results.
  factory ToolResult.fromItems(List<ItemResult> items) {
    final failed = items.where((i) => !i.success).length;
    return ToolResult(
      success: failed == 0,
      processedCount: items.length,
      failedCount: failed,
      itemResults: items,
    );
  }
}

/// Result for a single processed item (folder/project).
class ItemResult {
  /// Item path.
  final String path;

  /// Item name.
  final String name;

  /// Whether processing succeeded.
  final bool success;

  /// Result message.
  final String? message;

  /// Error message if failed.
  final String? error;

  const ItemResult({
    required this.path,
    required this.name,
    this.success = true,
    this.message,
    this.error,
  });

  const ItemResult.success({
    required this.path,
    required this.name,
    this.message,
  })  : success = true,
        error = null;

  const ItemResult.failure({
    required this.path,
    required this.name,
    required this.error,
  })  : success = false,
        message = null;
}

/// Runs tools based on their definitions.
///
/// Handles argument parsing, help display, command routing,
/// and traversal execution.
class ToolRunner {
  /// Tool definition.
  final ToolDefinition tool;

  /// Command executors by name.
  final Map<String, CommandExecutor> executors;

  /// Whether to print output.
  final bool verbose;

  /// Output writer (default: stdout).
  final StringSink output;

  ToolRunner({
    required this.tool,
    this.executors = const {},
    this.verbose = true,
    StringSink? output,
  }) : output = output ?? stdout;

  /// Run the tool with command-line arguments.
  Future<ToolResult> run(List<String> args) async {
    // Parse arguments
    final parser = CliArgParser(toolDefinition: tool);
    final cliArgs = parser.parse(args);

    // Handle help
    if (cliArgs.help) {
      if (cliArgs.commands.isNotEmpty) {
        final cmdName = cliArgs.commands.first;
        final cmd = tool.findCommand(cmdName);
        if (cmd != null) {
          output.writeln(HelpGenerator.generateCommandHelp(cmd, tool: tool));
          return const ToolResult.success();
        }
        output.writeln('Unknown command: :$cmdName');
        return const ToolResult.failure('Unknown command');
      }
      output.writeln(HelpGenerator.generateToolHelp(tool));
      return const ToolResult.success();
    }

    // Handle version
    if (cliArgs.version) {
      output.writeln('${tool.name} v${tool.version}');
      return const ToolResult.success();
    }

    // Handle multi-command mode
    if (tool.mode == ToolMode.multiCommand) {
      if (cliArgs.commands.isEmpty) {
        if (tool.defaultCommand != null) {
          return _runCommand(tool.defaultCommand!, cliArgs);
        }
        output.writeln(HelpGenerator.generateUsageSummary(tool));
        return const ToolResult.failure('No command specified');
      }

      // Run each command in sequence
      final results = <ItemResult>[];
      for (final cmdName in cliArgs.commands) {
        final result = await _runCommand(cmdName, cliArgs);
        results.addAll(result.itemResults);
        if (!result.success) {
          return result; // Stop on first failure
        }
      }
      return ToolResult.fromItems(results);
    }

    // Single command mode - run default executor
    final executor = executors['default'];
    if (executor == null) {
      return const ToolResult.failure('No default executor configured');
    }

    return _runWithTraversal(executor, null, cliArgs);
  }

  /// Run a specific command.
  Future<ToolResult> _runCommand(String cmdName, CliArgs cliArgs) async {
    final cmd = tool.findCommand(cmdName);
    if (cmd == null) {
      output.writeln('Unknown command: :$cmdName');
      return ToolResult.failure('Unknown command: $cmdName');
    }

    // Check for per-command --help
    final cmdArgs = cliArgs.commandArgs[cmdName];
    if (cmdArgs != null && cmdArgs.options['help'] == true) {
      output.writeln(HelpGenerator.generateCommandHelp(cmd, tool: tool));
      return const ToolResult.success();
    }

    final executor = executors[cmdName];
    if (executor == null) {
      return ToolResult.failure('No executor for command: $cmdName');
    }

    return _runWithTraversal(executor, cmd, cliArgs);
  }

  /// Run executor with traversal.
  Future<ToolResult> _runWithTraversal(
    CommandExecutor executor,
    CommandDefinition? cmd,
    CliArgs cliArgs,
  ) async {
    // Get execution root
    final executionRoot = cliArgs.root ?? Directory.current.path;

    // Build traversal info
    final supportsGit = cmd?.supportsGitTraversal ?? false;
    final BaseTraversalInfo traversalInfo = supportsGit
        ? cliArgs.toGitTraversalInfo(executionRoot: executionRoot)
        : cliArgs.toProjectTraversalInfo(executionRoot: executionRoot);

    // Check if command requires traversal
    if (cmd != null && !cmd.requiresTraversal) {
      // Execute without traversal
      return executor.executeWithoutTraversal(cliArgs);
    }

    // Execute with traversal
    final results = <ItemResult>[];

    await BuildBase.traverse(
      info: traversalInfo,
      run: (context) async {
        // Apply per-command filters for project traversal
        if (traversalInfo is ProjectTraversalInfo) {
          final cmdArgs = cliArgs.commandArgs[cmd?.name];
          if (cmdArgs != null) {
            // Check project patterns
            if (cmdArgs.projectPatterns.isNotEmpty) {
              final matches = _matchesAny(context.name, cmdArgs.projectPatterns);
              if (!matches) return true; // Skip, continue
            }
            // Check exclude patterns
            if (cmdArgs.excludePatterns.isNotEmpty) {
              final excluded = _matchesAny(context.name, cmdArgs.excludePatterns);
              if (excluded) return true; // Skip, continue
            }
          }
        }

        final result = await executor.execute(context, cliArgs);
        results.add(result);
        return true; // Continue to next
      },
    );

    return ToolResult.fromItems(results);
  }

  /// Check if name matches any pattern.
  bool _matchesAny(String name, List<String> patterns) {
    for (final pattern in patterns) {
      if (_matchGlob(name, pattern)) return true;
    }
    return false;
  }

  /// Simple glob matching.
  bool _matchGlob(String name, String pattern) {
    final regexStr = pattern
        .replaceAll('.', r'\.')
        .replaceAll('*', '.*')
        .replaceAll('?', '.');
    return RegExp('^$regexStr\$').hasMatch(name);
  }
}
