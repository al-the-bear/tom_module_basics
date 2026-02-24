import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';

/// Result of a pub get execution for a single project.
class PubGetResult {
  /// The project path (relative to workspace).
  final String projectPath;

  /// The project name from pubspec.yaml.
  final String projectName;

  /// Whether the command succeeded.
  final bool success;

  /// Standard output from the command.
  final String stdout;

  /// Standard error from the command.
  final String stderr;

  /// Exit code from the command.
  final int exitCode;

  /// Whether the output indicates updates are available.
  bool get hasUpdates => stdout.contains('available)') && !hasUpgrades;

  /// Whether the output indicates incompatible upgrades are available.
  bool get hasUpgrades =>
      stdout.contains('incompatible with dependency constraints');

  /// Whether there was an error.
  bool get hasError => !success || stderr.isNotEmpty;

  PubGetResult({
    required this.projectPath,
    required this.projectName,
    required this.success,
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });
}

/// Executes `dart pub get` across multiple projects.
///
/// Collects all output and displays it at the end, with filtering options.
class PubGetCommand {
  final String rootPath;
  final bool verbose;

  PubGetCommand({required this.rootPath, required this.verbose});

  /// Parse command arguments.
  static ArgParser get parser => ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
    ..addFlag(
      'errors',
      abbr: 'e',
      negatable: false,
      help: 'Only show projects with errors',
    )
    ..addFlag(
      'updates',
      abbr: 'u',
      negatable: false,
      help: 'Only show projects with available updates',
    )
    ..addFlag(
      'upgrades',
      abbr: 'U',
      negatable: false,
      help: 'Only show projects with incompatible upgrades',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Show detailed output',
    )
    ..addFlag(
      'recursive',
      abbr: 'R',
      negatable: true,
      defaultsTo: false,
      help: 'Scan directories recursively (use --no-recursive to disable)',
    )
    ..addOption(
      'scan',
      abbr: 's',
      help: 'Scan directory for projects to process',
    )
    ..addOption(
      'project',
      abbr: 'p',
      help: 'Project(s) to process (comma-separated, globs supported)',
    );

  /// Print usage help.
  static void printUsage() {
    print('Pub Get Command - Run dart pub get across projects');
    print('');
    print('Usage: buildkit :pubget [options]');
    print(
      '       buildkit :pubgetall  # Shortcut for :pubget --scan . --recursive',
    );
    print('');
    print('Options:');
    print(parser.usage);
    print('');
    print('Examples:');
    print('  buildkit :pubget --scan . --recursive');
    print('  buildkit :pubget -s . -R --errors');
    print('  buildkit :pubget --project tom_* --updates');
    print('  buildkit :pubgetall');
    print('  buildkit :pubgetall --errors');
    print(
      '  buildkit :pubgetall --no-recursive  # Only process top-level projects',
    );
  }

  /// Execute pub get across projects.
  ///
  /// Returns true if all projects succeeded, false if any failed.
  Future<bool> execute(List<String> args) async {
    ArgResults results;
    try {
      results = parser.parse(args);
    } catch (e) {
      print('Error parsing arguments: $e');
      printUsage();
      return false;
    }

    if (results['help'] as bool) {
      printUsage();
      return true;
    }

    final showErrors = results['errors'] as bool;
    final showUpdates = results['updates'] as bool;
    final showUpgrades = results['upgrades'] as bool;
    final isVerbose = verbose || (results['verbose'] as bool);
    final recursive = results['recursive'] as bool;
    final scanPath = results['scan'] as String?;
    final projectArg = results['project'] as String?;

    // Determine projects to process
    final currentDir = Directory.current.path;
    List<String> projectPaths;

    if (scanPath != null) {
      final scanDir = p.isAbsolute(scanPath)
          ? scanPath
          : p.join(currentDir, scanPath);
      projectPaths = _scanForProjects(scanDir, recursive: recursive);
    } else if (projectArg != null) {
      projectPaths = _resolveProjectPatterns(projectArg, basePath: currentDir);
    } else {
      // Default: current directory
      projectPaths = [currentDir];
    }

    if (projectPaths.isEmpty) {
      print('No projects found.');
      return false;
    }

    print('Running pub get on ${projectPaths.length} project(s)...');
    print('');

    // Execute pub get in all projects and collect results
    final results2 = <PubGetResult>[];
    var processedCount = 0;

    for (final projectPath in projectPaths) {
      final relativePath = p.relative(projectPath, from: rootPath);
      final projectName = _getProjectName(projectPath);

      // Show progress (pad to fixed width to clear previous longer names)
      processedCount++;
      final progressText =
          '  Processing ($processedCount/${projectPaths.length}): $projectName';
      // Pad to 120 chars to overwrite any previous longer text
      final paddedText = progressText.padRight(120);
      stdout.write('\r$paddedText');
      await stdout.flush();

      final result = await _runPubGet(projectPath, relativePath, projectName);
      results2.add(result);
    }

    // Clear progress line
    stdout.write('\r${' ' * 120}\r');

    // Apply filters and display results
    final filteredResults = _filterResults(
      results2,
      showErrors: showErrors,
      showUpdates: showUpdates,
      showUpgrades: showUpgrades,
    );

    // Display results
    _displayResults(filteredResults, isVerbose);

    // Summary
    print('');
    print('=' * 60);
    print('Pub Get Summary');
    print('=' * 60);
    print('Total projects: ${results2.length}');

    final successCount = results2.where((r) => r.success).length;
    final failCount = results2.where((r) => !r.success).length;
    final updateCount = results2.where((r) => r.hasUpdates).length;
    final upgradeCount = results2.where((r) => r.hasUpgrades).length;

    print('Succeeded: $successCount');
    if (failCount > 0) print('Failed: $failCount');
    if (updateCount > 0) print('With updates available: $updateCount');
    if (upgradeCount > 0) print('With incompatible upgrades: $upgradeCount');

    if (showErrors || showUpdates || showUpgrades) {
      print('Displayed (filtered): ${filteredResults.length}');
    }

    return failCount == 0;
  }

  /// Run dart pub get in a project directory.
  Future<PubGetResult> _runPubGet(
    String projectPath,
    String relativePath,
    String projectName,
  ) async {
    try {
      final result = await ProcessRunner.run(
        'dart',
        ['pub', 'get'],
        workingDirectory: projectPath,
        runInShell: true,
      );

      return PubGetResult(
        projectPath: relativePath,
        projectName: projectName,
        success: result.exitCode == 0,
        stdout: result.stdout,
        stderr: result.stderr,
        exitCode: result.exitCode,
      );
    } catch (e) {
      return PubGetResult(
        projectPath: relativePath,
        projectName: projectName,
        success: false,
        stdout: '',
        stderr: 'Error: $e',
        exitCode: -1,
      );
    }
  }

  /// Get project name from pubspec.yaml.
  String _getProjectName(String projectPath) {
    final pubspecFile = File(p.join(projectPath, 'pubspec.yaml'));
    if (pubspecFile.existsSync()) {
      final content = pubspecFile.readAsStringSync();
      final nameMatch = RegExp(
        r'^name:\s*(.+)$',
        multiLine: true,
      ).firstMatch(content);
      if (nameMatch != null) {
        return nameMatch.group(1)?.trim() ?? p.basename(projectPath);
      }
    }
    return p.basename(projectPath);
  }

  /// Filter results based on options.
  List<PubGetResult> _filterResults(
    List<PubGetResult> results, {
    required bool showErrors,
    required bool showUpdates,
    required bool showUpgrades,
  }) {
    // If no filters, show all
    if (!showErrors && !showUpdates && !showUpgrades) {
      return results;
    }

    return results.where((r) {
      if (showErrors && r.hasError) return true;
      if (showUpdates && r.hasUpdates) return true;
      if (showUpgrades && r.hasUpgrades) return true;
      return false;
    }).toList();
  }

  /// Display results.
  void _displayResults(List<PubGetResult> results, bool isVerbose) {
    for (final result in results) {
      print('');
      print('━' * 60);
      print('📦 ${result.projectName}');
      print('   ${result.projectPath}');
      print('');

      if (result.stdout.isNotEmpty) {
        // Clean up output - remove empty lines and indent
        final lines = result.stdout
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .toList();
        for (final line in lines) {
          print(line);
        }
      }

      if (result.stderr.isNotEmpty) {
        print('');
        print('STDERR:');
        final lines = result.stderr
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .toList();
        for (final line in lines) {
          print('  $line');
        }
      }

      // Status indicator
      if (result.success) {
        print('   ✓ Success');
      } else {
        print('   ✗ Failed');
      }
    }
  }

  /// Scan a directory for Dart projects (directories containing pubspec.yaml).
  List<String> _scanForProjects(String dir, {bool recursive = false}) {
    final root = Directory(dir);
    if (!root.existsSync()) return [];

    final results = <String>[];
    if (recursive) {
      for (final entity in root.listSync(recursive: true)) {
        if (entity is File && p.basename(entity.path) == 'pubspec.yaml') {
          results.add(p.dirname(entity.path));
        }
      }
    } else {
      for (final entity in root.listSync()) {
        if (entity is Directory) {
          final pubspec = File(p.join(entity.path, 'pubspec.yaml'));
          if (pubspec.existsSync()) results.add(entity.path);
        }
      }
      // Also check root itself
      final rootPubspec = File(p.join(dir, 'pubspec.yaml'));
      if (rootPubspec.existsSync()) results.insert(0, dir);
    }
    return results;
  }

  /// Resolve comma-separated project patterns (globs or paths).
  List<String> _resolveProjectPatterns(
    String patterns, {
    required String basePath,
  }) {
    final results = <String>[];
    for (final pattern
        in patterns
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)) {
      if (pattern.contains('*') ||
          pattern.contains('?') ||
          pattern.contains('[')) {
        final glob = Glob(pattern);
        for (final entity in glob.listSync(root: basePath)) {
          if (entity is Directory) {
            final pubspec = File(p.join(entity.path, 'pubspec.yaml'));
            if (pubspec.existsSync()) results.add(entity.path);
          }
        }
      } else {
        final resolved = p.isAbsolute(pattern)
            ? pattern
            : p.join(basePath, pattern);
        if (Directory(resolved).existsSync()) results.add(resolved);
      }
    }
    return results;
  }
}
