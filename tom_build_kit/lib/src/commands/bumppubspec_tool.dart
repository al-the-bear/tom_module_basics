import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'tool_base.dart';

/// Pubspec bump tool - updates package version references across projects.
///
/// Updates version constraints in pubspec.yaml files for specified packages.
/// Can replace `any`, `path:`, or `git:` dependencies with the actual version
/// currently used by those packages.
///
/// If `--refs` is not specified, automatically discovers all publishable
/// packages in the workspace (those without `publish_to: none`) and uses
/// their current versions.
///
/// ## Usage
///
/// ```bash
/// # Auto-discover publishable packages and update all references
/// buildkit -s . -r :bumppubspec
///
/// # Update references to specific package(s)
/// buildkit -s . -r :bumppubspec --refs tom_build_base
///
/// # Replace 'any' constraints with current version
/// buildkit -s . -r :bumppubspec --refs tom_build_base --replace-any
///
/// # Replace path dependencies with current version
/// buildkit -s . -r :bumppubspec --refs tom_build_base --replace-path
///
/// # Replace git dependencies with current version
/// buildkit -s . -r :bumppubspec --refs tom_build_base --replace-git
///
/// # Replace all non-versioned dependencies
/// buildkit -s . -r :bumppubspec --replace-any --replace-path --replace-git
///
/// # Dry run to see what would change
/// buildkit -s . -r :bumppubspec --replace-path -n
/// ```
class BumpPubspecTool extends ToolBase {
  @override
  String get toolKey => 'bumppubspec';

  @override
  String get toolDescription =>
      'Update package version references in pubspec.yaml files';

  @override
  void addToolOptions(ArgParser parser) {
    parser
      ..addOption('refs',
          help: 'Package names to update (comma-separated). '
              'If omitted, discovers all publishable packages in workspace.',
          valueHelp: 'pkg1,pkg2')
      ..addFlag('replace-any',
          negatable: false,
          help: 'Replace "any" version constraints with current version')
      ..addFlag('replace-path',
          negatable: false,
          help: 'Replace path: dependencies with current version')
      ..addFlag('replace-git',
          negatable: false,
          help: 'Replace git: dependencies with current version');
  }

  @override
  bool isToolProject(String dirPath) {
    // Any project with a pubspec.yaml is a valid target
    return File('$dirPath/pubspec.yaml').existsSync();
  }

  @override
  Future<bool> run(List<String> args) async {
    if (checkVersionArg(args)) return true;
    if (checkHelpArg(args)) {
      _printUsage(createParser());
      return true;
    }

    final parser = createParser();
    ArgResults results;
    WorkspaceNavigationArgs navArgs;
    String executionRoot;

    try {
      (results, navArgs, executionRoot) = parseArgsWithExecutionMode(parser, args);
    } on FormatException catch (e) {
      print('Error: $e');
      _printUsage(parser);
      return false;
    } on ArgumentError catch (e) {
      print('Error: $e');
      return false;
    }

    if (results['help'] as bool) {
      _printUsage(parser);
      return true;
    }

    verbose = results['verbose'] as bool;
    dryRun = results['dry-run'] as bool;
    final listMode = results['list'] as bool;
    final showMode = results['show'] as bool;

    // Parse options
    final refsOption = results['refs'] as String?;
    final replaceAny = results['replace-any'] as bool;
    final replacePath = results['replace-path'] as bool;
    final replaceGit = results['replace-git'] as bool;

    // Get package references - either from --refs or discover publishable packages
    List<String> packageRefs;
    if (refsOption != null && refsOption.isNotEmpty) {
      packageRefs = refsOption.split(',').map((s) => s.trim()).toList();
    } else {
      // Discover all publishable packages in the workspace
      if (verbose) {
        print('No --refs specified, discovering publishable packages...');
      }
      packageRefs = await _findPublishablePackages(executionRoot);
      if (packageRefs.isEmpty) {
        print('No publishable packages found in workspace');
        return false;
      }
      if (verbose) {
        print('Found ${packageRefs.length} publishable package(s): ${packageRefs.join(", ")}');
      }
    }

    // Validate paths
    if (!validateAndEnforcePaths(
      scan: navArgs.scan,
      project: navArgs.project,
      basePath: executionRoot,
    )) {
      return false;
    }

    // Find all packages in workspace to get their current versions
    final packageVersions = <String, String>{};
    for (final packageName in packageRefs) {
      final version = await _findPackageVersion(packageName, executionRoot);
      if (version != null) {
        packageVersions[packageName] = version;
        if (verbose) {
          print('Found $packageName: $version');
        }
      } else {
        print('Warning: Could not find version for package: $packageName');
      }
    }

    if (packageVersions.isEmpty) {
      print('Error: No package versions found for: ${packageRefs.join(", ")}');
      return false;
    }

    // Find projects using navigation args
    final projects = await findProjectsFromNavArgs(
      navArgs,
      basePath: executionRoot,
    );

    if (findProjectsError) return false;

    if (listMode) {
      print('Projects with pubspec.yaml:');
      for (final project in projects) {
        if (isToolProject(project)) {
          print('  ${p.relative(project, from: executionRoot)}');
        }
      }
      return true;
    }

    if (showMode) {
      for (final project in projects) {
        if (!isToolProject(project)) continue;
        final changes = _checkProjectForChanges(
          project,
          packageVersions,
          replaceAny: replaceAny,
          replacePath: replacePath,
          replaceGit: replaceGit,
        );
        if (changes.isNotEmpty) {
          print('${p.relative(project, from: executionRoot)}:');
          for (final change in changes) {
            print('  $change');
          }
        }
      }
      return true;
    }

    // Process each project
    var success = true;
    var updated = 0;
    var skipped = 0;

    for (final projectPath in projects) {
      if (!isToolProject(projectPath)) {
        skipped++;
        continue;
      }

      final result = await _updateProject(
        projectPath,
        packageVersions,
        executionRoot,
        replaceAny: replaceAny,
        replacePath: replacePath,
        replaceGit: replaceGit,
      );
      if (result > 0) {
        updated++;
      } else if (result < 0) {
        success = false;
      }
    }

    if (updated > 0 || skipped > 0) {
      print('');
      print('Pubspec update summary: $updated updated, $skipped skipped');
    }

    return success;
  }

  /// Find the version of a package by searching for its pubspec.yaml
  Future<String?> _findPackageVersion(String packageName, String executionRoot) async {
    // Search for the package directory
    final projectDiscovery = ProjectDiscovery(
      verbose: verbose,
      toolBasename: 'buildkit',
    );

    final projects = await projectDiscovery.scanForProjects(
      executionRoot,
      recursive: true,
    );

    for (final project in projects) {
      final pubspecPath = p.join(project, 'pubspec.yaml');
      if (File(pubspecPath).existsSync()) {
        final content = File(pubspecPath).readAsStringSync();
        final yaml = loadYaml(content);
        if (yaml is YamlMap && yaml['name'] == packageName) {
          final version = yaml['version'];
          if (version is String) {
            return version;
          }
        }
      }
    }
    return null;
  }

  /// Find all publishable packages in the workspace.
  ///
  /// A publishable package is one that does NOT have `publish_to: none` in pubspec.yaml.
  /// Returns a list of package names.
  Future<List<String>> _findPublishablePackages(String executionRoot) async {
    final projectDiscovery = ProjectDiscovery(
      verbose: verbose,
      toolBasename: 'buildkit',
    );

    final projects = await projectDiscovery.scanForProjects(
      executionRoot,
      recursive: true,
    );

    final publishable = <String>[];
    for (final project in projects) {
      final pubspecPath = p.join(project, 'pubspec.yaml');
      if (!File(pubspecPath).existsSync()) continue;

      final content = File(pubspecPath).readAsStringSync();
      final yaml = loadYaml(content);
      if (yaml is! YamlMap) continue;

      final name = yaml['name'];
      if (name is! String || name.isEmpty) continue;

      // Check if publishable (not publish_to: none)
      final publishTo = yaml['publish_to'];
      if (publishTo == 'none') continue;

      // Must have a version
      final version = yaml['version'];
      if (version is! String || version.isEmpty) continue;

      publishable.add(name);
    }

    return publishable;
  }

  /// Check what changes would be made to a project
  List<String> _checkProjectForChanges(
    String projectPath,
    Map<String, String> packageVersions, {
    required bool replaceAny,
    required bool replacePath,
    required bool replaceGit,
  }) {
    final changes = <String>[];
    final pubspecPath = p.join(projectPath, 'pubspec.yaml');

    if (!File(pubspecPath).existsSync()) return changes;

    final content = File(pubspecPath).readAsStringSync();
    final yaml = loadYaml(content) as YamlMap?;
    if (yaml == null) return changes;

    void checkDependencies(YamlMap? deps, String section) {
      if (deps == null) return;
      for (final entry in deps.entries) {
        final name = entry.key as String;
        if (!packageVersions.containsKey(name)) continue;

        final value = entry.value;
        final newVersion = '^${packageVersions[name]}';

        if (value == null || value == 'any') {
          if (replaceAny) {
            changes.add('$section $name: any → $newVersion');
          }
        } else if (value is YamlMap) {
          if (value.containsKey('path') && replacePath) {
            changes.add('$section $name: path: ${value['path']} → $newVersion');
          } else if (value.containsKey('git') && replaceGit) {
            changes.add('$section $name: git: ... → $newVersion');
          }
        } else if (value is String && value != newVersion) {
          changes.add('$section $name: $value → $newVersion');
        }
      }
    }

    checkDependencies(yaml['dependencies'] as YamlMap?, 'dependencies:');
    checkDependencies(yaml['dev_dependencies'] as YamlMap?, 'dev_dependencies:');

    return changes;
  }

  /// Update a project's pubspec.yaml
  ///
  /// Returns: >0 if updated, 0 if no changes needed, <0 if error
  Future<int> _updateProject(
    String projectPath,
    Map<String, String> packageVersions,
    String executionRoot, {
    required bool replaceAny,
    required bool replacePath,
    required bool replaceGit,
  }) async {
    final pubspecPath = p.join(projectPath, 'pubspec.yaml');

    if (!File(pubspecPath).existsSync()) return 0;

    final content = File(pubspecPath).readAsStringSync();
    final editor = YamlEditor(content);
    var changeCount = 0;

    void updateDependencies(String section) {
      final yaml = loadYaml(content) as YamlMap?;
      if (yaml == null) return;

      final deps = yaml[section] as YamlMap?;
      if (deps == null) return;

      for (final entry in deps.entries) {
        final name = entry.key as String;
        if (!packageVersions.containsKey(name)) continue;

        final value = entry.value;
        final newVersion = '^${packageVersions[name]}';
        var shouldUpdate = false;
        var oldValue = '';

        if (value == null || value == 'any') {
          if (replaceAny) {
            shouldUpdate = true;
            oldValue = value?.toString() ?? 'null';
          }
        } else if (value is YamlMap) {
          if (value.containsKey('path') && replacePath) {
            shouldUpdate = true;
            oldValue = 'path: ${value['path']}';
          } else if (value.containsKey('git') && replaceGit) {
            shouldUpdate = true;
            oldValue = 'git: ...';
          }
        } else if (value is String) {
          // Update existing version constraint
          if (value != newVersion) {
            shouldUpdate = true;
            oldValue = value;
          }
        }

        if (shouldUpdate) {
          try {
            editor.update([section, name], newVersion);
            changeCount++;

            final relProjectPath = p.relative(projectPath, from: executionRoot);
            if (dryRun) {
              print('[DRY-RUN] $relProjectPath: $name $oldValue → $newVersion');
            } else if (verbose) {
              print('$relProjectPath: $name $oldValue → $newVersion');
            }
          } catch (e) {
            print('Error updating $name in $projectPath: $e');
          }
        }
      }
    }

    updateDependencies('dependencies');
    updateDependencies('dev_dependencies');

    if (changeCount > 0 && !dryRun) {
      try {
        File(pubspecPath).writeAsStringSync(editor.toString());
        print('Updated: ${p.relative(projectPath, from: executionRoot)} ($changeCount changes)');
      } catch (e) {
        print('Error writing $pubspecPath: $e');
        return -1;
      }
    }

    return changeCount;
  }

  void _printUsage(ArgParser parser) {
    printUsageHeader();
    print('');
    print('Options:');
    print(parser.usage);
    print('');
    printNavigationHelp();
    print('');
    print('Examples:');
    print('  # Update all publishable package references (auto-discover)');
    print('  buildkit -s . -r :bumppubspec');
    print('');
    print('  # Update specific package references');
    print('  buildkit -s . -r :bumppubspec --refs tom_build_base');
    print('');
    print('  # Replace path dependencies with versioned ones');
    print('  buildkit -s . -r :bumppubspec --refs tom_build_base --replace-path');
    print('');
    print('  # Replace all non-versioned dependencies');
    print('  buildkit -s . -r :bumppubspec --refs tom_core,tom_basics --replace-any --replace-path --replace-git');
    print('');
    print('  # Dry run to see changes');
    print('  buildkit -s . -r :bumppubspec --replace-path -n');
  }
}
