import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';

import 'tool_base.dart';

/// Git branch tool - creates or switches branches across all repositories.
///
/// Uses inner-first traversal because when creating branches, you want
/// submodules to have the branch before the parent (for consistency).
class GitBranchTool extends ToolBase {
  @override
  String get toolKey => 'gitbranch';

  @override
  String get toolDescription =>
      'Create or switch branches across all repositories';

  /// If true, auto-inject --inner-first-git when running standalone.
  bool autoInnerFirst = false;

  @override
  void addToolOptions(ArgParser parser) {
    parser
      ..addOption('create',
          abbr: 'c',
          help: 'Create and switch to new branch')
      ..addOption('switch',
          abbr: 's',
          help: 'Switch to existing branch')
      ..addFlag('delete',
          abbr: 'd',
          negatable: false,
          help: 'Delete branch (requires --branch)')
      ..addOption('branch',
          abbr: 'b',
          help: 'Branch name for delete operation')
      ..addFlag('force',
          abbr: 'f',
          negatable: false,
          help: 'Force delete or force create')
      ..addFlag('list-branches',
          negatable: false,
          help: 'List branches in each repo');
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
      print('Error: gitbranch requires --inner-first-git (-i) or --outer-first-git (-o)');
      print('');
      print('Recommended: --inner-first-git (-i)');
      print('  Create branches in submodules first for consistency.');
      return false;
    }

    verbose = results['verbose'] as bool;
    dryRun = results['dry-run'] as bool;
    final createBranch = results['create'] as String?;
    final switchBranch = results['switch'] as String?;
    final deleteBranch = results['delete'] as bool;
    final branchName = results['branch'] as String?;
    final force = results['force'] as bool;
    final listBranches = results['list-branches'] as bool;
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

    if (listBranches) {
      for (final repoPath in repos) {
        final relPath = p.relative(repoPath, from: executionRoot);
        final branches = await _listBranches(repoPath);
        print('$relPath:');
        for (final branch in branches) {
          print('  $branch');
        }
      }
      return true;
    }

    // Determine operation
    List<String> gitArgs;
    String opName;
    
    if (createBranch != null) {
      gitArgs = ['checkout', '-b', createBranch];
      if (force) gitArgs.insert(1, '-B');
      opName = 'create branch $createBranch';
    } else if (switchBranch != null) {
      gitArgs = ['checkout', switchBranch];
      opName = 'switch to $switchBranch';
    } else if (deleteBranch) {
      if (branchName == null) {
        print('Error: --delete requires --branch <name>');
        return false;
      }
      gitArgs = ['branch', force ? '-D' : '-d', branchName];
      opName = 'delete branch $branchName';
    } else {
      // Just show current branches
      for (final repoPath in repos) {
        final relPath = p.relative(repoPath, from: executionRoot);
        final current = await _getCurrentBranch(repoPath);
        print('$relPath: $current');
      }
      return true;
    }

    var allSuccess = true;
    var successCount = 0;

    for (final repoPath in repos) {
      final relPath = p.relative(repoPath, from: executionRoot);
      
      if (!await _runGit(repoPath, gitArgs, relPath)) {
        allSuccess = false;
        continue;
      }
      successCount++;
    }

    print('');
    print('$opName: $successCount repository(ies)');

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

  Future<String> _getCurrentBranch(String repoPath) async {
    try {
      final result = await Process.run('git', ['rev-parse', '--abbrev-ref', 'HEAD'],
          workingDirectory: repoPath);
      return result.stdout.toString().trim();
    } catch (_) {
      return 'unknown';
    }
  }

  Future<List<String>> _listBranches(String repoPath) async {
    try {
      final result = await Process.run('git', ['branch', '-a'],
          workingDirectory: repoPath);
      return result.stdout.toString().split('\n').where((l) => l.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
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

  void _printUsage(ArgParser parser) {
    printUsageHeader();
    print('');
    print('Traversal: Fixed to inner-first (sub-repos processed before parents).');
    print('           Do NOT specify -i/-o flags via buildkit.');
    print('');
    print('Options:');
    print(parser.usage);
    print('');
    print('Examples:');
    print('  gitbranch -i                      # Show current branches');
    print('  gitbranch -i -c feature/new       # Create and switch');
    print('  gitbranch -i -s main              # Switch to main');
    print('  gitbranch -i -d -b old-branch     # Delete branch');
    print('  gitbranch -i --list-branches      # List all branches');
    print('');
    print('Via buildkit (do NOT specify -i/-o):');
    print('  bk :gitbranch');
    print('  bk :gitbranch -c feature/new');
  }
}
