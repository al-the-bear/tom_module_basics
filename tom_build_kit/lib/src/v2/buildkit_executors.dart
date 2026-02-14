/// Buildkit v2 command executors.
///
/// These executors implement the buildkit commands using the v2 ToolRunner
/// framework. They wrap the existing v1 tool implementations from
/// lib/src/commands/ as passthrough executors, allowing them to handle their
/// own traversal/discovery while the v2 framework handles command routing,
/// arg parsing, and macro substitution.
///
/// Strategy: All v1 tool executors use [executeWithoutTraversal] to bypass
/// the v2 ToolRunner's traversal. The v1 tools handle their own project
/// discovery internally. This allows a clean v2 command routing layer
/// while preserving all existing v1 tool behavior.
library;

import 'dart:io';

import 'package:tom_build_base/tom_build_base_v2.dart';

import '../commands/buildsorter_tool.dart';
import '../commands/bumpversion_tool.dart';
import '../commands/cleanup_tool.dart';
import '../commands/compiler_tool.dart';
import '../commands/dependencies_tool.dart';
import '../commands/git_tool.dart';
import '../commands/gitbranch_tool.dart';
import '../commands/gitcheckout_tool.dart';
import '../commands/gitclean_tool.dart';
import '../commands/gitcommit_tool.dart';
import '../commands/gitcompare_tool.dart';
import '../commands/gitmerge_tool.dart';
import '../commands/gitprune_tool.dart';
import '../commands/gitpull_tool.dart';
import '../commands/gitrebase_tool.dart';
import '../commands/gitreset_tool.dart';
import '../commands/gitstash_tool.dart';
import '../commands/gitstatus_tool.dart';
import '../commands/gitsync_tool.dart';
import '../commands/gitsquash_tool.dart';
import '../commands/gittag_tool.dart';
import '../commands/gitunstash_tool.dart';
import '../commands/publisher_tool.dart';
import '../commands/runner_tool.dart';
import '../commands/tool_base.dart';
import '../commands/versioner_tool.dart';
import '../pubget_command.dart';
import '../pubupdate_command.dart';

// =============================================================================
// V1 Tool Passthrough Executor
// =============================================================================

/// Passthrough executor that delegates to a v1 ToolBase.
///
/// Rebuilds command-line args from the parsed [CliArgs] and passes them
/// to the v1 tool's `run()` method. The v1 tool handles its own traversal
/// and project discovery.
class V1ToolPassthroughExecutor extends CommandExecutor {
  /// Factory function to create the v1 tool.
  final ToolBase Function() toolFactory;

  /// Fixed git traversal flags to inject (e.g., '--inner-first-git').
  final List<String> fixedGitFlags;

  V1ToolPassthroughExecutor({
    required this.toolFactory,
    this.fixedGitFlags = const [],
  });

  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    // Not used - all v1 tools handle their own traversal
    return ItemResult.failure(
      path: context.path,
      name: context.name,
      error: 'V1 tools use executeWithoutTraversal',
    );
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    final tool = toolFactory();
    final toolArgs = _buildToolArgs(args);

    try {
      final success = await tool.run(toolArgs);
      return success
          ? const ToolResult.success()
          : const ToolResult.failure('Command failed');
    } catch (e) {
      return ToolResult.failure(e.toString());
    }
  }

  /// Build v1-compatible argument list from parsed CliArgs.
  List<String> _buildToolArgs(CliArgs args) {
    final toolArgs = <String>[];

    // Inject fixed git flags first
    toolArgs.addAll(fixedGitFlags);

    // Standard options
    if (args.verbose) toolArgs.add('--verbose');
    if (args.dryRun) toolArgs.add('--dry-run');
    if (args.listOnly) toolArgs.add('--list');

    // Navigation options
    if (args.scan != null) {
      toolArgs.addAll(['--scan', args.scan!]);
    }
    if (args.root != null) {
      toolArgs.addAll(['--root', args.root!]);
    } else if (args.bareRoot) {
      toolArgs.add('-R');
    }
    if (args.effectiveRecursive) toolArgs.add('--recursive');
    if (args.innerFirstGit && !fixedGitFlags.contains('--inner-first-git')) {
      toolArgs.add('--inner-first-git');
    }
    if (args.outerFirstGit && !fixedGitFlags.contains('--outer-first-git')) {
      toolArgs.add('--outer-first-git');
    }
    if (args.workspaceRecursion) toolArgs.add('--workspace-recursion');
    if (args.buildOrder) toolArgs.add('--build-order');
    if (args.force) toolArgs.add('--force');

    // Project/exclude patterns
    for (final p in args.projectPatterns) {
      toolArgs.addAll(['--project', p]);
    }
    for (final x in args.excludePatterns) {
      toolArgs.addAll(['--exclude', x]);
    }
    for (final x in args.excludeProjects) {
      toolArgs.addAll(['--exclude-projects', x]);
    }
    for (final m in args.modules) {
      toolArgs.addAll(['--modules', m]);
    }
    for (final m in args.skipModules) {
      toolArgs.addAll(['--skip-modules', m]);
    }

    // Extra options (command-specific)
    for (final entry in args.extraOptions.entries) {
      final key = entry.key;
      final val = entry.value;
      if (val is bool && val) {
        toolArgs.add('--$key');
      } else if (val is String) {
        toolArgs.addAll(['--$key', val]);
      } else if (val is List) {
        for (final v in val) {
          toolArgs.addAll(['--$key', v.toString()]);
        }
      }
    }

    // Per-command args (from first command in multi-command)
    if (args.commands.isNotEmpty) {
      final cmdName = args.commands.first;
      final cmdArgs = args.commandArgs[cmdName];
      if (cmdArgs != null) {
        for (final p in cmdArgs.projectPatterns) {
          toolArgs.addAll(['--project', p]);
        }
        for (final x in cmdArgs.excludePatterns) {
          toolArgs.addAll(['--exclude', x]);
        }
        for (final entry in cmdArgs.options.entries) {
          final key = entry.key;
          final val = entry.value;
          if (val is bool && val) {
            toolArgs.add('--$key');
          } else if (val is String) {
            toolArgs.addAll(['--$key', val]);
          }
        }
      }
    }

    // Positional args
    toolArgs.addAll(args.positionalArgs);

    return toolArgs;
  }
}

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

/// Passthrough executor for :pubgetall (pubget --scan . --recursive).
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
    final root = args.scan ?? args.root ?? Directory.current.path;
    final pubGet = PubGetCommand(rootPath: root, verbose: args.verbose);

    final cmdArgs = <String>['--scan', root, '--recursive'];
    if (args.verbose) cmdArgs.add('--verbose');

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

/// Passthrough executor for :pubupdateall (pubupdate --scan . --recursive).
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
    final root = args.scan ?? args.root ?? Directory.current.path;
    final pubUpdate = PubUpdateCommand(rootPath: root, verbose: args.verbose);

    final cmdArgs = <String>['--scan', root, '--recursive'];
    if (args.verbose) cmdArgs.add('--verbose');

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

    try {
      final result = await Process.run('dcli', dcliArgs);
      if (result.stdout.toString().isNotEmpty) {
        stdout.write(result.stdout);
      }
      if (result.exitCode != 0) {
        if (result.stderr.toString().isNotEmpty) {
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

    onDefine(name, value);
    print('Defined: @$name = $value');
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
    final removed = onUndefine(name);

    if (removed) {
      print('Removed macro: @$name');
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
      final maxLen =
          macros.keys.map((k) => k.length).reduce((a, b) => a > b ? a : b);
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
/// All v1 tool executors use [V1ToolPassthroughExecutor] which delegates
/// to the v1 tool's `run()` method, allowing it to handle its own traversal.
///
/// Git tool executors inject fixed git traversal flags based on the
/// documented default order for each git operation.
///
/// The macro callbacks are used for define/undefine/defines commands.
Map<String, CommandExecutor> createBuildkitExecutors({
  required void Function(String name, String value) onDefine,
  required bool Function(String name) onUndefine,
  required Map<String, String> Function() getMacros,
}) {
  return {
    // Build tools
    'versioner': V1ToolPassthroughExecutor(toolFactory: VersionerTool.new),
    'bumpversion': V1ToolPassthroughExecutor(toolFactory: BumpVersionTool.new),
    'compiler': V1ToolPassthroughExecutor(toolFactory: CompilerTool.new),
    'runner': V1ToolPassthroughExecutor(toolFactory: RunnerTool.new),
    'cleanup': V1ToolPassthroughExecutor(toolFactory: CleanupTool.new),
    'dependencies': V1ToolPassthroughExecutor(toolFactory: DependenciesTool.new),
    'publisher': V1ToolPassthroughExecutor(toolFactory: PublisherTool.new),
    'buildsorter': V1ToolPassthroughExecutor(toolFactory: BuildSorterTool.new),

    // Pub commands (have their own non-ToolBase API)
    'pubget': PubGetExecutor(),
    'pubgetall': PubGetAllExecutor(),
    'pubupdate': PubUpdateExecutor(),
    'pubupdateall': PubUpdateAllExecutor(),

    // Git tools - inner first (operations that start from leaves)
    'git': V1ToolPassthroughExecutor(toolFactory: GitTool.new),
    'gitstatus': V1ToolPassthroughExecutor(
      toolFactory: () => GitStatusTool()..autoInnerFirst = true,
    ),
    'gitcommit': V1ToolPassthroughExecutor(
      toolFactory: GitCommitTool.new,
      fixedGitFlags: ['--inner-first-git'],
    ),
    'gitbranch': V1ToolPassthroughExecutor(
      toolFactory: GitBranchTool.new,
      fixedGitFlags: ['--inner-first-git'],
    ),
    'gittag': V1ToolPassthroughExecutor(
      toolFactory: GitTagTool.new,
      fixedGitFlags: ['--inner-first-git'],
    ),
    'gitclean': V1ToolPassthroughExecutor(
      toolFactory: GitCleanTool.new,
      fixedGitFlags: ['--inner-first-git'],
    ),
    'gitcompare': V1ToolPassthroughExecutor(
      toolFactory: GitCompareTool.new,
      fixedGitFlags: ['--inner-first-git'],
    ),
    'gitmerge': V1ToolPassthroughExecutor(
      toolFactory: GitMergeTool.new,
      fixedGitFlags: ['--inner-first-git'],
    ),
    'gitsquash': V1ToolPassthroughExecutor(
      toolFactory: GitSquashTool.new,
      fixedGitFlags: ['--inner-first-git'],
    ),
    'gitrebase': V1ToolPassthroughExecutor(
      toolFactory: GitRebaseTool.new,
      fixedGitFlags: ['--inner-first-git'],
    ),
    'gitstash': V1ToolPassthroughExecutor(
      toolFactory: GitStashTool.new,
      fixedGitFlags: ['--inner-first-git'],
    ),

    // Git tools - outer first (operations that start from root)
    'gitpull': V1ToolPassthroughExecutor(
      toolFactory: GitPullTool.new,
      fixedGitFlags: ['--outer-first-git'],
    ),
    'gitcheckout': V1ToolPassthroughExecutor(
      toolFactory: GitCheckoutTool.new,
      fixedGitFlags: ['--outer-first-git'],
    ),
    'gitreset': V1ToolPassthroughExecutor(
      toolFactory: GitResetTool.new,
      fixedGitFlags: ['--outer-first-git'],
    ),
    'gitsync': V1ToolPassthroughExecutor(
      toolFactory: GitSyncTool.new,
      fixedGitFlags: ['--outer-first-git'],
    ),
    'gitprune': V1ToolPassthroughExecutor(
      toolFactory: GitPruneTool.new,
      fixedGitFlags: ['--outer-first-git'],
    ),
    'gitunstash': V1ToolPassthroughExecutor(
      toolFactory: GitUnstashTool.new,
      fixedGitFlags: ['--outer-first-git'],
    ),

    // Other
    'dcli': DcliExecutor(),

    // Macros
    'define': DefineExecutor(onDefine: onDefine),
    'undefine': UndefineExecutor(onUndefine: onUndefine),
    'defines': DefinesExecutor(getMacros: getMacros),
  };
}
