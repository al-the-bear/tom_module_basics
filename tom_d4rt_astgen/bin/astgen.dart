/// AST Generator CLI - Converts Dart source files to serialized AST YAML files
///
/// Configuration is read from buildkit.yaml (astgen: section).
///
/// Usage:
///   dart run tom_d4rt_astgen:astgen [options]
///
/// Options:
///   -p, --project=`<path>`   Process a specific project directory
///   -s, --scan=`<path>`      Scan directory for projects to process
///   -r, --recursive        Process subprojects recursively
///   -c, --config=`<path>`    Path to config file (default: buildkit.yaml)
///   -v, --verbose          Enable verbose output
///   -n, --dry-run          Show what would be done without doing it
///   -h, --help             Show this help message
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:args/args.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:tom_build_base/tom_build_base.dart';

import 'package:tom_d4rt_astgen/tom_d4rt_astgen.dart';

const toolKey = 'astgen';

void main(List<String> args) async {
  // Check for version command first (before parsing)
  if (args.isNotEmpty && 
      (args[0] == 'version' || 
       args[0] == '-version' || 
       args[0] == '--version')) {
    _printVersion();
    exit(0);
  }

  final parser = ArgParser()
    ..addOption('project',
        abbr: 'p',
        help: 'Project(s) to process (comma-separated, globs: tom_*_builder, ./*)')
    ..addOption('scan', abbr: 's', help: 'Scan directory for projects to process')
    ..addFlag('recursive', abbr: 'r', help: 'Process subprojects recursively')
    ..addOption('config', abbr: 'c', defaultsTo: TomBuildConfig.projectFilename, help: 'Path to config file')
    ..addFlag('verbose', abbr: 'v', help: 'Enable verbose output')
    ..addFlag('dry-run', abbr: 'n', help: 'Show what would be done without doing it')
    ..addFlag('list', abbr: 'l', help: 'List projects that would be processed (no action)')
    ..addFlag('show',
        help: 'With --list, show tom_build.yaml configuration for each project',
        negatable: false)
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help message');

  final ArgResults results;
  try {
    results = parser.parse(args);
    
    // Check for unexpected arguments
    if (results.rest.isNotEmpty) {
      print('Error: Unknown arguments: ${results.rest.join(' ')}\n');
      _printUsage(parser);
      exit(1);
    }
  } catch (e) {
    print('Error: $e\n');
    _printUsage(parser);
    exit(1);
  }

  if (results['help'] as bool) {
    _printUsage(parser);
    exit(0);
  }

  final basePath = Directory.current.path;
  final dryRun = results['dry-run'] as bool;

  // Load config from tom_build.yaml
  var config = TomBuildConfig.load(dir: basePath, toolKey: toolKey);

  // Override with command-line args
  config = (config ?? const TomBuildConfig()).copyWith(
    project: results['project'] as String?,
    scan: results['scan'] as String?,
    recursive: results['recursive'] as bool,
    verbose: results['verbose'] as bool,
  );

  // Validate paths
  final pathError = validatePathContainment(
    project: config.project,
    projects: config.projects,
    scan: config.scan,
    basePath: basePath,
  );
  if (pathError != null) {
    print('Error: $pathError');
    exit(1);
  }

  // Find projects to process
  final projects = await _findProjects(config, basePath);

  if (projects.isEmpty) {
    print('No projects found to process.');
    if (config.verbose) {
      print('Tip: Create a tom_build.yaml with an "astgen:" section or use --project option');
    }
    exit(0);
  }

  // Handle --list mode: just list projects without processing
  final listOnly = results['list'] as bool;
  final showConfig = results['show'] as bool;
  if (listOnly) {
    final workspaceRoot = ProjectDiscovery.findWorkspaceRoot(basePath);
    print('Astgen projects (${projects.length}):');
    for (final project in projects) {
      final relativePath = p.relative(project, from: workspaceRoot);
      print('  $relativePath');
      
      if (showConfig) {
        _printBuildYamlSection(project, workspaceRoot);
      }
    }
    exit(0);
  }

  // Print header
  print('astgen: Running on ${projects.length} project(s)');
  print('');

  // Process each project
  final result = ProcessingResult();
  for (final projectPath in projects) {
    // Show project being processed
    final displayPath = p.relative(projectPath, from: basePath);
    print('  $displayPath');

    if (config.verbose) {
      print('=' * 60);
    }

    final success = await _processProject(
      projectPath,
      results['config'] as String,
      config.verbose,
      dryRun,
    );

    if (success) {
      result.addSuccess();
    } else {
      result.addFailure();
    }
  }

  // Summary
  print('');
  print('astgen: Processed ${projects.length} project(s)');
  if (result.hasFailures) {
    print('  Failed: ${result.failureCount}');
    exit(1);
  }
}

/// Find projects to process based on configuration
Future<List<String>> _findProjects(TomBuildConfig config, String basePath) async {
  final discovery = ProjectDiscovery(verbose: config.verbose);

  // Project pattern(s) specified (supports comma-separated, globs, ./* etc.)
  if (config.project != null) {
    return discovery.resolveProjectPatterns(
      config.project!,
      basePath: basePath,
      projectFilter: _isAstgenProject,
    );
  }

  // Scan directory for projects
  if (config.scan != null) {
    final scanPath = p.isAbsolute(config.scan!)
        ? config.scan!
        : p.join(basePath, config.scan!);

    final allProjects = await discovery.scanForProjects(
      scanPath,
      recursive: config.recursive,
      toolKey: toolKey,
    );

    // Filter to only astgen projects
    return allProjects.where((path) => _isAstgenProject(path)).toList();
  }

  // Default: process current directory if it has config
  if (_isAstgenProject(basePath)) {
    return [basePath];
  }

  return [];
}

/// Check if a directory is an astgen project
bool _isAstgenProject(String dirPath) {
  // Must have pubspec.yaml
  if (!File('$dirPath/pubspec.yaml').existsSync()) {
    return false;
  }

  // Check for tom_build.yaml with astgen section
  return hasTomBuildConfig(dirPath, toolKey);
}

/// Process a single project
Future<bool> _processProject(
  String projectPath,
  String configFileName,
  bool verbose,
  bool dryRun,
) async {
  // Load conversion configurations from tom_build.yaml
  final configPath = p.join(projectPath, configFileName);
  final configs = _loadConfig(configPath, verbose);
  if (configs == null) {
    return false;
  }

  // Change to project directory for processing
  final originalDir = Directory.current.path;
  Directory.current = projectPath;

  try {
    // Process conversions
    final converter = AstConverter();
    var totalFiles = 0;
    var successCount = 0;
    var errorCount = 0;

    for (final conversionConfig in configs) {
      if (verbose) {
        print('\nProcessing conversion:');
        print('  Root: ${conversionConfig.root}');
        print('  Entrypoints: ${conversionConfig.entrypoints}');
        if (conversionConfig.exclude.isNotEmpty) {
          print('  Exclude: ${conversionConfig.exclude}');
        }
        print('  Output: ${conversionConfig.output}');
        print('  Preserve structure: ${conversionConfig.preserveStructure}');
        print('  Include sourcemap: ${conversionConfig.includeSourcemap}');
        print('  Include imports: ${conversionConfig.includeImports}');
        if (conversionConfig.includeImports) {
          print('  Import depth: ${conversionConfig.importDepth}');
          print('  Include relative imports: ${conversionConfig.includeRelativeImports}');
        }
      }

    // Resolve output directory
    final resolvedOutput = _resolveOutputPath(conversionConfig.output, verbose);
    if (resolvedOutput == null) {
      print('Error: Failed to resolve output path: ${conversionConfig.output}');
      errorCount++;
      continue;
    }

    // Resolve entrypoint files
    final files = _findFiles(
      conversionConfig.entrypoints,
      conversionConfig.exclude,
      conversionConfig.root,
      verbose,
    );

    if (files.isEmpty) {
      print('Warning: No files matched pattern: ${conversionConfig.entrypoints}');
      continue;
    }

    totalFiles += files.length;

    // Process each file
    for (final file in files) {
      final relativePath = p.relative(file, from: conversionConfig.root);
      final outputPath = _getOutputPath(
        file,
        conversionConfig.root,
        resolvedOutput,
        conversionConfig.preserveStructure,
      );

      if (verbose || dryRun) {
        print('  ${dryRun ? '[DRY RUN] ' : ''}$relativePath -> $outputPath');
      }

      if (!dryRun) {
        try {
          _convertFile(
            file, 
            outputPath, 
            converter, 
            conversionConfig,
            verbose,
          );
          successCount++;
        } catch (e, stackTrace) {
          print('Error converting $file: $e');
          if (verbose) {
            print('Stack trace: $stackTrace');
          }
          errorCount++;
          // Always fail on errors - exit immediately
          exit(1);
        }
      }
    }
  }

    // Summary for this project
    if (verbose) {
      print('\n${dryRun ? 'Would convert' : 'Converted'} $totalFiles file(s)');
      if (!dryRun) {
        print('  Success: $successCount');
        if (errorCount > 0) {
          print('  Errors: $errorCount');
          return false;
        }
      }
    }

    return true;
  } finally {
    // Restore original directory
    Directory.current = originalDir;
  }
}

void _printVersion() {
  try {
    const version = String.fromEnvironment('version', defaultValue: '1.0.0');
    const buildNumber = String.fromEnvironment('buildNumber', defaultValue: '0');
    const gitCommit = String.fromEnvironment('gitCommit', defaultValue: 'unknown');
    const buildTimestamp = String.fromEnvironment('buildTimestamp', defaultValue: '');
    
    print('AST Generator Tool $version+$buildNumber');
    if (gitCommit != 'unknown') {
      print('Git: $gitCommit');
    }
    if (buildTimestamp.isNotEmpty) {
      print('Built: $buildTimestamp');
    }
  } catch (e) {
    print('AST Generator Tool 1.0.0 (version info unavailable)');
  }
}

/// Print the buildkit.yaml section for a project (--show option).
void _printBuildYamlSection(String projectPath, String workspaceRoot) {
  final yamlPath = p.join(projectPath, TomBuildConfig.projectFilename);
  final yamlFile = File(yamlPath);
  
  if (!yamlFile.existsSync()) {
    print('    (no buildkit.yaml)');
    return;
  }
  
  try {
    final content = yamlFile.readAsStringSync();
    final rootYaml = loadYaml(content) as YamlMap?;
    if (rootYaml == null) {
      print('    (empty buildkit.yaml)');
      return;
    }
    
    // Navigate to astgen section
    final astgenSection = rootYaml['astgen'] as YamlMap?;
    if (astgenSection == null) {
      print('    (no astgen section in buildkit.yaml)');
      return;
    }
    
    // Print the astgen section as YAML
    print('    buildkit.yaml:');
    _printYamlNode(astgenSection, indent: 6);
  } catch (e) {
    print('    (error reading buildkit.yaml: $e)');
  }
}

/// Print a YAML node with proper indentation.
void _printYamlNode(dynamic node, {int indent = 0}) {
  final prefix = ' ' * indent;
  
  if (node is YamlMap) {
    for (final entry in node.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (value is YamlMap || value is YamlList) {
        print('$prefix$key:');
        _printYamlNode(value, indent: indent + 2);
      } else {
        print('$prefix$key: $value');
      }
    }
  } else if (node is YamlList) {
    for (final item in node) {
      if (item is YamlMap) {
        // Print first key on same line as dash
        final entries = item.entries.toList();
        if (entries.isNotEmpty) {
          final first = entries.first;
          if (first.value is YamlMap || first.value is YamlList) {
            print('$prefix- ${first.key}:');
            _printYamlNode(first.value, indent: indent + 4);
          } else {
            print('$prefix- ${first.key}: ${first.value}');
          }
          // Print remaining keys indented
          for (var i = 1; i < entries.length; i++) {
            final entry = entries[i];
            if (entry.value is YamlMap || entry.value is YamlList) {
              print('$prefix  ${entry.key}:');
              _printYamlNode(entry.value, indent: indent + 4);
            } else {
              print('$prefix  ${entry.key}: ${entry.value}');
            }
          }
        }
      } else if (item is YamlList) {
        print('$prefix-');
        _printYamlNode(item, indent: indent + 2);
      } else {
        print('$prefix- $item');
      }
    }
  } else {
    print('$prefix$node');
  }
}

void _printUsage(ArgParser parser) {
  print('AST Generator CLI - Converts Dart source files to serialized AST YAML files');
  print('');
  print('Usage: dart run tom_d4rt_astgen:astgen [options]');
  print('');
  print('Options:');
  print(parser.usage);
  print('');
  print('Configuration:');
  print('  Reads from tom_build.yaml file with the following structure:');
  print('');
  print('  astgen:');
  print('    convert:');
  print('      - entrypoints: lib/*.runner.dart');
  print('        output: project:tom_runtime/asset');
  print('        root: .');
  print('');
  print('Output:');
  print('  Generated files have the extension .ast.yaml');
  print('  Example: my_tool.dart -> my_tool.ast.yaml');
  print('');
  print('Documentation:');
  print('  See doc/astgen_build_yaml.md for full configuration options');
}

class _ConversionConfig {
  final String entrypoints;
  final List<String> exclude;
  final String output;
  final String root;
  final bool preserveStructure;
  final bool includeSourcemap;
  final bool includeImports;
  final int importDepth;
  final bool includeRelativeImports;

  _ConversionConfig({
    required this.entrypoints,
    required this.exclude,
    required this.output,
    required this.root,
    required this.preserveStructure,
    required this.includeSourcemap,
    required this.includeImports,
    required this.importDepth,
    required this.includeRelativeImports,
  });
}

List<_ConversionConfig>? _loadConfig(String configPath, bool verbose) {
  final configFile = File(configPath);

  if (!configFile.existsSync()) {
    print('Error: Configuration file not found: $configPath');
    return null;
  }

  try {
    final yamlString = configFile.readAsStringSync();
    final yaml = loadYaml(yamlString) as YamlMap;

    if (!yaml.containsKey('astgen')) {
      print('Error: No "astgen" section found in $configPath');
      return null;
    }

    final astgenConfig = yaml['astgen'] as YamlMap;

    if (!astgenConfig.containsKey('convert')) {
      print('Error: No "convert" section found in astgen configuration');
      return null;
    }

    final convertList = astgenConfig['convert'] as YamlList;
    final configs = <_ConversionConfig>[];

    for (final item in convertList) {
      final config = item as YamlMap;

      final entrypoints = config['entrypoints'] as String?;
      final output = config['output'] as String?;
      final root = config['root'] as String? ?? '.';
      
      // Parse exclude list
      final exclude = <String>[];
      if (config.containsKey('exclude')) {
        final excludeValue = config['exclude'];
        if (excludeValue is YamlList) {
          exclude.addAll(excludeValue.map((e) => e.toString()));
        } else if (excludeValue is String) {
          exclude.add(excludeValue);
        }
      }
      
      // Parse options with defaults
      final preserveStructure = config['preserve_structure'] as bool? ?? false;
      final includeSourcemap = config['include_sourcemap'] as bool? ?? false;
      final includeImports = config['include_imports'] as bool? ?? false;
      final importDepth = config['import_depth'] as int? ?? 1;
      final includeRelativeImports = config['include_relative_imports'] as bool? ?? true;

      if (entrypoints == null) {
        print('Error: Missing "entrypoints" in conversion configuration');
        return null;
      }

      if (output == null) {
        print('Error: Missing "output" in conversion configuration');
        return null;
      }

      configs.add(_ConversionConfig(
        entrypoints: entrypoints,
        exclude: exclude,
        output: output,
        root: root,
        preserveStructure: preserveStructure,
        includeSourcemap: includeSourcemap,
        includeImports: includeImports,
        importDepth: importDepth,
        includeRelativeImports: includeRelativeImports,
      ));
    }

    if (verbose) {
      print('Loaded ${configs.length} conversion configuration(s) from $configPath');
    }

    return configs;
  } catch (e) {
    print('Error parsing configuration file: $e');
    return null;
  }
}

List<String> _findFiles(String pattern, List<String> excludePatterns, String root, bool verbose) {
  final glob = Glob(pattern);
  final excludeGlobs = excludePatterns.map((p) => Glob(p)).toList();
  final files = <String>[];

  // Change to root directory for glob matching
  final originalDir = Directory.current.path;
  Directory.current = root;

  try {
    for (final entity in glob.listSync()) {
      if (entity is File) {
        final filePath = entity.path;
        
        // Check if file matches any exclude pattern
        var excluded = false;
        for (final excludeGlob in excludeGlobs) {
          if (excludeGlob.matches(filePath)) {
            excluded = true;
            if (verbose) {
              print('  Excluding: $filePath');
            }
            break;
          }
        }
        
        if (!excluded) {
          files.add(p.join(root, filePath));
        }
      }
    }
  } finally {
    Directory.current = originalDir;
  }

  if (verbose && files.isNotEmpty) {
    print('  Found ${files.length} file(s) matching pattern: $pattern');
  }

  return files;
}

String? _resolveOutputPath(String outputTemplate, bool verbose) {
  // Handle project:name/path notation
  final projectPattern = RegExp(r'^project:([^/]+)(.*)$');
  final match = projectPattern.firstMatch(outputTemplate);
  
  if (match != null) {
    final projectName = match.group(1)!;
    var subPath = match.group(2) ?? '';
    
    // Remove leading slash from subPath if present
    if (subPath.startsWith('/')) {
      subPath = subPath.substring(1);
    }
    
    // Search for project in workspace
    final projectPath = _findProjectInWorkspace(projectName, verbose);
    if (projectPath == null) {
      print('Error: Project "$projectName" not found in workspace');
      return null;
    }
    
    return p.join(projectPath, subPath);
  }
  
  // Handle absolute and relative paths
  return outputTemplate;
}

String? _findProjectInWorkspace(String projectName, bool verbose) {
  // Start from current directory and search upwards for workspace root
  var currentDir = Directory.current;
  
  // First, try to find in sibling directories
  final parent = currentDir.parent;
  
  // Search in parent and sibling directories
  final searchDirs = [
    parent,
    ...parent.listSync().whereType<Directory>(),
  ];
  
  for (final dir in searchDirs) {
    // Check if this directory contains a project with the name
    final projectDir = Directory(p.join(dir.path, projectName));
    if (projectDir.existsSync()) {
      final pubspecFile = File(p.join(projectDir.path, 'pubspec.yaml'));
      if (pubspecFile.existsSync()) {
        // Verify the project name in pubspec.yaml
        final pubspecContent = pubspecFile.readAsStringSync();
        final pubspec = loadYaml(pubspecContent) as YamlMap;
        final name = pubspec['name'] as String?;
        
        if (name == projectName) {
          if (verbose) {
            print('  Found project "$projectName" at: ${projectDir.path}');
          }
          return projectDir.path;
        }
      }
    }
    
    // Also check subdirectories
    if (dir.path != parent.path) {
      for (final subDir in dir.listSync().whereType<Directory>()) {
        final projectDir = Directory(p.join(subDir.path, projectName));
        if (projectDir.existsSync()) {
          final pubspecFile = File(p.join(projectDir.path, 'pubspec.yaml'));
          if (pubspecFile.existsSync()) {
            final pubspecContent = pubspecFile.readAsStringSync();
            final pubspec = loadYaml(pubspecContent) as YamlMap;
            final name = pubspec['name'] as String?;
            
            if (name == projectName) {
              if (verbose) {
                print('  Found project "$projectName" at: ${projectDir.path}');
              }
              return projectDir.path;
            }
          }
        }
      }
    }
  }
  
  return null;
}

String _getOutputPath(String inputFile, String root, String outputDir, bool preserveStructure) {
  // Get basename and replace extension
  final basename = p.basenameWithoutExtension(inputFile);
  final outputFilename = '$basename.ast.yaml';

  if (preserveStructure) {
    // Preserve directory structure relative to root
    final relativePath = p.relative(inputFile, from: root);
    final relativeDir = p.dirname(relativePath);
    
    if (relativeDir == '.') {
      return p.join(outputDir, outputFilename);
    } else {
      return p.join(outputDir, relativeDir, outputFilename);
    }
  } else {
    // Flat output - all files in output directory
    return p.join(outputDir, outputFilename);
  }
}

void _convertFile(
  String inputPath, 
  String outputPath, 
  AstConverter converter, 
  _ConversionConfig config,
  bool verbose,
) {
  // Read and parse the Dart file
  final content = File(inputPath).readAsStringSync();
  final parseResult = parseString(
    content: content,
    path: inputPath,
  );

  // Check for parse errors - always fail on errors
  if (parseResult.errors.isNotEmpty) {
    print('Parse errors found in $inputPath:');
    for (final error in parseResult.errors) {
      print('  ${error.message} at line ${error.offset}');
    }
    throw Exception('Parse errors in $inputPath');
  }

  // Convert to serializable AST
  final ast = converter.convertCompilationUnit(parseResult.unit);

  // Convert to JSON first (since our AST model has toJson)
  var jsonData = ast.toJson();

  // Add sourcemap if requested
  if (config.includeSourcemap) {
    jsonData = {
      'sourcemap': {
        'source_file': p.absolute(inputPath),
        'generated_at': DateTime.now().toIso8601String(),
      },
      'ast': jsonData,
    };
  }

  // TODO: Handle include_imports if enabled
  if (config.includeImports) {
    // This would require:
    // 1. Parsing import directives from the AST
    // 2. Resolving import paths (relative vs package imports)
    // 3. Recursively converting imported files up to import_depth
    // 4. Filtering based on include_relative_imports setting
    // 5. Avoiding circular imports
    // For now, this is a placeholder
    if (verbose) {
      print('    Note: include_imports not yet implemented');
    }
  }

  // Convert JSON to YAML string
  final yamlString = _jsonToYaml(jsonData);

  // Ensure output directory exists
  final outputFile = File(outputPath);
  outputFile.parent.createSync(recursive: true);

  // Write YAML file
  outputFile.writeAsStringSync(yamlString);

  if (verbose) {
    print('    Generated: $outputPath (${outputFile.lengthSync()} bytes)');
  }
}

String _jsonToYaml(Map<String, dynamic> json, [int indent = 0]) {
  final buffer = StringBuffer();
  final indentStr = '  ' * indent;

  json.forEach((key, value) {
    if (value == null) {
      // Skip null values for cleaner output
      return;
    }

    buffer.write('$indentStr$key:');

    if (value is Map<String, dynamic>) {
      buffer.writeln();
      buffer.write(_jsonToYaml(value, indent + 1));
    } else if (value is List) {
      if (value.isEmpty) {
        buffer.writeln(' []');
      } else {
        buffer.writeln();
        for (final item in value) {
          if (item is Map<String, dynamic>) {
            buffer.writeln('$indentStr  -');
            buffer.write(_jsonToYaml(item, indent + 2));
          } else {
            buffer.writeln('$indentStr  - ${_formatValue(item)}');
          }
        }
      }
    } else {
      buffer.writeln(' ${_formatValue(value)}');
    }
  });

  return buffer.toString();
}

String _formatValue(dynamic value) {
  if (value is String) {
    // Escape special characters and quote if needed
    if (value.contains('\n') || value.contains(':') || value.contains('#')) {
      return '"${value.replaceAll('"', '\\"').replaceAll('\n', '\\n')}"';
    }
    return value;
  }
  return value.toString();
}
