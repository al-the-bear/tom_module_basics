import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';

/// Result of a pub upgrade execution for a single project.
class PubUpdateResult {
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

  /// Whether the output indicates packages were upgraded.
  bool get hasChanges =>
      stdout.contains('Changed ') || stdout.contains('Upgraded ');

  /// Whether there was an error.
  bool get hasError => !success || stderr.isNotEmpty;

  PubUpdateResult({
    required this.projectPath,
    required this.projectName,
    required this.success,
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });
}

/// Executes `dart pub upgrade` across multiple projects.
///
/// Collects all output and displays it at the end, with filtering options.
class PubUpdateCommand {
  final String rootPath;
  final bool verbose;

  PubUpdateCommand({
    required this.rootPath,
    required this.verbose,
  });

  /// Parse command arguments.
  static ArgParser get parser => ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
    ..addFlag('errors',
        abbr: 'e',
        negatable: false,
        help: 'Only show projects with errors')
    ..addFlag('changes',
        abbr: 'c',
        negatable: false,
        help: 'Only show projects with changed packages')
    ..addFlag('major-versions',
        negatable: false,
        help: 'Allow upgrading to latest resolvable versions (major versions)')
    ..addFlag('verbose',
        abbr: 'v', negatable: false, help: 'Show detailed output')
    ..addFlag('recursive',
        abbr: 'R',
        negatable: true,
        defaultsTo: false,
        help: 'Scan directories recursively (use --no-recursive to disable)')
    ..addOption('scan',
        abbr: 's', help: 'Scan directory for projects to process')
    ..addOption('project',
        abbr: 'p',
        help: 'Project(s) to process (comma-separated, globs supported)');

  /// Print usage help.
  static void printUsage() {
    print('Pub Update Command - Run dart pub upgrade across projects');
    print('');
    print('Usage: buildkit :pubupdate [options]');
    print('       buildkit :pubupdateall  # Shortcut for :pubupdate --scan . --recursive');
    print('');
    print('Options:');
    print(parser.usage);
    print('');
    print('Examples:');
    print('  buildkit :pubupdate --scan . --recursive');
    print('  buildkit :pubupdate -s . -R --errors');
    print('  buildkit :pubupdate --project tom_* --changes');
    print('  buildkit :pubupdate --major-versions');
    print('  buildkit :pubupdateall');
    print('  buildkit :pubupdateall --errors');
    print('  buildkit :pubupdateall --no-recursive  # Only process top-level projects');
  }

  /// Execute pub upgrade across projects.
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
    final showChanges = results['changes'] as bool;
    final majorVersions = results['major-versions'] as bool;
    final isVerbose = verbose || (results['verbose'] as bool);
    final recursive = results['recursive'] as bool;
    final scanPath = results['scan'] as String?;
    final projectArg = results['project'] as String?;

    // Determine projects to process
    final currentDir = Directory.current.path;
    final discovery = ProjectDiscovery(verbose: isVerbose);
    List<String> projectPaths;

    if (scanPath != null) {
      final scanDir =
          p.isAbsolute(scanPath) ? scanPath : p.join(currentDir, scanPath);
      projectPaths = await discovery.scanForProjects(
        scanDir,
        recursive: recursive,
        toolKey: null, // Scan all projects, not just those with buildkit config
      );
    } else if (projectArg != null) {
      projectPaths = await discovery.resolveProjectPatterns(
        projectArg,
        basePath: currentDir,
      );
    } else {
      // Default: current directory
      projectPaths = [currentDir];
    }

    if (projectPaths.isEmpty) {
      print('No projects found.');
      return false;
    }

    print('Running pub upgrade on ${projectPaths.length} project(s)...');
    if (majorVersions) {
      print('(with --major-versions)');
    }
    print('');

    // Execute pub upgrade in all projects and collect results
    final results2 = <PubUpdateResult>[];
    var processedCount = 0;

    for (final projectPath in projectPaths) {
      final relativePath = p.relative(projectPath, from: rootPath);
      final projectName = _getProjectName(projectPath);

      // Show progress (pad to fixed width to clear previous longer names)
      processedCount++;
      final progressText = '  Processing ($processedCount/${projectPaths.length}): $projectName';
      // Pad to 120 chars to overwrite any previous longer text
      final paddedText = progressText.padRight(120);
      stdout.write('\r$paddedText');
      await stdout.flush();

      final result = await _runPubUpgrade(
        projectPath,
        relativePath,
        projectName,
        majorVersions: majorVersions,
      );
      results2.add(result);
    }

    // Clear progress line
    stdout.write('\r${' ' * 120}\r');

    // Apply filters and display results
    final filteredResults = _filterResults(
      results2,
      showErrors: showErrors,
      showChanges: showChanges,
    );

    // Display results
    _displayResults(filteredResults, isVerbose);

    // Summary
    print('');
    print('=' * 60);
    print('Pub Update Summary');
    print('=' * 60);
    print('Total projects: ${results2.length}');

    final successCount = results2.where((r) => r.success).length;
    final failCount = results2.where((r) => !r.success).length;
    final changesCount = results2.where((r) => r.hasChanges).length;

    print('Succeeded: $successCount');
    if (failCount > 0) print('Failed: $failCount');
    if (changesCount > 0) print('With package changes: $changesCount');

    if (showErrors || showChanges) {
      print('Displayed (filtered): ${filteredResults.length}');
    }

    return failCount == 0;
  }

  /// Run dart pub upgrade in a project directory.
  Future<PubUpdateResult> _runPubUpgrade(
    String projectPath,
    String relativePath,
    String projectName, {
    required bool majorVersions,
  }) async {
    try {
      final args = ['pub', 'upgrade'];
      if (majorVersions) {
        args.add('--major-versions');
      }

      final result = await ProcessRunner.run(
        'dart',
        args,
        workingDirectory: projectPath,
        runInShell: true,
      );

      return PubUpdateResult(
        projectPath: relativePath,
        projectName: projectName,
        success: result.exitCode == 0,
        stdout: result.stdout,
        stderr: result.stderr,
        exitCode: result.exitCode,
      );
    } catch (e) {
      return PubUpdateResult(
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
      final nameMatch =
          RegExp(r'^name:\s*(.+)$', multiLine: true).firstMatch(content);
      if (nameMatch != null) {
        return nameMatch.group(1)?.trim() ?? p.basename(projectPath);
      }
    }
    return p.basename(projectPath);
  }

  /// Filter results based on options.
  List<PubUpdateResult> _filterResults(
    List<PubUpdateResult> results, {
    required bool showErrors,
    required bool showChanges,
  }) {
    // If no filters, show all
    if (!showErrors && !showChanges) {
      return results;
    }

    return results.where((r) {
      if (showErrors && r.hasError) return true;
      if (showChanges && r.hasChanges) return true;
      return false;
    }).toList();
  }

  /// Display results.
  void _displayResults(List<PubUpdateResult> results, bool isVerbose) {
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
}
