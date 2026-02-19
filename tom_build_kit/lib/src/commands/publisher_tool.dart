import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';
import 'package:yaml/yaml.dart';

import 'tool_base.dart';

/// Publisher tool - scans projects and shows publishing status.
///
/// For each project, displays a single-line summary of:
/// - Uncommitted changes
/// - Unpushed commits (if git repo)
/// - Path dependencies that prevent publishing
/// - Missing README.md or LICENSE
/// - publish_to: none status
class PublisherTool extends ToolBase {
  @override
  String get toolKey => 'publisher';

  @override
  String get toolDescription =>
      'Show publishing status for all projects';

  @override
  void addToolOptions(ArgParser parser) {
    parser
      ..addFlag('show-all',
          abbr: 'a',
          negatable: false,
          help: 'Show all projects, including publish_to: none')
      ..addFlag('fix',
          abbr: 'f',
          negatable: false,
          help: 'Attempt to fix common issues (future feature)');
  }

  @override
  bool isToolProject(String dirPath) {
    final pubspec = File('$dirPath/pubspec.yaml');
    return pubspec.existsSync();
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
      (results, navArgs, executionRoot) = parseArgsWithExecutionMode(parser, args);
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
    final showAll = results['show-all'] as bool;
    final listMode = results['list'] as bool;

    // Find projects using navigation args
    final projects = await findProjectsFromNavArgs(
      navArgs,
      basePath: executionRoot,
    );

    if (findProjectsError) return false;

    if (listMode) {
      print('Projects with pubspec.yaml:');
      for (final project in projects) {
        if (isToolProject(project)) {
          print('  ${p.relative(project, from: executionRoot)}');
        }
      }
      return true;
    }

    // Analyze each project
    final statuses = <_ProjectStatus>[];
    for (final projectPath in projects) {
      if (!isToolProject(projectPath)) continue;
      final status = await _analyzeProject(projectPath, executionRoot);
      statuses.add(status);
    }

    // Print results
    _printResults(statuses, showAll, executionRoot);

    return true;
  }

  Future<_ProjectStatus> _analyzeProject(String projectPath, String wsRoot) async {
    final pubspecFile = File(p.join(projectPath, 'pubspec.yaml'));
    final name = p.basename(projectPath);
    
    if (!pubspecFile.existsSync()) {
      return _ProjectStatus(
        path: projectPath,
        name: name,
        error: 'No pubspec.yaml',
      );
    }

    // Parse pubspec
    YamlMap pubspec;
    try {
      final content = pubspecFile.readAsStringSync();
      pubspec = loadYaml(content) as YamlMap;
    } catch (e) {
      return _ProjectStatus(
        path: projectPath,
        name: name,
        error: 'Invalid pubspec.yaml',
      );
    }

    final pubName = pubspec['name'] as String? ?? name;
    final publishTo = pubspec['publish_to'] as String?;
    final isNotPublished = publishTo == 'none';

    // Check for path dependencies
    final pathDeps = <String>[];
    final deps = pubspec['dependencies'] as YamlMap?;
    final devDeps = pubspec['dev_dependencies'] as YamlMap?;
    
    void checkDeps(YamlMap? depsMap) {
      if (depsMap == null) return;
      for (final entry in depsMap.entries) {
        final value = entry.value;
        if (value is YamlMap && value.containsKey('path')) {
          pathDeps.add(entry.key as String);
        }
      }
    }
    checkDeps(deps);
    checkDeps(devDeps);

    // Check for missing files
    final hasReadme = File(p.join(projectPath, 'README.md')).existsSync();
    final hasLicense = File(p.join(projectPath, 'LICENSE')).existsSync() ||
                       File(p.join(projectPath, 'LICENSE.md')).existsSync();
    final hasChangelog = File(p.join(projectPath, 'CHANGELOG.md')).existsSync();

    // Check git status
    bool? hasUncommitted;
    bool? hasUnpushed;
    
    if (_isGitRepo(projectPath)) {
      hasUncommitted = await _hasUncommittedChanges(projectPath);
      hasUnpushed = await _hasUnpushedCommits(projectPath);
    }

    return _ProjectStatus(
      path: projectPath,
      name: pubName,
      isNotPublished: isNotPublished,
      pathDependencies: pathDeps,
      hasReadme: hasReadme,
      hasLicense: hasLicense,
      hasChangelog: hasChangelog,
      hasUncommitted: hasUncommitted,
      hasUnpushed: hasUnpushed,
    );
  }

  bool _isGitRepo(String dirPath) {
    final gitPath = p.join(dirPath, '.git');
    return Directory(gitPath).existsSync() || File(gitPath).existsSync();
  }

  String? _findGitRoot(String dirPath) {
    var current = p.normalize(p.absolute(dirPath));
    final root = p.rootPrefix(current);

    while (current != root) {
      final gitPath = p.join(current, '.git');
      if (Directory(gitPath).existsSync() || File(gitPath).existsSync()) {
        return current;
      }
      current = p.dirname(current);
    }
    return null;
  }

  Future<bool> _hasUncommittedChanges(String dirPath) async {
    final gitRoot = _findGitRoot(dirPath);
    if (gitRoot == null) return false;
    
    try {
      final result = await ProcessRunner.run(
        'git',
        ['status', '--porcelain', '--', dirPath],
        workingDirectory: gitRoot,
      );
      return result.stdout.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _hasUnpushedCommits(String dirPath) async {
    final gitRoot = _findGitRoot(dirPath);
    if (gitRoot == null) return false;
    
    try {
      // Get current branch
      final branchResult = await ProcessRunner.run(
        'git',
        ['rev-parse', '--abbrev-ref', 'HEAD'],
        workingDirectory: gitRoot,
      );
      final branch = branchResult.stdout.trim();
      if (branch.isEmpty) return false;

      // Check for unpushed commits
      final result = await ProcessRunner.run(
        'git',
        ['log', branch, '--not', '--remotes', '--oneline'],
        workingDirectory: gitRoot,
      );
      return result.stdout.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _printResults(List<_ProjectStatus> statuses, bool showAll, String wsRoot) {
    for (final status in statuses) {
      final relPath = p.relative(status.path, from: wsRoot);
      
      if (status.error != null) {
        print('$relPath: ${status.error}');
        continue;
      }

      if (status.isNotPublished) {
        if (showAll) {
          print('$relPath: Not published');
        }
        continue;
      }

      final issues = <String>[];
      
      if (status.hasUncommitted == true) {
        issues.add('uncommitted');
      }
      if (status.hasUnpushed == true) {
        issues.add('unpushed');
      }
      if (status.pathDependencies.isNotEmpty) {
        final count = status.pathDependencies.length;
        issues.add('$count path dep${count > 1 ? 's' : ''}');
      }
      if (!status.hasReadme) {
        issues.add('no README');
      }
      if (!status.hasLicense) {
        issues.add('no LICENSE');
      }
      if (!status.hasChangelog) {
        issues.add('no CHANGELOG');
      }

      if (issues.isEmpty) {
        print('$relPath: Ready to publish');
      } else {
        print('$relPath: ${issues.join(', ')}');
      }
    }
  }

  void _printUsage(ArgParser parser) {
    printUsageHeader();
    print('');
    print('Options:');
    print(parser.usage);
    print('');
    printExecutionModesExplanation();
    printUsageFooter();
  }
}

class _ProjectStatus {
  final String path;
  final String name;
  final String? error;
  final bool isNotPublished;
  final List<String> pathDependencies;
  final bool hasReadme;
  final bool hasLicense;
  final bool hasChangelog;
  final bool? hasUncommitted;
  final bool? hasUnpushed;

  _ProjectStatus({
    required this.path,
    required this.name,
    this.error,
    this.isNotPublished = false,
    this.pathDependencies = const [],
    this.hasReadme = true,
    this.hasLicense = true,
    this.hasChangelog = true,
    this.hasUncommitted,
    this.hasUnpushed,
  });
}
