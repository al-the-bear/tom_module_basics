import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';

import 'tool_base.dart';

/// Git reset tool - resets repositories to a specific state.
///
/// Uses outer-first traversal because the parent repo should be reset first
/// to determine which submodule commits are expected.
class GitResetTool extends ToolBase {
  @override
  String get toolKey => 'gitreset';

  @override
  String get toolDescription =>
      'Reset all repositories to a specific state';

  /// If true, auto-inject --outer-first-git when running standalone.
  bool autoOuterFirst = false;

  @override
  void addToolOptions(ArgParser parser) {
    parser
      ..addFlag('soft',
          negatable: false,
          help: 'Soft reset (keep changes staged)')
      ..addFlag('mixed',
          negatable: false,
          help: 'Mixed reset (unstage changes, keep working tree)')
      ..addFlag('hard',
          negatable: false,
          help: 'Hard reset (discard all changes)')
      ..addOption('to',
          help: 'Reset to commit/branch/tag (default: HEAD)')
      ..addFlag('upstream',
          abbr: 'u',
          negatable: false,
          help: 'Reset to upstream tracking branch')
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
      print('Error: gitreset requires --outer-first-git (-o) or --inner-first-git (-i)');
      print('');
      print('Recommended: --outer-first-git (-o)');
      print('  Reset parent first to get correct submodule references.');
      return false;
    }

    verbose = results['verbose'] as bool;
    dryRun = results['dry-run'] as bool;
    final soft = results['soft'] as bool;
    final mixed = results['mixed'] as bool;
    final hard = results['hard'] as bool;
    final resetTo = results['to'] as String?;
    final upstream = results['upstream'] as bool;
    final listMode = results['list'] as bool;

    // Validate mode options
    final modeCount = [soft, mixed, hard].where((m) => m).length;
    if (modeCount > 1) {
      print('Error: Specify only one of --soft, --mixed, or --hard');
      return false;
    }

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
    var successCount = 0;

    for (final repoPath in repos) {
      final relPath = p.relative(repoPath, from: executionRoot);
      
      // Build reset command for this repo
      final gitArgs = ['reset'];
      if (soft) gitArgs.add('--soft');
      if (mixed) gitArgs.add('--mixed');
      if (hard) gitArgs.add('--hard');
      
      if (upstream) {
        final upstreamRef = await _getUpstreamRef(repoPath);
        if (upstreamRef == null) {
          print('$relPath: no upstream configured');
          continue;
        }
        gitArgs.add(upstreamRef);
      } else if (resetTo != null) {
        gitArgs.add(resetTo);
      } else {
        gitArgs.add('HEAD');
      }

      if (!await _runGit(repoPath, gitArgs, relPath)) {
        allSuccess = false;
        continue;
      }
      successCount++;
    }

    print('');
    print('Reset $successCount repository(ies)');

    return allSuccess;
  }

  bool _hasGitTraversalFlag(List<String> args) {
    return args.contains('-i') || args.contains('--inner-first-git') ||
           args.contains('-o') || args.contains('--outer-first-git');
  }

  Future<String?> _getUpstreamRef(String repoPath) async {
    try {
      final result = await ProcessRunner.run(
        'git', ['rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}'],
        workingDirectory: repoPath,
      );
      if (result.exitCode == 0) {
        return result.stdout.trim();
      }
      return null;
    } catch (_) {
      return null;
    }
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
    print('WHAT IT DOES:');
    print('  Resets all repositories to a specific state.');
    print('  Default: --mixed reset to HEAD (unstage changes, keep files).');
    print('');
    print('COMMANDS EXECUTED:');
    print('  git reset --mixed HEAD            (default, unstage but keep changes)');
    print('  git reset --soft HEAD             (with --soft, keep staged)');
    print('  git reset --hard HEAD             (with --hard, discard everything)');
    print('  git reset --mixed origin/<branch> (with -u, reset to upstream)');
    print('');
    print('RESET MODES EXPLAINED:');
    print('  --soft    Keep changes staged. Useful to squash commits.');
    print('  --mixed   Unstage changes, keep working tree. (DEFAULT)');
    print('            Useful to redo staging decisions.');
    print('  --hard    Discard ALL changes. Working tree matches target.');
    print('            DESTRUCTIVE: Uncommitted work is LOST.');
    print('');
    print('WHEN TO USE:');
    print('  - Undo accidental staging (default --mixed)');
    print('  - Discard all local changes (--hard)');
    print('  - Sync with remote, discarding local work (--hard -u)');
    print('');
    print('Traversal: Fixed to outer-first (parent repos reset before sub-repos).');
    print('           Do NOT specify -i/-o flags via buildkit.');
    print('');
    print('COMMAND OPTIONS:');
    print('  --soft              Keep changes staged.');
    print('  --mixed             Unstage changes, keep working tree. (default)');
    print('  --hard              Discard all changes. DESTRUCTIVE.');
    print('  --to <ref>          Reset to specific commit/branch/tag (default: HEAD).');
    print('  -u, --upstream      Reset to upstream tracking branch.');
    print('');
    print('STANDARD OPTIONS:');
    print(parser.usage);
    print('');
    print('EXAMPLES:');
    print('  gitreset                      # Unstage all changes (--mixed HEAD)');
    print('  gitreset --soft               # Keep changes staged');
    print('  gitreset --hard               # Discard all local changes');
    print('  gitreset --hard -u            # Reset to upstream (discard local)');
    print('  gitreset --soft --to HEAD~1   # Undo last commit, keep changes staged');
    print('');
    print('VIA BUILDKIT:');
    print('  bk :gitreset');
    print('  bk :gitreset --hard -u');
  }
}
