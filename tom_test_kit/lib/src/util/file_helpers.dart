/// File-system helpers for tracking file discovery.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'format_helpers.dart';

/// Returns the default output path for a baseline file.
///
/// Creates a path like `<projectPath>/doc/baseline_<MMDD_HHMM>.csv`.
String defaultBaselinePath(String projectPath, {DateTime? now}) {
  final ts = now ?? DateTime.now();
  return p.join(projectPath, 'doc', 'baseline_${baselineTimestamp(ts)}.csv');
}

/// Finds the most recent `baseline_*.csv` file in a project's `doc/` folder.
///
/// Returns the absolute path of the latest file, or null if no tracking
/// files exist.
String? findLatestTrackingFile(String projectPath) {
  final docDir = Directory(p.join(projectPath, 'doc'));
  if (!docDir.existsSync()) return null;

  final files = docDir
      .listSync()
      .whereType<File>()
      .where((f) =>
          p.basename(f.path).startsWith('baseline_') &&
          f.path.endsWith('.csv'))
      .toList();

  if (files.isEmpty) return null;

  // Sort by name (timestamp in filename) — latest first
  files.sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
  return files.first.path;
}

/// Saves raw JSON test output to `last_testrun.json` in the project's
/// `doc/` directory (same location as baseline files).
///
/// Overwrites any existing file.
Future<void> saveLastTestRunJson(
    String projectPath, List<String> jsonLines) async {
  final dir = Directory(p.join(projectPath, 'doc'));
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  final file = File(p.join(dir.path, 'last_testrun.json'));
  await file.writeAsString('${jsonLines.join('\n')}\n');
}
