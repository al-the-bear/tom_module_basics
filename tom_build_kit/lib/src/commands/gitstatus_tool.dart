import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';

import 'tool_base.dart';

/// Git status tool - shows status of all git repositories in the workspace.
///
/// For each repository, displays:
/// - Uncommitted changes (staged and unstaged)
/// - Unpushed commits
/// - Current branch
/// - Stashed changes count
/// - Untracked files count
///
/// Requires --inner-first-git (-i) or --outer-first-git (-o) flag.
class GitStatusTool extends ToolBase {
  @override
  String get toolKey => 'gitstatus';

  @override
  String get toolDescription =>
      'Show git status for all repositories in workspace';

  /// If true, auto-inject --inner-first-git when running standalone.
  bool autoInnerFirst = false;

  @override
  void addToolOptions(ArgParser parser) {
    parser
      ..addFlag('details',
          abbr: 'd',
          negatable: false,
          help: 'Show detailed output (files, commits)')
      ..addFlag('no-fetch',
          negatable: false,
          help: 'Skip fetching from remote (fetch is default)')
      ..addFlag('stash',
          negatable: false,
          help: 'Include stash information')
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

    // Auto-inject --inner-first-git for standalone binary
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

    // Require git traversal flag (unless auto-injected)
    if (!navArgs.innerFirstGit && !navArgs.outerFirstGit) {
      print('Error: gitstatus requires --inner-first-git (-i) or --outer-first-git (-o)');
      print('');
      print('Examples:');
      print('  gitstatus -i              # Inner repos first (deepest first)');
      print('  gitstatus -o              # Outer repos first (shallowest first)');
      print('  bk :gitstatus -i          # Via buildkit');
      return false;
    }

    verbose = results['verbose'] as bool;
    dryRun = results['dry-run'] as bool;
    final showDetails = results['details'] as bool;
    final doFetch = !(results['no-fetch'] as bool);
    final showStash = results['stash'] as bool;
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
            ? depthB.compareTo(depthA) // deepest first
            : depthA.compareTo(depthB); // shallowest first
      }
      return p.basename(a).compareTo(p.basename(b));
    });

    if (listMode) {
      print('Git repositories (${navArgs.innerFirstGit ? 'inner-first' : 'outer-first'}):');
      for (final repo in repos) {
        print('  ${p.relative(repo, from: executionRoot)}');
      }
      return true;
    }

    // Fetch if requested
    if (doFetch) {
      print('Fetching from remotes...');
      for (final repo in repos) {
        await _gitFetch(repo);
      }
      print('');
    }

    // Analyze each repository
    for (final repoPath in repos) {
      final status = await _analyzeRepo(repoPath, showStash: showStash);
      _printRepoStatus(
        status, 
        executionRoot, 
        showDetails: showDetails,
      );
    }

    return true;
  }

  bool _hasGitTraversalFlag(List<String> args) {
    return args.contains('-i') ||
           args.contains('--inner-first-git') ||
           args.contains('-o') ||
           args.contains('--outer-first-git');
  }

  Future<void> _gitFetch(String repoPath) async {
    try {
      await Process.run('git', ['fetch', '--all', '--quiet'],
          workingDirectory: repoPath);
    } catch (_) {
      // Ignore fetch errors
    }
  }

  Future<_RepoStatus> _analyzeRepo(String repoPath, {bool showStash = false}) async {
    final name = p.basename(repoPath);
    
    // Get current branch
    String branch;
    try {
      final result = await Process.run(
        'git', ['rev-parse', '--abbrev-ref', 'HEAD'],
        workingDirectory: repoPath,
      );
      branch = result.stdout.toString().trim();
    } catch (_) {
      branch = 'unknown';
    }

    // Get status (staged, unstaged, untracked)
    List<String> stagedFiles = [];
    List<String> unstagedFiles = [];
    List<String> untrackedFiles = [];
    
    try {
      final result = await Process.run(
        'git', ['status', '--porcelain'],
        workingDirectory: repoPath,
      );
      final lines = result.stdout.toString().split('\n').where((l) => l.isNotEmpty);
      for (final line in lines) {
        if (line.length < 3) continue;
        final indexStatus = line[0];
        final workStatus = line[1];
        final file = line.substring(3);
        
        if (indexStatus == '?' && workStatus == '?') {
          untrackedFiles.add(file);
        } else {
          if (indexStatus != ' ' && indexStatus != '?') {
            stagedFiles.add(file);
          }
          if (workStatus != ' ' && workStatus != '?') {
            unstagedFiles.add(file);
          }
        }
      }
    } catch (_) {
      // Ignore
    }

    // Get unpushed commits
    List<String> unpushedCommits = [];
    try {
      final result = await Process.run(
        'git', ['log', '@{u}..HEAD', '--oneline'],
        workingDirectory: repoPath,
      );
      if (result.exitCode == 0) {
        unpushedCommits = result.stdout.toString()
            .split('\n')
            .where((l) => l.isNotEmpty)
            .toList();
      }
    } catch (_) {
      // No upstream or other error
    }

    // Get stash count
    int stashCount = 0;
    if (showStash) {
      try {
        final result = await Process.run(
          'git', ['stash', 'list'],
          workingDirectory: repoPath,
        );
        stashCount = result.stdout.toString()
            .split('\n')
            .where((l) => l.isNotEmpty)
            .length;
      } catch (_) {
        // Ignore
      }
    }

    return _RepoStatus(
      path: repoPath,
      name: name,
      branch: branch,
      stagedFiles: stagedFiles,
      unstagedFiles: unstagedFiles,
      untrackedFiles: untrackedFiles,
      unpushedCommits: unpushedCommits,
      stashCount: stashCount,
    );
  }

  void _printRepoStatus(
    _RepoStatus status,
    String wsRoot, {
    bool showDetails = false,
  }) {
    final relPath = p.relative(status.path, from: wsRoot);
    final issues = <String>[];

    final hasUncommitted = status.stagedFiles.isNotEmpty || 
                           status.unstagedFiles.isNotEmpty;
    final hasUntracked = status.untrackedFiles.isNotEmpty;
    final hasUnpushed = status.unpushedCommits.isNotEmpty;

    if (hasUncommitted) {
      final count = status.stagedFiles.length + status.unstagedFiles.length;
      issues.add('$count uncommitted');
    }
    if (hasUntracked) {
      issues.add('${status.untrackedFiles.length} untracked');
    }
    if (hasUnpushed) {
      issues.add('${status.unpushedCommits.length} unpushed');
    }
    if (status.stashCount > 0) {
      issues.add('${status.stashCount} stashed');
    }

    if (issues.isEmpty) {
      print('$relPath (${status.branch}): clean');
    } else {
      print('$relPath (${status.branch}): ${issues.join(', ')}');
    }

    if (showDetails) {
      if (status.stagedFiles.isNotEmpty) {
        print('  Staged:');
        for (final file in status.stagedFiles) {
          print('    + $file');
        }
      }
      if (status.unstagedFiles.isNotEmpty) {
        print('  Modified:');
        for (final file in status.unstagedFiles) {
          print('    M $file');
        }
      }
      if (status.untrackedFiles.isNotEmpty) {
        print('  Untracked:');
        for (final file in status.untrackedFiles) {
          print('    ? $file');
        }
      }
      if (status.unpushedCommits.isNotEmpty) {
        print('  Unpushed commits:');
        for (final commit in status.unpushedCommits) {
          print('    > $commit');
        }
      }
    }
  }

  void _printUsage(ArgParser parser) {
    printUsageHeader();
    print('');
    print('WHAT IT DOES:');
    print('  Checks the git status of all repositories in the workspace.');
    print('  For each repo shows: branch, uncommitted changes, unpushed commits.');
    print('');
    print('COMMANDS EXECUTED:');
    print('  git fetch origin              (default, skip with --no-fetch)');
    print('  git status --porcelain        (check for uncommitted changes)');
    print('  git rev-list @{u}..HEAD       (check for unpushed commits)');
    print('');
    print('WHEN TO USE:');
    print('  - Before starting work to see remote changes');
    print('  - Before committing to verify what will be committed');
    print('  - To get an overview of all repo states at once');
    print('');
    print('Traversal: Defaults to inner-first (-i). Can override with -o.');
    print('');
    print('COMMAND OPTIONS:');
    print('  -d, --details     Show file-level details (staged/unstaged/untracked files)');
    print('  --no-fetch        Skip fetching from remote (faster, but may miss remote changes)');
    print('  --stash           Include count of stashed changes');
    print('');
    print('STANDARD OPTIONS:');
    print(parser.usage);
    print('');
    print('EXAMPLES:');
    print('  gitstatus                     # Check all repos (fetches first)');
    print('  gitstatus --no-fetch          # Quick check without fetching');
    print('  gitstatus -d                  # Show file-by-file details');
    print('  gitstatus --stash             # Also show stash counts');
    print('');
    print('VIA BUILDKIT:');
    print('  bk :gitstatus                 # Uses default inner-first');
    print('  bk :gitstatus -o              # Override to outer-first');
  }
}

class _RepoStatus {
  final String path;
  final String name;
  final String branch;
  final List<String> stagedFiles;
  final List<String> unstagedFiles;
  final List<String> untrackedFiles;
  final List<String> unpushedCommits;
  final int stashCount;

  _RepoStatus({
    required this.path,
    required this.name,
    required this.branch,
    this.stagedFiles = const [],
    this.unstagedFiles = const [],
    this.untrackedFiles = const [],
    this.unpushedCommits = const [],
    this.stashCount = 0,
  });
}
