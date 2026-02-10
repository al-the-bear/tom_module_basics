import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';

import 'tool_base.dart';

/// Git compare tool - compares current branch with another branch.
///
/// Shows the diff between current branch and a target branch.
/// Uses three-dot diff to show changes since the branches diverged.
class GitCompareTool extends ToolBase {
  @override
  String get toolKey => 'gitcompare';

  @override
  String get toolDescription =>
      'Compare current branch with another branch';

  /// If true, auto-inject --inner-first-git when running standalone.
  bool autoInnerFirst = false;

  @override
  void addToolOptions(ArgParser parser) {
    parser
      ..addOption('branch',
          help: 'Branch to compare with (or use positional argument)')
      ..addFlag('stat',
          negatable: false,
          help: 'Show only file statistics, not full diff')
      ..addFlag('name-only',
          negatable: false,
          help: 'Show only changed file names')
      ..addFlag('summary',
          negatable: false,
          help: 'Show condensed summary of changes')
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
      print('Error: gitcompare requires --inner-first-git (-i) or --outer-first-git (-o)');
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

    final showStat = results['stat'] as bool;
    final nameOnly = results['name-only'] as bool;
    final showSummary = results['summary'] as bool;

    // Guided mode
    if (guided) {
      return await _runGuided(executionRoot, navArgs);
    }

    if (branch == null) {
      print('Error: Branch name required');
      print('');
      print('Usage:');
      print('  gitcompare main');
      print('  gitcompare -b feature/other');
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
      
      // Build diff command - use three-dot diff for changes since divergence
      final diffArgs = ['diff', '$branch...HEAD'];
      if (showStat) diffArgs.add('--stat');
      if (nameOnly) diffArgs.add('--name-only');
      if (showSummary) diffArgs.add('--summary');

      await _runGitWithOutput(repoPath, diffArgs, relPath);
    }

    return true;
  }

  Future<bool> _runGuided(String executionRoot, WorkspaceNavigationArgs navArgs) async {
    print('');
    print('=== Git Compare - Guided Mode ===');
    print('');
    
    // Get available branches
    final repos = _findGitRepositories(executionRoot);
    if (repos.isEmpty) {
      print('No git repositories found.');
      return false;
    }

    // Show branches from first repo as example
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
    
    stdout.write('Compare with branch (name or number): ');
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
    print('Output format:');
    print('  1. Full diff (default)');
    print('  2. File statistics (--stat)');
    print('  3. File names only (--name-only)');
    print('  4. Summary (--summary)');
    stdout.write('Choose [1-4, default=1]: ');
    final formatInput = stdin.readLineSync()?.trim() ?? '1';
    
    final diffArgs = ['diff', '$branch...HEAD'];
    switch (formatInput) {
      case '2':
        diffArgs.add('--stat');
      case '3':
        diffArgs.add('--name-only');
      case '4':
        diffArgs.add('--summary');
    }
    
    print('');
    print('Command to execute in each repository:');
    print('  git ${diffArgs.join(' ')}');
    print('');
    stdout.write('Proceed? [Y/n]: ');
    final confirm = stdin.readLineSync()?.trim().toLowerCase() ?? 'y';
    if (confirm == 'n' || confirm == 'no') {
      print('Cancelled.');
      return false;
    }
    
    print('');
    for (final repoPath in repos) {
      final relPath = p.relative(repoPath, from: executionRoot);
      await _runGitWithOutput(repoPath, diffArgs, relPath);
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

  Future<void> _runGitWithOutput(String repoPath, List<String> args, String relPath) async {
    if (dryRun) {
      print('[DRY RUN] $relPath: git ${args.join(' ')}');
      return;
    }
    
    print('[$relPath]');
    
    try {
      final result = await Process.run('git', args, workingDirectory: repoPath);
      final output = result.stdout.toString().trim();
      if (output.isNotEmpty) {
        print(output);
      } else {
        print('  (no differences)');
      }
      if (result.stderr.toString().trim().isNotEmpty) {
        print('  ${result.stderr}');
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
    print('  Compares your current branch with another branch across all repositories.');
    print('  Uses three-dot diff to show changes since the branches diverged.');
    print('');
    print('COMMANDS EXECUTED:');
    print('  git diff <branch>...HEAD            (show changes since divergence)');
    print('  git diff <branch>...HEAD --stat     (with --stat, file statistics)');
    print('  git diff <branch>...HEAD --name-only  (with --name-only)');
    print('');
    print('WHEN TO USE:');
    print('  - Before creating a pull request, review all changes');
    print('  - Compare feature branch against main to see what you changed');
    print('  - Quick audit of changes across multiple repos');
    print('');
    print('Traversal: Fixed to inner-first.');
    print('           Do NOT specify -i/-o flags via buildkit.');
    print('');
    print('COMMAND OPTIONS:');
    print('  <branch>            Branch to compare with (positional argument)');
    print('  --branch <name>     Branch to compare with (alternative to positional)');
    print('  --stat              Show file statistics instead of full diff');
    print('  --name-only         Show only changed file names');
    print('  --summary           Show condensed change summary');
    print('  -g, --guide         Guided mode with step-by-step prompts');
    print('');
    print('STANDARD OPTIONS:');
    print(parser.usage);
    print('');
    print('EXAMPLES:');
    print('  gitcompare main                # Compare with main branch');
    print('  gitcompare main --stat         # Show file stats only');
    print('  gitcompare feature/other       # Compare with feature branch');
    print('  gitcompare -g                  # Guided mode');
    print('');
    print('VIA BUILDKIT:');
    print('  bk :gitcompare main');
  }
}
