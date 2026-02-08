import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'tool_base.dart';
import 'versioner_tool.dart';

/// Version bump tool - bumps pubspec.yaml versions across projects.
///
/// Increases the patch version by default for every project. Projects
/// can be selectively assigned minor or major bumps via `--minor` and
/// `--major` options. After bumping, optionally runs the versioner tool
/// to regenerate version.g.dart files (with `--versioner`).
///
/// The build counter (tom_build_state.json) is reset to 0 for each
/// bumped project, so the first versioner run after a bump starts at 1.
///
/// ## Usage
///
/// ```bash
/// # Bump all projects in workspace (patch by default)
/// versionbump -s . -r
///
/// # Bump with minor for specific projects, major for others
/// versionbump -s . -r --minor tom_core,tom_basics --major tom_d4rt
///
/// # Bump and regenerate version files
/// versionbump -s . -r --versioner
///
/// # Dry run to see what would change
/// versionbump -s . -r --dry-run
/// ```
class VersionBumpTool extends ToolBase {
  @override
  String get toolKey => 'versionbump';

  @override
  String get toolDescription =>
      'Bump pubspec.yaml versions across projects';

  @override
  void addToolOptions(ArgParser parser) {
    parser
      ..addMultiOption('minor',
          help: 'Projects to bump minor version (comma-separated or repeated)')
      ..addMultiOption('major',
          help: 'Projects to bump major version (comma-separated or repeated)')
      ..addFlag('versioner',
          abbr: 'v',
          negatable: false,
          help: 'Run versioner after bumping to regenerate version files');
  }

  @override
  bool isToolProject(String dirPath) {
    // Any project with a pubspec.yaml is a valid bump target
    return File('$dirPath/pubspec.yaml').existsSync();
  }

  @override
  Future<bool> run(List<String> args) async {
    if (checkVersionArg(args)) return true;

    final parser = createParser();
    ArgResults results;

    try {
      results = parser.parse(args);
    } catch (e) {
      print('Error: $e');
      _printUsage(parser);
      return false;
    }

    if (results['help'] as bool) {
      _printUsage(parser);
      return true;
    }

    verbose = results['verbose'] as bool;
    dryRun = results['dry-run'] as bool;
    final listMode = results['list'] as bool;
    final showMode = results['show'] as bool;

    // Parse minor/major project lists (flatten comma-separated values)
    final minorProjects = _expandProjectList(results['minor'] as List<String>);
    final majorProjects = _expandProjectList(results['major'] as List<String>);
    final runVersioner = results['versioner'] as bool;

    final basePath = Directory.current.path;

    // Validate paths
    if (!validateAndEnforcePaths(
      scan: results['scan'] as String?,
      project: results['project'] as String?,
      basePath: basePath,
    )) {
      return false;
    }

    // Find projects
    final projects = await findProjects(
      project: results['project'] as String?,
      scan: results['scan'] as String?,
      recursive: results['recursive'] as bool,
      exclude: results['exclude'] as List<String>,
      excludeProjects: results['exclude-projects'] as List<String>,
      recursionExclude: results['recursion-exclude'] as List<String>,
      basePath: basePath,
    );

    if (listMode) {
      print('Projects with pubspec.yaml:');
      for (final project in projects) {
        if (isToolProject(project)) {
          print('  ${p.relative(project, from: basePath)}');
        }
      }
      return true;
    }

    if (showMode) {
      for (final project in projects) {
        final version = _readCurrentVersion(project);
        if (version != null) {
          final name = p.basename(project);
          final bumpType = _determineBumpType(
              name, project, minorProjects, majorProjects);
          print('  ${p.relative(project, from: basePath)}: '
              '$version → ${_bumpVersionString(version, bumpType)} ($bumpType)');
        }
      }
      return true;
    }

    // Process each project
    var success = true;
    var bumped = 0;
    var skipped = 0;

    for (final projectPath in projects) {
      if (!isToolProject(projectPath)) {
        skipped++;
        continue;
      }

      final projectName = p.basename(projectPath);
      final bumpType = _determineBumpType(
          projectName, projectPath, minorProjects, majorProjects);

      final result = await _bumpProject(projectPath, bumpType, basePath);
      if (result) {
        bumped++;
      } else {
        success = false;
      }
    }

    if (bumped > 0 || skipped > 0) {
      print('');
      print('Version bump summary: $bumped bumped, $skipped skipped');
    }

    // Run versioner if requested
    if (runVersioner && success) {
      print('');
      print('________ Running versioner');
      print('');

      final versionerTool = VersionerTool()
        ..verbose = verbose
        ..dryRun = dryRun;

      // Build versioner args from the same scan/project/recursive options
      final versionerArgs = <String>[];
      final scan = results['scan'] as String?;
      final project = results['project'] as String?;
      final recursive = results['recursive'] as bool;

      if (scan != null) {
        versionerArgs.addAll(['-s', scan]);
      }
      if (project != null) {
        versionerArgs.addAll(['-p', project]);
      }
      if (recursive) {
        versionerArgs.add('-r');
      }
      if (verbose) {
        versionerArgs.add('-v');
      }
      if (dryRun) {
        versionerArgs.add('-n');
      }
      for (final exclude in results['exclude'] as List<String>) {
        versionerArgs.addAll(['-x', exclude]);
      }

      final versionerResult = await versionerTool.run(versionerArgs);
      if (!versionerResult) {
        success = false;
      }
    }

    return success;
  }

  /// Expand a list of project arguments, splitting comma-separated values.
  ///
  /// Input: `['tom_core,tom_basics', 'tom_d4rt']`
  /// Output: `{'tom_core', 'tom_basics', 'tom_d4rt'}`
  Set<String> _expandProjectList(List<String> args) {
    final result = <String>{};
    for (final arg in args) {
      for (final name in arg.split(',')) {
        final trimmed = name.trim();
        if (trimmed.isNotEmpty) result.add(trimmed);
      }
    }
    return result;
  }

  /// Determine bump type for a project based on minor/major lists.
  ///
  /// Matches by project folder name or the full relative path.
  _BumpType _determineBumpType(
    String projectName,
    String projectPath,
    Set<String> minorProjects,
    Set<String> majorProjects,
  ) {
    if (_matchesProjectList(projectName, projectPath, majorProjects)) {
      return _BumpType.major;
    }
    if (_matchesProjectList(projectName, projectPath, minorProjects)) {
      return _BumpType.minor;
    }
    return _BumpType.patch;
  }

  /// Check if a project matches any entry in a project list.
  ///
  /// Matches against the folder name and also checks if any list entry
  /// is a suffix of the project path (e.g., 'xternal/tom_module_basics/tom_build_kit').
  bool _matchesProjectList(
    String projectName,
    String projectPath,
    Set<String> projectList,
  ) {
    if (projectList.contains(projectName)) return true;
    for (final pattern in projectList) {
      if (projectPath.endsWith(pattern)) return true;
    }
    return false;
  }

  /// Read the current version from pubspec.yaml.
  String? _readCurrentVersion(String projectPath) {
    final pubspecFile = File('$projectPath/pubspec.yaml');
    if (!pubspecFile.existsSync()) return null;

    try {
      final content = pubspecFile.readAsStringSync();
      final yaml = loadYaml(content) as YamlMap?;
      return yaml?['version']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Bump the version in a project's pubspec.yaml.
  Future<bool> _bumpProject(
    String projectPath,
    _BumpType bumpType,
    String basePath,
  ) async {
    final pubspecFile = File('$projectPath/pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      print('  Error: No pubspec.yaml in ${p.relative(projectPath, from: basePath)}');
      return false;
    }

    try {
      final content = pubspecFile.readAsStringSync();
      final yaml = loadYaml(content) as YamlMap?;
      if (yaml == null || !yaml.containsKey('version')) {
        if (verbose) {
          print('  Skipping ${p.basename(projectPath)}: no version field');
        }
        return true;
      }

      final currentVersion = yaml['version'].toString();
      final newVersion = _bumpVersionString(currentVersion, bumpType);

      if (dryRun) {
        print('  [DRY RUN] ${p.basename(projectPath)}: '
            '$currentVersion → $newVersion ($bumpType)');
        return true;
      }

      // Update pubspec.yaml (preserve formatting, just replace the version line)
      final newContent = _updateVersionInYaml(content, newVersion);
      pubspecFile.writeAsStringSync(newContent);

      // Reset build counter
      _resetBuildCounter(projectPath);

      print('  ${p.basename(projectPath)}: $currentVersion → $newVersion ($bumpType)');
      return true;
    } catch (e) {
      print('  Error bumping ${p.basename(projectPath)}: $e');
      return false;
    }
  }

  /// Bump a version string according to the bump type.
  ///
  /// Parses `major.minor.patch` (ignoring any pre-release or build metadata),
  /// bumps the appropriate component, and returns the new version string.
  String _bumpVersionString(String version, _BumpType type) {
    // Strip any pre-release suffix or build metadata for parsing
    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)').firstMatch(version);
    if (match == null) return version; // Can't parse, return unchanged

    final major = int.parse(match.group(1)!);
    final minor = int.parse(match.group(2)!);
    final patch = int.parse(match.group(3)!);

    switch (type) {
      case _BumpType.major:
        return '${major + 1}.0.0';
      case _BumpType.minor:
        return '$major.${minor + 1}.0';
      case _BumpType.patch:
        return '$major.$minor.${patch + 1}';
    }
  }

  /// Update the version field in YAML content while preserving formatting.
  String _updateVersionInYaml(String content, String newVersion) {
    final versionRegex = RegExp(r'^version:\s*[\S]+', multiLine: true);
    return content.replaceFirst(versionRegex, 'version: $newVersion');
  }

  /// Reset the build counter in tom_build_state.json to 0.
  void _resetBuildCounter(String projectPath) {
    final stateFile = File('$projectPath/tom_build_state.json');
    try {
      stateFile.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'buildNumber': 0,
          'lastBuild': DateTime.now().toUtc().toIso8601String(),
          'lastVersionBump': DateTime.now().toUtc().toIso8601String(),
        }),
      );
      if (verbose) print('    Build counter reset to 0');
    } catch (e) {
      if (verbose) print('    Warning: Could not reset build counter: $e');
    }
  }

  void _printUsage(ArgParser parser) {
    print('Version Bump Tool - $toolDescription');
    print('');
    print('Usage: versionbump [options]');
    print('       buildkit :versionbump [options]');
    print('       dart run tom_build_kit:versionbump [options]');
    print('       versionbump version');
    print('');
    print('Options:');
    print(parser.usage);
    print('');
    print('Behavior:');
    print('  - All projects get a patch bump by default');
    print('  - Use --minor to specify projects for minor bump');
    print('  - Use --major to specify projects for major bump');
    print('  - Build counter (tom_build_state.json) is reset to 0');
    print('  - Use --versioner to regenerate version.g.dart files after bump');
    print('');
    print('Examples:');
    print('  versionbump -s . -r                        # Patch bump all');
    print('  versionbump -s . -r -v                     # Bump all + versioner');
    print('  versionbump -s . -r --minor tom_core       # Minor for tom_core');
    print('  versionbump -s . -r --minor tom_core,tom_basics --major tom_d4rt');
    print('  versionbump --project tom_build_kit         # Bump single project');
    print('  versionbump -s . -r -n                     # Dry run');
  }
}

/// The type of version bump.
enum _BumpType {
  major,
  minor,
  patch;

  @override
  String toString() => name;
}
