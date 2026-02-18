import 'dart:io';

import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

import '../folder/fs_folder.dart';

/// Global skip file that blocks all tools.
const kTomSkipYaml = 'tom_skip.yaml';

/// Type of skip marker found in a directory.
enum _SkipType {
  /// `tom_skip.yaml` — global skip for all tools.
  globalSkip,

  /// `{toolBasename}_skip.yaml` — tool-specific skip.
  toolSkip,

  /// Nested workspace boundary (e.g., `buildkit_master.yaml`).
  workspaceBoundary,
}

/// Scans directories and builds a list of FsFolders.
///
/// Handles recursive scanning, skip markers, and recursion exclusions.
class FolderScanner {
  /// Tool basename for tool-specific skip files (e.g., 'issuekit' → 'issuekit_skip.yaml').
  final String toolBasename;

  /// Whether to print verbose messages for skipped directories.
  final bool verbose;

  /// Create a FolderScanner.
  ///
  /// [toolBasename] - Tool name for tool-specific skip files. Defaults to 'buildkit'.
  /// [verbose] - If true, print messages when directories are skipped.
  FolderScanner({this.toolBasename = 'buildkit', this.verbose = false});

  /// Tool-specific skip filename.
  String get skipFilename => '${toolBasename}_skip.yaml';

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
      isRoot: true, // Don't skip the initial scan directory
    );
    
    return folders;
  }

  Future<void> _scanDirectory(
    Directory dir,
    List<FsFolder> results, {
    required bool recursive,
    required List<String> recursionExclude,
    bool isRoot = false,
  }) async {
    // Check for skip markers.
    // Skip markers mean "don't include this folder AND don't descend into children"
    final skipMarker = !isRoot ? _getSkipMarker(dir.path) : null;
    
    if (skipMarker != null) {
      // Any skip marker (workspace boundary, global skip, or tool skip)
      // means we should NOT include this folder and NOT descend further.
      if (verbose) {
        final skipFile = switch (skipMarker) {
          _SkipType.globalSkip => kTomSkipYaml,
          _SkipType.toolSkip => skipFilename,
          _SkipType.workspaceBoundary => '${toolBasename}_master.yaml',
        };
        print('Skipping ($skipFile): ${p.basename(dir.path)}');
      }
      return;
    }
    
    // No skip marker — add this directory
    results.add(FsFolder(path: dir.path));
    
    if (!recursive) return;
    
    // Check if this directory has {toolBasename}.yaml with recursive: false
    if (_hasToolConfigRecursiveFalse(dir.path)) return;
    
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

  /// Determine skip marker type for a directory.
  ///
  /// Returns:
  /// - [_SkipType.globalSkip] for `tom_skip.yaml`
  /// - [_SkipType.toolSkip] for `{toolBasename}_skip.yaml`
  /// - [_SkipType.workspaceBoundary] for nested workspace markers
  /// - null if no skip marker found
  _SkipType? _getSkipMarker(String dirPath) {
    // Workspace boundaries — separate workspaces, stop descending
    if (File(p.join(dirPath, '${toolBasename}_master.yaml')).existsSync() ||
        File(p.join(dirPath, 'tom_workspace.yaml')).existsSync()) {
      return _SkipType.workspaceBoundary;
    }
    // Global skip file — blocks all tools
    if (File(p.join(dirPath, kTomSkipYaml)).existsSync()) {
      return _SkipType.globalSkip;
    }
    // Tool-specific skip file
    if (File(p.join(dirPath, skipFilename)).existsSync()) {
      return _SkipType.toolSkip;
    }
    return null;
  }

  /// Check if {toolBasename}.yaml exists and has recursive: false.
  bool _hasToolConfigRecursiveFalse(String dirPath) {
    final configPath = p.join(dirPath, '$toolBasename.yaml');
    final file = File(configPath);
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

  /// Find the topmost git repository by traversing up from [startPath].
  ///
  /// Traverses up the directory tree from [startPath] to the filesystem root,
  /// returning the path of the outermost (topmost) git repository found.
  /// Returns null if no git repository is found in the path.
  ///
  /// Example: If startPath is `/a/b/c` and both `/a` and `/a/b` are git repos,
  /// this returns `/a` (the topmost one).
  String? findTopRepo(String startPath) {
    var current = p.normalize(p.absolute(startPath));
    String? topRepo;
    
    while (true) {
      // Check if this is a git repo
      final gitDir = Directory(p.join(current, '.git'));
      final gitFile = File(p.join(current, '.git'));
      
      if (gitDir.existsSync() || gitFile.existsSync()) {
        topRepo = current;
      }
      
      // Move to parent directory
      final parent = p.dirname(current);
      if (parent == current) {
        // Reached root
        break;
      }
      current = parent;
    }
    
    return topRepo;
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
