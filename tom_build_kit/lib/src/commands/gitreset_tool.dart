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
          help: 'Reset to upstream tracking branch');
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

  Future<String?> _getUpstreamRef(String repoPath) async {
    try {
      final result = await Process.run(
        'git', ['rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}'],
        workingDirectory: repoPath,
      );
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
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
    print('Traversal: Fixed to outer-first (parent repos reset before sub-repos).');
    print('           Do NOT specify -i/-o flags via buildkit.');
    print('');
    print('Options:');
    print(parser.usage);
    print('');
    print('Examples:');
    print('  gitreset -o                   # Reset to HEAD (mixed)');
    print('  gitreset -o --hard            # Hard reset to HEAD');
    print('  gitreset -o --hard -u         # Hard reset to upstream');
    print('  gitreset -o --soft --to HEAD~1  # Soft reset to previous commit');
    print('');
    print('Via buildkit (do NOT specify -i/-o):');
    print('  bk :gitreset');
    print('  bk :gitreset --hard');
  }
}
