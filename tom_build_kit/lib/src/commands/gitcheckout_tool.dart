import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';

import 'tool_base.dart';

/// Git checkout tool - checkout branches or tags across all repositories.
///
/// Uses outer-first traversal because when checking out a specific state,
/// the parent repo should be checked out first to determine which submodule
/// commits are expected.
class GitCheckoutTool extends ToolBase {
  @override
  String get toolKey => 'gitcheckout';

  @override
  String get toolDescription =>
      'Checkout branches or tags across all repositories';

  /// If true, auto-inject --outer-first-git when running standalone.
  bool autoOuterFirst = false;

  @override
  void addToolOptions(ArgParser parser) {
    parser
      ..addOption('branch',
          abbr: 'b',
          help: 'Branch to checkout')
      ..addOption('tag',
          abbr: 't',
          help: 'Tag to checkout')
      ..addOption('commit',
          abbr: 'c',
          help: 'Commit hash to checkout')
      ..addFlag('create',
          abbr: 'B',
          negatable: false,
          help: 'Create branch if it does not exist')
      ..addFlag('force',
          abbr: 'f',
          negatable: false,
          help: 'Force checkout (discard changes)');
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
      print('Error: gitcheckout requires --outer-first-git (-o) or --inner-first-git (-i)');
      print('');
      print('Recommended: --outer-first-git (-o)');
      print('  Checkout parent first to get correct submodule references.');
      return false;
    }

    verbose = results['verbose'] as bool;
    dryRun = results['dry-run'] as bool;
    final branch = results['branch'] as String?;
    final tag = results['tag'] as String?;
    final commit = results['commit'] as String?;
    final create = results['create'] as bool;
    final force = results['force'] as bool;
    final listMode = results['list'] as bool;

    // Require a target
    final targetCount = [branch, tag, commit].where((t) => t != null).length;
    if (targetCount == 0 && !listMode) {
      print('Error: Specify --branch, --tag, or --commit');
      return false;
    }
    if (targetCount > 1) {
      print('Error: Specify only one of --branch, --tag, or --commit');
      return false;
    }

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

    // Build checkout command
    final gitArgs = ['checkout'];
    if (force) gitArgs.add('-f');
    if (create && branch != null) {
      gitArgs.add('-B');
      gitArgs.add(branch);
    } else if (branch != null) {
      gitArgs.add(branch);
    } else if (tag != null) {
      gitArgs.add(tag);
    } else if (commit != null) {
      gitArgs.add(commit);
    }

    final target = branch ?? tag ?? commit;

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
    print('Checked out $target: $successCount repository(ies)');

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
    print('Traversal: Fixed to outer-first (parent repos checked out before sub-repos).');
    print('           Do NOT specify -i/-o flags via buildkit.');
    print('');
    print('Options:');
    print(parser.usage);
    print('');
    print('Examples:');
    print('  gitcheckout -o -b main        # Checkout main branch');
    print('  gitcheckout -o -t v1.0.0      # Checkout tag');
    print('  gitcheckout -o -b new -B      # Create and checkout branch');
    print('  gitcheckout -o -b main -f     # Force checkout');
    print('');
    print('Via buildkit (do NOT specify -i/-o):');
    print('  bk :gitcheckout -b main');
    print('  bk :gitcheckout -t v1.0.0');
  }
}
