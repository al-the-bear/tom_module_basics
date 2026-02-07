import 'dart:io';

import 'package:tom_build_base/tom_build_base.dart';

/// Example: A simple CLI tool that scans for Dart projects and reports findings.
void main() async {
  final workspacePath = Directory.current.path;
  const toolKey = 'mytool';

  // 1. Load tool-specific configuration from tom_build.yaml
  final config = TomBuildConfig.load(
    dir: workspacePath,
    toolKey: toolKey,
  );

  if (config != null) {
    print('Found tom_build.yaml config:');
    print('  project: ${config.project}');
    print('  recursive: ${config.recursive}');
    print('  verbose: ${config.verbose}');
  }

  // 2. Scan for projects using ProjectScanner
  final scanner = ProjectScanner(
    toolKey: toolKey,
    basePath: workspacePath,
    verbose: true,
  );

  final projects = scanner.scanForProjects(workspacePath, []);

  print('\nFound ${projects.length} projects:');
  for (final project in projects) {
    // 3. Check if a project defines builders (skip those)
    if (isBuildYamlBuilderDefinition(project)) {
      print('  [builder] $project — skipping');
      continue;
    }

    print('  [project] $project');
  }

  // 4. Use ProjectDiscovery for advanced glob-based discovery
  final discovery = ProjectDiscovery(verbose: false);
  final resolved = await discovery.resolveProjectPatterns(
    'tom_*',
    basePath: workspacePath,
  );
  print('\nGlob-resolved projects: ${resolved.length}');

  // 5. Check path containment for security
  if (isPathContained('/some/project/lib', '/some/project')) {
    print('\nPath is safely contained within project root.');
  }

  // 6. Track processing results
  final result = ProcessingResult();
  for (final project in projects) {
    result.addSuccess();
    print('  Processed: $project');
  }
  print('\nTotal: ${result.successCount} succeeded, ${result.failureCount} failed');
}
