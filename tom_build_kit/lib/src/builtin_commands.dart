import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'commands/buildsorter_tool.dart';
import 'commands/cleanup_tool.dart';
import 'commands/versioner_tool.dart';
import 'commands/versionbumper_tool.dart';
import 'commands/compiler_tool.dart';
import 'commands/runner_tool.dart';
import 'commands/dependencies_tool.dart';
import 'pubget_command.dart';

/// Registry of built-in commands that can be executed within pipelines.
///
/// Most commands run the respective tools directly using their Dart
/// implementation. The `dcli` command spawns an external process.
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
    'buildsorter',
    'versioner',
    'versionbumper',
    'compiler',
    'runner',
    'cleanup',
    'dependencies',
    'pubget',
    'pubgetall',
    'dcli',
  };

  /// Execute a built-in command.
  /// 
  /// Returns true if successful, false otherwise.
  /// Automatically injects `--project <projectPath>` into tool args
  /// when no `--project` or `-p` is already specified in the args.
  Future<bool> execute(String command) async {
    final parts = command.trim().split(RegExp(r'\s+'));
    final cmd = parts.first.toLowerCase();
    var args = parts.skip(1).toList();

    // Forward --project to tool if not already in args (bug #18 fix).
    // Skip injection for dcli — it doesn't use --project; it uses
    // the working directory instead.
    if (cmd != 'dcli' &&
        projectPath.isNotEmpty &&
        !args.contains('--project') &&
        !args.contains('-p')) {
      args = ['--project', projectPath, ...args];
    }

    switch (cmd) {
      case 'buildsorter':
        return _runBuildSorter(args);
      case 'versioner':
        return _runVersioner(args);
      case 'versionbumper':
        return _runVersionBumper(args);
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
      case 'dcli':
        return _runDcli(args);
      default:
        print('  Unknown built-in command: $cmd');
        return false;
    }
  }

  Future<bool> _runVersioner(List<String> args) async {
    if (verbose) print('  [builtin] Running versioner...');
    final tool = VersionerTool()
      ..verbose = verbose
      ..dryRun = dryRun;
    return tool.run(args);
  }

  Future<bool> _runVersionBumper(List<String> args) async {
    if (verbose) print('  [builtin] Running versionbumper...');
    final tool = VersionBumperTool()
      ..verbose = verbose
      ..dryRun = dryRun;
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
    final tool = DependenciesTool()
      ..verbose = verbose
      ..dryRun = dryRun;
    return tool.run(args);
  }

  Future<bool> _runBuildSorter(List<String> args) async {
    if (verbose) print('  [builtin] Running buildsorter...');
    final tool = BuildSorterTool()
      ..verbose = verbose
      ..dryRun = dryRun;
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

  // ---------------------------------------------------------------------------
  // dcli command — external process with path resolution
  // ---------------------------------------------------------------------------

  /// Execute `dcli` with path resolution and conditional file existence.
  ///
  /// Syntax: `dcli <file|expression> [-init-source <file>] [-no-init-source]`
  ///
  /// Path notations:
  /// - `~w/path` — workspace root
  /// - `~s/path` — workspace `_scripts/` folder
  /// - `::name`  — workspace `_scripts/bin/` folder
  ///
  /// If the argument has no extension, `.dart` is appended.
  /// If wrapped in double quotes, it's treated as an expression (always runs).
  /// For file targets, the command is only executed if the file exists (silent
  /// skip otherwise). This allows optional per-project build scripts.
  Future<bool> _runDcli(List<String> args) async {
    if (args.isEmpty) {
      print('  Error: dcli requires a file, script, or expression argument.');
      return false;
    }

    // Separate the target (file/expression) from dcli options.
    // The target is the first argument that is NOT an option.
    String? target;
    final dcliArgs = <String>[];
    var i = 0;
    while (i < args.length) {
      final arg = args[i];
      if (arg == '-init-source') {
        // Consumes the next argument as the init-source file.
        dcliArgs.add(arg);
        i++;
        if (i < args.length) {
          dcliArgs.add(_resolveDcliPath(args[i]));
        } else {
          print('  Error: -init-source requires a file argument.');
          return false;
        }
      } else if (arg == '-no-init-source') {
        dcliArgs.add(arg);
      } else if (arg.startsWith('-')) {
        // Unknown option — reject.
        print('  Error: Unknown dcli option "$arg".');
        print('  Only -init-source <file> and -no-init-source are allowed '
            'in buildkit context.');
        return false;
      } else if (target == null) {
        target = arg;
      } else {
        print('  Error: Unexpected extra argument "$arg" for dcli command.');
        return false;
      }
      i++;
    }

    if (target == null) {
      print('  Error: dcli requires a file, script, or expression argument.');
      return false;
    }

    // Detect expression mode: wrapped in double quotes.
    final isExpression =
        target.startsWith('"') && target.endsWith('"') && target.length > 1;

    if (isExpression) {
      // Expression mode — always execute.
      if (verbose) print('  [builtin] Running dcli expression...');
      if (dryRun) {
        print('  [DRY RUN] Would run dcli $target ${dcliArgs.join(' ')}'
            .trimRight());
        return true;
      }
      return _executeDcliProcess([target, ...dcliArgs]);
    }

    // File mode — resolve path and check existence.
    final resolvedPath = _resolveDcliPath(target);

    // Determine absolute path for existence check.
    final absolutePath = p.isAbsolute(resolvedPath)
        ? resolvedPath
        : p.join(projectPath, resolvedPath);

    if (!File(absolutePath).existsSync()) {
      // Silent skip — file doesn't exist (optional script pattern).
      if (verbose) {
        print('  [builtin] Skipping dcli — file not found: $resolvedPath');
      }
      return true;
    }

    if (verbose) print('  [builtin] Running dcli $resolvedPath...');
    if (dryRun) {
      print('  [DRY RUN] Would run dcli $resolvedPath ${dcliArgs.join(' ')}'
          .trimRight());
      return true;
    }

    return _executeDcliProcess([resolvedPath, ...dcliArgs]);
  }

  /// Resolve dcli path notations.
  ///
  /// - `~w/path` → `<rootPath>/path`
  /// - `~s/path` → `<rootPath>/_scripts/path`
  /// - `::name`  → `<rootPath>/_scripts/bin/name`
  /// - No extension → append `.dart`
  String _resolveDcliPath(String input) {
    var resolved = input;

    if (resolved.startsWith('~w/')) {
      resolved = p.join(rootPath, resolved.substring(3));
    } else if (resolved.startsWith('~s/')) {
      resolved = p.join(rootPath, '_scripts', resolved.substring(3));
    } else if (resolved.startsWith('::')) {
      resolved = p.join(rootPath, '_scripts', 'bin', resolved.substring(2));
    }

    // Auto-add .dart extension if none present.
    if (p.extension(resolved).isEmpty) {
      resolved = '$resolved.dart';
    }

    return resolved;
  }

  /// Spawn the `dcli` process with the given arguments.
  Future<bool> _executeDcliProcess(List<String> args) async {
    final dcliArgs = args.join(' ');
    if (verbose) print('  Executing: dcli $dcliArgs');

    try {
      final result = await Process.run(
        'dcli',
        args,
        workingDirectory: projectPath,
        environment: {
          ...Platform.environment,
          'BUILDKIT_PROJECT': projectPath,
          'BUILDKIT_ROOT': rootPath,
        },
      );

      if (result.stdout.toString().isNotEmpty) {
        stdout.write(result.stdout);
      }
      if (result.stderr.toString().isNotEmpty) {
        stderr.write(result.stderr);
      }

      if (result.exitCode != 0) {
        print('  dcli command failed with exit code ${result.exitCode}');
        return false;
      }

      return true;
    } catch (e) {
      print('  Error executing dcli: $e');
      print('  Make sure dcli is installed and on your PATH.');
      return false;
    }
  }
}
