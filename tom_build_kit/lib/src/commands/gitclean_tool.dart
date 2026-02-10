import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';

import 'tool_base.dart';

/// Git clean tool - cleans untracked files across all repositories.
///
/// Uses inner-first traversal (safer to clean submodules before parent).
class GitCleanTool extends ToolBase {
  @override
  String get toolKey => 'gitclean';

  @override
  String get toolDescription =>
      'Clean untracked files across all repositories';

  /// If true, auto-inject --inner-first-git when running standalone.
  bool autoInnerFirst = false;

  @override
  void addToolOptions(ArgParser parser) {
    parser
      ..addFlag('force',
          abbr: 'f',
          negatable: false,
          help: 'Actually remove files (required)')
      ..addFlag('directories',
          abbr: 'd',
          negatable: false,
          help: 'Remove untracked directories too')
      ..addFlag('ignored',
          abbr: 'x',
          negatable: false,
          help: 'Remove ignored files too')
      ..addFlag('interactive',
          abbr: 'i',
          negatable: false,
          help: 'Interactive mode')
      ..addMultiOption('exclude',
          abbr: 'e',
          help: 'Exclude patterns')
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
      print('Error: gitclean requires --inner-first-git (-i) or --outer-first-git (-o)');
      return false;
    }

    verbose = results['verbose'] as bool;
    dryRun = results['dry-run'] as bool;
    final force = results['force'] as bool;
    final directories = results['directories'] as bool;
    final ignored = results['ignored'] as bool;
    final interactive = results['interactive'] as bool;
    final excludePatterns = results['exclude'] as List<String>;
    final listMode = results['list'] as bool;

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

    // Build clean command
    final gitArgs = ['clean'];
    if (dryRun || !force) gitArgs.add('-n'); // Dry run if not force
    if (force && !dryRun) gitArgs.add('-f');
    if (directories) gitArgs.add('-d');
    if (ignored) gitArgs.add('-x');
    if (interactive && !dryRun) gitArgs.add('-i');
    for (final pattern in excludePatterns) {
      gitArgs.addAll(['-e', pattern]);
    }

    if (!force && !dryRun) {
      print('Showing what would be cleaned (use --force to actually clean):');
      print('');
    }

    var allSuccess = true;

    for (final repoPath in repos) {
      final relPath = p.relative(repoPath, from: executionRoot);
      
      if (!await _runGit(repoPath, gitArgs, relPath)) {
        allSuccess = false;
      }
    }

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
    print('$relPath: git ${args.join(' ')}');
    try {
      final result = await Process.run('git', args, workingDirectory: repoPath);
      final stdout = result.stdout.toString().trim();
      if (stdout.isNotEmpty) {
        for (final line in stdout.split('\n')) {
          print('  $line');
        }
      }
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
    print('WHAT IT DOES:');
    print('  Removes untracked files from all repositories.');
    print('  Default: DRY RUN showing what would be removed. Requires -f to actually delete.');
    print('');
    print('COMMANDS EXECUTED:');
    print('  git clean -n                 (default, dry run preview)');
    print('  git clean -f                 (with -f, remove untracked files)');
    print('  git clean -f -d              (with -d, also remove directories)');
    print('  git clean -f -d -x           (with -x, also remove ignored files)');
    print('');
    print('WHEN TO USE:');
    print('  - Remove build artifacts and generated files');
    print('  - Clean up after experiments');
    print('  - Reset to pristine state (with -x)');
    print('');
    print('Traversal: Fixed to inner-first (sub-repos cleaned before parents).');
    print('           Do NOT specify -i/-o flags via buildkit.');
    print('');
    print('COMMAND OPTIONS:');
    print('  -f, --force            Actually remove files (REQUIRED to delete).');
    print('                         Without -f, only shows what would be removed.');
    print('  -d, --directories      Also remove untracked directories.');
    print('  -x, --ignored          Also remove files ignored by .gitignore.');
    print('                         Includes build/, .dart_tool/, etc.');
    print('  -i, --interactive      Interactive mode: confirm each deletion.');
    print('  -e, --exclude <pat>    Exclude files matching pattern from removal.');
    print('');
    print('SAFETY:');
    print('  - Always run WITHOUT -f first to see what will be removed');
    print('  - Removed files are PERMANENTLY DELETED (not in git, not in trash)');
    print('');
    print('STANDARD OPTIONS:');
    print(parser.usage);
    print('');
    print('EXAMPLES:');
    print('  gitclean                       # Preview what would be removed');
    print('  gitclean -f                    # Remove untracked files');
    print('  gitclean -f -d                 # Remove files and directories');
    print('  gitclean -f -d -x              # Remove everything including ignored');
    print('  gitclean -f -e "*.log"         # Remove but keep .log files');
    print('');
    print('VIA BUILDKIT:');
    print('  bk :gitclean');
    print('  bk :gitclean -f -d');
  }
}
