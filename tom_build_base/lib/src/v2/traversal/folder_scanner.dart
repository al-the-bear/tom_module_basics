import 'dart:io';

import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

import '../folder/fs_folder.dart';

/// Scans directories and builds a list of FsFolders.
///
/// Handles recursive scanning, skip markers, and recursion exclusions.
class FolderScanner {
  /// Scan for folders starting from [root].
  ///
  /// [recursive] - If true, descend into subdirectories.
  /// [recursionExclude] - Patterns to skip during recursive descent.
  Future<List<FsFolder>> scan(
    String root, {
    bool recursive = false,
    List<String> recursionExclude = const [],
  }) async {
    final folders = <FsFolder>[];
    final rootDir = Directory(root);
    
    if (!rootDir.existsSync()) {
      return folders;
    }
    
    await _scanDirectory(
      rootDir,
      folders,
      recursive: recursive,
      recursionExclude: recursionExclude,
    );
    
    return folders;
  }

  Future<void> _scanDirectory(
    Directory dir,
    List<FsFolder> results, {
    required bool recursive,
    required List<String> recursionExclude,
  }) async {
    // Check for skip markers BEFORE adding or descending
    if (_hasSkipMarker(dir.path)) return;
    
    // Add this directory
    results.add(FsFolder(path: dir.path));
    
    if (!recursive) return;
    
    // Check if this directory has buildkit.yaml with recursive: false
    if (_hasBuildkitRecursiveFalse(dir.path)) return;
    
    // Descend into subdirectories
    try {
      await for (final entity in dir.list()) {
        if (entity is Directory) {
          final name = p.basename(entity.path);
          
          // Skip hidden directories
          if (name.startsWith('.')) continue;
          
          // Apply recursion exclusions
          if (_matchesAny(entity.path, name, recursionExclude)) continue;
          
          await _scanDirectory(
            entity,
            results,
            recursive: recursive,
            recursionExclude: recursionExclude,
          );
        }
      }
    } on FileSystemException {
      // Permission denied or other filesystem error - skip this directory
    }
  }

  /// Check for skip markers that exclude entire subtrees.
  bool _hasSkipMarker(String dirPath) {
    // buildkit_skip.yaml - skip this folder and all descendants
    if (File(p.join(dirPath, 'buildkit_skip.yaml')).existsSync()) {
      return true;
    }
    // Workspace boundaries - stop descending into nested workspaces
    if (File(p.join(dirPath, 'buildkit_master.yaml')).existsSync() ||
        File(p.join(dirPath, 'tom_workspace.yaml')).existsSync()) {
      return true;
    }
    return false;
  }

  /// Check if buildkit.yaml exists and has recursive: false.
  bool _hasBuildkitRecursiveFalse(String dirPath) {
    final buildkitPath = p.join(dirPath, 'buildkit.yaml');
    final file = File(buildkitPath);
    if (!file.existsSync()) return false;
    
    try {
      final content = file.readAsStringSync();
      // Simple check - look for recursive: false pattern
      final lines = content.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('recursive:')) {
          final value = trimmed.substring('recursive:'.length).trim();
          return value == 'false' || value == 'no';
        }
      }
    } catch (_) {
      // Ignore read errors
    }
    return false;
  }

  /// Check if path or name matches any of the patterns.
  bool _matchesAny(String path, String name, List<String> patterns) {
    for (final pattern in patterns) {
      // Try glob match on path
      try {
        final glob = Glob(pattern);
        if (glob.matches(path) || glob.matches(name)) {
          return true;
        }
      } catch (_) {
        // Invalid glob pattern - try simple contains match
        if (path.contains(pattern) || name == pattern) {
          return true;
        }
      }
    }
    return false;
  }
}

/// Finds git repositories under a given root.
class GitRepoFinder {
  /// Find all git repositories under [root].
  Future<List<FsFolder>> findAll(String root) async {
    final repos = <FsFolder>[];
    await _findGitRepos(Directory(root), repos);
    return repos;
  }

  Future<void> _findGitRepos(Directory dir, List<FsFolder> results) async {
    if (!dir.existsSync()) return;
    
    // Check if this is a git repo
    final gitDir = Directory(p.join(dir.path, '.git'));
    final gitFile = File(p.join(dir.path, '.git'));
    
    if (gitDir.existsSync() || gitFile.existsSync()) {
      results.add(FsFolder(path: dir.path));
    }
    
    // Continue searching subdirectories
    try {
      await for (final entity in dir.list()) {
        if (entity is Directory) {
          final name = p.basename(entity.path);
          if (name.startsWith('.')) continue; // Skip hidden
          await _findGitRepos(entity, results);
        }
      }
    } on FileSystemException {
      // Permission denied - skip
    }
  }
}
