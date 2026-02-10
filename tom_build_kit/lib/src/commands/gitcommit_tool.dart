import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';

import 'tool_base.dart';

/// Git commit tool - commits and pushes all repositories with the same message.
///
/// Commits all staged changes in each repository using the same commit message,
/// then optionally pushes to remote.
///
/// Requires --inner-first-git (-i) flag.
class GitCommitTool extends ToolBase {
  @override
  String get toolKey => 'gitcommit';

  @override
  String get toolDescription =>
      'Commit and push all repositories with the same message';

  /// If true, auto-inject --inner-first-git when running standalone.
  bool autoInnerFirst = false;

  @override
  void addToolOptions(ArgParser parser) {
    parser
      ..addOption('message',
          abbr: 'm',
          help: 'Commit message (required)')
      ..addFlag('no-push',
          negatable: false,
          help: 'Skip pushing to remote')
      ..addFlag('add-all',
          abbr: 'A',
          negatable: false,
          help: 'Stage ALL changes including untracked (git add -A)')
      ..addFlag('staged-only',
          negatable: false,
          help: 'Only commit already-staged changes (skip auto-staging)')
      ..addFlag('amend',
          negatable: false,
          help: 'Amend the last commit (use with --no-push)')
      ..addFlag('push-force',
          negatable: false,
          help: 'Force push (use with caution)')
      ..addFlag('status-only',
          negatable: false,
          help: 'Only show status, do not commit');
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

    // Auto-inject --inner-first-git for standalone binary
    var effectiveArgs = args;
    if (autoInnerFirst && !_hasGitTraversalFlag(args)) {
      effectiveArgs = ['--inner-first-git', ...args];
    }

    final parser = createParser();
    ArgResults results;
    WorkspaceNavigationArgs navArgs;
    String executionRoot;

    try {
      (results, navArgs, executionRoot) = parseArgsWithExecutionMode(parser, effectiveArgs);
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

    // Require --inner-first-git
    if (!navArgs.innerFirstGit) {
      print('Error: gitcommit requires --inner-first-git (-i)');
      print('');
      print('This ensures sub-repositories are committed before parent repos,');
      print('preventing dirty submodule references.');
      print('');
      print('Example:');
      print('  gitcommit -i -m "Your commit message"');
      return false;
    }

    verbose = results['verbose'] as bool;
    dryRun = results['dry-run'] as bool;
    
    final message = results['message'] as String?;
    final noPush = results['no-push'] as bool;
    final addAll = results['add-all'] as bool;
    final stagedOnly = results['staged-only'] as bool;
    final amend = results['amend'] as bool;
    final pushForce = results['push-force'] as bool;
    final statusOnly = results['status-only'] as bool;
    final listMode = results['list'] as bool;

    // Determine staging mode:
    // - addAll: stage everything including untracked (git add -A)
    // - stagedOnly: only commit what's already staged
    // - default: stage modified/deleted files (git add -u)
    final addUpdated = !addAll && !stagedOnly;

    // Validate message requirement
    if (!statusOnly && !listMode && message == null && !amend) {
      print('Error: -m/--message is required');
      print('');
      print('Example:');
      print('  gitcommit -i -m "Your commit message"');
      return false;
    }

    // Find git repositories
    final repos = _findGitRepositories(executionRoot);
    
    if (repos.isEmpty) {
      print('No git repositories found in: $executionRoot');
      return true;
    }

    // Sort by depth (inner first)
    repos.sort((a, b) {
      final depthA = p.split(a).length;
      final depthB = p.split(b).length;
      if (depthA != depthB) {
        return depthB.compareTo(depthA); // deepest first
      }
      return p.basename(a).compareTo(p.basename(b));
    });

    if (listMode) {
      print('Git repositories (inner-first):');
      for (final repo in repos) {
        print('  ${p.relative(repo, from: executionRoot)}');
      }
      return true;
    }

    if (statusOnly) {
      print('Repository status (inner-first order):');
      for (final repoPath in repos) {
        await _printRepoStatus(repoPath, executionRoot);
      }
      return true;
    }

    // Process each repository
    var allSuccess = true;
    var commitCount = 0;
    var pushCount = 0;

    for (final repoPath in repos) {
      final relPath = p.relative(repoPath, from: executionRoot);
      
      // Check if there are changes to commit
      final hasChanges = await _hasChanges(repoPath, addAll: addAll, addUpdated: addUpdated);
      
      if (!hasChanges && !amend) {
        if (verbose) {
          print('$relPath: no changes');
        }
        continue;
      }

      // Stage changes if requested
      if (addAll || addUpdated) {
        final addFlag = addAll ? '-A' : '-u';
        if (!await _runGit(repoPath, ['add', addFlag], relPath)) {
          allSuccess = false;
          continue;
        }
      }

      // Commit
      final commitArgs = amend
          ? ['commit', '--amend', '--no-edit']
          : ['commit', '-m', message!];
      
      if (!await _runGit(repoPath, commitArgs, relPath)) {
        // Check if it's just "nothing to commit"
        final status = await Process.run('git', ['status', '--porcelain'],
            workingDirectory: repoPath);
        if (status.stdout.toString().trim().isEmpty) {
          if (verbose) {
            print('$relPath: nothing to commit');
          }
          continue;
        }
        allSuccess = false;
        continue;
      }
      
      commitCount++;
      print('$relPath: committed');

      // Push
      if (!noPush) {
        final pushArgs = pushForce 
            ? ['push', '--force-with-lease']
            : ['push'];
        
        if (!await _runGit(repoPath, pushArgs, relPath)) {
          print('  Warning: push failed for $relPath');
          // Don't fail the whole operation for push failures
        } else {
          pushCount++;
          if (verbose) {
            print('$relPath: pushed');
          }
        }
      }
    }

    // Summary
    print('');
    if (noPush) {
      print('Committed $commitCount repository(ies)');
    } else {
      print('Committed $commitCount, pushed $pushCount repository(ies)');
    }

    return allSuccess;
  }

  bool _hasGitTraversalFlag(List<String> args) {
    return args.contains('-i') ||
           args.contains('--inner-first-git') ||
           args.contains('-o') ||
           args.contains('--outer-first-git');
  }

  List<String> _findGitRepositories(String rootPath) {
    final repos = <String>[];
    final rootDir = Directory(rootPath);

    if (!rootDir.existsSync()) return repos;

    bool isGitRepo(String dirPath) {
      final gitPath = p.join(dirPath, '.git');
      return Directory(gitPath).existsSync() || File(gitPath).existsSync();
    }

    if (isGitRepo(rootPath)) {
      repos.add(rootPath);
    }

    final searchDirs = <String>[rootPath];
    final xternalDir = Directory(p.join(rootPath, 'xternal'));
    if (xternalDir.existsSync()) {
      searchDirs.add(xternalDir.path);
    }
    final xternalAppsDir = Directory(p.join(rootPath, 'xternal_apps'));
    if (xternalAppsDir.existsSync()) {
      searchDirs.add(xternalAppsDir.path);
    }

    for (final searchDir in searchDirs) {
      try {
        for (final entity in Directory(searchDir).listSync()) {
          if (entity is Directory && entity.path != rootPath) {
            if (isGitRepo(entity.path)) {
              repos.add(entity.path);
            }
          }
        }
      } catch (_) {
        // Permission errors, etc.
      }
    }

    return repos;
  }

  Future<bool> _hasChanges(String repoPath, {bool addAll = false, bool addUpdated = false}) async {
    try {
      if (addAll) {
        // Check for any changes (staged, unstaged, untracked)
        final result = await Process.run('git', ['status', '--porcelain'],
            workingDirectory: repoPath);
        return result.stdout.toString().trim().isNotEmpty;
      } else if (addUpdated) {
        // Check for modified/deleted files only
        final result = await Process.run('git', ['status', '--porcelain'],
            workingDirectory: repoPath);
        final lines = result.stdout.toString().split('\n');
        return lines.any((line) => line.isNotEmpty && !line.startsWith('??'));
      } else {
        // Check for staged changes only
        final result = await Process.run('git', ['diff', '--cached', '--quiet'],
            workingDirectory: repoPath);
        return result.exitCode != 0;
      }
    } catch (_) {
      return false;
    }
  }

  Future<void> _printRepoStatus(String repoPath, String wsRoot) async {
    final relPath = p.relative(repoPath, from: wsRoot);
    
    try {
      final result = await Process.run('git', ['status', '--porcelain'],
          workingDirectory: repoPath);
      final lines = result.stdout.toString().split('\n').where((l) => l.isNotEmpty);
      
      if (lines.isEmpty) {
        print('$relPath: clean');
      } else {
        print('$relPath: ${lines.length} file(s) changed');
        for (final line in lines) {
          print('  $line');
        }
      }
    } catch (e) {
      print('$relPath: error reading status');
    }
  }

  Future<bool> _runGit(String repoPath, List<String> args, String relPath) async {
    if (dryRun) {
      print('[DRY RUN] $relPath: git ${args.join(' ')}');
      return true;
    }

    if (verbose) {
      print('$relPath: git ${args.join(' ')}');
    }

    try {
      final result = await Process.run('git', args, workingDirectory: repoPath);
      
      if (result.exitCode != 0) {
        final stderr = result.stderr.toString().trim();
        if (stderr.isNotEmpty && verbose) {
          print('  $stderr');
        }
        return false;
      }
      return true;
    } catch (e) {
      print('$relPath: git error - $e');
      return false;
    }
  }

  void _printUsage(ArgParser parser) {
    printUsageHeader();
    print('');
    print('Traversal: Fixed to inner-first (sub-repos committed before parents).');
    print('           Do NOT specify -i/-o flags via buildkit.');
    print('');
    print('Default behavior:');
    print('  - Stages modified/deleted tracked files (git add -u)');
    print('  - Commits with provided message');
    print('  - Pushes to remote');
    print('');
    print('Options:');
    print(parser.usage);
    print('');
    print('Common workflows:');
    print('  gitcommit -m "message"            # Stage modified + commit + push');
    print('  gitcommit -A -m "message"         # Stage ALL (incl. untracked) + commit');
    print('  gitcommit -m "msg" --no-push      # Commit without pushing');
    print('  gitcommit --staged-only -m "msg"  # Only commit pre-staged changes');
    print('  gitcommit --status-only           # Just show status');
    print('');
    print('Via buildkit:');
    print('  bk :gitcommit -m "message"');
  }
}
