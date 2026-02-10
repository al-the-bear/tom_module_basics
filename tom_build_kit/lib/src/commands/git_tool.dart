import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';

import 'tool_base.dart';

/// Git tool - runs arbitrary git commands across all repositories.
///
/// Executes any git command in all git repositories in the workspace.
/// Useful for commands not covered by specific tools (e.g., git log, git stash).
///
/// Requires --inner-first-git (-i) or --outer-first-git (-o) flag.
class GitTool extends ToolBase {
  @override
  String get toolKey => 'git';

  @override
  String get toolDescription =>
      'Run arbitrary git commands across all repositories';

  @override
  void addToolOptions(ArgParser parser) {
    // No tool-specific options - all args after -- are passed to git
  }

  @override
  bool isToolProject(String dirPath) {
    final gitPath = p.join(dirPath, '.git');
    return Directory(gitPath).existsSync() || File(gitPath).existsSync();
  }

  @override
  Future<bool> run(List<String> args) async {
    if (checkVersionArg(args)) return true;
    if (checkHelpArg(args)) {
      _printUsage(createParser());
      return true;
    }

    final parser = createParser();
    ArgResults results;
    WorkspaceNavigationArgs navArgs;
    String executionRoot;

    try {
      (results, navArgs, executionRoot) =
          parseArgsWithExecutionMode(parser, args);
    } on FormatException catch (e) {
      print('Error: $e');
      _printUsage(parser);
      return false;
    } on ArgumentError catch (e) {
      print('Error: $e');
      return false;
    }

    if (results['help'] as bool) {
      _printUsage(parser);
      return true;
    }

    // Require git traversal flag - no default for :git
    if (!navArgs.innerFirstGit && !navArgs.outerFirstGit) {
      print('Error: :git requires --inner-first-git (-i) or --outer-first-git (-o)');
      print('');
      print('Examples:');
      print('  bk :git -i -- log --oneline -5   # Show last 5 commits, inner repos first');
      print('  bk :git -o -- stash list         # List stashes, outer repos first');
      print('  bk :git -i -- remote -v          # Show remotes, inner repos first');
      return false;
    }

    verbose = results['verbose'] as bool;
    dryRun = results['dry-run'] as bool;
    final listMode = results['list'] as bool;

    // Get git command args (everything after parsing)
    final gitArgs = results.rest;
    if (gitArgs.isEmpty && !listMode) {
      print('Error: No git command specified');
      print('');
      print('Usage: bk :git -i|-o [options] -- <git-command> [git-args...]');
      print('');
      print('Examples:');
      print('  bk :git -i -- log --oneline -5');
      print('  bk :git -o -- stash list');
      return false;
    }

    // Find git repositories
    final repos = _findGitRepositories(executionRoot);

    if (repos.isEmpty) {
      print('No git repositories found in: $executionRoot');
      return true;
    }

    // Sort by depth based on traversal order
    final innerFirst = navArgs.innerFirstGit;
    repos.sort((a, b) {
      final depthA = p.split(a).length;
      final depthB = p.split(b).length;
      if (depthA != depthB) {
        return innerFirst
            ? depthB.compareTo(depthA) // deepest first
            : depthA.compareTo(depthB); // shallowest first
      }
      return p.basename(a).compareTo(p.basename(b));
    });

    if (listMode) {
      final orderLabel = innerFirst ? 'inner-first' : 'outer-first';
      print('Git repositories ($orderLabel):');
      for (final repo in repos) {
        print('  ${p.relative(repo, from: executionRoot)}');
      }
      return true;
    }

    // Process each repository
    var allSuccess = true;
    var processedCount = 0;

    for (final repoPath in repos) {
      final relPath = p.relative(repoPath, from: executionRoot);
      final displayPath = relPath.isEmpty ? '.' : relPath;

      if (dryRun) {
        print('[DRY RUN] $displayPath: git ${gitArgs.join(' ')}');
        processedCount++;
        continue;
      }

      if (verbose) {
        print('$displayPath: git ${gitArgs.join(' ')}');
      }

      final result = await Process.run('git', gitArgs, workingDirectory: repoPath);

      // Print output with repo prefix if multiple repos
      final hasOutput = result.stdout.toString().trim().isNotEmpty ||
          result.stderr.toString().trim().isNotEmpty;

      if (hasOutput || result.exitCode != 0) {
        print('[$displayPath]');
        if (result.stdout.toString().trim().isNotEmpty) {
          print(result.stdout.toString().trimRight());
        }
        if (result.stderr.toString().trim().isNotEmpty) {
          stderr.write(result.stderr);
        }
        if (result.exitCode != 0) {
          print('  Exit code: ${result.exitCode}');
          allSuccess = false;
        }
        print('');
      }

      processedCount++;
    }

    // Summary
    final orderLabel = innerFirst ? 'inner-first' : 'outer-first';
    print('Ran git ${gitArgs.first} on $processedCount repository(ies) ($orderLabel)');

    return allSuccess;
  }

  List<String> _findGitRepositories(String rootPath) {
    final repos = <String>[];
    final rootDir = Directory(rootPath);

    void scanDirectory(Directory dir) {
      // Check if this directory is a git repo
      final gitPath = p.join(dir.path, '.git');
      if (Directory(gitPath).existsSync() || File(gitPath).existsSync()) {
        repos.add(dir.path);
      }

      // Scan subdirectories
      try {
        for (final entity in dir.listSync(followLinks: false)) {
          if (entity is Directory) {
            // Skip hidden directories (except .git which we already checked)
            final name = p.basename(entity.path);
            if (name.startsWith('.')) continue;

            // Skip excluded directories
            if (_isExcludedDirectory(name)) continue;

            // Check for buildkit_skip.yaml
            final skipFile = File(p.join(entity.path, kBuildkitSkipYaml));
            if (skipFile.existsSync()) continue;

            scanDirectory(entity);
          }
        }
      } catch (e) {
        // Ignore permission errors etc.
      }
    }

    scanDirectory(rootDir);
    return repos;
  }

  bool _isExcludedDirectory(String name) {
    const excluded = {
      'node_modules',
      'build',
      '.dart_tool',
      '.pub-cache',
      '.gradle',
      '__pycache__',
    };
    return excluded.contains(name);
  }

  void _printUsage(ArgParser parser) {
    printUsageHeader();
    print('');
    print('Runs any git command across all repositories in the workspace.');
    print('Requires -i (inner-first) or -o (outer-first) traversal flag.');
    print('');
    print('Options:');
    print(parser.usage);
    print('');
    print('Git Command:');
    print('  Everything after -- is passed to git as the command.');
    print('');
    print('Examples:');
    print('  git -i -- log --oneline -5        # Last 5 commits per repo');
    print('  git -o -- stash list              # List stashes in each repo');
    print('  git -i -- remote -v               # Show remotes');
    print('  git -i --list                     # List repos without running command');
    print('  git -i -n -- fetch                # Dry-run fetch');
    print('');
    print('Via buildkit:');
    print('  bk :git -i -- log --oneline -5');
    print('  bk :git -o -- branch -a');
    printUsageFooter();
  }
}
