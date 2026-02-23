/// Native v2 executor for the goto command.
///
/// Resolves a project by name, project ID, or folder name and prints
/// the absolute path to stdout.  Designed to be wrapped by a shell
/// function for `cd`:
///
/// ```bash
/// cdp() { local d; d="$(buildkit :goto "$@")" && cd "$d"; }
/// ```
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';
import 'package:tom_build_base/tom_build_base_v2.dart';

/// Executor for the `:goto` command.
///
/// Resolution order (first match wins):
/// 1. Folder basename exact match
/// 2. Project ID match (from tom_project.yaml or buildkit.yaml)
/// 3. Project name match (from tom_project.yaml or buildkit.yaml)
///
/// Uses [ProjectDiscovery.resolveProjectPatterns] with workspace-wide
/// recursive search.
class GotoExecutor extends CommandExecutor {
  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    return ItemResult.failure(
      path: context.path,
      name: context.name,
      error: 'goto uses executeWithoutTraversal',
    );
  }

  @override
  Future<ToolResult> executeWithoutTraversal(CliArgs args) async {
    // The project name/ID comes from positional args (after :goto).
    final positional = args.positionalArgs;

    if (positional.isEmpty) {
      stderr.writeln('Usage: buildkit :goto <project-name|project-id|folder>');
      stderr.writeln('');
      stderr.writeln('Resolves a project and prints its absolute path.');
      stderr.writeln('');
      stderr.writeln('Shell integration:');
      stderr.writeln('  cdp() { local d; d="\$(buildkit :goto "\$@")" && cd "\$d"; }');
      return const ToolResult.failure('No project specified');
    }

    final searchTerm = positional.first;
    final workspaceRoot = ProjectDiscovery.findWorkspaceRoot(
      args.root ?? Directory.current.path,
    );

    if (args.verbose) {
      stderr.writeln('Searching workspace: $workspaceRoot');
      stderr.writeln('Looking for: $searchTerm');
    }

    // Use ProjectDiscovery to resolve the project pattern.
    final discovery = ProjectDiscovery(verbose: args.verbose);
    final results = await discovery.resolveProjectPatterns(
      searchTerm,
      basePath: workspaceRoot,
    );

    if (results.isEmpty) {
      stderr.writeln('Project not found: $searchTerm');
      return ToolResult.failure('Project not found: $searchTerm');
    }

    if (results.length > 1) {
      // Multiple matches — print all to stderr and use the first.
      stderr.writeln(
        'Multiple matches for "$searchTerm" (using first):',
      );
      for (final r in results) {
        stderr.writeln('  ${p.relative(r, from: workspaceRoot)}');
      }
    }

    // Print the resolved absolute path to stdout (only useful output).
    stdout.writeln(results.first);
    return const ToolResult.success();
  }
}
