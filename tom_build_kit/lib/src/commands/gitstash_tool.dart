import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';

import 'tool_base.dart';

/// Git stash tool - stashes uncommitted changes across all repositories.
///
/// Safely saves uncommitted work to the stash stack, allowing you to
/// switch branches or pull changes without committing incomplete work.
class GitStashTool extends ToolBase {
  @override
  String get toolKey => 'gitstash';

  @override
  String get toolDescription =>
      'Stash uncommitted changes across all repositories';

  /// If true, auto-inject --inner-first-git when running standalone.
  bool autoInnerFirst = false;

  @override
  void addToolOptions(ArgParser parser) {
    parser
      ..addOption('message',
          abbr: 'm',
          help: 'Stash message (helps identify stash later)')
      ..addFlag('include-untracked',
          abbr: 'u',
          negatable: false,
          help: 'Also stash untracked files')
      ..addFlag('keep-index',
          negatable: false,
          help: 'Keep staged changes in the index')
      ..addFlag('list-stashes',
          abbr: 'l',
          negatable: false,
          help: 'List stashes in each repository')
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

    if (!navArgs.innerFirstGit && !navArgs.outerFirstGit) {
      print('Error: gitstash requires --inner-first-git (-i) or --outer-first-git (-o)');
      print('');
      print('Recommended: --inner-first-git (-i)');
      print('  Stash sub-repos first to maintain order for unstashing.');
      return false;
    }

    verbose = results['verbose'] as bool;
    dryRun = results['dry-run'] as bool;
    final message = results['message'] as String?;
    final includeUntracked = results['include-untracked'] as bool;
    final keepIndex = results['keep-index'] as bool;
    final listStashes = results['list-stashes'] as bool;
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

    // List stashes mode
    if (listStashes) {
      for (final repoPath in repos) {
        final relPath = p.relative(repoPath, from: executionRoot);
        final stashes = await _getStashList(repoPath);
        if (stashes.isEmpty) {
          if (verbose) print('$relPath: no stashes');
          continue;
        }
        print('$relPath:');
        for (final stash in stashes) {
          print('  $stash');
        }
      }
      return true;
    }

    // Stash mode
    var allSuccess = true;
    var stashedCount = 0;
    var noChangesCount = 0;

    for (final repoPath in repos) {
      final relPath = p.relative(repoPath, from: executionRoot);
      
      // Check if there are changes to stash
      final hasChanges = await _hasUncommittedChanges(repoPath, includeUntracked);
      if (!hasChanges) {
        if (verbose) {
          print('$relPath: nothing to stash');
        }
        noChangesCount++;
        continue;
      }

      // Build stash command
      final stashArgs = ['stash', 'push'];
      if (message != null) {
        stashArgs.addAll(['-m', message]);
      }
      if (includeUntracked) {
        stashArgs.add('--include-untracked');
      }
      if (keepIndex) {
        stashArgs.add('--keep-index');
      }

      if (!await _runGit(repoPath, stashArgs, relPath)) {
        allSuccess = false;
        continue;
      }
      stashedCount++;
    }

    print('');
    print('Stashed changes in $stashedCount repo(s), $noChangesCount repo(s) had no changes');

    return allSuccess;
  }

  bool _hasGitTraversalFlag(List<String> args) {
    return args.contains('-i') || args.contains('--inner-first-git') ||
           args.contains('-o') || args.contains('--outer-first-git');
  }

  Future<bool> _hasUncommittedChanges(String repoPath, bool includeUntracked) async {
    try {
      final args = includeUntracked 
          ? ['status', '--porcelain']
          : ['status', '--porcelain', '--untracked-files=no'];
      final result = await Process.run('git', args, workingDirectory: repoPath);
      return result.stdout.toString().trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> _getStashList(String repoPath) async {
    try {
      final result = await Process.run(
        'git', ['stash', 'list'],
        workingDirectory: repoPath,
      );
      if (result.exitCode != 0) return [];
      
      final output = result.stdout.toString().trim();
      if (output.isEmpty) return [];
      return output.split('\n');
    } catch (_) {
      return [];
    }
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
            final name = p.basename(entity.path);
            if (name.startsWith('.')) continue;
            
            final skipFile = File(p.join(entity.path, kBuildkitSkipYaml));
            if (skipFile.existsSync()) continue;
            
            if (isGitRepo(entity.path)) repos.add(entity.path);
          }
        }
      } catch (_) {}
    }

    return repos;
  }

  Future<bool> _runGit(String repoPath, List<String> args, String relPath) async {
    if (dryRun) {
      print('[DRY RUN] $relPath: git ${args.join(' ')}');
      return true;
    }
    
    print('$relPath: git ${args.join(' ')}');
    
    try {
      final result = await Process.run('git', args, workingDirectory: repoPath);
      if (result.exitCode != 0) {
        final stderr = result.stderr.toString().trim();
        if (stderr.isNotEmpty) print('  Error: $stderr');
        return false;
      }
      
      final stdout = result.stdout.toString().trim();
      if (stdout.isNotEmpty && verbose) {
        print('  $stdout');
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
    print('  Saves uncommitted changes to the stash stack in all repositories.');
    print('  Changes are removed from working tree but can be restored later.');
    print('');
    print('COMMANDS EXECUTED:');
    print('  git stash push                           (save changes)');
    print('  git stash push -m "message"              (with -m, named stash)');
    print('  git stash push --include-untracked       (with -u, include new files)');
    print('  git stash list                           (with -l, show stashes)');
    print('');
    print('WHEN TO USE:');
    print('  - Need to switch branches but have uncommitted work');
    print('  - Want to pull changes but have local modifications');
    print('  - Save work-in-progress without committing');
    print('  - Quickly switch context for urgent fix');
    print('');
    print('Traversal: Fixed to inner-first (sub-repos stashed before parents).');
    print('           Do NOT specify -i/-o flags via buildkit.');
    print('');
    print('COMMAND OPTIONS:');
    print('  -m, --message <msg>     Name your stash for easy identification.');
    print('                          Strongly recommended for clarity.');
    print("  -u, --include-untracked Include new files that aren't tracked yet.");
    print('                          Without this, only modified tracked files are stashed.');
    print('  --keep-index            Keep staged changes in the index.');
    print('                          Stash only unstaged changes.');
    print('  -l, --list-stashes      Show stash list for each repo instead of stashing.');
    print('');
    print('RESTORING STASHED CHANGES:');
    print('  Use gitunstash to restore stashed changes.');
    print('  Stashes are a stack: latest stash is restored first (LIFO).');
    print('');
    print('STANDARD OPTIONS:');
    print(parser.usage);
    print('');
    print('EXAMPLES:');
    print('  gitstash                               # Stash all changes');
    print('  gitstash -m "WIP: feature X"           # Stash with description');
    print('  gitstash -m "WIP" -u                   # Include untracked files');
    print('  gitstash -l                            # List all stashes');
    print('  gitstash --keep-index                  # Only stash unstaged changes');
    print('');
    print('VIA BUILDKIT:');
    print('  bk :gitstash -m "WIP"');
  }
}
