import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';

import 'tool_base.dart';

/// Git unstash tool - restores stashed changes across all repositories.
///
/// Pops or applies stashed changes. Warns loudly about merge conflicts.
class GitUnstashTool extends ToolBase {
  @override
  String get toolKey => 'gitunstash';

  @override
  String get toolDescription =>
      'Restore stashed changes across all repositories';

  /// If true, auto-inject --outer-first-git when running standalone.
  bool autoOuterFirst = false;

  @override
  void addToolOptions(ArgParser parser) {
    parser
      ..addFlag('apply',
          negatable: false,
          help: 'Apply stash but keep it in stack (default: pop)')
      ..addOption('stash',
          abbr: 's',
          help: 'Specific stash to restore (e.g., stash@{0})')
      ..addFlag('list-stashes',
          abbr: 'l',
          negatable: false,
          help: 'List stashes in each repository')
      ..addFlag('drop',
          negatable: false,
          help: 'Drop stash without applying (use with -s)')
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
      print('Error: gitunstash requires --outer-first-git (-o) or --inner-first-git (-i)');
      print('');
      print('Recommended: --outer-first-git (-o)');
      print('  Restore parent repos first to match gitstash order.');
      return false;
    }

    verbose = results['verbose'] as bool;
    dryRun = results['dry-run'] as bool;
    final applyOnly = results['apply'] as bool;
    final specificStash = results['stash'] as String?;
    final listStashes = results['list-stashes'] as bool;
    final dropStash = results['drop'] as bool;
    final listMode = results['list'] as bool;

    var repos = _findGitRepositories(executionRoot);

    // Apply modules filter if specified
    if (navArgs.modules.isNotEmpty) {
      final wsRoot = findWorkspaceRoot(executionRoot);
      repos = ProjectDiscovery.applyModulesFilter(
        repos,
        navArgs.modules,
        wsRoot,
        verbose: verbose,
        log: (msg) => print(msg),
      );
    }
    
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

    // Drop stash mode
    if (dropStash) {
      return await _dropStashes(repos, executionRoot, specificStash);
    }

    // Unstash mode
    var allSuccess = true;
    var restoredCount = 0;
    var noStashCount = 0;
    var conflictCount = 0;

    for (final repoPath in repos) {
      final relPath = p.relative(repoPath, from: executionRoot);
      
      // Check if there are stashes
      final hasStashes = await _hasStashes(repoPath);
      if (!hasStashes) {
        if (verbose) {
          print('$relPath: no stashes');
        }
        noStashCount++;
        continue;
      }

      // Build stash command
      final stashArgs = <String>['stash'];
      if (applyOnly) {
        stashArgs.add('apply');
      } else {
        stashArgs.add('pop');
      }
      if (specificStash != null) {
        stashArgs.add(specificStash);
      }

      final result = await _runGitWithOutput(repoPath, stashArgs, relPath);
      
      if (!result.success) {
        allSuccess = false;
        if (result.hasConflicts) {
          conflictCount++;
          print('');
          print('*** WARNING: MERGE CONFLICT in $relPath ***');
          print('');
          print('The stash could not be cleanly applied. You need to:');
          print('  1. Resolve conflicts in the affected files');
          print('  2. Stage resolved files: git add <file>');
          print('  3. If you used pop, the stash is NOT dropped (still in stack)');
          print('');
        }
        continue;
      }
      restoredCount++;
    }

    print('');
    if (conflictCount > 0) {
      print('!!! $conflictCount REPO(S) HAD MERGE CONFLICTS - SEE WARNINGS ABOVE !!!');
      print('');
    }
    print('Restored stash in $restoredCount repo(s), $noStashCount repo(s) had no stashes');
    
    if (conflictCount > 0) {
      print('');
      print('Tip: Use "git stash show -p" to see stash contents');
      print('     Use "git checkout --ours/--theirs <file>" to resolve conflicts');
    }

    return allSuccess;
  }

  Future<bool> _dropStashes(List<String> repos, String executionRoot, String? specificStash) async {
    var droppedCount = 0;
    var allSuccess = true;

    for (final repoPath in repos) {
      final relPath = p.relative(repoPath, from: executionRoot);
      
      final hasStashes = await _hasStashes(repoPath);
      if (!hasStashes) {
        if (verbose) print('$relPath: no stashes');
        continue;
      }

      final stashArgs = ['stash', 'drop'];
      if (specificStash != null) {
        stashArgs.add(specificStash);
      }

      if (!await _runGit(repoPath, stashArgs, relPath)) {
        allSuccess = false;
        continue;
      }
      droppedCount++;
    }

    print('');
    print('Dropped stash in $droppedCount repo(s)');
    return allSuccess;
  }

  bool _hasGitTraversalFlag(List<String> args) {
    return args.contains('-i') || args.contains('--inner-first-git') ||
           args.contains('-o') || args.contains('--outer-first-git');
  }

  Future<bool> _hasStashes(String repoPath) async {
    try {
      final result = await Process.run(
        'git', ['stash', 'list'],
        workingDirectory: repoPath,
      );
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
      return true;
    } catch (e) {
      print('$relPath: git error - $e');
      return false;
    }
  }

  Future<({bool success, bool hasConflicts})> _runGitWithOutput(
    String repoPath, 
    List<String> args, 
    String relPath,
  ) async {
    if (dryRun) {
      print('[DRY RUN] $relPath: git ${args.join(' ')}');
      return (success: true, hasConflicts: false);
    }
    
    print('$relPath: git ${args.join(' ')}');
    
    try {
      final result = await Process.run('git', args, workingDirectory: repoPath);
      
      final stdout = result.stdout.toString();
      final stderr = result.stderr.toString();
      final output = '$stdout\n$stderr'.toLowerCase();
      
      final hasConflicts = output.contains('conflict') || 
                          output.contains('merge conflict') ||
                          output.contains('unmerged');
      
      if (result.exitCode != 0) {
        if (stderr.trim().isNotEmpty) {
          print('  $stderr');
        }
        return (success: false, hasConflicts: hasConflicts);
      }
      
      if (verbose && stdout.trim().isNotEmpty) {
        print('  $stdout');
      }
      
      return (success: true, hasConflicts: false);
    } catch (e) {
      print('$relPath: git error - $e');
      return (success: false, hasConflicts: false);
    }
  }

  void _printUsage(ArgParser parser) {
    printUsageHeader();
    print('');
    print('WHAT IT DOES:');
    print('  Restores stashed changes in all repositories.');
    print('  Default behavior: "pop" (apply and remove from stack).');
    print('');
    print('COMMANDS EXECUTED:');
    print('  git stash pop                (default, apply and remove)');
    print('  git stash apply              (with --apply, keep in stack)');
    print('  git stash drop               (with --drop, remove without apply)');
    print('');
    print('WHEN TO USE:');
    print('  - After gitstash, to restore your saved work');
    print('  - After pulling/merging, to reapply local changes');
    print('  - When returning to previous context');
    print('');
    print('Traversal: Fixed to outer-first (reverse of gitstash order).');
    print('           Do NOT specify -i/-o flags via buildkit.');
    print('');
    print('COMMAND OPTIONS:');
    print('  --apply               Apply stash but keep it in stack.');
    print('                        Useful if you might need it again.');
    print('  -s, --stash <ref>     Restore specific stash (e.g., stash@{1}).');
    print('                        Default: latest stash (stash@{0}).');
    print('  -l, --list-stashes    List stashes in each repo.');
    print('  --drop                Drop stash without applying (with -s).');
    print('');
    print('MERGE CONFLICTS:');
    print('  If stashed changes conflict with current state:');
    print('  - A loud warning is shown');
    print('  - You must manually resolve conflicts');
    print('  - With pop, the stash is NOT removed if conflicts occur');
    print('');
    print('STANDARD OPTIONS:');
    print(parser.usage);
    print('');
    print('EXAMPLES:');
    print('  gitunstash                     # Pop latest stash (apply + remove)');
    print('  gitunstash --apply             # Apply but keep stash');
    print('  gitunstash -s stash@{1}        # Pop second-latest stash');
    print('  gitunstash -l                  # List all stashes');
    print('  gitunstash --drop              # Drop latest stash without applying');
    print('');
    print('VIA BUILDKIT:');
    print('  bk :gitunstash');
  }
}
