import 'dart:async';

import 'commands/cleanup_tool.dart';
import 'commands/versioner_tool.dart';
import 'commands/compiler_tool.dart';
import 'commands/runner_tool.dart';
import 'commands/dependencies_tool.dart';
import 'pubget_command.dart';

/// Registry of built-in commands that can be executed within pipelines.
///
/// All commands run the respective tools directly using their Dart
/// implementation — no external process spawning.
class BuiltinCommands {
  final String projectPath;
  final String rootPath;
  final bool verbose;
  final bool dryRun;

  BuiltinCommands({
    required this.projectPath,
    required this.rootPath,
    required this.verbose,
    required this.dryRun,
  });

  /// Check if a command is a built-in command.
  bool isBuiltin(String command) {
    final parts = command.trim().split(RegExp(r'\s+'));
    final cmd = parts.first.toLowerCase();
    return _builtinNames.contains(cmd);
  }

  static const _builtinNames = {
    'versioner',
    'compiler',
    'runner',
    'cleanup',
    'dependencies',
    'pubget',
    'pubgetall',
  };

  /// Execute a built-in command.
  /// 
  /// Returns true if successful, false otherwise.
  Future<bool> execute(String command) async {
    final parts = command.trim().split(RegExp(r'\s+'));
    final cmd = parts.first.toLowerCase();
    final args = parts.skip(1).toList();

    switch (cmd) {
      case 'versioner':
        return _runVersioner(args);
      case 'compiler':
        return _runCompiler(args);
      case 'runner':
        return _runRunner(args);
      case 'cleanup':
        return _runCleanup(args);
      case 'dependencies':
        return _runDependencies(args);
      case 'pubget':
        return _runPubGet(args);
      case 'pubgetall':
        return _runPubGetAll(args);
      default:
        print('  Unknown built-in command: $cmd');
        return false;
    }
  }

  Future<bool> _runVersioner(List<String> args) async {
    if (verbose) print('  [builtin] Running versioner...');
    if (dryRun) {
      print('  [DRY RUN] Would run versioner with args: $args');
      return true;
    }
    final tool = VersionerTool()..verbose = verbose;
    return tool.run(args);
  }

  Future<bool> _runCompiler(List<String> args) async {
    if (verbose) print('  [builtin] Running compiler...');
    if (dryRun) {
      print('  [DRY RUN] Would run compiler with args: $args');
      return true;
    }
    final tool = CompilerTool()
      ..verbose = verbose
      ..dryRun = dryRun;
    return tool.run(args);
  }

  Future<bool> _runRunner(List<String> args) async {
    if (verbose) print('  [builtin] Running build runner...');
    if (dryRun) {
      print('  [DRY RUN] Would run runner with args: $args');
      return true;
    }
    final tool = RunnerTool()
      ..verbose = verbose
      ..dryRun = dryRun;
    return tool.run(args);
  }

  Future<bool> _runCleanup(List<String> args) async {
    if (verbose) print('  [builtin] Running cleanup...');
    if (dryRun) {
      print('  [DRY RUN] Would run cleanup with args: $args');
      return true;
    }
    final tool = CleanupTool()
      ..verbose = verbose
      ..dryRun = dryRun;
    return tool.run(args);
  }

  Future<bool> _runDependencies(List<String> args) async {
    if (verbose) print('  [builtin] Running dependencies...');
    if (dryRun) {
      print('  [DRY RUN] Would run dependencies with args: $args');
      return true;
    }
    final tool = DependenciesTool()..verbose = verbose;
    return tool.run(args);
  }

  Future<bool> _runPubGet(List<String> args) async {
    if (verbose) print('  [builtin] Running pubget...');
    if (dryRun) {
      print('  [DRY RUN] Would run pubget with args: $args');
      return true;
    }
    final pubGetCommand = PubGetCommand(
      rootPath: rootPath,
      verbose: verbose,
    );
    return pubGetCommand.execute(args);
  }

  Future<bool> _runPubGetAll(List<String> args) async {
    if (verbose) print('  [builtin] Running pubgetall (scan . --recursive)...');
    if (dryRun) {
      print('  [DRY RUN] Would run pubgetall with args: $args');
      return true;
    }
    final pubGetCommand = PubGetCommand(
      rootPath: rootPath,
      verbose: verbose,
    );
    final fullArgs = ['--scan', '.', '--recursive', ...args];
    return pubGetCommand.execute(fullArgs);
  }
}
