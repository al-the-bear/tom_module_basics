import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';

import 'tool_base.dart';

/// Git squash tool - squash merges a branch into current branch.
///
/// Dedicated tool for squash merges with a clean interface.
/// Combines all commits from source branch into a single staged change.
class GitSquashTool extends ToolBase {
  @override
  String get toolKey => 'gitsquash';

  @override
  String get toolDescription =>
      'Squash merge a branch into current branch';

  /// If true, auto-inject --inner-first-git when running standalone.
  bool autoInnerFirst = true;

  @override
  void addToolOptions(ArgParser parser) {
    parser
      ..addOption('branch',
          help: 'Branch to squash merge (or use positional argument)')
      ..addOption('message',
          abbr: 'm',
          help: 'Commit message (required after squash)')
      ..addFlag('commit',
          negatable: false,
          help: 'Automatically commit after squash merge')
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
      print('Error: gitsquash requires --inner-first-git (-i) or --outer-first-git (-o)');
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

    final message = results['message'] as String?;
    final autoCommit = results['commit'] as bool;

    // Guided mode
    if (guided) {
      return await _runGuided(executionRoot, navArgs);
    }

    if (branch == null) {
      print('Error: Branch name required');
      print('');
      print('Usage:');
      print('  gitsquash feature/my-branch');
      print('  gitsquash -b release/1.0 -m "Merged release 1.0"');
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

    for (final repoPath in repos) {
      final relPath = p.relative(repoPath, from: executionRoot);
      
      // Run squash merge
      await _runGit(repoPath, ['merge', '--squash', branch], relPath);
      
      // Auto-commit if requested
      if (autoCommit && message != null) {
        await _runGit(repoPath, ['commit', '-m', message], relPath);
      }
    }

    if (!autoCommit) {
      print('');
      print('Squash merge complete. Changes are staged but not committed.');
      print('Run:');
      print('  gitcommit -m "Your message"');
      print('');
    }

    return true;
  }

  Future<bool> _runGuided(String executionRoot, WorkspaceNavigationArgs navArgs) async {
    print('');
    print('=== Git Squash - Guided Mode ===');
    print('');
    print('Squash merge combines all commits from a branch into a single change.');
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
    
    stdout.write('Squash merge from branch (name or number): ');
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
    stdout.write('Auto-commit after squash? [y/N]: ');
    final commitInput = stdin.readLineSync()?.trim().toLowerCase() ?? '';
    final autoCommit = commitInput == 'y' || commitInput == 'yes';
    
    String? message;
    if (autoCommit) {
      stdout.write('Commit message: ');
      message = stdin.readLineSync()?.trim() ?? '';
      if (message.isEmpty) {
        message = 'Squash merge $branch';
      }
    }
    
    print('');
    print('Commands to execute in each repository:');
    print('  git merge --squash $branch');
    if (autoCommit && message != null) {
      print('  git commit -m "$message"');
    }
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
      await _runGit(repoPath, ['merge', '--squash', branch], relPath);
      if (autoCommit && message != null) {
        await _runGit(repoPath, ['commit', '-m', message], relPath);
      }
    }
    
    if (!autoCommit) {
      print('');
      print('Squash merge complete. Changes are staged but not committed.');
      print('Run: gitcommit -m "Your message"');
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
    print('  Performs a squash merge from a source branch into your current branch.');
    print('  Combines ALL commits from the source branch into a single staged change.');
    print('  After the squash, you need to commit (or use --commit for auto-commit).');
    print('');
    print('COMMANDS EXECUTED:');
    print('  git merge --squash <branch>  (squash merge without commit)');
    print('  git commit -m "<message>"    (if --commit is used)');
    print('');
    print('WHEN TO USE:');
    print('  - Clean up messy feature branch history before merging to main');
    print('  - Create a single commit that represents an entire feature');
    print('  - When you do not want merge commits in your history');
    print('');
    print('Traversal: Fixed to inner-first.');
    print('           Inner repos squash first, then outer.');
    print('');
    print('COMMAND OPTIONS:');
    print('  <branch>             Branch to squash merge (positional argument)');
    print('  --branch <name>      Branch to squash merge (alternative to positional)');
    print('  -m, --message <msg>  Commit message (used with --commit)');
    print('  --commit             Automatically commit after squash merge');
    print('  -g, --guide          Guided mode with step-by-step prompts');
    print('');
    print('STANDARD OPTIONS:');
    print(parser.usage);
    print('');
    print('EXAMPLES:');
    print('  gitsquash feature/auth                     # Squash merge, manual commit');
    print('  gitsquash feature/auth --commit -m "Add auth"  # Auto commit');
    print('  gitsquash -g                               # Guided mode');
    print('');
    print('AFTER SQUASH (if not using --commit):');
    print('  gitcommit -m "Your message here"');
    print('');
    print('VIA BUILDKIT:');
    print('  bk :gitsquash feature/branch');
  }
}
