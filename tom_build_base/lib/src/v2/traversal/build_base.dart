import 'dart:io';

import '../folder/fs_folder.dart';
import 'command_context.dart';
import 'filter_pipeline.dart';
import 'folder_scanner.dart';
import 'nature_detector.dart';
import 'traversal_info.dart';

/// Result of a traversal operation.
class ProcessingResult {
  final List<String> _successes = [];
  final List<String> _failures = [];
  final Map<String, Object> _errors = {};

  /// Paths that were processed successfully.
  List<String> get successes => List.unmodifiable(_successes);

  /// Paths that failed processing (command returned false).
  List<String> get failures => List.unmodifiable(_failures);

  /// Paths that threw errors, with the error objects.
  Map<String, Object> get errors => Map.unmodifiable(_errors);

  /// Total number of folders processed.
  int get total => _successes.length + _failures.length + _errors.length;

  /// Number of successful operations.
  int get successCount => _successes.length;

  /// Number of failures (including errors).
  int get failureCount => _failures.length + _errors.length;

  /// Whether all operations succeeded.
  bool get allSucceeded => _failures.isEmpty && _errors.isEmpty;

  void recordSuccess(String path) => _successes.add(path);
  void recordFailure(String path) => _failures.add(path);
  void recordError(String path, Object error) => _errors[path] = error;

  @override
  String toString() => 'ProcessingResult(success: $successCount, failed: $failureCount, total: $total)';
}

/// Main entry point for workspace traversal.
///
/// Provides static methods for scanning, filtering, and executing
/// commands on folders across a workspace.
abstract class BuildBase {
  /// Traverse folders and execute callback on each.
  ///
  /// [info] - ProjectTraversalInfo or GitTraversalInfo configuration.
  /// [run] - Callback for each matching folder.
  /// [requiredNatures] - Folder MUST have ALL of these natures (null = no requirement).
  /// [worksWithNatures] - Natures the callback can handle (informational).
  static Future<ProcessingResult> traverse({
    required BaseTraversalInfo info,
    required Future<bool> Function(CommandContext) run,
    Set<Type>? requiredNatures,
    Set<Type> worksWithNatures = const {},
  }) async {
    final detector = NatureDetector();
    final filter = FilterPipeline();
    final sorter = FolderSorter();
    final result = ProcessingResult();

    // Get folders based on traversal type
    List<FsFolder> folders;
    switch (info) {
      case ProjectTraversalInfo pi:
        folders = await _scanProjects(pi);
        folders = filter.applyProjectFilters(folders, pi);
      case GitTraversalInfo gi:
        folders = await _findGitRepos(gi);
        folders = filter.applyGitFilters(folders, gi);
      default:
        folders = [];
    }

    // Detect natures and create contexts
    final contexts = <CommandContext>[];
    for (final folder in folders) {
      final natures = detector.detectNatures(folder);
      // Store natures in folder for filter pipeline access
      folder.natures.addAll(natures);
      contexts.add(CommandContext(
        fsFolder: folder,
        natures: natures,
        executionRoot: info.executionRoot,
        traversal: info,
      ));
    }

    // Apply ordering based on traversal type
    List<CommandContext> ordered;
    switch (info) {
      case GitTraversalInfo gi:
        ordered = gi.gitMode == GitTraversalMode.innerFirst
            ? sorter.sortByInnerFirst(contexts, (c) => c.path)
            : sorter.sortByOuterFirst(contexts, (c) => c.path);
      case ProjectTraversalInfo pi when pi.buildOrder:
        ordered = sorter.sortByBuildOrder(contexts, (c) => c.path, (c) => c.name);
      default:
        ordered = contexts;
    }

    // Execute on each context
    for (final ctx in ordered) {
      // Check required natures
      if (requiredNatures != null && requiredNatures.isNotEmpty) {
        final hasAll = requiredNatures.every((t) =>
            ctx.natures.any((n) => n.runtimeType == t));
        if (!hasAll) continue;
      }

      try {
        final success = await run(ctx);
        success ? result.recordSuccess(ctx.path) : result.recordFailure(ctx.path);
      } catch (e) {
        result.recordError(ctx.path, e);
      }
    }

    return result;
  }

  /// Scan for projects based on ProjectTraversalInfo.
  static Future<List<FsFolder>> _scanProjects(ProjectTraversalInfo info) async {
    final scanner = FolderScanner();
    return await scanner.scan(
      info.scan,
      recursive: info.recursive,
      recursionExclude: info.recursionExclude,
    );
  }

  /// Find all git repositories based on GitTraversalInfo.
  static Future<List<FsFolder>> _findGitRepos(GitTraversalInfo info) async {
    final finder = GitRepoFinder();
    return await finder.findAll(info.executionRoot);
  }

  /// Get list of projects without executing anything.
  ///
  /// Useful for scripts that need to iterate manually or preview results.
  static Future<List<CommandContext>> findProjects({
    String scan = '.',
    bool recursive = true,
    List<String>? include,
    List<String>? exclude,
    Set<Type>? requiredNatures,
  }) async {
    final info = ProjectTraversalInfo(
      scan: scan,
      recursive: recursive,
      executionRoot: Directory.current.path,
      projectPatterns: include ?? [],
      excludeProjects: exclude ?? [],
    );

    final scanner = FolderScanner();
    final filter = FilterPipeline();
    final detector = NatureDetector();

    final folders = await scanner.scan(
      info.scan,
      recursive: info.recursive,
      recursionExclude: info.recursionExclude,
    );

    final filtered = filter.applyProjectFilters(folders, info);

    return filtered.map((folder) {
      final natures = detector.detectNatures(folder);
      folder.natures.addAll(natures);
      return CommandContext(
        fsFolder: folder,
        natures: natures,
        executionRoot: info.executionRoot,
      );
    }).where((ctx) =>
        requiredNatures == null ||
        requiredNatures.every((t) => ctx.natures.any((n) => n.runtimeType == t))
    ).toList();
  }

  /// Convenience method to iterate over all Dart projects.
  static Future<ProcessingResult> forEachDartProject(
    Future<bool> Function(CommandContext ctx) run, {
    String scan = '.',
    bool recursive = true,
    List<String>? include,
    List<String>? exclude,
  }) async {
    final info = ProjectTraversalInfo(
      scan: scan,
      recursive: recursive,
      executionRoot: Directory.current.path,
      projectPatterns: include ?? [],
      excludeProjects: exclude ?? [],
    );

    return traverse(
      info: info,
      run: run,
      // Note: Using runtime type checking in the callback instead of requiredNatures
      // because DartProjectFolder is abstract
    );
  }

  /// Convenience method to iterate over all git repositories.
  static Future<ProcessingResult> forEachGitRepo(
    Future<bool> Function(CommandContext ctx) run, {
    GitTraversalMode mode = GitTraversalMode.innerFirst,
    List<String>? modules,
    List<String>? skipModules,
  }) async {
    final info = GitTraversalInfo(
      executionRoot: Directory.current.path,
      gitMode: mode,
      modules: modules ?? [],
      skipModules: skipModules ?? [],
    );

    return traverse(
      info: info,
      run: run,
    );
  }
}
