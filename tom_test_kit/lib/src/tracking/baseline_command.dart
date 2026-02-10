import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/test_run.dart';
import '../model/tracking_file.dart';
import '../parser/dart_test_parser.dart';

/// Implements the `:baseline` subcommand.
///
/// Runs `dart test` and creates a new baseline tracking file.
class BaselineCommand {
  /// Runs the baseline command for a single project.
  ///
  /// [projectPath] is the project directory (must contain pubspec.yaml).
  /// [outputPath] overrides the default output location.
  /// [testArgs] are additional arguments passed to `dart test`.
  /// [verbose] enables diagnostic output.
  ///
  /// Returns true on success, false on failure.
  static Future<bool> run({
    required String projectPath,
    String? outputPath,
    List<String> testArgs = const [],
    bool verbose = false,
  }) async {
    // Run dart test
    final results = await DartTestParser.runAndParse(
      projectPath: projectPath,
      additionalArgs: testArgs,
      verbose: verbose,
    );

    if (results == null) {
      stderr.writeln('[$projectPath] Failed to run dart test.');
      return false;
    }

    // Create baseline run (copy results into a run marked as baseline)
    final baselineRun = TestRun(
      timestamp: results.run.timestamp,
      isBaseline: true,
      results: Map.of(results.run.results),
    );

    // Create tracking file
    final tracking = TrackingFile.fromBaseline(results.entries, baselineRun);

    // Determine output path
    final resolvedOutput = outputPath ?? _defaultOutputPath(projectPath);

    // Write the file
    await tracking.write(resolvedOutput);

    // Print summary
    final relativePath = p.relative(resolvedOutput, from: projectPath);
    print('  Created: $relativePath');
    print('  Tests: ${results.totalTests} '
        '(${results.passedTests} passed, '
        '${results.failedTests} failed'
        '${results.skippedTests > 0 ? ', ${results.skippedTests} skipped' : ''})');

    return true;
  }

  /// Returns the default output path for a baseline file.
  static String _defaultOutputPath(String projectPath) {
    final now = DateTime.now();
    final timestamp = '${_pad(now.month)}${_pad(now.day)}_'
        '${_pad(now.hour)}${_pad(now.minute)}';
    return p.join(projectPath, 'doc', 'baseline_$timestamp.md');
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
