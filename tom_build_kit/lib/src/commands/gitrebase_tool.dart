import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';

import 'tool_base.dart';

/// Git rebase tool - rebases current branch onto another branch.
///
/// Provides rebase functionality with abort/continue/skip support.
/// WARNING: Rebase rewrites history - use with caution.
class GitRebaseTool extends ToolBase {
  @override
  String get toolKey => 'gitrebase';

  @override
  String get toolDescription =>
      'Rebase current branch onto another branch';

  /// If true, auto-inject --inner-first-git when running standalone.
  bool autoInnerFirst = true;

  @override
  void addToolOptions(ArgParser parser) {
    parser
      ..addOption('onto',
          help: 'Branch to rebase onto (or use positional argument)')
      ..addFlag('abort',
          negatable: false,
          help: 'Abort an in-progress rebase')
      ..addFlag('continue',
          negatable: false,
          help: 'Continue after resolving conflicts')
      ..addFlag('skip',
          negatable: false,
          help: 'Skip current commit and continue')
      ..addFlag('guide',
          abbr: 'g',
          negatable: false,
          help: 'Guided mode - step-by-step prompts (NOT git interactive rebase)')
      ..addFlag('git-interactive',
          negatable: false,
          help: 'Use git interactive rebase (git rebase -i)');
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
      print('Error: gitrebase requires --inner-first-git (-i) or --outer-first-git (-o)');
      return false;
    }

    verbose = results['verbose'] as bool;
    dryRun = results['dry-run'] as bool;
    final guided = results['guide'] as bool;
    final listMode = results['list'] as bool;

    // Get branch from option or positional argument
    var onto = results['onto'] as String?;
    if (onto == null && results.rest.isNotEmpty) {
      onto = results.rest.first;
    }

    final doAbort = results['abort'] as bool;
    final doContinue = results['continue'] as bool;
    final doSkip = results['skip'] as bool;
    final gitInteractive = results['git-interactive'] as bool;

    // Guided mode
    if (guided) {
      return await _runGuided(executionRoot, navArgs);
    }

    // Abort/continue/skip handling
    if (doAbort) {
      return await _runCommand(executionRoot, navArgs, listMode, ['rebase', '--abort']);
    }
    if (doContinue) {
      return await _runCommand(executionRoot, navArgs, listMode, ['rebase', '--continue']);
    }
    if (doSkip) {
      return await _runCommand(executionRoot, navArgs, listMode, ['rebase', '--skip']);
    }

    if (onto == null) {
      print('Error: Target branch required');
      print('');
      print('Usage:');
      print('  gitrebase main');
      print('  gitrebase --onto develop');
      return false;
    }

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

    // Warning for multi-repo rebase
    if (repos.length > 1) {
      print('WARNING: Rebasing ${repos.length} repositories.');
      print('         Rebase rewrites history. If these repos are pushed,');
      print('         you may need to force-push.\n');
    }

    for (final repoPath in repos) {
      final relPath = p.relative(repoPath, from: executionRoot);
      
      // Build rebase command
      final rebaseArgs = ['rebase'];
      if (gitInteractive) rebaseArgs.add('-i');
      rebaseArgs.add(onto);

      await _runGit(repoPath, rebaseArgs, relPath);
    }

    return true;
  }

  Future<bool> _runCommand(String executionRoot, WorkspaceNavigationArgs navArgs, bool listMode, List<String> command) async {
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
      await _runGit(repoPath, command, relPath);
    }
    return true;
  }

  Future<bool> _runGuided(String executionRoot, WorkspaceNavigationArgs navArgs) async {
    print('');
    print('=== Git Rebase - Guided Mode ===');
    print('');
    print('WARNING: Rebase rewrites commit history!');
    print('         Only rebase commits that have NOT been pushed.');
    print('');
    
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
      print('No git repositories found.');
      return false;
    }

    // Check for in-progress rebase
    print('What would you like to do?');
    print('  1. Rebase onto a branch');
    print('  2. Abort in-progress rebase');
    print('  3. Continue after resolving conflicts');
    print('  4. Skip current commit');
    print('  5. Cancel');
    stdout.write('Choose [1-5]: ');
    final actionInput = stdin.readLineSync()?.trim() ?? '5';

    switch (actionInput) {
      case '2':
        print('');
        print('Command: git rebase --abort');
        print('');
        stdout.write('Proceed? [y/N]: ');
        final confirm = stdin.readLineSync()?.trim().toLowerCase() ?? '';
        if (confirm != 'y' && confirm != 'yes') {
          print('Cancelled.');
          return false;
        }
        return await _runCommand(executionRoot, navArgs, false, ['rebase', '--abort']);
      
      case '3':
        print('');
        print('Command: git rebase --continue');
        print('');
        stdout.write('Proceed? [y/N]: ');
        final confirm = stdin.readLineSync()?.trim().toLowerCase() ?? '';
        if (confirm != 'y' && confirm != 'yes') {
          print('Cancelled.');
          return false;
        }
        return await _runCommand(executionRoot, navArgs, false, ['rebase', '--continue']);
      
      case '4':
        print('');
        print('Command: git rebase --skip');
        print('');
        stdout.write('Proceed? [y/N]: ');
        final confirm = stdin.readLineSync()?.trim().toLowerCase() ?? '';
        if (confirm != 'y' && confirm != 'yes') {
          print('Cancelled.');
          return false;
        }
        return await _runCommand(executionRoot, navArgs, false, ['rebase', '--skip']);
      
      case '5':
        print('Cancelled.');
        return false;
      
      case '1':
      default:
        break;
    }

    // Show branches from first repo
    final firstRepo = repos.first;
    final branches = await _getBranches(firstRepo);
    
    print('');
    print('Available branches (from ${p.basename(firstRepo)}):');
    for (var i = 0; i < branches.length && i < 10; i++) {
      print('  ${i + 1}. ${branches[i]}');
    }
    if (branches.length > 10) {
      print('  ... and ${branches.length - 10} more');
    }
    print('');
    
    stdout.write('Rebase onto branch (name or number): ');
    final input = stdin.readLineSync()?.trim() ?? '';
    if (input.isEmpty) {
      print('Cancelled.');
      return false;
    }
    
    String onto;
    final num = int.tryParse(input);
    if (num != null && num > 0 && num <= branches.length) {
      onto = branches[num - 1].replaceFirst('* ', '').trim();
    } else {
      onto = input;
    }
    
    print('');
    print('Use git interactive rebase (-i)?');
    print('  This allows you to edit, squash, or reorder commits.');
    stdout.write('Use interactive? [y/N]: ');
    final interactiveInput = stdin.readLineSync()?.trim().toLowerCase() ?? '';
    final gitInteractive = interactiveInput == 'y' || interactiveInput == 'yes';
    
    final rebaseArgs = ['rebase'];
    if (gitInteractive) rebaseArgs.add('-i');
    rebaseArgs.add(onto);
    
    print('');
    print('Command to execute in each repository:');
    print('  git ${rebaseArgs.join(' ')}');
    print('');
    print('WARNING: This rewrites history. Only proceed if commits are not pushed.');
    stdout.write('Proceed? [y/N]: ');
    final confirm = stdin.readLineSync()?.trim().toLowerCase() ?? '';
    if (confirm != 'y' && confirm != 'yes') {
      print('Cancelled.');
      return false;
    }
    
    print('');
    for (final repoPath in repos) {
      final relPath = p.relative(repoPath, from: executionRoot);
      await _runGit(repoPath, rebaseArgs, relPath);
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
    print('  Rebases your current branch onto another branch across all repositories.');
    print('  Rebase replays your commits on top of the target branch.');
    print('');
    print('  WARNING: Rebase rewrites commit history!');
    print('           Only rebase commits that have NOT been pushed.');
    print('           If pushed, you will need to force-push.');
    print('');
    print('COMMANDS EXECUTED:');
    print('  git rebase <branch>      (rebase onto branch)');
    print('  git rebase -i <branch>   (interactive rebase)');
    print('  git rebase --continue    (continue after conflict resolution)');
    print('  git rebase --abort       (abort and restore original state)');
    print('  git rebase --skip        (skip current commit)');
    print('');
    print('WHEN TO USE:');
    print('  - Update feature branch with latest main changes');
    print('  - Create linear history (no merge commits)');
    print('  - Clean up commits before merging (interactive)');
    print('');
    print('Traversal: Fixed to inner-first.');
    print('           Inner repos rebase first, then outer.');
    print('');
    print('COMMAND OPTIONS:');
    print('  <branch>             Branch to rebase onto (positional argument)');
    print('  --onto <branch>      Branch to rebase onto (alternative to positional)');
    print('  --git-interactive    Use git interactive rebase (git rebase -i)');
    print('  --abort              Abort an in-progress rebase');
    print('  --continue           Continue after resolving conflicts');
    print('  --skip               Skip current commit and continue');
    print('  -g, --guide          Guided mode for this tool (NOT git -i)');
    print('');
    print('STANDARD OPTIONS:');
    print(parser.usage);
    print('');
    print('EXAMPLES:');
    print('  gitrebase main              # Rebase onto main');
    print('  gitrebase --abort           # Abort rebase in progress');
    print('  gitrebase --continue        # Continue after fixing conflicts');
    print('  gitrebase main --git-interactive  # Interactive rebase');
    print('  gitrebase -g                # Guided mode');
    print('');
    print('VIA BUILDKIT:');
    print('  bk :gitrebase main');
  }
}
