import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';

import 'tool_base.dart';

/// Git prune tool - removes stale remote-tracking branches.
///
/// Cleans up local references to branches that have been deleted on the remote.
/// Safe operation: only removes local tracking refs, not actual branches.
class GitPruneTool extends ToolBase {
  @override
  String get toolKey => 'gitprune';

  @override
  String get toolDescription =>
      'Remove stale remote-tracking branches';

  /// If true, auto-inject --outer-first-git when running standalone.
  bool autoOuterFirst = false;

  @override
  void addToolOptions(ArgParser parser) {
    parser
      ..addFlag('dry-run-git',
          negatable: false,
          help: 'Show what would be pruned without removing')
      ..addOption('remote',
          defaultsTo: 'origin',
          help: 'Remote name to prune')
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
      print('Error: gitprune requires --outer-first-git (-o) or --inner-first-git (-i)');
      print('');
      print('Recommended: --outer-first-git (-o)');
      print('  Prune parent repos first.');
      return false;
    }

    verbose = results['verbose'] as bool;
    dryRun = results['dry-run'] as bool;
    final dryRunGit = results['dry-run-git'] as bool;
    final remote = results['remote'] as String;
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

    var allSuccess = true;
    var prunedCount = 0;
    var totalPruned = 0;

    for (final repoPath in repos) {
      final relPath = p.relative(repoPath, from: executionRoot);
      
      // First check what would be pruned
      final staleBranches = await _getStaleBranches(repoPath, remote);
      
      if (staleBranches.isEmpty) {
        if (verbose) {
          print('$relPath: no stale branches');
        }
        continue;
      }

      if (dryRun || dryRunGit) {
        print('$relPath: would prune ${staleBranches.length} stale branch(es):');
        for (final branch in staleBranches) {
          print('  - $branch');
        }
        totalPruned += staleBranches.length;
        prunedCount++;
        continue;
      }

      // Actually prune
      print('$relPath: pruning ${staleBranches.length} stale branch(es)...');
      if (!await _runGit(repoPath, ['remote', 'prune', remote], relPath)) {
        allSuccess = false;
        continue;
      }
      
      for (final branch in staleBranches) {
        print('  - pruned: $branch');
      }
      totalPruned += staleBranches.length;
      prunedCount++;
    }

    print('');
    if (dryRun || dryRunGit) {
      print('Would prune $totalPruned stale branch(es) from $prunedCount repo(s)');
    } else {
      print('Pruned $totalPruned stale branch(es) from $prunedCount repo(s)');
    }

    return allSuccess;
  }

  bool _hasGitTraversalFlag(List<String> args) {
    return args.contains('-i') || args.contains('--inner-first-git') ||
           args.contains('-o') || args.contains('--outer-first-git');
  }

  Future<List<String>> _getStaleBranches(String repoPath, String remote) async {
    try {
      // git remote prune --dry-run shows what would be pruned
      final result = await Process.run(
        'git', ['remote', 'prune', remote, '--dry-run'],
        workingDirectory: repoPath,
      );
      
      if (result.exitCode != 0) return [];
      
      final output = result.stdout.toString();
      final lines = output.split('\n')
          .where((line) => line.contains('[would prune]') || line.contains('* [would prune]'))
          .map((line) {
            // Parse "* [would prune] origin/branch-name" or " * [would prune] origin/branch"
            final match = RegExp(r'\[would prune\]\s+(.+)').firstMatch(line);
            return match?.group(1)?.trim() ?? '';
          })
          .where((s) => s.isNotEmpty)
          .toList();
      
      return lines;
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
    print('  Removes stale remote-tracking branches from all repositories.');
    print('  These are local references to branches that no longer exist on the remote.');
    print('');
    print('COMMANDS EXECUTED:');
    print('  git remote prune origin --dry-run   (first, to see what will be pruned)');
    print('  git remote prune origin             (then, to actually prune)');
    print('');
    print('WHAT GETS REMOVED:');
    print('  - Remote-tracking refs like origin/deleted-branch');
    print('  - Only refs to branches deleted on remote');
    print('  - Does NOT delete local branches');
    print('  - Does NOT affect any committed code');
    print('');
    print('WHEN TO USE:');
    print('  - After team members delete merged branches on GitHub/GitLab');
    print('  - To clean up clutter from "git branch -r"');
    print('  - Periodically for workspace hygiene');
    print('');
    print('Traversal: Fixed to outer-first.');
    print('           Do NOT specify -i/-o flags via buildkit.');
    print('');
    print('COMMAND OPTIONS:');
    print('  --dry-run-git       Show what would be pruned without removing.');
    print('                      Different from -n which affects the tool itself.');
    print('  --remote <name>     Remote to prune (default: origin).');
    print('');
    print('SAFETY:');
    print('  This is a SAFE operation:');
    print('  - Only removes local tracking references');
    print('  - The actual branches on remote are already gone');
    print('  - Your local branches are NOT affected');
    print('  - Use --dry-run-git first to see what will be removed');
    print('');
    print('STANDARD OPTIONS:');
    print(parser.usage);
    print('');
    print('EXAMPLES:');
    print('  gitprune                      # Prune all stale remote branches');
    print('  gitprune --dry-run-git        # Preview what would be pruned');
    print('  gitprune --remote upstream    # Prune from upstream remote');
    print('');
    print('VIA BUILDKIT:');
    print('  bk :gitprune');
  }
}
