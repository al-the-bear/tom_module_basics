import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';
import 'package:yaml/yaml.dart';

/// Example: A CLI tool that displays the version from every Dart project it
/// discovers.  It exercises most `tom_build_base` features:
///
///   • TomBuildConfig — loading and merging workspace/project config
///   • ConfigMerger — merging workspace + project exclude lists
///   • ProjectScanner — finding projects with custom validation
///   • ProjectDiscovery — glob-based and recursive project resolution
///   • build.yaml utilities — skipping builder-definition packages
///   • Path utilities — containment validation
///   • ProcessingResult — batch success/failure tracking
///
/// Usage:
///   dart run example/tom_build_base_example.dart [workspace-path]
///
/// The tool looks for a `show_versions:` section in `tom_build.yaml` and
/// `tom_build_master.yaml` to control scanning behaviour.

const toolKey = 'show_versions';

void main(List<String> arguments) async {
  // ── 1. Determine workspace root ──────────────────────────────────────────
  final basePath = arguments.isNotEmpty
      ? p.normalize(p.absolute(arguments.first))
      : Directory.current.path;

  print('Workspace: $basePath\n');

  // ── 2. Load configuration (master + project, merged) ────────────────────
  //
  // TomBuildConfig.loadMaster reads the workspace-level tom_build_master.yaml
  // while TomBuildConfig.load reads the project-level tom_build.yaml.
  // Merging lets the project override workspace defaults.
  final masterConfig =
      TomBuildConfig.loadMaster(dir: basePath, toolKey: toolKey);
  final projectConfig = TomBuildConfig.load(dir: basePath, toolKey: toolKey);

  // Merge: project overrides workspace.
  TomBuildConfig config;
  if (masterConfig != null && projectConfig != null) {
    config = masterConfig.merge(projectConfig);
    print('Config: merged master + project');
  } else {
    config =
        projectConfig ?? masterConfig ?? const TomBuildConfig(verbose: true);
    print('Config: ${projectConfig != null ? "project" : masterConfig != null ? "master" : "defaults"}');
  }

  print('  verbose   : ${config.verbose}');
  print('  recursive : ${config.recursive}');
  print('  exclude   : ${config.exclude}');
  print('');

  // ── 3. ConfigMerger — combine workspace and project exclusions ──────────
  //
  // Exclusion lists are additive: both levels contribute.
  final workspaceExclude = masterConfig?.exclude ?? [];
  final projectExclude = projectConfig?.exclude ?? [];
  final mergedExclude =
      ConfigMerger.mergeAdditive(workspaceExclude, projectExclude);

  // Scalar merge: project verbose overrides workspace verbose
  final verbose = ConfigMerger.mergeScalar(
    masterConfig?.verbose ?? false,
    projectConfig?.verbose ?? false,
  );

  if (verbose) {
    print('Merged excludes : $mergedExclude');
    print('');
  }

  // ── 4. Path validation ──────────────────────────────────────────────────
  //
  // Validate all configured paths are inside the workspace (security).
  final pathError = validatePathContainment(
    project: config.project,
    projects: config.projects,
    scan: config.scan,
    basePath: basePath,
  );
  if (pathError != null) {
    stderr.writeln('Path error: $pathError');
    exit(1);
  }
  print('Path validation : OK');

  // Quick inline containment check
  assert(isPathContained(p.join(basePath, 'lib'), basePath));
  print('');

  // ── 5. Discover projects ────────────────────────────────────────────────
  //
  // Strategy:  If a glob pattern is configured, use ProjectDiscovery;
  //            otherwise fall back to ProjectScanner.
  List<String> projectPaths;

  if (config.projects.isNotEmpty) {
    // 5a. Glob-based discovery via ProjectDiscovery
    final discovery = ProjectDiscovery(
      verbose: verbose,
      log: (msg) => print('  [discovery] $msg'),
    );

    projectPaths = await discovery.resolveProjectPatterns(
      config.projects.join(','),
      basePath: basePath,
      projectFilter: (path) => !isBuildYamlBuilderDefinition(path),
    );
    print('ProjectDiscovery found ${projectPaths.length} projects (glob)');
  } else {
    // 5b. ProjectScanner — recursive directory scan with custom validator
    final scanner = ProjectScanner(
      toolKey: toolKey,
      basePath: basePath,
      verbose: verbose,
      log: (msg) => print('  [scanner] $msg'),
      // Custom validator: any directory with pubspec.yaml
      projectValidator: (dirPath, _) =>
          File(p.join(dirPath, 'pubspec.yaml')).existsSync(),
    );

    projectPaths = scanner.scanForProjects(basePath, mergedExclude);
    print('ProjectScanner found ${projectPaths.length} projects (scan)');
  }

  // Apply exclusions (useful when paths come from multiple sources)
  final scanner2 = ProjectScanner(
    toolKey: toolKey,
    basePath: basePath,
  );
  projectPaths = scanner2.applyExclusions(projectPaths, mergedExclude);

  print('After exclusions : ${projectPaths.length} projects\n');

  // ── 6. Process each project — read version, track results ───────────────
  final result = ProcessingResult();

  for (final projectPath in projectPaths) {
    final name = p.basename(projectPath);

    // 6a. build.yaml checks: skip builder-definition packages
    if (isBuildYamlBuilderDefinition(projectPath)) {
      print('  ⏭  $name — builder definition, skipping');
      continue;
    }

    // 6b. Optionally check if a builder consumer config exists
    if (hasBuildYamlConsumerConfig(
        projectPath, 'tom_version_builder:version_builder')) {
      if (verbose) print('  ℹ  $name has version_builder consumer config');
    }

    // 6c. Check if builder is enabled
    if (isBuildYamlBuilderEnabled(
        projectPath, 'tom_version_builder:version_builder')) {
      if (verbose) print('  ℹ  $name — version_builder is enabled');
    }

    // 6d. Read builder options
    final builderOpts = getBuildYamlBuilderOptions(
      projectPath,
      'tom_version_builder:version_builder',
    );
    if (builderOpts != null && verbose) {
      print('  ℹ  $name — builder options: $builderOpts');
    }

    // 6e. Check for tool-specific tom_build.yaml config
    if (hasTomBuildConfig(projectPath, toolKey) && verbose) {
      print('  ℹ  $name has $toolKey section in tom_build.yaml');
    }

    // 6f. Read the version from pubspec.yaml
    final version = _readVersion(projectPath);
    if (version != null) {
      result.addSuccess(1);
      print('  ✓  $name $version');
    } else {
      result.addFailure();
      print('  ✗  $name — no version found');
    }
  }

  // ── 7. Merge a sub-result (e.g., from a parallel workstream) ────────────
  final otherResult = ProcessingResult(successCount: 0, failureCount: 0);
  result.merge(otherResult);

  // ── 8. Summary ──────────────────────────────────────────────────────────
  print('');
  print('──────────────────────────────────────');
  print('Total projects : ${result.totalCount}');
  print('Succeeded      : ${result.successCount}');
  print('Failed         : ${result.failureCount}');
  print('Files scanned  : ${result.fileCount}');

  if (result.hasFailures) {
    exit(1);
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

/// Read the `version:` field from a project's pubspec.yaml.
String? _readVersion(String projectPath) {
  final pubspecFile = File(p.join(projectPath, 'pubspec.yaml'));
  if (!pubspecFile.existsSync()) return null;

  try {
    final content = pubspecFile.readAsStringSync();
    final yaml = loadYaml(content) as YamlMap?;
    return yaml?['version']?.toString();
  } catch (_) {
    return null;
  }
}
