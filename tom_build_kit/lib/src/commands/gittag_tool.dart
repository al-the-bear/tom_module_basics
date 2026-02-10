import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';

import 'tool_base.dart';

/// Git tag tool - creates or lists tags across all repositories.
///
/// Uses inner-first traversal because when tagging a release, you want
/// to tag submodules first so the parent repo can reference tagged versions.
class GitTagTool extends ToolBase {
  @override
  String get toolKey => 'gittag';

  @override
  String get toolDescription =>
      'Create or list tags across all repositories';

  /// If true, auto-inject --inner-first-git when running standalone.
  bool autoInnerFirst = false;

  @override
  void addToolOptions(ArgParser parser) {
    parser
      ..addOption('create',
          abbr: 'c',
          help: 'Create a new tag')
      ..addOption('message',
          abbr: 'm',
          help: 'Tag message (creates annotated tag)')
      ..addOption('delete',
          abbr: 'd',
          help: 'Delete a tag')
      ..addFlag('push',
          negatable: false,
          help: 'Push tags to remote after creating')
      ..addFlag('list-tags',
          negatable: false,
          help: 'List tags in each repo')
      ..addOption('remote',
          defaultsTo: 'origin',
          help: 'Remote name for push');
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
      print('Error: gittag requires --inner-first-git (-i) or --outer-first-git (-o)');
      print('');
      print('Recommended: --inner-first-git (-i)');
      print('  Tag submodules first so parent references tagged versions.');
      return false;
    }

    verbose = results['verbose'] as bool;
    dryRun = results['dry-run'] as bool;
    final createTag = results['create'] as String?;
    final message = results['message'] as String?;
    final deleteTag = results['delete'] as String?;
    final pushTags = results['push'] as bool;
    final listTags = results['list-tags'] as bool;
    final remote = results['remote'] as String;
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

    if (listTags) {
      for (final repoPath in repos) {
        final relPath = p.relative(repoPath, from: executionRoot);
        final tags = await _listTags(repoPath);
        print('$relPath:');
        for (final tag in tags.take(10)) {
          print('  $tag');
        }
        if (tags.length > 10) print('  ... and ${tags.length - 10} more');
      }
      return true;
    }

    var allSuccess = true;
    var successCount = 0;
    String opName;
    List<String> gitArgs;

    if (createTag != null) {
      if (message != null) {
        gitArgs = ['tag', '-a', createTag, '-m', message];
      } else {
        gitArgs = ['tag', createTag];
      }
      opName = 'create tag $createTag';
    } else if (deleteTag != null) {
      gitArgs = ['tag', '-d', deleteTag];
      opName = 'delete tag $deleteTag';
    } else {
      // Show latest tag in each repo
      for (final repoPath in repos) {
        final relPath = p.relative(repoPath, from: executionRoot);
        final latestTag = await _getLatestTag(repoPath);
        print('$relPath: ${latestTag ?? "(no tags)"}');
      }
      return true;
    }

    for (final repoPath in repos) {
      final relPath = p.relative(repoPath, from: executionRoot);
      
      if (!await _runGit(repoPath, gitArgs, relPath)) {
        allSuccess = false;
        continue;
      }
      successCount++;

      if (pushTags && createTag != null) {
        await _runGit(repoPath, ['push', remote, createTag], relPath);
      } else if (pushTags && deleteTag != null) {
        await _runGit(repoPath, ['push', remote, ':refs/tags/$deleteTag'], relPath);
      }
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

  Future<List<String>> _listTags(String repoPath) async {
    try {
      final result = await Process.run('git', ['tag', '-l', '--sort=-version:refname'],
          workingDirectory: repoPath);
      return result.stdout.toString().split('\n').where((l) => l.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  Future<String?> _getLatestTag(String repoPath) async {
    try {
      final result = await Process.run('git', ['describe', '--tags', '--abbrev=0'],
          workingDirectory: repoPath);
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
    print('Traversal: Fixed to inner-first (submodules tagged before parents).');
    print('           Do NOT specify -i/-o flags via buildkit.');
    print('');
    print('Options:');
    print(parser.usage);
    print('');
    print('Examples:');
    print('  gittag -i                         # Show latest tag per repo');
    print('  gittag -i -c v1.0.0               # Create lightweight tag');
    print('  gittag -i -c v1.0.0 -m "Release"  # Create annotated tag');
    print('  gittag -i -c v1.0.0 --push        # Create and push');
    print('  gittag -i -d v1.0.0               # Delete tag');
    print('  gittag -i --list-tags             # List all tags');
    print('');
    print('Via buildkit (do NOT specify -i/-o):');
    print('  bk :gittag');
    print('  bk :gittag -c v1.0.0 --push');
  }
}
