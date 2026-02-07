import 'dart:async';
import 'dart:io';

import 'pubget_command.dart';

/// Registry of built-in commands that can be executed within pipelines.
/// 
/// These commands run the respective tools directly without spawning
/// a new process, for better performance and integration.
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
    'astgen',
    'd4rtgen',
    'cleanup',
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
      case 'astgen':
        return _runAstgen(args);
      case 'd4rtgen':
        return _runD4rtgen(args);
      case 'cleanup':
        return _runCleanup(args);
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

    // TODO: Import and call versioner directly
    // For now, fall back to running as external process
    return _runExternal('versioner', args);
  }

  Future<bool> _runCompiler(List<String> args) async {
    if (verbose) print('  [builtin] Running compiler...');
    if (dryRun) {
      print('  [DRY RUN] Would run compiler with args: $args');
      return true;
    }

    // TODO: Import and call compiler directly
    // For now, fall back to running as external process
    return _runExternal('compiler', args);
  }

  Future<bool> _runRunner(List<String> args) async {
    if (verbose) print('  [builtin] Running build runner...');
    if (dryRun) {
      print('  [DRY RUN] Would run runner with args: $args');
      return true;
    }

    // TODO: Import and call runner directly
    // For now, fall back to running as external process
    return _runExternal('runner', args);
  }

  Future<bool> _runAstgen(List<String> args) async {
    if (verbose) print('  [builtin] Running astgen...');
    if (dryRun) {
      print('  [DRY RUN] Would run astgen with args: $args');
      return true;
    }

    // TODO: Import and call astgen directly
    // For now, fall back to running as external process
    return _runExternal('astgen', args);
  }

  Future<bool> _runD4rtgen(List<String> args) async {
    if (verbose) print('  [builtin] Running d4rtgen...');
    if (dryRun) {
      print('  [DRY RUN] Would run d4rtgen with args: $args');
      return true;
    }

    // TODO: Import and call d4rtgen directly
    // For now, fall back to running as external process
    return _runExternal('d4rtgen', args);
  }

  Future<bool> _runCleanup(List<String> args) async {
    if (verbose) print('  [builtin] Running cleanup...');
    if (dryRun) {
      print('  [DRY RUN] Would run cleanup with args: $args');
      return true;
    }

    // Built-in cleanup: remove generated files, build directories, etc.
    final targets = args.isEmpty
        ? ['build', '.dart_tool/build', '**/*.g.dart']
        : args;

    for (final target in targets) {
      if (target.contains('*')) {
        // Glob pattern - would need glob package
        if (verbose) print('    Cleanup glob: $target');
      } else {
        final path = '$projectPath/$target';
        final entity = FileSystemEntity.isDirectorySync(path)
            ? Directory(path)
            : File(path);
        if (entity.existsSync()) {
          if (verbose) print('    Removing: $target');
          try {
            entity.deleteSync(recursive: true);
          } catch (e) {
            print('    Warning: Failed to remove $target: $e');
          }
        }
      }
    }

    return true;
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

    // pubgetall is a shortcut for pubget --scan . --recursive
    final pubGetCommand = PubGetCommand(
      rootPath: rootPath,
      verbose: verbose,
    );
    // Prepend --scan . --recursive to the args
    final fullArgs = ['--scan', '.', '--recursive', ...args];
    return pubGetCommand.execute(fullArgs);
  }

  /// Run a command as an external process (fallback).
  Future<bool> _runExternal(String command, List<String> args) async {
    final allArgs = [...args];
    if (verbose && !allArgs.contains('-v') && !allArgs.contains('--verbose')) {
      allArgs.add('--verbose');
    }

    try {
      final result = await Process.run(
        command,
        allArgs,
        workingDirectory: projectPath,
        runInShell: true,
      );

      if (result.stdout.toString().isNotEmpty) {
        stdout.write(result.stdout);
      }
      if (result.stderr.toString().isNotEmpty) {
        stderr.write(result.stderr);
      }

      return result.exitCode == 0;
    } catch (e) {
      print('  Error running $command: $e');
      return false;
    }
  }
}
