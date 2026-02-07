import 'dart:async';
import 'dart:io';

import 'pipeline_config.dart';
import 'pipeline_step.dart';
import 'builtin_commands.dart';

/// Executes pipelines with dependency resolution.
class PipelineExecutor {
  final PipelineConfig config;
  final String projectPath;
  final String rootPath;
  final bool verbose;
  final bool dryRun;

  /// Track which pipelines have been executed to avoid duplicates.
  final Set<String> _executedPipelines = {};

  /// Track execution stack to detect circular dependencies.
  final List<String> _executionStack = [];

  late final BuiltinCommands _builtinCommands;

  PipelineExecutor({
    required this.config,
    required this.projectPath,
    required this.rootPath,
    required this.verbose,
    required this.dryRun,
  }) {
    _builtinCommands = BuiltinCommands(
      projectPath: projectPath,
      rootPath: rootPath,
      verbose: verbose,
      dryRun: dryRun,
    );
  }

  /// Execute a pipeline by name.
  /// 
  /// Returns true if successful, false otherwise.
  Future<bool> execute(String pipelineName) async {
    // Check if already executed
    if (_executedPipelines.contains(pipelineName)) {
      if (verbose) print('Pipeline "$pipelineName" already executed, skipping.');
      return true;
    }

    // Check for circular dependency
    if (_executionStack.contains(pipelineName)) {
      print('Error: Circular dependency detected: ${_executionStack.join(' -> ')} -> $pipelineName');
      return false;
    }

    // Get pipeline configuration
    final pipeline = config.getPipeline(pipelineName);
    if (pipeline == null) {
      print('Error: Pipeline "$pipelineName" not found.');
      print('Available pipelines: ${config.pipelines.keys.join(', ')}');
      return false;
    }

    // Check if executable (for top-level calls)
    if (_executionStack.isEmpty && !pipeline.executable) {
      print('Error: Pipeline "$pipelineName" is not executable from command line.');
      return false;
    }

    _executionStack.add(pipelineName);

    try {
      if (verbose) {
        print('');
        print('=' * 60);
        print('Pipeline: $pipelineName');
        print('=' * 60);
      }

      // Execute runBefore pipelines
      for (final beforeName in pipeline.runBefore) {
        if (!await execute(beforeName)) {
          print('Error: runBefore pipeline "$beforeName" failed.');
          return false;
        }
      }

      // Execute precore steps
      if (pipeline.precore.isNotEmpty) {
        if (verbose) print('\n[precore]');
        if (!await _executeSteps(pipeline.precore)) {
          print('Error: precore steps failed.');
          return false;
        }
      }

      // Execute core steps
      if (pipeline.core.isNotEmpty) {
        if (verbose) print('\n[core]');
        if (!await _executeSteps(pipeline.core)) {
          print('Error: core steps failed.');
          return false;
        }
      }

      // Execute postcore steps
      if (pipeline.postcore.isNotEmpty) {
        if (verbose) print('\n[postcore]');
        if (!await _executeSteps(pipeline.postcore)) {
          print('Error: postcore steps failed.');
          return false;
        }
      }

      // Execute runAfter pipelines
      for (final afterName in pipeline.runAfter) {
        if (!await execute(afterName)) {
          print('Error: runAfter pipeline "$afterName" failed.');
          return false;
        }
      }

      _executedPipelines.add(pipelineName);
      if (verbose) print('\nPipeline "$pipelineName" completed successfully.');
      return true;
    } finally {
      _executionStack.removeLast();
    }
  }

  /// Execute a single command directly (for :command syntax).
  ///
  /// This is used when running commands directly from the command line
  /// without going through a pipeline definition.
  Future<bool> executeCommand(String command) async {
    return _executeCommand(command);
  }

  /// Execute a list of pipeline steps.
  Future<bool> _executeSteps(List<PipelineStep> steps) async {
    for (final step in steps) {
      // Check platform filter
      if (!step.shouldRunOnCurrentPlatform()) {
        if (verbose) {
          print('  Skipping step (platform filter): ${step.platforms}');
        }
        continue;
      }

      // Execute each command in the step
      for (final command in step.commands) {
        if (!await _executeCommand(command)) {
          return false;
        }
      }
    }
    return true;
  }

  /// Execute a single command.
  Future<bool> _executeCommand(String command) async {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return true;

    if (verbose) print('  Command: $trimmed');

    // Check if it's an explicit shell command (trusted - from pipeline config)
    if (trimmed.startsWith('shell ')) {
      return _executeShellCommand(trimmed.substring(6).trim());
    }

    // Check if it's a built-in command
    if (_builtinCommands.isBuiltin(trimmed)) {
      return _builtinCommands.execute(trimmed);
    }

    // Check if it's a pipeline reference
    if (config.pipelines.containsKey(trimmed)) {
      return execute(trimmed);
    }

    // Check if it's an allowed binary
    final binaryName = trimmed.split(RegExp(r'\s+')).first.toLowerCase();
    if (config.allowedBinaries.contains(binaryName)) {
      if (verbose) {
        print('  [allowed binary] Executing: $trimmed');
      }
      return _executeShellCommand(trimmed);
    }

    // Unknown command - NOT allowed
    print('  Error: Unknown command "$trimmed".');
    print('  Only built-in commands, configured pipelines, and allowed '
        'binaries can be executed.');
    print('  To run arbitrary shell commands, use the "shell " prefix in '
        'pipeline configuration.');
    if (config.allowedBinaries.isNotEmpty) {
      print('  Allowed binaries: ${config.allowedBinaries.join(', ')}');
    }
    return false;
  }

  /// Execute a shell command.
  Future<bool> _executeShellCommand(String command) async {
    // Expand variables
    final expanded = _expandVariables(command);

    if (dryRun) {
      print('  [DRY RUN] Would execute: $expanded');
      return true;
    }

    if (verbose) print('  Executing: $expanded');

    try {
      final result = await Process.run(
        'sh',
        ['-c', expanded],
        workingDirectory: projectPath,
        environment: _buildEnvironment(),
      );

      if (result.stdout.toString().isNotEmpty) {
        stdout.write(result.stdout);
      }
      if (result.stderr.toString().isNotEmpty) {
        stderr.write(result.stderr);
      }

      if (result.exitCode != 0) {
        print('  Command failed with exit code ${result.exitCode}');
        return false;
      }

      return true;
    } catch (e) {
      print('  Error executing command: $e');
      return false;
    }
  }

  /// Expand variables in a command string.
  String _expandVariables(String command) {
    var result = command;

    // Platform variables
    result = result.replaceAll(r'${current-platform-vs}', _getCurrentPlatformVs());
    result = result.replaceAll(r'${current-os}', Platform.operatingSystem);

    // Path variables
    result = result.replaceAll(r'${project}', projectPath);
    result = result.replaceAll(r'${root}', rootPath);

    return result;
  }

  /// Get the current platform in VS Code format (e.g., "darwin-arm64").
  String _getCurrentPlatformVs() {
    final os = Platform.operatingSystem;
    final arch = _getCurrentArch();

    switch (os) {
      case 'macos':
        return 'darwin-$arch';
      case 'linux':
        return 'linux-$arch';
      case 'windows':
        return 'win32-$arch';
      default:
        return '$os-$arch';
    }
  }

  String _getCurrentArch() {
    final dartExe = Platform.resolvedExecutable;
    if (dartExe.contains('arm64') || dartExe.contains('aarch64')) {
      return 'arm64';
    }
    if (dartExe.contains('arm')) {
      return 'armhf';
    }
    return 'x64';
  }

  /// Build environment variables for shell commands.
  Map<String, String> _buildEnvironment() {
    return {
      ...Platform.environment,
      'BUILDKIT_PROJECT': projectPath,
      'BUILDKIT_ROOT': rootPath,
      'BUILDKIT_PLATFORM': _getCurrentPlatformVs(),
    };
  }
}
