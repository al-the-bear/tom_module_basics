import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';

import 'tool_base.dart';

/// Git merge tool - merges a branch into current branch.
///
/// Provides options for merge strategies including squash merges.
/// Supports guided mode for step-by-step merges.
class GitMergeTool extends ToolBase {
  @override
  String get toolKey => 'gitmerge';

  @override
  String get toolDescription =>
      'Merge a branch into current branch';

  /// If true, auto-inject --inner-first-git when running standalone.
  bool autoInnerFirst = true;

  @override
  void addToolOptions(ArgParser parser) {
    parser
      ..addOption('branch',
          help: 'Branch to merge (or use positional argument)')
      ..addFlag('squash',
          negatable: false,
          help: 'Squash all commits into one (no merge commit)')
      ..addFlag('no-commit',
          negatable: false,
          help: 'Merge but do not auto-commit')
      ..addFlag('no-ff',
          negatable: false,
          help: 'Create merge commit even if fast-forward is possible')
      ..addFlag('ff-only',
          negatable: false,
          help: 'Abort if fast-forward is not possible')
      ..addOption('message',
          abbr: 'm',
          help: 'Commit message for merge commit')
      ..addFlag('abort',
          negatable: false,
          help: 'Abort an in-progress merge')
      ..addFlag('continue',
          negatable: false,
          help: 'Continue after resolving merge conflicts')
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
      print('Error: gitmerge requires --inner-first-git (-i) or --outer-first-git (-o)');
      return false;
    }

    verbose = results['verbose'] as bool;
    dryRun = results['dry-run'] as bool;
    final guided = results['guide'] as bool;
    final listMode = results['list'] as bool;

    // Get branch from option or positional argument
    var branch = results['branch'] as String?;
    if (branch == null && results.rest.isNotEmpty) {
      branch = results.rest.first;
    }

    final squash = results['squash'] as bool;
    final noCommit = results['no-commit'] as bool;
    final noFf = results['no-ff'] as bool;
    final ffOnly = results['ff-only'] as bool;
    final message = results['message'] as String?;
    final doAbort = results['abort'] as bool;
    final doContinue = results['continue'] as bool;

    // Guided mode
    if (guided) {
      return await _runGuided(executionRoot, navArgs);
    }

    // Abort/continue handling
    if (doAbort) {
      return await _runAbort(executionRoot, navArgs, listMode);
    }
    if (doContinue) {
      return await _runContinue(executionRoot, navArgs, listMode);
    }

    if (branch == null) {
      print('Error: Branch name required');
      print('');
      print('Usage:');
      print('  gitmerge feature/my-branch');
      print('  gitmerge -b release/1.0');
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

    for (final repoPath in repos) {
      final relPath = p.relative(repoPath, from: executionRoot);
      
      // Build merge command
      final mergeArgs = ['merge'];
      if (squash) mergeArgs.add('--squash');
      if (noCommit) mergeArgs.add('--no-commit');
      if (noFf) mergeArgs.add('--no-ff');
      if (ffOnly) mergeArgs.add('--ff-only');
      if (message != null) {
        mergeArgs.addAll(['-m', message]);
      }
      mergeArgs.add(branch);

      await _runGit(repoPath, mergeArgs, relPath);
    }

    return true;
  }

  Future<bool> _runAbort(String executionRoot, WorkspaceNavigationArgs navArgs, bool listMode) async {
    final repos = _findGitRepositories(executionRoot);
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

    for (final repoPath in repos) {
      final relPath = p.relative(repoPath, from: executionRoot);
      await _runGit(repoPath, ['merge', '--abort'], relPath);
    }
    return true;
  }

  Future<bool> _runContinue(String executionRoot, WorkspaceNavigationArgs navArgs, bool listMode) async {
    final repos = _findGitRepositories(executionRoot);
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

    for (final repoPath in repos) {
      final relPath = p.relative(repoPath, from: executionRoot);
      await _runGit(repoPath, ['merge', '--continue'], relPath);
    }
    return true;
  }

  Future<bool> _runGuided(String executionRoot, WorkspaceNavigationArgs navArgs) async {
    print('');
    print('=== Git Merge - Guided Mode ===');
    print('');
    
    final repos = _findGitRepositories(executionRoot);
    if (repos.isEmpty) {
      print('No git repositories found.');
      return false;
    }

    // Show branches from first repo
    final firstRepo = repos.first;
    final branches = await _getBranches(firstRepo);
    
    print('Available branches (from ${p.basename(firstRepo)}):');
    for (var i = 0; i < branches.length && i < 10; i++) {
      print('  ${i + 1}. ${branches[i]}');
    }
    if (branches.length > 10) {
      print('  ... and ${branches.length - 10} more');
    }
    print('');
    
    stdout.write('Merge from branch (name or number): ');
    final input = stdin.readLineSync()?.trim() ?? '';
    if (input.isEmpty) {
      print('Cancelled.');
      return false;
    }
    
    String branch;
    final num = int.tryParse(input);
    if (num != null && num > 0 && num <= branches.length) {
      branch = branches[num - 1].replaceFirst('* ', '').trim();
    } else {
      branch = input;
    }
    
    print('');
    print('Merge strategy:');
    print('  1. Normal merge (default, creates merge commit if needed)');
    print('  2. Squash merge (combine all commits into one staged change)');
    print('  3. Fast-forward only (abort if not possible)');
    print('  4. No fast-forward (always create merge commit)');
    stdout.write('Choose [1-4, default=1]: ');
    final strategyInput = stdin.readLineSync()?.trim() ?? '1';
    
    final mergeArgs = ['merge'];
    switch (strategyInput) {
      case '2':
        mergeArgs.add('--squash');
      case '3':
        mergeArgs.add('--ff-only');
      case '4':
        mergeArgs.add('--no-ff');
    }
    
    // Custom message for merge commit
    print('');
    stdout.write('Custom merge message (leave empty for default): ');
    final messageInput = stdin.readLineSync()?.trim() ?? '';
    if (messageInput.isNotEmpty) {
      mergeArgs.addAll(['-m', messageInput]);
    }
    
    mergeArgs.add(branch);
    
    print('');
    print('Command to execute in each repository:');
    print('  git ${mergeArgs.join(' ')}');
    print('');
    print('WARNING: This will modify your repositories.');
    stdout.write('Proceed? [y/N]: ');
    final confirm = stdin.readLineSync()?.trim().toLowerCase() ?? '';
    if (confirm != 'y' && confirm != 'yes') {
      print('Cancelled.');
      return false;
    }
    
    print('');
    for (final repoPath in repos) {
      final relPath = p.relative(repoPath, from: executionRoot);
      await _runGit(repoPath, mergeArgs, relPath);
    }
    
    return true;
  }

  Future<List<String>> _getBranches(String repoPath) async {
    try {
      final result = await Process.run('git', ['branch', '-a'], workingDirectory: repoPath);
      if (result.exitCode != 0) return [];
      return result.stdout.toString().trim().split('\n').where((s) => s.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
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

  Future<void> _runGit(String repoPath, List<String> args, String relPath) async {
    if (dryRun) {
      print('[DRY RUN] $relPath: git ${args.join(' ')}');
      return;
    }
    
    print('[$relPath] git ${args.join(' ')}');
    
    try {
      final result = await Process.run('git', args, workingDirectory: repoPath);
      final output = result.stdout.toString().trim();
      if (output.isNotEmpty) {
        print('  $output');
      }
      final stderr = result.stderr.toString().trim();
      if (stderr.isNotEmpty) {
        print('  $stderr');
      }
      if (result.exitCode != 0) {
        print('  Exit code: ${result.exitCode}');
      }
      print('');
    } catch (e) {
      print('  Error: $e');
    }
  }

  void _printUsage(ArgParser parser) {
    printUsageHeader();
    print('');
    print('WHAT IT DOES:');
    print('  Merges a specified branch into your current branch across all repositories.');
    print('  Supports different merge strategies including squash and fast-forward options.');
    print('');
    print('COMMANDS EXECUTED:');
    print('  git merge <branch>           (standard merge)');
    print('  git merge --squash <branch>  (squash all commits)');
    print('  git merge --no-ff <branch>   (force merge commit)');
    print('  git merge --ff-only <branch> (fast-forward or fail)');
    print('');
    print('WHEN TO USE:');
    print('  - Merge feature branch into main/develop');
    print('  - Combine changes from another branch');
    print('  - Use --squash for clean history (single commit)');
    print('');
    print('Traversal: Fixed to inner-first.');
    print('           Inner repos merge first, then outer.');
    print('');
    print('COMMAND OPTIONS:');
    print('  <branch>             Branch to merge (positional argument)');
    print('  --branch <name>      Branch to merge (alternative to positional)');
    print('  --squash             Squash all commits into one (requires manual commit)');
    print('  --no-commit          Perform merge but do not commit');
    print('  --no-ff              Create merge commit even if fast-forward possible');
    print('  --ff-only            Only merge if fast-forward is possible');
    print('  -m, --message <msg>  Custom commit message for merge');
    print('  --abort              Abort an in-progress merge');
    print('  --continue           Continue after resolving conflicts');
    print('  -g, --guide          Guided mode with step-by-step prompts');
    print('');
    print('STANDARD OPTIONS:');
    print(parser.usage);
    print('');
    print('EXAMPLES:');
    print('  gitmerge feature/auth         # Merge feature/auth into current');
    print('  gitmerge main --squash        # Squash merge from main');
    print('  gitmerge release/1.0 --no-ff  # Force merge commit');
    print('  gitmerge --abort              # Abort merge in progress');
    print('  gitmerge -g                   # Guided mode');
    print('');
    print('VIA BUILDKIT:');
    print('  bk :gitmerge feature/branch');
  }
}
