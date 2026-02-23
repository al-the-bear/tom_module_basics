/// Native v2 executor for the goto command.
///
/// Resolves a project by name, project ID, or folder name and prints
/// the absolute path to stdout.  Designed to be wrapped by a shell
/// function for `cd`:
///
/// ```bash
/// cdp() { local d; d="$(goto "$@")" && cd "$d"; }
/// ```
///
/// **Anchor-walking search strategy:**
///
/// Starting from the current directory, walks up the directory tree looking
/// for "anchors" — directories that contain a `.git` subfolder/file or a
/// `buildkit_master.yaml` file.  At each anchor, attempts to find the
/// requested project in the subtree below it.  If not found, continues up
/// to the next anchor.  Stops at the filesystem root or on permission
/// errors.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';
import 'package:tom_build_base/tom_build_base_v2.dart';

/// Executor for the `:goto` command.
///
/// Resolution order per anchor (first match wins):
/// 1. Folder basename exact match
/// 2. Project ID match (from tom_project.yaml or buildkit.yaml)
/// 3. Project name match (from tom_project.yaml or buildkit.yaml)
///
/// Anchor order: walks up from cwd, trying each anchor directory in turn
/// until the project is found or the filesystem root is reached.
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
      stderr.writeln('Usage: goto <project-name|project-id|folder>');
      stderr.writeln('');
      stderr.writeln('Resolves a project and prints its absolute path.');
      stderr.writeln('Walks up from the current directory, scanning at each');
      stderr.writeln('anchor (.git or buildkit_master.yaml) until found.');
      stderr.writeln('');
      stderr.writeln('Shell integration:');
      stderr.writeln(r'  cdp() { local d; d="$(goto "$@")" && cd "$d"; }');
      return const ToolResult.failure('No project specified');
    }

    final searchTerm = positional.first;
    final startDir = p.normalize(
      p.absolute(args.root ?? Directory.current.path),
    );
    final verbose = args.verbose;

    // Collect anchors from startDir upward.
    final walker = AnchorWalker(
      verbose: verbose,
      log: (msg) => stderr.writeln('  $msg'),
    );
    final anchors = walker.collectAnchors(startDir);

    if (anchors.isEmpty) {
      // No anchors found at all — use startDir itself as the only candidate.
      anchors.add(startDir);
    }

    // Try each anchor, closest first.
    final discovery = ProjectDiscovery(verbose: verbose);

    for (final anchor in anchors) {
      if (verbose) {
        stderr.writeln('Goto: scanning $anchor');
      }

      try {
        final results = await discovery.resolveProjectPatterns(
          searchTerm,
          basePath: anchor,
        );

        if (results.isNotEmpty) {
          if (results.length > 1) {
            stderr.writeln('Multiple matches for "$searchTerm" (using first):');
            for (final r in results) {
              stderr.writeln('  ${p.relative(r, from: anchor)}');
            }
          }

          // Print the resolved absolute path to stdout (only useful output).
          stdout.writeln(results.first);
          return const ToolResult.success();
        }

        if (verbose) {
          stderr.writeln('  not found at this anchor, trying next...');
        }
      } on FileSystemException catch (e) {
        // Permission denied or similar OS error during scanning.
        if (verbose) {
          stderr.writeln('  (skipped: ${e.message} at $anchor)');
        } else {
          stderr.writeln('  (skipped: permission denied at $anchor)');
        }
      }
    }

    stderr.writeln('Project not found: $searchTerm');
    return ToolResult.failure('Project not found: $searchTerm');
  }
}
