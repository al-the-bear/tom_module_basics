import 'package:dcli/dcli.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../tom_build_base.dart';

/// Default tool key used by the show-versions tool.
const showVersionsToolKey = 'show_versions';

/// Result of a [showVersions] run.
class ShowVersionsResult {
  /// Projects with their versions (path → version string).
  final Map<String, String> versions;

  /// Projects where the version could not be read.
  final List<String> failures;

  /// The underlying [ProcessingResult] with counts.
  final ProcessingResult processingResult;

  const ShowVersionsResult({
    required this.versions,
    required this.failures,
    required this.processingResult,
  });

  /// Whether every discovered project was read successfully.
  bool get isSuccess => failures.isEmpty;
}

/// Options for [showVersions].
class ShowVersionsOptions {
  /// Workspace root path.  Defaults to the current directory.
  final String basePath;

  /// Tool key for config lookup.  Defaults to [showVersionsToolKey].
  final String toolKey;

  /// Enable verbose / debug output.
  final bool verbose;

  /// Optional log callback for diagnostic messages.
  final void Function(String message)? log;

  const ShowVersionsOptions({
    required this.basePath,
    this.toolKey = showVersionsToolKey,
    this.verbose = false,
    this.log,
  });
}

/// Discover all Dart projects under [options.basePath] and read their
/// `pubspec.yaml` version field.
///
/// This function exercises the full `tom_build_base` surface:
///
///   • [TomBuildConfig] — loading and merging workspace / project config
///   • [ConfigMerger] — additive exclude-list merging
///   • [ProjectScanner] — directory-walk with custom validation
///   • [ProjectDiscovery] — glob-based project resolution
///   • build.yaml utilities — skipping builder-definition packages
///   • Path utilities — containment validation
///   • [ProcessingResult] — batch success / failure tracking
Future<ShowVersionsResult> showVersions(ShowVersionsOptions options) async {
  final basePath = options.basePath;
  final toolKey = options.toolKey;
  final verbose = options.verbose;
  void log(String msg) => options.log?.call(msg);

  // ── 1. Load configuration (master + project, merged) ────────────────────
  final masterConfig =
      TomBuildConfig.loadMaster(dir: basePath, toolKey: toolKey);
  final projectConfig = TomBuildConfig.load(dir: basePath, toolKey: toolKey);

  TomBuildConfig config;
  if (masterConfig != null && projectConfig != null) {
    config = masterConfig.merge(projectConfig);
    log('Config: merged master + project');
  } else {
    config =
        projectConfig ?? masterConfig ?? const TomBuildConfig(verbose: true);
    log('Config: ${projectConfig != null ? "project" : masterConfig != null ? "master" : "defaults"}');
  }

  // ── 2. ConfigMerger — combine workspace and project exclusions ──────────
  final mergedExclude = ConfigMerger.mergeAdditive<String>(
    masterConfig?.exclude ?? const <String>[],
    projectConfig?.exclude ?? const <String>[],
  );

  final effectiveVerbose = ConfigMerger.mergeScalar(
    masterConfig?.verbose ?? false,
    projectConfig?.verbose ?? verbose,
  );

  if (effectiveVerbose) {
    log('Merged excludes: $mergedExclude');
  }

  // ── 3. Path validation ──────────────────────────────────────────────────
  final pathError = validatePathContainment(
    project: config.project,
    projects: config.projects,
    scan: config.scan,
    basePath: basePath,
  );
  if (pathError != null) {
    throw ArgumentError('Path validation failed: $pathError');
  }

  // ── 4. Discover projects ────────────────────────────────────────────────
  List<String> projectPaths;

  if (config.projects.isNotEmpty) {
    // Glob-based discovery via ProjectDiscovery
    final discovery = ProjectDiscovery(
      verbose: effectiveVerbose,
      log: (msg) => log('[discovery] $msg'),
    );

    projectPaths = await discovery.resolveProjectPatterns(
      config.projects.join(','),
      basePath: basePath,
      projectFilter: (path) => !isBuildYamlBuilderDefinition(path),
    );
    log('ProjectDiscovery found ${projectPaths.length} projects (glob)');
  } else {
    // ProjectScanner — recursive directory scan with custom validator
    final scanner = ProjectScanner(
      toolKey: toolKey,
      basePath: basePath,
      verbose: effectiveVerbose,
      log: (msg) => log('[scanner] $msg'),
      projectValidator: (dirPath, _) =>
          exists(p.join(dirPath, 'pubspec.yaml')),
    );

    projectPaths = scanner.scanForProjects(basePath, mergedExclude);
    log('ProjectScanner found ${projectPaths.length} projects (scan)');
  }

  // Apply exclusions
  final scanner = ProjectScanner(toolKey: toolKey, basePath: basePath);
  projectPaths = scanner.applyExclusions(projectPaths, mergedExclude);

  log('After exclusions: ${projectPaths.length} projects');

  // ── 5. Process each project — read version, track results ───────────────
  final result = ProcessingResult();
  final versions = <String, String>{};
  final failures = <String>[];

  for (final projectPath in projectPaths) {
    // Skip builder-definition packages
    if (isBuildYamlBuilderDefinition(projectPath)) {
      log('Skipping builder definition: ${p.basename(projectPath)}');
      continue;
    }

    // Log builder consumer info when verbose
    if (effectiveVerbose) {
      if (hasBuildYamlConsumerConfig(
          projectPath, 'tom_version_builder:version_builder')) {
        log('${p.basename(projectPath)} has version_builder consumer config');
      }
      if (isBuildYamlBuilderEnabled(
          projectPath, 'tom_version_builder:version_builder')) {
        log('${p.basename(projectPath)} — version_builder is enabled');
      }
      final builderOpts = getBuildYamlBuilderOptions(
        projectPath,
        'tom_version_builder:version_builder',
      );
      if (builderOpts != null) {
        log('${p.basename(projectPath)} — builder options: $builderOpts');
      }
      if (hasTomBuildConfig(projectPath, toolKey)) {
        log('${p.basename(projectPath)} has $toolKey in tom_build.yaml');
      }
    }

    // Read version
    final version = readPubspecVersion(projectPath);
    if (version != null) {
      result.addSuccess(1);
      versions[projectPath] = version;
    } else {
      result.addFailure();
      failures.add(projectPath);
    }
  }

  return ShowVersionsResult(
    versions: versions,
    failures: failures,
    processingResult: result,
  );
}

/// Read the `version:` field from a project's pubspec.yaml.
///
/// Returns `null` if the file doesn't exist or can't be parsed.
String? readPubspecVersion(String projectPath) {
  final pubspecPath = p.join(projectPath, 'pubspec.yaml');
  if (!exists(pubspecPath)) return null;

  try {
    final content = read(pubspecPath).toParagraph();
    final yaml = loadYaml(content) as YamlMap?;
    return yaml?['version']?.toString();
  } catch (_) {
    return null;
  }
}
