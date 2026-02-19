import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';

import 'tool_base.dart';

/// Git pull tool - pulls latest from all repositories.
///
/// Uses outer-first traversal because parent repos should be pulled first
/// to get updated submodule references, then submodules are updated.
class GitPullTool extends ToolBase {
  @override
  String get toolKey => 'gitpull';

  @override
  String get toolDescription =>
      'Pull latest from all repositories';

  /// If true, auto-inject --outer-first-git when running standalone.
  bool autoOuterFirst = false;

  @override
  void addToolOptions(ArgParser parser) {
    parser
      ..addFlag('rebase',
          negatable: false,
          help: 'Rebase instead of fast-forward only')
      ..addFlag('allow-merge',
          negatable: false,
          help: 'Allow merge commits (overrides default --ff-only)')
      ..addOption('remote',
          defaultsTo: 'origin',
          help: 'Remote name to pull from')
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

    // Auto-inject --outer-first-git for standalone binary
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

    // Require git traversal flag
    if (!navArgs.innerFirstGit && !navArgs.outerFirstGit) {
      print('Error: gitpull requires --outer-first-git (-o) or --inner-first-git (-i)');
      print('');
      print('Recommended: --outer-first-git (-o)');
      print('  Pull parent repos first to get updated submodule references.');
      return false;
    }

    verbose = results['verbose'] as bool;
    dryRun = results['dry-run'] as bool;
    final useRebase = results['rebase'] as bool;
    final allowMerge = results['allow-merge'] as bool;
    final ffOnly = !useRebase && !allowMerge;  // Default is ff-only
    final remote = results['remote'] as String;
    final listMode = results['list'] as bool;

    // Find git repositories
    var repos = WorkspaceScanner().findGitRepoPaths(executionRoot);

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

    // Sort by depth
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
      print('Git repositories (${navArgs.outerFirstGit ? 'outer-first' : 'inner-first'}):');
      for (final repo in repos) {
        print('  ${p.relative(repo, from: executionRoot)}');
      }
      return true;
    }

    // Pull each repository
    var allSuccess = true;
    var pullCount = 0;

    for (final repoPath in repos) {
      final relPath = p.relative(repoPath, from: executionRoot);
      
      // Build pull command
      final pullArgs = ['pull', remote];
      if (useRebase) pullArgs.add('--rebase');
      if (ffOnly) pullArgs.add('--ff-only');

      if (!await _runGit(repoPath, pullArgs, relPath)) {
        allSuccess = false;
        continue;
      }
      pullCount++;
    }

    print('');
    print('Pulled $pullCount repository(ies)');

    return allSuccess;
  }

  bool _hasGitTraversalFlag(List<String> args) {
    return args.contains('-i') ||
           args.contains('--inner-first-git') ||
           args.contains('-o') ||
           args.contains('--outer-first-git');
  }

  Future<bool> _runGit(String repoPath, List<String> args, String relPath) async {
    if (dryRun) {
      print('[DRY RUN] $relPath: git ${args.join(' ')}');
      return true;
    }

    print('$relPath: git ${args.join(' ')}');

    try {
      final result = await ProcessRunner.run('git', args, workingDirectory: repoPath);
      
      if (result.exitCode != 0) {
        final stderr = result.stderr.trim();
        if (stderr.isNotEmpty) {
          print('  Error: $stderr');
        }
        return false;
      }
      
      if (verbose) {
        final stdout = result.stdout.trim();
        if (stdout.isNotEmpty) print('  $stdout');
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
    print('  Pulls latest changes from remote for all repositories.');
    print('  Uses --ff-only by default to prevent accidental merge commits.');
    print('');
    print('COMMANDS EXECUTED:');
    print('  git pull origin <branch> --ff-only   (default, fail if merge needed)');
    print('  git pull origin <branch> --rebase    (with --rebase)');
    print('  git pull origin <branch>             (with --allow-merge)');
    print('');
    print('WHEN TO USE:');
    print('  - At start of work session to get latest changes');
    print('  - After someone else pushed changes you need');
    print('  - Regular sync during collaborative work');
    print('');
    print('Traversal: Fixed to outer-first (parent repos pulled before sub-repos).');
    print('           Do NOT specify -i/-o flags via buildkit.');
    print('');
    print('COMMAND OPTIONS:');
    print('  --rebase          Rebase local commits on top of remote changes.');
    print('                    Creates linear history, good for feature branches.');
    print('                    May require conflict resolution.');
    print('  --allow-merge     Allow merge commits when branches diverged.');
    print('                    Creates merge commit, preserves branch history.');
    print('  --remote <name>   Remote to pull from (default: origin)');
    print('');
    print('DEFAULT BEHAVIOR (--ff-only):');
    print('  - Fast-forward only: fails if local has commits not in remote');
    print('  - Safest option: no accidental merges or rebases');
    print('  - If it fails, decide explicitly: --rebase or --allow-merge');
    print('');
    print('STANDARD OPTIONS:');
    print(parser.usage);
    print('');
    print('EXAMPLES:');
    print('  gitpull                    # Pull with --ff-only (default, safe)');
    print('  gitpull --rebase           # Pull and rebase local commits');
    print('  gitpull --allow-merge      # Pull and allow merge commits');
    print('');
    print('VIA BUILDKIT:');
    print('  bk :gitpull                # Uses fixed outer-first traversal');
  }
}
