/// Buildkit v2 command executors.
///
/// All buildkit commands are implemented as native v2 [CommandExecutor]s.
/// Project/git traversal is handled by the v2 ToolRunner framework based
/// on each command's [CommandDefinition.requiresTraversal] flag.
///
/// - Traversal executors implement [execute] (called per folder).
/// - Non-traversal executors implement [executeWithoutTraversal].
library;

import 'dart:io';

import 'package:tom_build_base/tom_build_base.dart';
import 'package:tom_build_base/tom_build_base_v2.dart';

import '../pubget_command.dart';
import '../pubupdate_command.dart';
import 'executors/buildsorter_executor.dart';
import 'executors/bumppubspec_executor.dart';
import 'executors/bumpversion_executor.dart';
import 'executors/cleanup_executor.dart';
import 'executors/compiler_executor.dart';
import 'executors/dependencies_executor.dart';
import 'executors/execute_executor.dart';
import 'executors/git_executors.dart';
import 'executors/findproject_executor.dart';
import 'executors/publisher_executor.dart';
import 'executors/runner_executor.dart';
import 'executors/status_executor.dart';
import 'executors/versioner_executor.dart';

// =============================================================================
// Pub Command Executors
// =============================================================================

/// Passthrough executor for :pubget.
class PubGetExecutor extends CommandExecutor {
  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return ItemResult.failure(
      path: context.path,
      name: context.name,
      error: 'pubget uses executeWithoutTraversal',
    );
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    final root = args.scan ?? args.root ?? Directory.current.path;
    final pubGet = PubGetCommand(rootPath: root, verbose: args.verbose);

    final cmdArgs = <String>['--scan', root];
    if (args.effectiveRecursive) cmdArgs.add('--recursive');
    if (args.verbose) cmdArgs.add('--verbose');
    if (args.dryRun) cmdArgs.add('--dry-run');

    // Pass through extra options
    for (final entry in args.extraOptions.entries) {
      final key = entry.key;
      final val = entry.value;
      if (val is bool && val) cmdArgs.add('--$key');
    }

    // Per-command args
    if (args.commands.isNotEmpty) {
      final cmdName = args.commands.first;
      final perCmd = args.commandArgs[cmdName];
      if (perCmd != null) {
        for (final p in perCmd.projectPatterns) {
          cmdArgs.addAll(['--project', p]);
        }
        for (final entry in perCmd.options.entries) {
          if (entry.value is bool && entry.value == true) {
            cmdArgs.add('--${entry.key}');
          }
        }
      }
    }

    final success = await pubGet.execute(cmdArgs);
    return success
        ? const ToolResult.success()
        : const ToolResult.failure('pub get failed');
  }
}

/// Passthrough executor for :pubgetall (pubget -R `<workspace>` --scan `<workspace>` --recursive).
///
/// Always operates on the complete workspace by resolving the workspace root
/// and passing it as both -R (execution root) and --scan root.
class PubGetAllExecutor extends CommandExecutor {
  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return ItemResult.failure(
      path: context.path,
      name: context.name,
      error: 'pubgetall uses executeWithoutTraversal',
    );
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    final wsRoot =
        args.root ?? findWorkspaceRoot(args.scan ?? Directory.current.path);
    final pubGet = PubGetCommand(rootPath: wsRoot, verbose: args.verbose);

    final cmdArgs = <String>['--scan', wsRoot, '--recursive'];
    if (args.verbose) cmdArgs.add('--verbose');
    if (args.dryRun) cmdArgs.add('--dry-run');

    for (final entry in args.extraOptions.entries) {
      if (entry.value is bool && entry.value == true) {
        cmdArgs.add('--${entry.key}');
      }
    }

    final success = await pubGet.execute(cmdArgs);
    return success
        ? const ToolResult.success()
        : const ToolResult.failure('pub get failed');
  }
}

/// Passthrough executor for :pubupdate.
class PubUpdateExecutor extends CommandExecutor {
  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return ItemResult.failure(
      path: context.path,
      name: context.name,
      error: 'pubupdate uses executeWithoutTraversal',
    );
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    final root = args.scan ?? args.root ?? Directory.current.path;
    final pubUpdate = PubUpdateCommand(rootPath: root, verbose: args.verbose);

    final cmdArgs = <String>['--scan', root];
    if (args.effectiveRecursive) cmdArgs.add('--recursive');
    if (args.verbose) cmdArgs.add('--verbose');
    if (args.dryRun) cmdArgs.add('--dry-run');

    for (final entry in args.extraOptions.entries) {
      final key = entry.key;
      final val = entry.value;
      if (val is bool && val) cmdArgs.add('--$key');
    }

    if (args.commands.isNotEmpty) {
      final cmdName = args.commands.first;
      final perCmd = args.commandArgs[cmdName];
      if (perCmd != null) {
        for (final p in perCmd.projectPatterns) {
          cmdArgs.addAll(['--project', p]);
        }
        for (final entry in perCmd.options.entries) {
          if (entry.value is bool && entry.value == true) {
            cmdArgs.add('--${entry.key}');
          }
        }
      }
    }

    final success = await pubUpdate.execute(cmdArgs);
    return success
        ? const ToolResult.success()
        : const ToolResult.failure('pub upgrade failed');
  }
}

/// Passthrough executor for :pubupdateall (pubupdate -R `<workspace>` --scan `<workspace>` --recursive).
///
/// Always operates on the complete workspace by resolving the workspace root
/// and passing it as both -R (execution root) and --scan root.
class PubUpdateAllExecutor extends CommandExecutor {
  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return ItemResult.failure(
      path: context.path,
      name: context.name,
      error: 'pubupdateall uses executeWithoutTraversal',
    );
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    final wsRoot =
        args.root ?? findWorkspaceRoot(args.scan ?? Directory.current.path);
    final pubUpdate = PubUpdateCommand(rootPath: wsRoot, verbose: args.verbose);

    final cmdArgs = <String>['--scan', wsRoot, '--recursive'];
    if (args.verbose) cmdArgs.add('--verbose');
    if (args.dryRun) cmdArgs.add('--dry-run');

    for (final entry in args.extraOptions.entries) {
      if (entry.value is bool && entry.value == true) {
        cmdArgs.add('--${entry.key}');
      }
    }

    final success = await pubUpdate.execute(cmdArgs);
    return success
        ? const ToolResult.success()
        : const ToolResult.failure('pub upgrade failed');
  }
}

// =============================================================================
// Other Executors
// =============================================================================

/// Executor for :dcli command.
class DcliExecutor extends CommandExecutor {
  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return ItemResult.failure(
      path: context.path,
      name: context.name,
      error: 'dcli uses executeWithoutTraversal',
    );
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    if (args.positionalArgs.isEmpty) {
      return const ToolResult.failure('Missing dcli script or expression');
    }

    final dcliArgs = <String>[];

    final initSource = args.extraOptions['init-source'];
    if (initSource is String) {
      dcliArgs.addAll(['-init-source', initSource]);
    }
    if (args.extraOptions['no-init-source'] == true) {
      dcliArgs.add('-no-init-source');
    }
    dcliArgs.addAll(args.positionalArgs);

    if (args.dryRun) {
      print('[DRY RUN] Would run: dcli ${dcliArgs.join(' ')}');
      return const ToolResult.success();
    }

    try {
      final result = await ProcessRunner.run('dcli', dcliArgs);
      if (result.stdout.isNotEmpty) {
        stdout.write(result.stdout);
      }
      if (result.exitCode != 0) {
        if (result.stderr.isNotEmpty) {
          stderr.write(result.stderr);
        }
        return ToolResult.failure('dcli exited with code ${result.exitCode}');
      }
      return const ToolResult.success();
    } catch (e) {
      return ToolResult.failure(e.toString());
    }
  }
}

// =============================================================================
// Macro Executors (non-traversal)
// =============================================================================

/// Executor for define command.
class DefineExecutor extends CommandExecutor {
  final void Function(String name, String value) onDefine;

  DefineExecutor({required this.onDefine});

  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return ItemResult.failure(
      path: context.path,
      name: context.name,
      error: 'define is a non-traversal command',
    );
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    if (args.positionalArgs.isEmpty) {
      return const ToolResult.failure('Missing argument: name=value');
    }

    final def = args.positionalArgs.first;
    final eqIndex = def.indexOf('=');
    if (eqIndex <= 0) {
      return const ToolResult.failure('Invalid format. Use: define name=value');
    }

    final name = def.substring(0, eqIndex);
    final value = [
      def.substring(eqIndex + 1),
      ...args.positionalArgs.skip(1),
    ].join(' ').trim();

    if (args.dryRun) {
      print('[DRY RUN] Would define macro: $name=$value');
      return const ToolResult.success();
    }

    onDefine(name, value);
    print('Defined macro: $name');
    return const ToolResult.success(processedCount: 1);
  }
}

/// Executor for undefine command.
class UndefineExecutor extends CommandExecutor {
  final bool Function(String name) onUndefine;

  UndefineExecutor({required this.onUndefine});

  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return ItemResult.failure(
      path: context.path,
      name: context.name,
      error: 'undefine is a non-traversal command',
    );
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    if (args.positionalArgs.isEmpty) {
      return const ToolResult.failure('Missing argument: macro name');
    }

    final name = args.positionalArgs.first;

    if (args.dryRun) {
      print('[DRY RUN] Would undefine macro: $name');
      return const ToolResult.success();
    }

    final removed = onUndefine(name);

    if (removed) {
      print('Removed macro: $name');
      return const ToolResult.success(processedCount: 1);
    } else {
      return ToolResult.failure('Macro not found: $name');
    }
  }
}

/// Executor for defines listing command.
class DefinesExecutor extends CommandExecutor {
  final Map<String, String> Function() getMacros;

  DefinesExecutor({required this.getMacros});

  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return ItemResult.failure(
      path: context.path,
      name: context.name,
      error: 'defines is a non-traversal command',
    );
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    final macros = getMacros();

    if (macros.isEmpty) {
      print('No macros defined.');
    } else {
      print('Defined macros:');
      final maxLen = macros.keys
          .map((k) => k.length)
          .reduce((a, b) => a > b ? a : b);
      for (final entry in macros.entries) {
        print('  @${entry.key.padRight(maxLen)} = ${entry.value}');
      }
    }

    return const ToolResult.success();
  }
}

// =============================================================================
// Factory Function
// =============================================================================

/// Create all buildkit executors.
///
/// All tool commands use native v2 executors. Git executors are defined
/// in [git_executors.dart]. Project tool executors are in individual files
/// under `executors/`.
///
/// The macro callbacks are used for define/undefine/defines commands.
Map<String, CommandExecutor> createBuildkitExecutors({
  required void Function(String name, String value) onDefine,
  required bool Function(String name) onUndefine,
  required Map<String, String> Function() getMacros,
}) {
  return {
    // Build tools
    'versioner': VersionerExecutor(),
    'bumpversion': BumpVersionExecutor(),
    'bumppubspec': BumpPubspecExecutor(),
    'compiler': CompilerExecutor(),
    'runner': RunnerExecutor(),
    'cleanup': CleanupExecutor(),
    'dependencies': DependenciesExecutor(),
    'publisher': PublisherExecutor(),
    'status': StatusExecutor(),
    'buildsorter': BuildSorterExecutor(),
    'execute': ExecuteExecutor(),

    // Pub commands (have their own non-ToolBase API)
    'pubget': PubGetExecutor(),
    'pubgetall': PubGetAllExecutor(),
    'pubupdate': PubUpdateExecutor(),
    'pubupdateall': PubUpdateAllExecutor(),

    // Git tools
    'git': GitPassthroughExecutor(),
    'gitstatus': GitStatusExecutor(),
    'gitcommit': GitCommitExecutor(),
    'gitpull': GitPullExecutor(),
    'gitbranch': GitBranchExecutor(),
    'gittag': GitTagExecutor(),
    'gitcheckout': GitCheckoutExecutor(),
    'gitreset': GitResetExecutor(),
    'gitclean': GitCleanExecutor(),
    'gitsync': GitSyncExecutor(),
    'gitprune': GitPruneExecutor(),
    'gitstash': GitStashExecutor(),
    'gitunstash': GitUnstashExecutor(),
    'gitcompare': GitCompareExecutor(),
    'gitmerge': GitMergeExecutor(),
    'gitsquash': GitSquashExecutor(),
    'gitrebase': GitRebaseExecutor(),

    // Other
    'findproject': FindProjectExecutor(),
    'dcli': DcliExecutor(),

    // Macros
    'define': DefineExecutor(onDefine: onDefine),
    'undefine': UndefineExecutor(onUndefine: onUndefine),
    'defines': DefinesExecutor(getMacros: getMacros),
  };
}
