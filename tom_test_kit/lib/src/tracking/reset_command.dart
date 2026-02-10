import 'dart:io';

import 'package:path/path.dart' as p;

/// Implements the `:reset` subcommand.
///
/// Deletes all baseline_*.csv files and last_testrun.json in the project's
/// doc/ directory. Prompts for confirmation unless --force is specified.
class ResetCommand {
  /// Runs the command for a single project.
  ///
  /// Returns true on success, false on failure.
  static Future<bool> run({
    required String projectPath,
    bool force = false,
    bool verbose = false,
  }) async {
    final docDir = Directory(p.join(projectPath, 'doc'));
    if (!docDir.existsSync()) {
      print('  No doc/ directory — nothing to reset.');
      return true;
    }

    // Find files to delete
    final filesToDelete = <File>[];
    for (final entity in docDir.listSync()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name.startsWith('baseline_') && name.endsWith('.csv')) {
        filesToDelete.add(entity);
      } else if (name == 'last_testrun.json') {
        filesToDelete.add(entity);
      }
    }

    if (filesToDelete.isEmpty) {
      print('  No tracking files found — nothing to reset.');
      return true;
    }

    // Show what will be deleted
    print('  Files to delete (${filesToDelete.length}):');
    for (final file in filesToDelete) {
      print('    ${p.relative(file.path, from: projectPath)}');
    }

    // Confirm unless forced
    if (!force) {
      stdout.write('  Delete these files? [y/N] ');
      final answer = stdin.readLineSync()?.trim().toLowerCase();
      if (answer != 'y' && answer != 'yes') {
        print('  Aborted.');
        return true;
      }
    }

    // Delete files
    var deleted = 0;
    for (final file in filesToDelete) {
      try {
        file.deleteSync();
        deleted++;
        if (verbose) {
          print('  Deleted: ${p.relative(file.path, from: projectPath)}');
        }
      } catch (e) {
        stderr.writeln('  Failed to delete ${file.path}: $e');
      }
    }

    print('  Deleted $deleted file(s).');
    return true;
  }
}
