import 'dart:io';

import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;

import 'build_config.dart';
import 'path_utils.dart';

/// A function type for checking if a directory is a valid project.
/// 
/// [dirPath] - The path to check
/// [toolKey] - The tool key to look for in configuration (e.g., 'dartgen', 'versioner')
/// 
/// Returns true if the directory is a valid project for the given tool.
typedef ProjectValidator = bool Function(String dirPath, String toolKey);

/// Default project validator that checks for pubspec.yaml and tool configuration.
/// 
/// A directory is a valid project if it has:
/// - pubspec.yaml AND
/// - build.yaml with the tool section OR tom_build.yaml with the tool section
bool defaultProjectValidator(String dirPath, String toolKey) {
  final pubspecFile = File(p.join(dirPath, 'pubspec.yaml'));
  if (!pubspecFile.existsSync()) return false;

  // Check for build.yaml with tool configuration
  final buildFile = File(p.join(dirPath, 'build.yaml'));
  if (buildFile.existsSync()) {
    try {
      final content = buildFile.readAsStringSync();
      // Simple check: does build.yaml contain the tool key?
      if (content.contains('$toolKey:')) {
        return true;
      }
    } catch (_) {}
  }

  // Check for tom_build.yaml with tool section
  return hasTomBuildConfig(dirPath, toolKey);
}

/// Scans for and discovers projects in a directory structure.
class ProjectScanner {
  /// The tool key to look for (e.g., 'dartgen', 'versioner').
  final String toolKey;
  
  /// The base path for containment validation.
  final String basePath;
  
  /// Function to validate if a directory is a project.
  final ProjectValidator projectValidator;
  
  /// Whether to print verbose output.
  final bool verbose;
  
  /// Output function for verbose messages.
  final void Function(String) log;

  /// Creates a new project scanner.
  /// 
  /// [toolKey] - The tool key to look for in configurations
  /// [basePath] - The base path for containment validation
  /// [projectValidator] - Optional custom validator (defaults to [defaultProjectValidator])
  /// [verbose] - Whether to print verbose output
  /// [log] - Optional custom log function (defaults to print)
  ProjectScanner({
    required this.toolKey,
    required this.basePath,
    ProjectValidator? projectValidator,
    this.verbose = false,
    void Function(String)? log,
  })  : projectValidator = projectValidator ?? defaultProjectValidator,
        log = log ?? print;

  void _log(String message) {
    if (verbose) log(message);
  }

  /// Finds all immediate subdirectories of [projectDir] that are valid projects.
  /// 
  /// Excludes directories matching the [exclude] patterns.
  List<String> findSubprojects(String projectDir, List<String> exclude) {
    final dir = Directory(projectDir);
    if (!dir.existsSync()) {
      return [];
    }

    final projects = <String>[];

    for (final entity in dir.listSync()) {
      if (entity is! Directory) continue;

      final dirPath = entity.path;
      final dirName = p.basename(dirPath);

      // Check exclusions
      if (_matchesExclusion(dirName, dirPath, exclude)) {
        _log('Excluding subdirectory: $dirPath');
        continue;
      }

      // Check if it's a valid project
      if (projectValidator(dirPath, toolKey)) {
        projects.add(dirPath);
      }
    }

    return projects;
  }

  /// Finds projects matching glob patterns.
  /// 
  /// [patterns] - List of glob patterns to match
  /// [exclude] - Patterns to exclude from results
  /// 
  /// Returns a list of project directory paths.
  List<String> findProjectsByGlob(List<String> patterns, List<String> exclude) {
    final projects = <String>[];

    for (final pattern in patterns) {
      final fullPattern = p.isAbsolute(pattern)
          ? pattern
          : p.join(basePath, pattern);

      _log('Scanning glob pattern: $fullPattern');

      try {
        final glob = Glob(fullPattern);
        for (final entity in glob.listSync()) {
          if (entity is! Directory) continue;

          final dirPath = entity.path;

          // Check containment
          if (!isPathContained(dirPath, basePath)) {
            _log('Skipping directory outside base path: $dirPath');
            continue;
          }

          // Check exclusions
          if (_matchesExclusion(p.basename(dirPath), dirPath, exclude)) {
            _log('Excluding: $dirPath');
            continue;
          }

          // Check if it's a valid project
          if (projectValidator(dirPath, toolKey)) {
            if (!projects.contains(dirPath)) {
              projects.add(dirPath);
            }
          }
        }
      } catch (e) {
        _log('Error processing glob pattern "$pattern": $e');
      }
    }

    return projects;
  }

  /// Scans a directory tree for projects recursively.
  /// 
  /// [scanPath] - The root path to start scanning from
  /// [exclude] - Patterns to exclude from results
  /// 
  /// Returns a list of project directory paths.
  List<String> scanForProjects(String scanPath, List<String> exclude) {
    final projects = <String>[];
    _scanDirectory(scanPath, projects, exclude);
    return projects;
  }

  void _scanDirectory(String dirPath, List<String> projects, List<String> exclude) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return;

    // Check if this directory is a project
    if (projectValidator(dirPath, toolKey)) {
      projects.add(dirPath);
      // Don't recurse into project directories - they are leaf nodes
      return;
    }

    // Recurse into subdirectories
    try {
      for (final entity in dir.listSync()) {
        if (entity is! Directory) continue;

        final subDirPath = entity.path;
        final dirName = p.basename(subDirPath);

        // Skip hidden directories
        if (dirName.startsWith('.')) continue;

        // Check exclusions
        if (_matchesExclusion(dirName, subDirPath, exclude)) {
          _log('Excluding: $subDirPath');
          continue;
        }

        _scanDirectory(subDirPath, projects, exclude);
      }
    } catch (e) {
      _log('Error scanning directory "$dirPath": $e');
    }
  }

  /// Filters a list of project paths by applying exclusion patterns.
  /// 
  /// [projectPaths] - List of project paths to filter
  /// [exclude] - Patterns to exclude
  /// 
  /// Returns filtered list of project paths.
  List<String> applyExclusions(List<String> projectPaths, List<String> exclude) {
    if (exclude.isEmpty) return projectPaths;

    return projectPaths.where((projectPath) {
      final dirName = p.basename(projectPath);
      final matches = _matchesExclusion(dirName, projectPath, exclude);
      if (matches) {
        _log('Excluding: $projectPath');
      }
      return !matches;
    }).toList();
  }

  /// Checks if a directory matches any exclusion pattern.
  bool _matchesExclusion(String dirName, String fullPath, List<String> patterns) {
    for (final pattern in patterns) {
      // Simple name matching
      if (pattern == dirName) return true;

      // Glob pattern matching against directory name
      if (pattern.contains('*') || pattern.contains('?')) {
        final glob = Glob(pattern);
        if (glob.matches(dirName)) return true;
        
        // Also try matching against the full relative path
        final relativePath = p.relative(fullPath, from: basePath);
        if (glob.matches(relativePath)) return true;
      }
    }
    return false;
  }
}
