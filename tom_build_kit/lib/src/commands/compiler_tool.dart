import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../builders/compiler_builder.dart';
import '../platform_utils.dart';
import 'tool_base.dart';

/// Configuration for the compiler tool CLI.
class CompilerConfig {
  final String? project;
  final String? scan;
  final bool recursive;
  final List<String> exclude;
  final List<String> recursionExclude;
  final bool verbose;
  final bool dryRun;
  final List<String> targetFilter;
  final List<CommandSection> precompileSections;
  final List<CompileSection> compileSections;
  final List<CommandSection> postcompileSections;

  CompilerConfig({
    this.project,
    this.scan,
    this.recursive = false,
    this.exclude = const [],
    this.recursionExclude = const [],
    this.verbose = false,
    this.dryRun = false,
    this.targetFilter = const [],
    this.precompileSections = const [],
    this.compileSections = const [],
    this.postcompileSections = const [],
  });

  /// Load config from tom_build.yaml.
  static CompilerConfig? loadFromYaml(String dir) {
    final file = File('$dir/tom_build.yaml');
    if (!file.existsSync()) return null;

    try {
      final content = file.readAsStringSync();
      final yaml = loadYaml(content) as YamlMap?;
      if (yaml == null) return null;

      final compilerYaml = yaml['compiler'] as YamlMap?;
      if (compilerYaml == null) return null;

      return CompilerConfig(
        project: compilerYaml['project'] as String?,
        scan: compilerYaml['scan'] as String?,
        recursive: compilerYaml['recursive'] as bool? ?? false,
        exclude: ToolBase.toStringList(compilerYaml['exclude']),
        recursionExclude: ToolBase.toStringList(
            compilerYaml['recursion-exclude'] ?? compilerYaml['recursionExclude']),
      );
    } catch (_) {
      return null;
    }
  }

  /// Load compilation config from build.yaml.
  static CompilerConfig? loadFromBuildYaml(String dir,
      {String builderKey = 'tom_build_kit:compiler_builder'}) {
    final file = File('$dir/build.yaml');
    if (!file.existsSync()) return null;

    try {
      final content = file.readAsStringSync();
      final yaml = loadYaml(content) as YamlMap?;
      if (yaml == null) return null;

      final targets = yaml['targets'] as YamlMap?;
      final defaultTarget = targets?[r'$default'] as YamlMap?;
      final builders = defaultTarget?['builders'] as YamlMap?;
      final builder = builders?[builderKey] as YamlMap?;
      final options = builder?['options'] as YamlMap?;
      if (options == null) return null;

      // Parse precompile sections
      final precompile = <CommandSection>[];
      final precompileRaw = options['precompile'];
      if (precompileRaw is List) {
        for (final item in precompileRaw) {
          precompile.add(CommandSection.fromJson(item));
        }
      }

      // Parse compile sections
      final compiles = <CompileSection>[];
      final compilesRaw = options['compiles'];
      if (compilesRaw is List) {
        for (final item in compilesRaw) {
          compiles.add(CompileSection.fromJson(item));
        }
      }

      // Parse postcompile sections
      final postcompile = <CommandSection>[];
      final postcompileRaw = options['postcompile'];
      if (postcompileRaw is List) {
        for (final item in postcompileRaw) {
          postcompile.add(CommandSection.fromJson(item));
        }
      }

      return CompilerConfig(
        precompileSections: precompile,
        compileSections: compiles,
        postcompileSections: postcompile,
      );
    } catch (_) {
      return null;
    }
  }

  /// Merge with another config (other takes precedence).
  CompilerConfig merge(CompilerConfig other) {
    return CompilerConfig(
      project: other.project ?? project,
      scan: other.scan ?? scan,
      recursive: other.recursive || recursive,
      exclude: [...exclude, ...other.exclude],
      recursionExclude: [...recursionExclude, ...other.recursionExclude],
      verbose: other.verbose || verbose,
      dryRun: other.dryRun || dryRun,
      targetFilter: other.targetFilter.isNotEmpty
          ? other.targetFilter
          : targetFilter,
      precompileSections: other.precompileSections.isNotEmpty
          ? other.precompileSections
          : precompileSections,
      compileSections: other.compileSections.isNotEmpty
          ? other.compileSections
          : compileSections,
      postcompileSections: other.postcompileSections.isNotEmpty
          ? other.postcompileSections
          : postcompileSections,
    );
  }
}

/// Compiler tool - cross-platform Dart compilation with pre/post-compile commands.
///
/// Supports placeholder resolution, platform filtering, multi-target compilation,
/// and configurable command sequences.
class CompilerTool extends ToolBase {
  @override
  String get toolKey => 'compiler';

  @override
  String get toolDescription =>
      'Cross-platform Dart compilation with pre/post-compile commands';

  @override
  void addToolOptions(ArgParser parser) {
    parser.addOption('targets',
        abbr: 't',
        help: 'Target platforms (comma-separated, e.g., linux-x64,darwin-arm64)');
  }

  @override
  bool isToolProject(String dirPath) {
    final pubspec = File('$dirPath/pubspec.yaml');
    if (!pubspec.existsSync()) return false;
    final buildYaml = File('$dirPath/build.yaml');
    if (!buildYaml.existsSync()) return false;
    try {
      final content = buildYaml.readAsStringSync();
      return content.contains('tom_build_kit:compiler_builder');
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> run(List<String> args) async {
    if (checkVersionArg(args)) return true;

    final parser = createParser();
    ArgResults results;

    try {
      results = parser.parse(args);
    } catch (e) {
      print('Error: $e');
      _printUsage(parser);
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

    // Parse target filter
    final targetsArg = results['targets'] as String?;
    final targetFilter = targetsArg != null
        ? targetsArg.split(',').map((s) => s.trim()).toList()
        : <String>[];

    // Load workspace-level config
    final basePath = Directory.current.path;
    var config = CompilerConfig.loadFromYaml(basePath) ?? CompilerConfig();

    // Override with CLI options
    config = config.merge(CompilerConfig(
      project: results['project'] as String?,
      scan: results['scan'] as String?,
      recursive: results['recursive'] as bool,
      exclude: results['exclude'] as List<String>,
      recursionExclude: results['recursion-exclude'] as List<String>,
      verbose: verbose,
      dryRun: dryRun,
      targetFilter: targetFilter,
    ));

    // Validate paths
    if (!validateAndEnforcePaths(
      scan: config.scan,
      project: config.project,
      basePath: basePath,
    )) {
      return false;
    }

    // Find projects
    final projects = await findProjects(
      project: config.project,
      scan: config.scan,
      recursive: config.recursive,
      exclude: config.exclude,
      recursionExclude: config.recursionExclude,
      basePath: basePath,
    );

    if (listMode) {
      print('Projects with compiler configuration:');
      for (final project in projects) {
        if (isToolProject(project)) {
          print('  ${p.relative(project, from: basePath)}');
        }
      }
      return true;
    }

    if (showMode) {
      for (final project in projects) {
        print('Project: ${p.relative(project, from: basePath)}');
        printBuildYamlSection(project, 'tom_build_kit:compiler_builder');
      }
      return true;
    }

    // Process each project
    var success = true;
    for (final projectPath in projects) {
      if (!await processProject(projectPath, config)) {
        success = false;
      }
    }

    return success;
  }

  /// Process a single project: run precompile, compile, postcompile.
  Future<bool> processProject(
      String projectPath, CompilerConfig config) async {
    if (verbose) print('Processing: ${p.basename(projectPath)}');

    // Load project-level config (tom_build.yaml then build.yaml)
    var projectConfig = config;
    final yamlConfig = CompilerConfig.loadFromYaml(projectPath);
    if (yamlConfig != null) {
      projectConfig = projectConfig.merge(yamlConfig);
    }
    final buildYamlConfig = CompilerConfig.loadFromBuildYaml(projectPath);
    if (buildYamlConfig != null) {
      projectConfig = projectConfig.merge(buildYamlConfig);
    }

    if (projectConfig.compileSections.isEmpty) {
      if (verbose) print('  No compile sections configured');
      return true;
    }

    final currentPlatform = PlatformUtils.getCurrentPlatform();
    if (verbose) print('  Current platform: $currentPlatform');

    // Save and change to project directory
    final savedDir = Directory.current.path;
    Directory.current = projectPath;

    try {
      // Run precompile commands (continue on failure)
      for (final section in projectConfig.precompileSections) {
        await _runCommandSection(
          section: section,
          currentPlatform: currentPlatform,
          config: projectConfig,
          sectionName: 'precompile',
        );
      }

      // Run compile sections
      for (final section in projectConfig.compileSections) {
        // Check if this section runs on current platform
        if (section.platforms.isNotEmpty) {
          final matches = section.platforms.any(
              (p) => PlatformUtils.matchesPlatform(p, currentPlatform));
          if (!matches) {
            if (verbose) {
              print('  Skipping compile section (platform: '
                  '${section.platforms.join(', ')})');
            }
            continue;
          }
        }

        // Determine target platforms
        var targets = section.targets.isNotEmpty
            ? _expandTargets(section.targets)
            : [currentPlatform];

        // Apply target filter
        if (projectConfig.targetFilter.isNotEmpty) {
          targets = targets.where((t) {
            return projectConfig.targetFilter.any(
                (f) => PlatformUtils.matchesPlatform(f, t));
          }).toList();
          if (targets.isEmpty) {
            if (verbose) print('  No targets match filter');
            continue;
          }
        }

        // Compile each file for each target
        for (final file in section.files) {
          for (final target in targets) {
            if (!await _compileFile(
              file: file,
              targetPlatform: target,
              currentPlatform: currentPlatform,
              commandTemplates: section.commandlines,
              projectPath: projectPath,
              config: projectConfig,
            )) {
              return false;
            }
          }
        }
      }

      // Run postcompile commands (continue on failure)
      for (final section in projectConfig.postcompileSections) {
        await _runCommandSection(
          section: section,
          currentPlatform: currentPlatform,
          config: projectConfig,
          sectionName: 'postcompile',
        );
      }

      return true;
    } finally {
      Directory.current = savedDir;
    }
  }

  /// Run a command section (precompile/postcompile).
  Future<bool> _runCommandSection({
    required CommandSection section,
    required String currentPlatform,
    required CompilerConfig config,
    required String sectionName,
  }) async {
    // Check platform filter
    if (section.platforms.isNotEmpty) {
      final matches = section.platforms.any(
          (p) => PlatformUtils.matchesPlatform(p, currentPlatform));
      if (!matches) {
        if (verbose) {
          print('  Skipping $sectionName (platform: '
              '${section.platforms.join(', ')})');
        }
        return true;
      }
    }

    for (final commandTemplate in section.commandlines) {
      // Resolve current-platform placeholders
      var command = commandTemplate
          .replaceAll(r'${current-os}',
              PlatformUtils.getTargetOS(currentPlatform))
          .replaceAll(r'${current-arch}',
              PlatformUtils.getTargetArch(currentPlatform))
          .replaceAll(r'${current-platform}',
              PlatformUtils.vsCodeToDartTarget(currentPlatform))
          .replaceAll(r'${current-platform-vs}', currentPlatform);

      // Replace environment variables
      command = _replaceEnvVars(command);

      if (dryRun) {
        print('  [DRY RUN] $sectionName: $command');
        continue;
      }

      if (verbose) print('  $sectionName: $command');

      final result = await Process.run(
        '/bin/sh',
        ['-c', command],
        environment: Platform.environment,
      );

      if (result.stdout.toString().isNotEmpty) {
        stdout.write(result.stdout);
      }
      if (result.stderr.toString().isNotEmpty) {
        stderr.write(result.stderr);
      }

      if (result.exitCode != 0) {
        print('  Error: $sectionName command failed (exit ${result.exitCode})');
        return false;
      }
    }

    return true;
  }

  /// Compile a single file for a target platform.
  Future<bool> _compileFile({
    required String file,
    required String targetPlatform,
    required String currentPlatform,
    required List<String> commandTemplates,
    required String projectPath,
    required CompilerConfig config,
  }) async {
    // File path components
    final filePath = p.normalize(file);
    final fileName = p.basenameWithoutExtension(filePath);
    final fileBasename = p.basename(filePath);
    final fileExtension = p.extension(filePath);
    final fileDir = p.dirname(filePath);

    // Target platform components
    final targetOS = PlatformUtils.getTargetOS(targetPlatform);
    final targetArch = PlatformUtils.getTargetArch(targetPlatform);
    final targetDart = PlatformUtils.vsCodeToDartTarget(targetPlatform);
    final currentOS = PlatformUtils.getTargetOS(currentPlatform);
    final currentArch = PlatformUtils.getTargetArch(currentPlatform);

    for (final template in commandTemplates) {
      var command = template
          // File placeholders
          .replaceAll(r'${file}', filePath)
          .replaceAll(r'${file.path}', filePath)
          .replaceAll(r'${file.name}', fileName)
          .replaceAll(r'${file.basename}', fileBasename)
          .replaceAll(r'${file.extension}', fileExtension)
          .replaceAll(r'${file.dir}', fileDir)
          // Target platform placeholders
          .replaceAll(r'${target-os}', targetOS)
          .replaceAll(r'${target-arch}', targetArch)
          .replaceAll(r'${target-platform}', targetDart)
          .replaceAll(r'${target-platform-vs}', targetPlatform)
          // Current platform placeholders
          .replaceAll(r'${current-os}', currentOS)
          .replaceAll(r'${current-arch}', currentArch)
          .replaceAll(r'${current-platform}', currentPlatform)
          .replaceAll(r'${current-platform-vs}', currentPlatform);

      // Also support [placeholder] format
      command = command
          .replaceAll('[file]', filePath)
          .replaceAll('[file.name]', fileName)
          .replaceAll('[target-os]', targetOS)
          .replaceAll('[target-arch]', targetArch)
          .replaceAll('[target-platform]', targetDart)
          .replaceAll('[target-platform-vs]', targetPlatform);

      // Replace environment variables
      command = _replaceEnvVars(command);

      if (dryRun) {
        print('  [DRY RUN] compile ($targetPlatform): $command');
        continue;
      }

      if (verbose) {
        print('  Compiling $fileName for $targetPlatform...');
        print('    Command: $command');
      } else {
        print('  Compiling $fileName for $targetPlatform');
      }

      final result = await Process.run(
        '/bin/sh',
        ['-c', command],
        workingDirectory: projectPath,
        environment: Platform.environment,
      );

      if (result.stdout.toString().isNotEmpty) {
        stdout.write(result.stdout);
      }
      if (result.stderr.toString().isNotEmpty) {
        stderr.write(result.stderr);
      }

      if (result.exitCode != 0) {
        print('  Error: Compilation failed for $fileName ($targetPlatform)');
        return false;
      }
    }

    return true;
  }

  /// Expand target platform specifications (handles generic names like "linux").
  List<String> _expandTargets(List<String> targets) {
    final expanded = <String>[];
    for (final target in targets) {
      expanded.addAll(PlatformUtils.normalizePlatform(target));
    }
    return expanded;
  }

  /// Replace environment variables in a command string.
  /// Supports $VAR and [VAR] formats.
  String _replaceEnvVars(String command) {
    var result = command;

    // Replace $HOME, $USER, etc.
    result = result.replaceAllMapped(
      RegExp(r'\$(\w+)'),
      (match) {
        final varName = match.group(1)!;
        // Don't replace our own ${placeholder} patterns
        if (varName.startsWith('{')) return match.group(0)!;
        return Platform.environment[varName] ?? '';
      },
    );

    // Replace [VAR] format
    result = result.replaceAllMapped(
      RegExp(r'\[(\w+)\]'),
      (match) {
        final varName = match.group(1)!;
        return Platform.environment[varName] ?? '';
      },
    );

    return result;
  }

  void _printUsage(ArgParser parser) {
    print('Compiler Tool - $toolDescription');
    print('');
    print('Usage: compiler [options]');
    print('       buildkit :compiler [options]');
    print('');
    print('Placeholders in command lines:');
    print('  \${file}              - Source file path');
    print('  \${file.name}         - File name without extension');
    print('  \${file.basename}     - File name with extension');
    print('  \${target-os}         - Target OS (macos, linux, windows)');
    print('  \${target-arch}       - Target arch (x64, arm64, arm)');
    print('  \${target-platform}   - Dart target (macos-arm64)');
    print('  \${target-platform-vs} - VS Code format (darwin-arm64)');
    print('  \${current-os}        - Current OS');
    print('  \${current-platform-vs} - Current platform (VS Code format)');
    print('');
    print('Options:');
    print(parser.usage);
  }
}
