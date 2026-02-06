#!/usr/bin/env dart
/// Compiler CLI tool
///
/// Command-line interface for compiling Dart projects to native executables
/// with support for cross-compilation and multiple target platforms.
///
/// ## Configuration Sources
///
/// 1. Command-line arguments
/// 2. `tom_build.yaml` (compiler: section) in project directory for CLI options
/// 3. `build.yaml` (tom_compiler_builder:compiler_builder options) for compilation configs
///
/// ## Usage
///
/// ```bash
/// # Compile current project
/// compiler
///
/// # Compile specific project
/// compiler --project=my_app
///
/// # Scan and compile all projects
/// compiler --scan=. --recursive
///
/// # Show help
/// compiler --help
/// ```
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart';
import 'package:yaml/yaml.dart';

import 'package:tom_compiler_builder/src/compiler_builder.dart';
import 'package:tom_compiler_builder/src/platform_utils.dart';

/// The tool key for compiler in tom_build.yaml
const _toolKey = 'compiler';

/// Global verbose flag
bool _verbose = false;

/// Configuration for the compiler CLI.
class CompilerConfig {
  final String? project;
  final String? scan;
  final bool recursive;
  final List<String> exclude;
  final List<String> recursionExclude;
  final bool verbose;
  final bool dryRun;

  // Compiler-specific options
  final List<CompileSection> compileSections;

  const CompilerConfig({
    this.project,
    this.scan,
    this.recursive = false,
    this.exclude = const [],
    this.recursionExclude = const [],
    this.verbose = false,
    this.dryRun = false,
    this.compileSections = const [],
  });

  /// Load configuration from tom_build.yaml file (compiler: section).
  static CompilerConfig? loadFromYaml(String dir) {
    final yamlPath = p.join(dir, 'tom_build.yaml');
    final yamlFile = File(yamlPath);

    if (!yamlFile.existsSync()) return null;

    try {
      final content = yamlFile.readAsStringSync();
      final rootYaml = loadYaml(content) as YamlMap?;
      if (rootYaml == null) return null;

      final compilerYaml = rootYaml['compiler'] as YamlMap?;
      if (compilerYaml == null) return null;

      return CompilerConfig(
        project: compilerYaml['project'] as String?,
        scan: compilerYaml['scan'] as String?,
        recursive: compilerYaml['recursive'] as bool? ?? false,
        exclude: _toStringList(compilerYaml['exclude']),
        recursionExclude: _toStringList(
          compilerYaml['recursion-exclude'] ?? compilerYaml['recursionExclude'],
        ),
        verbose: compilerYaml['verbose'] as bool? ?? false,
      );
    } catch (e) {
      if (_verbose) {
        print('Error loading tom_build.yaml: $e');
      }
      return null;
    }
  }

  /// Load configuration from build.yaml file (tom_compiler_builder:compiler_builder options).
  static CompilerConfig? loadFromBuildYaml(String dir) {
    final buildYamlPath = p.join(dir, 'build.yaml');
    final buildYamlFile = File(buildYamlPath);

    if (!buildYamlFile.existsSync()) return null;

    try {
      final content = buildYamlFile.readAsStringSync();
      final rootYaml = loadYaml(content) as YamlMap?;
      if (rootYaml == null) return null;

      final targets = rootYaml['targets'] as YamlMap?;
      if (targets == null) return null;

      final defaultTarget = targets[r'$default'] as YamlMap?;
      if (defaultTarget == null) return null;

      final builders = defaultTarget['builders'] as YamlMap?;
      if (builders == null) return null;

      final compilerBuilder =
          builders['tom_compiler_builder:compiler_builder'] as YamlMap?;
      if (compilerBuilder == null) return null;

      final options = compilerBuilder['options'] as YamlMap?;
      if (options == null) return null;

      // Parse compile sections
      final sections = <CompileSection>[];
      final compilesRaw = options['compiles'];
      if (compilesRaw is YamlList) {
        for (final item in compilesRaw) {
          sections.add(CompileSection.fromJson(item));
        }
      }

      return CompilerConfig(
        compileSections: sections,
      );
    } catch (e) {
      if (_verbose) {
        print('Error loading build.yaml: $e');
      }
      return null;
    }
  }

  static List<String> _toStringList(dynamic value) {
    if (value == null) return [];
    if (value is String) return [value];
    if (value is YamlList) return value.map((e) => e.toString()).toList();
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  /// Merge this config with another, with the other taking precedence.
  CompilerConfig merge(CompilerConfig other) {
    return CompilerConfig(
      project: other.project ?? project,
      scan: other.scan ?? scan,
      recursive: other.recursive || recursive,
      exclude: [...exclude, ...other.exclude],
      recursionExclude: [...recursionExclude, ...other.recursionExclude],
      verbose: other.verbose || verbose,
      dryRun: other.dryRun || dryRun,
      compileSections: other.compileSections.isNotEmpty
          ? other.compileSections
          : compileSections,
    );
  }
}

void main(List<String> arguments) async {
  // Check for version command first (before parsing)
  if (arguments.isNotEmpty && 
      (arguments[0] == 'version' || 
       arguments[0] == '-version' || 
       arguments[0] == '--version')) {
    _printVersion();
    exit(0);
  }

  final parser = ArgParser()
    ..addOption('project',
        abbr: 'p', help: 'Path to specific project to compile')
    ..addOption('scan', abbr: 's', help: 'Directory to scan for projects')
    ..addFlag('recursive',
        abbr: 'r',
        help: 'Process subprojects recursively',
        negatable: false)
    ..addMultiOption('exclude',
        abbr: 'e', help: 'Glob patterns for projects to exclude')
    ..addMultiOption('recursion-exclude',
        help: 'Glob patterns to exclude from recursive traversal')
    ..addFlag('verbose',
        abbr: 'v', help: 'Show detailed output', negatable: false)
    ..addFlag('dry-run',
        abbr: 'd',
        help: 'Show what would be compiled without executing',
        negatable: false)
    ..addFlag('help', abbr: 'h', help: 'Show this help message', negatable: false);

  final ArgResults args;
  try {
    args = parser.parse(arguments);
    
    // Check for unexpected arguments (rest)
    if (args.rest.isNotEmpty) {
      stderr.writeln('Error: Unknown arguments: ${args.rest.join(' ')}');
      stderr.writeln('');
      _printUsage(parser);
      exit(1);
    }
  } catch (e) {
    stderr.writeln('Error: $e');
    stderr.writeln('');
    _printUsage(parser);
    exit(1);
  }

  if (args['help'] as bool) {
    _printUsage(parser);
    exit(0);
  }

  // Build config from CLI args
  final cliConfig = CompilerConfig(
    project: args['project'] as String?,
    scan: args['scan'] as String?,
    recursive: args['recursive'] as bool,
    exclude: args['exclude'] as List<String>,
    recursionExclude: args['recursion-exclude'] as List<String>,
    verbose: args['verbose'] as bool,
    dryRun: args['dry-run'] as bool,
  );

  _verbose = cliConfig.verbose;

  // Check if any meaningful option was provided
  final hasAnyOption = cliConfig.project != null || cliConfig.scan != null;

  CompilerConfig config;
  if (!hasAnyOption) {
    // Try loading from tom_build.yaml in current directory
    final yamlConfig = CompilerConfig.loadFromYaml(Directory.current.path);
    if (yamlConfig != null) {
      if (cliConfig.verbose) {
        print('Using configuration from tom_build.yaml (compiler: section)');
      }
      config = yamlConfig.merge(cliConfig);
    } else {
      // Default: process current directory
      config = CompilerConfig(
        project: Directory.current.path,
        recursive: cliConfig.recursive,
        exclude: cliConfig.exclude,
        recursionExclude: cliConfig.recursionExclude,
        verbose: cliConfig.verbose,
        dryRun: cliConfig.dryRun,
      );
    }
  } else {
    config = cliConfig;
  }

  // Validate path containment
  final validationError = validatePathContainment(
    project: config.project,
    scan: config.scan,
    basePath: Directory.current.path,
  );
  if (validationError != null) {
    stderr.writeln('Error: $validationError');
    stderr.writeln('All paths must be within the current working directory.');
    exit(1);
  }

  // Determine projects to process
  final projects = await _findProjects(config, Directory.current.path);

  if (projects.isEmpty) {
    print('No projects found to process.');
    if (config.verbose) {
      print('Tip: Create a build.yaml with tom_compiler_builder:compiler_builder section');
    }
    exit(0);
  }

  // Print header
  print('=' * 60);
  print('Compiler running');
  print('=' * 60);
  print('');

  // Process projects
  final result = ProcessingResult();
  for (final projectPath in projects) {
    final displayPath = p.relative(projectPath, from: Directory.current.path);
    print('Project: $displayPath');

    final success = await _processProject(projectPath, config);

    if (success) {
      result.addSuccess();
    } else {
      result.addFailure();
    }
    print('');
  }

  // Summary
  print('Compiler: Processed ${projects.length} project(s)');
  if (result.hasFailures) {
    print('  Failed: ${result.failureCount}');
    exit(1);
  }
}

/// Find projects to process based on configuration.
Future<List<String>> _findProjects(
    CompilerConfig config, String basePath) async {
  // Single project specified
  if (config.project != null) {
    final projectPath = p.normalize(p.join(basePath, config.project!));
    if (_isCompilerProject(projectPath)) {
      return [projectPath];
    } else {
      print(
          'Warning: Specified project does not have compiler configuration: ${config.project}');
      return [];
    }
  }

  // Scan directory for projects
  if (config.scan != null) {
    final scanner = ProjectScanner(
      toolKey: _toolKey,
      basePath: basePath,
      verbose: config.verbose,
      projectValidator: _isCompilerProject,
    );

    return scanner.scanForProjects(
      config.scan!,
      config.exclude,
    );
  }

  // Default: process current directory if it has config
  if (_isCompilerProject(basePath)) {
    return [basePath];
  }

  return [];
}

/// Check if a directory is a compiler project.
bool _isCompilerProject(String dirPath, [String? _]) {
  // Must have pubspec.yaml
  if (!File('$dirPath/pubspec.yaml').existsSync()) {
    return false;
  }

  // Check for build.yaml with compiler configuration
  final buildYaml = File('$dirPath/build.yaml');
  if (buildYaml.existsSync()) {
    try {
      final yaml = loadYaml(buildYaml.readAsStringSync()) as YamlMap;
      final targets = yaml['targets'] as YamlMap?;
      if (targets != null) {
        final defaultTarget = targets[r'$default'] as YamlMap?;
        if (defaultTarget != null) {
          final builders = defaultTarget['builders'] as YamlMap?;
          if (builders != null) {
            return builders
                .containsKey('tom_compiler_builder:compiler_builder');
          }
        }
      }
    } catch (_) {
      return false;
    }
  }

  return false;
}

/// Process a single project.
Future<bool> _processProject(String projectPath, CompilerConfig config) async {
  // Load compilation configuration from build.yaml
  var projectConfig = CompilerConfig.loadFromBuildYaml(projectPath);

  if (projectConfig == null || projectConfig.compileSections.isEmpty) {
    if (config.verbose) {
      print('Warning: No compilation configuration found in build.yaml');
    }
    return false;
  }

  // Merge with CLI config
  projectConfig = projectConfig.merge(config);

  // Get current platform
  final currentPlatform = PlatformUtils.getCurrentPlatform();
  if (config.verbose) {
    print('Current platform: $currentPlatform');
  }

  // Change to project directory
  final originalDir = Directory.current;
  Directory.current = projectPath;

  try {
    var compilationCount = 0;

    // Process each compilation section
    for (final section in projectConfig.compileSections) {
      // Check if this section should run on current platform
      if (section.platforms.isNotEmpty) {
        var matches = false;
        for (final platform in section.platforms) {
          if (PlatformUtils.matchesPlatform(platform, currentPlatform)) {
            matches = true;
            break;
          }
        }
        if (!matches) {
          if (config.verbose) {
            print(
                'Skipping section - current platform $currentPlatform not in platforms: ${section.platforms}');
          }
          continue;
        }
      }

      // Determine target platforms
      List<String> targetPlatforms;
      if (section.targets.isEmpty) {
        // No targets specified - compile for current platform only
        targetPlatforms = [currentPlatform];
      } else {
        // Expand target patterns
        targetPlatforms = [];
        for (final target in section.targets) {
          targetPlatforms.addAll(PlatformUtils.normalizePlatform(target));
        }
      }

      // Compile each file for each target
      for (final file in section.files) {
        for (final targetPlatform in targetPlatforms) {
          final success = await _compileFile(
            file: file,
            targetPlatform: targetPlatform,
            currentPlatform: currentPlatform,
            commandTemplates: section.commandlines,
            projectPath: projectPath,
            config: config,
          );

          if (success) {
            compilationCount++;
          }
        }
      }
    }

    if (compilationCount > 0) {
      print('Completed $compilationCount compilation(s)');
    }

    return true;
  } finally {
    Directory.current = originalDir;
  }
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
  // Parse file path components
  final filePath = p.normalize(file);
  final fileName = p.basenameWithoutExtension(file);
  final fileExtension = p.extension(file);
  final fileDir = p.dirname(file);
  final fileBasename = p.basename(file);
  
  // Resolve placeholders in all command templates
  final dartTarget = PlatformUtils.vsCodeToDartTarget(targetPlatform);
  final currentOS = PlatformUtils.getOSFromPlatform(currentPlatform);
  final targetOS = PlatformUtils.getOSFromPlatform(targetPlatform);
  
  final commands = commandTemplates.map((template) {
    var cmd = template
        // Full file path
        .replaceAll('\${file}', file)
        // File components
        .replaceAll('\${file.path}', filePath)
        .replaceAll('\${file.name}', fileName)
        .replaceAll('\${file.basename}', fileBasename)
        .replaceAll('\${file.extension}', fileExtension)
        .replaceAll('\${file.dir}', fileDir)
        // Platform targets
        .replaceAll('\${target}', dartTarget)
        .replaceAll('\${target_platform}', targetPlatform)
        .replaceAll('\${current_platform}', currentPlatform)
        // OS names (user-friendly: macos, linux, windows)
        .replaceAll('\${current_os}', currentOS)
        .replaceAll('\${target_os}', targetOS);

    // Replace environment variables (angled brackets only)
    return _replaceEnvVars(cmd);
  }).toList();

  print('Compiling: $file -> $targetPlatform');

  if (config.dryRun) {
    for (var i = 0; i < commands.length; i++) {
      print('  [DRY RUN] Command ${i + 1}/${commands.length}: ${commands[i]}');
    }
    return true;
  }

  // Execute commands sequentially, stopping on first failure
  try {
    // Set up environment with PATH
    final environment = Map<String, String>.from(Platform.environment);
    
    for (var i = 0; i < commands.length; i++) {
      final command = commands[i];
      final cmdNum = commands.length > 1 ? '${i + 1}/${commands.length}' : '';
      final prefix = cmdNum.isEmpty ? '' : ' ($cmdNum)';
      
      // Always print the command being executed
      print('  Executing$prefix: $command');
      
      final result = await Process.run(
        '/bin/sh',
        ['-c', command],
        // No workingDirectory needed - we already changed Directory.current
        environment: environment,
        runInShell: false,
      );

      if (result.exitCode != 0) {
        print('  Failed (exit code ${result.exitCode})');
        if (result.stderr.toString().trim().isNotEmpty) {
          print('  Error: ${result.stderr}');
        }
        return false; // Stop on first failure
      }
      
      if (config.verbose && result.stdout.toString().trim().isNotEmpty) {
        print('  Output: ${result.stdout}');
      }
    }
    
    print('  Success');
    return true;
  } catch (e) {
    print('  Error executing command: $e');
    return false;
  }
}

/// Replace environment variable placeholders in command string.
/// Only handles angled bracket format: <VAR>
String _replaceEnvVars(String command) {
  // Replace <VAR> pattern only
  final varPattern = RegExp(r'<(\w+)>');
  return command.replaceAllMapped(varPattern, (match) {
    final varName = match.group(1)!;
    return Platform.environment[varName] ?? '';
  });
}

void _printVersion() {
  try {
    // Try to load generated version
    // ignore: unused_local_variable
    const version = String.fromEnvironment('version', defaultValue: '1.0.0');
    const buildNumber = String.fromEnvironment('buildNumber', defaultValue: '0');
    const gitCommit = String.fromEnvironment('gitCommit', defaultValue: 'unknown');
    const buildTimestamp = String.fromEnvironment('buildTimestamp', defaultValue: '');
    
    print('Compiler Tool $version+$buildNumber');
    if (gitCommit != 'unknown') {
      print('Git: $gitCommit');
    }
    if (buildTimestamp.isNotEmpty) {
      print('Built: $buildTimestamp');
    }
  } catch (e) {
    // Fallback if version.g.dart doesn't exist
    print('Compiler Tool 1.0.0 (version info unavailable)');
  }
}

void _printUsage(ArgParser parser) {
  print('Compiler CLI - Cross-compilation tool');
  print('');
  print('Usage: compiler [options]');
  print('');
  print('Options:');
  print(parser.usage);
  print('');
  print('Configuration:');
  print('  tom_build.yaml - CLI options (project discovery)');
  print('  build.yaml     - Compilation configurations');
  print('');
  print('Examples:');
  print('  # Compile current project');
  print('  compiler');
  print('');
  print('  # Compile specific project');
  print('  compiler --project=my_app');
  print('');
  print('  # Scan and compile all projects');
  print('  compiler --scan=. --recursive');
}
