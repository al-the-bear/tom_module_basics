import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';

import 'tool_base.dart';

/// Git sync tool - syncs all repositories with remote (fetch + rebase/merge).
///
/// Uses outer-first traversal because parent repos should be synced first
/// to get updated submodule references before syncing submodules.
class GitSyncTool extends ToolBase {
  @override
  String get toolKey => 'gitsync';

  @override
  String get toolDescription =>
      'Sync all repositories with remote (fetch + merge/rebase)';

  /// If true, auto-inject --outer-first-git when running standalone.
  bool autoOuterFirst = false;

  @override
  void addToolOptions(ArgParser parser) {
    parser
      ..addFlag('rebase',
          negatable: false,
          help: 'Rebase instead of merge')
      ..addFlag('no-stash',
          negatable: false,
          help: 'Skip stashing uncommitted changes (stash is default)')
      ..addFlag('no-push',
          negatable: false,
          help: 'Skip pushing after sync (push is default)')
      ..addFlag('prune',
          negatable: false,
          help: 'Prune stale remote tracking branches')
      ..addOption('remote',
          defaultsTo: 'origin',
          help: 'Remote name')
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

    var effectiveArgs = args;
    if (autoOuterFirst && !_hasGitTraversalFlag(args)) {
      effectiveArgs = ['--outer-first-git', ...args];
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

    if (!navArgs.innerFirstGit && !navArgs.outerFirstGit) {
      print('Error: gitsync requires --outer-first-git (-o) or --inner-first-git (-i)');
      print('');
      print('Recommended: --outer-first-git (-o)');
      print('  Sync parent repos first before syncing submodules.');
      return false;
    }

    verbose = results['verbose'] as bool;
    dryRun = results['dry-run'] as bool;
    final useRebase = results['rebase'] as bool;
    final useStash = !(results['no-stash'] as bool);
    final doPush = !(results['no-push'] as bool);
    final doPrune = results['prune'] as bool;
    final remote = results['remote'] as String;
    final listMode = results['list'] as bool;

    final repos = _findGitRepositories(executionRoot);
    
    if (repos.isEmpty) {
      print('No git repositories found in: $executionRoot');
      return true;
    }

    repos.sort((a, b) {
      final depthA = p.split(a).length;
      final depthB = p.split(b).length;
      if (depthA != depthB) {
        return navArgs.innerFirstGit
            ? depthB.compareTo(depthA)
            : depthA.compareTo(depthB);
      }
      return p.basename(a).compareTo(p.basename(b));
    });

    if (listMode) {
      print('Git repositories:');
      for (final repo in repos) {
        print('  ${p.relative(repo, from: executionRoot)}');
      }
      return true;
    }

    var allSuccess = true;
    var syncCount = 0;

    for (final repoPath in repos) {
      final relPath = p.relative(repoPath, from: executionRoot);
      var stashed = false;

      // Stash if requested and there are changes
      if (useStash) {
        final hasChanges = await _hasUncommittedChanges(repoPath);
        if (hasChanges) {
          if (!await _runGit(repoPath, ['stash', 'push', '-m', 'gitsync auto-stash'], relPath)) {
            allSuccess = false;
            continue;
          }
          stashed = true;
        }
      }

      // Fetch
      final fetchArgs = ['fetch', remote];
      if (doPrune) fetchArgs.add('--prune');
      if (!await _runGit(repoPath, fetchArgs, relPath)) {
        if (stashed) await _runGit(repoPath, ['stash', 'pop'], relPath);
        allSuccess = false;
        continue;
      }

      // Merge or rebase
      final syncArgs = useRebase
          ? ['rebase', '$remote/${await _getDefaultBranch(repoPath)}']
          : ['merge', '$remote/${await _getDefaultBranch(repoPath)}', '--ff-only'];
      
      if (!await _runGit(repoPath, syncArgs, relPath)) {
        if (stashed) await _runGit(repoPath, ['stash', 'pop'], relPath);
        allSuccess = false;
        continue;
      }

      // Push if requested
      if (doPush) {
        await _runGit(repoPath, ['push', remote], relPath);
      }

      // Pop stash
      if (stashed) {
        await _runGit(repoPath, ['stash', 'pop'], relPath);
      }

      syncCount++;
    }

    print('');
    print('Synced $syncCount repository(ies)');

    return allSuccess;
  }

  bool _hasGitTraversalFlag(List<String> args) {
    return args.contains('-i') || args.contains('--inner-first-git') ||
           args.contains('-o') || args.contains('--outer-first-git');
  }

  List<String> _findGitRepositories(String rootPath) {
    final repos = <String>[];
    final rootDir = Directory(rootPath);
    if (!rootDir.existsSync()) return repos;

    bool isGitRepo(String dirPath) {
      final gitPath = p.join(dirPath, '.git');
      return Directory(gitPath).existsSync() || File(gitPath).existsSync();
    }

    if (isGitRepo(rootPath)) repos.add(rootPath);

    final searchDirs = <String>[rootPath];
    for (final subdir in ['xternal', 'xternal_apps']) {
      final dir = Directory(p.join(rootPath, subdir));
      if (dir.existsSync()) searchDirs.add(dir.path);
    }

    for (final searchDir in searchDirs) {
      try {
        for (final entity in Directory(searchDir).listSync()) {
          if (entity is Directory && entity.path != rootPath) {
            if (isGitRepo(entity.path)) repos.add(entity.path);
          }
        }
      } catch (_) {}
    }
    return repos;
  }

  Future<bool> _hasUncommittedChanges(String repoPath) async {
    try {
      final result = await Process.run('git', ['status', '--porcelain'],
          workingDirectory: repoPath);
      return result.stdout.toString().trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<String> _getDefaultBranch(String repoPath) async {
    try {
      final result = await Process.run(
        'git', ['rev-parse', '--abbrev-ref', 'HEAD'],
        workingDirectory: repoPath,
      );
      return result.stdout.toString().trim();
    } catch (_) {
      return 'main';
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
        if (stderr.isNotEmpty) print('$relPath: $stderr');
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
    print('  Full sync: stash local changes, fetch+merge from remote, push, pop stash.');
    print('  A complete round-trip sync of all repositories in one command.');
    print('');
    print('COMMANDS EXECUTED:');
    print('  git stash push -m "gitsync auto-stash"  (if uncommitted changes exist)');
    print('  git fetch origin                         (get remote changes)');
    print('  git merge origin/<branch>                (or --rebase for rebase)');
    print('  git push origin <branch>                 (push local commits)');
    print('  git stash pop                            (restore stashed changes)');
    print('');
    print('WHEN TO USE:');
    print('  - At start of work session (sync with team)');
    print('  - Before ending work (push your changes)');
    print('  - Periodic sync during long work sessions');
    print('');
    print('Traversal: Fixed to outer-first (parent repos synced before sub-repos).');
    print('           Do NOT specify -i/-o flags via buildkit.');
    print('');
    print('COMMAND OPTIONS:');
    print('  --rebase        Rebase local commits instead of merge.');
    print('                  Creates linear history, but may require conflict resolution.');
    print('  --no-stash      Don\'t stash uncommitted changes before sync.');
    print('                  Sync will fail if you have uncommitted changes.');
    print('  --no-push       Skip pushing after pulling. Just get remote changes.');
    print('  --prune         Remove stale remote-tracking branches.');
    print('                  Cleans up local refs to branches deleted on remote.');
    print('  --remote <name> Remote to sync with (default: origin)');
    print('');
    print('DEFAULT BEHAVIOR:');
    print('  - Stashes uncommitted changes (auto-restored after sync)');
    print('  - Fetches and merges remote changes');
    print('  - Pushes local commits to remote');
    print('  - Does NOT prune (keeps local backup of deleted remote branches)');
    print('');
    print('STANDARD OPTIONS:');
    print(parser.usage);
    print('');
    print('EXAMPLES:');
    print('  gitsync                    # Full sync (stash, fetch, merge, push, pop)');
    print('  gitsync --rebase           # Sync with rebase instead of merge');
    print('  gitsync --no-push          # Just pull, don\'t push yet');
    print('  gitsync --prune            # Also clean up stale remote branches');
    print('');
    print('VIA BUILDKIT:');
    print('  bk :gitsync');
  }
}
