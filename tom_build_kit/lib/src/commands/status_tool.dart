import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';

import '../version.versioner.dart';
import 'tool_base.dart';

/// Status information for a buildkit tool binary.
class ToolStatus {
  final String name;
  final String? version;
  final String? buildNumber;
  final String? gitCommit;
  final String? buildTime;
  final String? dartSdkVersion;
  final bool available;
  final bool conformant;
  final String? error;

  ToolStatus({
    required this.name,
    this.version,
    this.buildNumber,
    this.gitCommit,
    this.buildTime,
    this.dartSdkVersion,
    this.available = true,
    this.conformant = true,
    this.error,
  });

  /// Whether this tool's version matches the source version.
  bool matchesSource(String sourceVersion, int sourceBuildNumber, String sourceCommit) {
    return version == sourceVersion &&
        buildNumber == sourceBuildNumber.toString() &&
        gitCommit == sourceCommit;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'available': available,
        'conformant': conformant,
        if (version != null) 'version': version,
        if (buildNumber != null) 'buildNumber': buildNumber,
        if (gitCommit != null) 'gitCommit': gitCommit,
        if (buildTime != null) 'buildTime': buildTime,
        if (dartSdkVersion != null) 'dartSdkVersion': dartSdkVersion,
        if (error != null) 'error': error,
      };
}

/// Git status information for a repository.
class GitRepoStatus {
  final String path;
  final String name;
  final String branch;
  final List<String> stagedFiles;
  final List<String> unstagedFiles;
  final List<String> untrackedFiles;
  final List<String> unpushedCommits;

  GitRepoStatus({
    required this.path,
    required this.name,
    required this.branch,
    this.stagedFiles = const [],
    this.unstagedFiles = const [],
    this.untrackedFiles = const [],
    this.unpushedCommits = const [],
  });

  bool get hasChanges =>
      stagedFiles.isNotEmpty ||
      unstagedFiles.isNotEmpty ||
      untrackedFiles.isNotEmpty;

  bool get hasUnpushed => unpushedCommits.isNotEmpty;

  int get totalChanges =>
      stagedFiles.length + unstagedFiles.length + untrackedFiles.length;

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'branch': branch,
        'hasChanges': hasChanges,
        'hasUnpushed': hasUnpushed,
        'staged': stagedFiles,
        'unstaged': unstagedFiles,
        'untracked': untrackedFiles,
        'unpushedCommits': unpushedCommits,
      };
}

/// Overall status result.
class StatusResult {
  final String sourceVersion;
  final int sourceBuildNumber;
  final String sourceCommit;
  final String sourceBuildTime;
  final String sourceDartSdk;
  final List<ToolStatus> tools;
  final List<GitRepoStatus> repos;
  final int commitsSinceOldest;
  final String? oldestToolCommit;

  StatusResult({
    required this.sourceVersion,
    required this.sourceBuildNumber,
    required this.sourceCommit,
    required this.sourceBuildTime,
    required this.sourceDartSdk,
    this.tools = const [],
    this.repos = const [],
    this.commitsSinceOldest = 0,
    this.oldestToolCommit,
  });

  Map<String, dynamic> toJson() => {
        'source': {
          'version': sourceVersion,
          'buildNumber': sourceBuildNumber,
          'gitCommit': sourceCommit,
          'buildTime': sourceBuildTime,
          'dartSdkVersion': sourceDartSdk,
        },
        'tools': tools.map((t) => t.toJson()).toList(),
        'repos': repos.map((r) => r.toJson()).toList(),
        'commitsSinceOldest': commitsSinceOldest,
        if (oldestToolCommit != null) 'oldestToolCommit': oldestToolCommit,
      };
}

/// Status tool - shows buildkit version, binary status, and git state.
///
/// Displays:
/// - Source version (from version.versioner.dart)
/// - Binary currency for all buildkit tools
/// - Git status (pending changes, unpushed commits)
///
/// This is an internal command, not a standalone executable.
class StatusTool extends ToolBase {
  /// List of buildkit tools to check.
  static const _toolNames = [
    'buildkit',
    'buildsorter',
    'bumpversion',
    'cleanup',
    'compiler',
    'dependencies',
    'gitbranch',
    'gitcheckout',
    'gitclean',
    'gitcommit',
    'gitcompare',
    'gitmerge',
    'gitprune',
    'gitpull',
    'gitrebase',
    'gitreset',
    'gitsquash',
    'gitstash',
    'gitstatus',
    'gitsync',
    'gittag',
    'gitunstash',
    'publisher',
    'runner',
    'versioner',
  ];

  @override
  String get toolKey => 'status';

  @override
  String get toolDescription =>
      'Show buildkit version, binary status, and git state';

  @override
  void addToolOptions(ArgParser parser) {
    parser
      ..addFlag('json',
          negatable: false, help: 'Output in JSON format')
      ..addFlag('skip-binaries',
          negatable: false, help: 'Skip binary version checks')
      ..addFlag('skip-git',
          negatable: false, help: 'Skip git status checks');
  }

  @override
  bool isToolProject(String dirPath) {
    // Status tool checks git repos
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

    final parser = createParser();
    ArgResults results;
    WorkspaceNavigationArgs navArgs;
    String executionRoot;

    try {
      (results, navArgs, executionRoot) =
          parseArgsWithExecutionMode(parser, args);
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

    verbose = results['verbose'] as bool;
    dryRun = results['dry-run'] as bool;
    final jsonOutput = results['json'] as bool;
    final skipBinaries = results['skip-binaries'] as bool;
    final skipGit = results['skip-git'] as bool;

    // Collect status information
    final result = await _collectStatus(
      executionRoot: executionRoot,
      navArgs: navArgs,
      skipBinaries: skipBinaries,
      skipGit: skipGit,
    );

    if (jsonOutput) {
      print(const JsonEncoder.withIndent('  ').convert(result.toJson()));
    } else {
      _printStatus(result, verbose: verbose);
    }

    return true;
  }

  Future<StatusResult> _collectStatus({
    required String executionRoot,
    required WorkspaceNavigationArgs navArgs,
    required bool skipBinaries,
    required bool skipGit,
  }) async {
    // Get tool status
    List<ToolStatus> tools = [];
    String? oldestCommit;

    if (!skipBinaries) {
      for (final toolName in _toolNames) {
        final status = await _checkToolVersion(toolName);
        tools.add(status);

        // Track oldest commit for comparison
        if (status.conformant && status.gitCommit != null) {
          // We'll use the first one as reference for simplicity
          // In a more sophisticated implementation, we could compare commits
          oldestCommit ??= status.gitCommit;
        }
      }
    }

    // Get git repo status
    List<GitRepoStatus> repos = [];
    int commitsSinceOldest = 0;

    if (!skipGit) {
      // Find git repos based on navigation args
      if (navArgs.innerFirstGit || navArgs.outerFirstGit) {
        final projects = await findProjectsFromNavArgs(
          navArgs,
          basePath: executionRoot,
        );
        for (final projectPath in projects) {
          final status = await _analyzeGitRepo(projectPath);
          if (status != null) {
            repos.add(status);
          }
        }
      } else {
        // Default: find the git root starting from execution root
        final gitRoot = await _findGitRoot(executionRoot);
        if (gitRoot != null) {
          final status = await _analyzeGitRepo(gitRoot);
          if (status != null) {
            repos.add(status);
          }
        }
      }

      // Count commits since oldest tool
      if (oldestCommit != null && repos.isNotEmpty) {
        commitsSinceOldest =
            await _countCommitsSince(repos.first.path, oldestCommit);
      }
    }

    return StatusResult(
      sourceVersion: BuildkitVersionInfo.version,
      sourceBuildNumber: BuildkitVersionInfo.buildNumber,
      sourceCommit: BuildkitVersionInfo.gitCommit,
      sourceBuildTime: BuildkitVersionInfo.buildTime,
      sourceDartSdk: BuildkitVersionInfo.dartSdkVersion,
      tools: tools,
      repos: repos,
      commitsSinceOldest: commitsSinceOldest,
      oldestToolCommit: oldestCommit,
    );
  }

  /// Find the git repository root starting from [startPath].
  ///
  /// Walks up the directory tree until a .git directory/file is found.
  /// Returns null if no git repo is found.
  Future<String?> _findGitRoot(String startPath) async {
    var current = startPath;
    while (true) {
      final gitDir = Directory(p.join(current, '.git'));
      final gitFile = File(p.join(current, '.git'));
      if (gitDir.existsSync() || gitFile.existsSync()) {
        return current;
      }
      final parent = p.dirname(current);
      if (parent == current) {
        // Reached root
        return null;
      }
      current = parent;
    }
  }

  /// Check a tool's version by running `<tool> --version`.
  ///
  /// Parses the expected format:
  /// `<tool> <version>+<build>.<commit> (<timestamp>) [Dart <sdk>]`
  Future<ToolStatus> _checkToolVersion(String toolName) async {
    try {
      final result = await ProcessRunner.run(toolName, ['--version']);

      if (result.exitCode != 0) {
        return ToolStatus(
          name: toolName,
          available: false,
          conformant: false,
          error: 'Exit code ${result.exitCode}',
        );
      }

      final output = result.stdout.trim();
      return _parseVersionOutput(toolName, output);
    } on ProcessException {
      return ToolStatus(
        name: toolName,
        available: false,
        conformant: false,
        error: 'Not found in PATH',
      );
    } catch (e) {
      return ToolStatus(
        name: toolName,
        available: false,
        conformant: false,
        error: e.toString(),
      );
    }
  }

  /// Parse version output in the expected format.
  ///
  /// Expected: `<tool> <version>+<build>.<commit> (<timestamp>) [Dart <sdk>]`
  /// Example: `versioner 1.5.0+10.c71e193 (2026-02-10T12:53:24.233913Z) [Dart 3.10.4]`
  /// Also handles multi-word names like "Build Kit 1.5.0+10..."
  ToolStatus _parseVersionOutput(String toolName, String output) {
    // Pattern: <name (can have spaces)> <version>+<build>.<commit> (<time>) [Dart <sdk>]
    // Use .+? to match tool name (non-greedy to stop before version)
    final regex = RegExp(
      r'^(.+?)\s+(\d+\.\d+\.\d+)\+(\d+)\.([a-f0-9]+)\s+\(([^)]+)\)\s+\[Dart\s+([^\]]+)\]$',
    );

    final match = regex.firstMatch(output);
    if (match == null) {
      // Try to extract what we can
      return _parsePartialVersion(toolName, output);
    }

    return ToolStatus(
      name: toolName,
      version: match.group(2),
      buildNumber: match.group(3),
      gitCommit: match.group(4),
      buildTime: match.group(5),
      dartSdkVersion: match.group(6),
      available: true,
      conformant: true,
    );
  }

  /// Try to extract partial version info from non-conformant output.
  ToolStatus _parsePartialVersion(String toolName, String output) {
    String? version;
    String? buildNumber;
    String? gitCommit;

    // Try to find version pattern (x.y.z)
    final versionMatch = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(output);
    if (versionMatch != null) {
      version = versionMatch.group(1);
    }

    // Try to find build number (+N)
    final buildMatch = RegExp(r'\+(\d+)').firstMatch(output);
    if (buildMatch != null) {
      buildNumber = buildMatch.group(1);
    }

    // Try to find git commit (7-char hex after .)
    final commitMatch = RegExp(r'\.([a-f0-9]{7})').firstMatch(output);
    if (commitMatch != null) {
      gitCommit = commitMatch.group(1);
    }

    return ToolStatus(
      name: toolName,
      version: version,
      buildNumber: buildNumber,
      gitCommit: gitCommit,
      available: true,
      conformant: false,
      error: 'Non-conformant version format',
    );
  }

  /// Analyze a git repository for status.
  Future<GitRepoStatus?> _analyzeGitRepo(String repoPath) async {
    final gitDir = Directory(p.join(repoPath, '.git'));
    final gitFile = File(p.join(repoPath, '.git'));
    if (!gitDir.existsSync() && !gitFile.existsSync()) {
      return null;
    }

    final name = p.basename(repoPath);

    // Get current branch
    String branch;
    try {
      final result = await ProcessRunner.run(
        'git',
        ['rev-parse', '--abbrev-ref', 'HEAD'],
        workingDirectory: repoPath,
      );
      branch = result.stdout.trim();
    } catch (_) {
      branch = 'unknown';
    }

    // Get status (staged, unstaged, untracked)
    List<String> stagedFiles = [];
    List<String> unstagedFiles = [];
    List<String> untrackedFiles = [];

    try {
      final result = await ProcessRunner.run(
        'git',
        ['status', '--porcelain'],
        workingDirectory: repoPath,
      );
      final lines =
          result.stdout.split('\n').where((l) => l.isNotEmpty);
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
      final result = await ProcessRunner.run(
        'git',
        ['log', '@{u}..HEAD', '--oneline'],
        workingDirectory: repoPath,
      );
      if (result.exitCode == 0) {
        unpushedCommits = result.stdout
            .split('\n')
            .where((l) => l.isNotEmpty)
            .toList();
      }
    } catch (_) {
      // No upstream or other error
    }

    return GitRepoStatus(
      path: repoPath,
      name: name,
      branch: branch,
      stagedFiles: stagedFiles,
      unstagedFiles: unstagedFiles,
      untrackedFiles: untrackedFiles,
      unpushedCommits: unpushedCommits,
    );
  }

  /// Count commits since a given commit hash.
  Future<int> _countCommitsSince(String repoPath, String commitHash) async {
    try {
      final result = await ProcessRunner.run(
        'git',
        ['rev-list', '--count', '$commitHash..HEAD'],
        workingDirectory: repoPath,
      );
      if (result.exitCode == 0) {
        return int.tryParse(result.stdout.trim()) ?? 0;
      }
    } catch (_) {
      // Ignore
    }
    return 0;
  }

  void _printStatus(StatusResult result, {required bool verbose}) {
    // Source Version
    print('╔═══════════════════════════════════════════════════════════════╗');
    print('║                     BUILDKIT STATUS                           ║');
    print('╚═══════════════════════════════════════════════════════════════╝');
    print('');
    print('Source Version');
    print('──────────────');
    print('  Version:      ${result.sourceVersion}+${result.sourceBuildNumber}');
    print('  Git Commit:   ${result.sourceCommit}');
    print('  Build Time:   ${result.sourceBuildTime}');
    print('  Dart SDK:     ${result.sourceDartSdk}');
    print('');

    // Binary Status
    if (result.tools.isNotEmpty) {
      print('Binary Status');
      print('─────────────');

      final current = <ToolStatus>[];
      final outdated = <ToolStatus>[];
      final unavailable = <ToolStatus>[];
      final nonConformant = <ToolStatus>[];

      for (final tool in result.tools) {
        if (!tool.available) {
          unavailable.add(tool);
        } else if (!tool.conformant) {
          nonConformant.add(tool);
        } else if (tool.matchesSource(
          result.sourceVersion,
          result.sourceBuildNumber,
          result.sourceCommit,
        )) {
          current.add(tool);
        } else {
          outdated.add(tool);
        }
      }

      if (current.isNotEmpty) {
        print('  ✓ Current (${current.length}): ${current.map((t) => t.name).join(', ')}');
      }
      if (outdated.isNotEmpty) {
        print('  ⚠ Outdated (${outdated.length}):');
        for (final tool in outdated) {
          print('    ${tool.name}: ${tool.version}+${tool.buildNumber}.${tool.gitCommit}');
        }
      }
      if (unavailable.isNotEmpty) {
        print('  ✗ Unavailable (${unavailable.length}): ${unavailable.map((t) => t.name).join(', ')}');
      }
      if (nonConformant.isNotEmpty) {
        print('  ? Non-conformant (${nonConformant.length}):');
        for (final tool in nonConformant) {
          print('    ${tool.name}: ${tool.error}');
        }
      }
      print('');
    }

    // Git Status
    if (result.repos.isNotEmpty) {
      print('Git Status');
      print('──────────');

      final reposWithChanges =
          result.repos.where((r) => r.hasChanges).toList();
      final reposWithUnpushed =
          result.repos.where((r) => r.hasUnpushed).toList();

      if (reposWithChanges.isEmpty && reposWithUnpushed.isEmpty) {
        print('  All repositories are clean and up to date.');
      } else {
        // Pending Changes
        if (reposWithChanges.isNotEmpty) {
          final totalFiles =
              reposWithChanges.fold<int>(0, (sum, r) => sum + r.totalChanges);
          print('  Pending Changes: ${reposWithChanges.length} repo(s), $totalFiles file(s)');

          if (verbose) {
            for (final repo in reposWithChanges) {
              print('    ${repo.name} (${repo.branch}):');
              for (final f in repo.stagedFiles) {
                print('      [staged] $f');
              }
              for (final f in repo.unstagedFiles) {
                print('      [modified] $f');
              }
              for (final f in repo.untrackedFiles) {
                print('      [untracked] $f');
              }
            }
          } else {
            print('    (Specify --verbose to see the $totalFiles modified files)');
          }
          print('');
        }

        // Unpushed Commits
        if (reposWithUnpushed.isNotEmpty) {
          final totalCommits = reposWithUnpushed.fold<int>(
              0, (sum, r) => sum + r.unpushedCommits.length);
          print('  Unpushed Commits: ${reposWithUnpushed.length} repo(s), $totalCommits commit(s)');

          if (verbose) {
            for (final repo in reposWithUnpushed) {
              print('    ${repo.name} (${repo.branch}):');
              for (final commit in repo.unpushedCommits) {
                print('      $commit');
              }
            }
          } else {
            print('    (Specify --verbose to see the $totalCommits unpushed commits)');
          }
        }
      }

      if (result.commitsSinceOldest > 0 && result.oldestToolCommit != null) {
        print('');
        print('  Note: ${result.commitsSinceOldest} commit(s) since oldest binary (${result.oldestToolCommit})');
      }
    }
  }

  void _printUsage(ArgParser parser) {
    printUsageHeader();
    print('');
    print('Options:');
    print(parser.usage);
    print('');
    printNavigationHelp();
    print('');
    print('Examples:');
    print('  bk :status                 # Quick status check');
    print('  bk :status -v              # Verbose with file details');
    print('  bk :status --json          # JSON output');
    print('  bk :status -i              # Include all git repos (inner-first)');
    print('  bk :status --skip-binaries # Skip binary checks');
  }
}
