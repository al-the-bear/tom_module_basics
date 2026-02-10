import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';

import '../guided/guided.dart';
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
      ..addFlag('tracked-only',
          abbr: 'u',
          negatable: false,
          help: 'Only stage modified/deleted tracked files (git add -u)')
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
          help: 'Only show status, do not commit')
      ..addFlag('guide',
          abbr: 'g',
          negatable: false,
          help: 'Guided mode - step-by-step prompts');
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
    final trackedOnly = results['tracked-only'] as bool;
    final stagedOnly = results['staged-only'] as bool;
    final amend = results['amend'] as bool;
    final pushForce = results['push-force'] as bool;
    final statusOnly = results['status-only'] as bool;
    final listMode = results['list'] as bool;
    final guide = results['guide'] as bool;

    // Handle guided mode
    if (guide) {
      return await _runGuided(executionRoot, navArgs);
    }

    // Determine staging mode:
    // - default: stage everything including untracked (git add -A)
    // - trackedOnly: stage modified/deleted files (git add -u)
    // - stagedOnly: only commit what's already staged
    final addAll = !trackedOnly && !stagedOnly;
    final addUpdated = trackedOnly && !stagedOnly;

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
    print('WHAT IT DOES:');
    print('  Commits all changes in all repositories with the same message,');
    print('  then pushes to remote. Stages ALL files including new ones by default.');
    print('');
    print('COMMANDS EXECUTED:');
    print('  git add -A                    (stage all changes, default)');
    print('  git add -u                    (with --tracked-only, only modified/deleted)');
    print('  git commit -m "message"       (commit with message)');
    print('  git push origin <branch>      (push to remote, skip with --no-push)');
    print('');
    print('WHEN TO USE:');
    print('  - After completing a feature or fix across multiple repos');
    print('  - For consistent commit messages across the workspace');
    print('  - Quick commit-and-push workflow');
    print('');
    print('Traversal: Fixed to inner-first (sub-repos committed before parents).');
    print('           Do NOT specify -i/-o flags via buildkit.');
    print('');
    print('COMMAND OPTIONS:');
    print('  -m, --message <msg>   Commit message (required)');
    print('  -u, --tracked-only    Only stage modified/deleted files (git add -u)');
    print('                        Skips new untracked files');
    print('  --staged-only         Skip auto-staging, only commit what\'s already staged');
    print('  --no-push             Commit without pushing to remote');
    print('  --amend               Amend the last commit instead of new commit');
    print('  --push-force          Force push (use with caution, for amended commits)');
    print('  --status-only         Just show status, don\'t commit');
    print('');
    print('STANDARD OPTIONS:');
    print(parser.usage);
    print('');
    print('EXAMPLES:');
    print('  gitcommit -m "Add feature"         # Stage all, commit, push');
    print('  gitcommit -m "Fix bug" -u          # Only stage modified files');
    print('  gitcommit -m "msg" --no-push       # Commit but don\'t push yet');
    print('  gitcommit -m "msg" --staged-only   # Only commit pre-staged changes');
    print('  gitcommit --status-only            # Preview what would be committed');
    print('');
    print('VIA BUILDKIT:');
    print('  bk :gitcommit -m "message"');
  }

  /// Run gitcommit in guided mode.
  Future<bool> _runGuided(
    String executionRoot,
    WorkspaceNavigationArgs navArgs,
  ) async {
    final guide = GuidedMode();

    guide.header('Git Commit - Guided Mode');

    // Find repositories with changes
    final repos = _findGitRepositories(executionRoot);
    if (repos.isEmpty) {
      guide.info('No git repositories found.');
      return true;
    }

    // Get status of each repo
    final reposWithChanges = <String>[];
    for (final repo in repos) {
      if (await _hasChanges(repo, addAll: true, addUpdated: false)) {
        reposWithChanges.add(repo);
      }
    }

    if (reposWithChanges.isEmpty) {
      guide.info('All repositories are clean - nothing to commit.');
      return true;
    }

    // Show repos with changes
    print('Repositories with changes:');
    for (final repo in reposWithChanges) {
      final relPath = p.relative(repo, from: executionRoot);
      print('  • $relPath');
    }
    print('');

    // Step 1: What to stage
    final stageChoice = guide.menu(
      'What files to stage?',
      [
        'All files (git add -A) [default]',
        'Tracked files only (git add -u)',
        'Already staged only (skip staging)',
        'Select by project scope',
      ],
    );

    if (stageChoice == -1) return true; // Cancelled

    bool addUpdated = false;
    bool stagedOnly = false;
    ProjectGroupSelection? scopeSelection;

    switch (stageChoice) {
      case 0:
        // addAll is default (neither addUpdated nor stagedOnly)
        break;
      case 1:
        addUpdated = true;
      case 2:
        stagedOnly = true;
      case 3:
        // Project scope selection
        final picker = ProjectGroupPicker(
          workspaceRoot: executionRoot,
          changedProjects: reposWithChanges,
        );
        scopeSelection = picker.pick();
        if (scopeSelection == null || scopeSelection.isEmpty) {
          guide.info('Cancelled.');
          return true;
        }
        // Will stage selected paths only
    }

    // Step 2: Commit message
    print('');
    final message = guide.input(
      'Commit message',
      validator: (s) => s.trim().isNotEmpty,
      validationError: 'Message cannot be empty',
    );

    if (message.trim().isEmpty) {
      guide.error('Commit message cannot be empty.');
      return false;
    }

    // Step 3: Push options
    print('');
    final pushChoice = guide.menu(
      'Push to remote?',
      [
        'Yes, push after commit [default]',
        'No, commit only (--no-push)',
      ],
    );

    if (pushChoice == -1) return true;

    final noPush = pushChoice == 1;

    // Build command preview
    final stageCmd = stagedOnly
        ? '(skip staging)'
        : addUpdated
            ? 'git add -u'
            : 'git add -A';
    final commitCmd = 'git commit -m "$message"';
    final pushCmd = noPush ? '(skip push)' : 'git push';

    guide.showPreview(
      command: '$stageCmd && $commitCmd && $pushCmd',
      repositories: scopeSelection != null
          ? scopeSelection.projects.map((p) => p.split('/').last).toList()
          : reposWithChanges
              .map((r) => p.relative(r, from: executionRoot))
              .toList(),
    );

    // Confirm
    if (!guide.confirm('Proceed?')) {
      guide.info('Cancelled.');
      return true;
    }

    // Execute
    print('');
    final targetRepos =
        scopeSelection?.projects ?? reposWithChanges;

    // Sort by depth (inner first)
    targetRepos.sort((a, b) {
      final depthA = p.split(a).length;
      final depthB = p.split(b).length;
      if (depthA != depthB) {
        return depthB.compareTo(depthA);
      }
      return p.basename(a).compareTo(p.basename(b));
    });

    var commitCount = 0;
    var pushCount = 0;
    var allSuccess = true;

    for (final repoPath in targetRepos) {
      final relPath = p.relative(repoPath, from: executionRoot);

      // Stage
      if (!stagedOnly) {
        List<String> addArgs;

        if (scopeSelection != null) {
          // Stage specific paths based on scope
          final scopes =
              scopeSelection.scopes[repoPath] ?? [ProjectScope.complete];
          final paths = <String>[];
          for (final scope in scopes) {
            for (final folder in scope.folders) {
              final folderPath =
                  folder == '.' ? repoPath : p.join(repoPath, folder);
              if (Directory(folderPath).existsSync()) {
                paths.add(folder == '.' ? '.' : folder);
              }
            }
          }
          addArgs = ['add', ...paths];
        } else {
          addArgs = addUpdated ? ['add', '-u'] : ['add', '-A'];
        }

        if (!await _runGit(repoPath, addArgs, relPath)) {
          allSuccess = false;
          continue;
        }
      }

      // Commit
      if (!await _runGit(repoPath, ['commit', '-m', message], relPath)) {
        final status = await Process.run(
          'git',
          ['status', '--porcelain'],
          workingDirectory: repoPath,
        );
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
      guide.success('$relPath: committed');

      // Push
      if (!noPush) {
        if (!await _runGit(repoPath, ['push'], relPath)) {
          guide.warning('$relPath: push failed');
        } else {
          pushCount++;
        }
      }
    }

    // Summary
    print('');
    if (noPush) {
      guide.success('Committed $commitCount repository(ies)');
    } else {
      guide.success(
          'Committed $commitCount, pushed $pushCount repository(ies)');
    }

    return allSuccess;
  }
}
