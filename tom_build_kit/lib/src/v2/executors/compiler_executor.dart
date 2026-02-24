/// Native v2 executor for the compiler command.
///
/// Cross-platform Dart compilation with pre/post-compile command sequences,
/// placeholder resolution, platform filtering, and multi-target compilation.
///
/// Reuses existing utility files for config parsing, platform detection,
/// and built-in command dispatch.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base.dart'
    show findWorkspaceRoot, ProcessRunner;
import 'package:tom_build_base/tom_build_base_v2.dart';
import 'package:yaml/yaml.dart';

import '../../builtin_commands.dart';
import '../../compiler_config.dart';
import '../../platform_utils.dart';
import '../../script_utils.dart' as script_utils;

// =============================================================================
// CompilerConfig (v2 version)
// =============================================================================

/// Configuration for the compiler tool, merging workspace + project configs.
class _CompilerConfig {
  final List<String> targetFilter;
  final List<String> executableFilter;
  final List<CommandSection> precompileSections;
  final List<CompileSection> compileSections;
  final List<CommandSection> postcompileSections;

  const _CompilerConfig({
    this.targetFilter = const [],
    this.executableFilter = const [],
    this.precompileSections = const [],
    this.compileSections = const [],
    this.postcompileSections = const [],
  });

  /// Load compile sections from buildkit.yaml compiler section.
  static _CompilerConfig? loadFromYaml(String dir) {
    final file = File('$dir/buildkit.yaml');
    if (!file.existsSync()) return null;

    try {
      final content = file.readAsStringSync();
      final yaml = loadYaml(content) as YamlMap?;
      if (yaml == null) return null;

      final compilerYaml = yaml['compiler'] as YamlMap?;
      if (compilerYaml == null) return null;

      final precompile = <CommandSection>[];
      final preRaw = compilerYaml['precompile'];
      if (preRaw is List) {
        for (final item in preRaw) {
          precompile.add(CommandSection.fromJson(item));
        }
      }

      final compiles = <CompileSection>[];
      final compilesRaw = compilerYaml['compiles'];
      if (compilesRaw is List) {
        for (final item in compilesRaw) {
          compiles.add(CompileSection.fromJson(item));
        }
      }

      final postcompile = <CommandSection>[];
      final postRaw = compilerYaml['postcompile'];
      if (postRaw is List) {
        for (final item in postRaw) {
          postcompile.add(CommandSection.fromJson(item));
        }
      }

      return _CompilerConfig(
        precompileSections: precompile,
        compileSections: compiles,
        postcompileSections: postcompile,
      );
    } catch (_) {
      return null;
    }
  }

  _CompilerConfig merge(_CompilerConfig other) {
    return _CompilerConfig(
      targetFilter: other.targetFilter.isNotEmpty
          ? other.targetFilter
          : targetFilter,
      executableFilter: other.executableFilter.isNotEmpty
          ? other.executableFilter
          : executableFilter,
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

// =============================================================================
// Executor
// =============================================================================

/// Native v2 executor for the `:compiler` command.
class CompilerExecutor extends CommandExecutor {
  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    final projectPath = context.path;

    // Check if project has compiler config
    if (!_hasCompilerConfig(projectPath)) {
      return ItemResult.success(
        path: projectPath,
        name: context.name,
        message: 'skipped (no compiler config)',
      );
    }

    // List mode: just print project path
    if (args.listOnly) {
      print('  ${p.relative(projectPath, from: context.executionRoot)}');
      return ItemResult.success(
        path: projectPath,
        name: context.name,
        message: 'listed',
      );
    }

    // Dump config mode: show compiler configuration
    if (args.dumpConfig) {
      final config = _CompilerConfig.loadFromYaml(projectPath);
      print('  ${context.name}:');
      if (config != null) {
        if (config.compileSections.isNotEmpty) {
          print('    compiles: ${config.compileSections.length} sections');
          for (final section in config.compileSections) {
            final desc = section.files.isNotEmpty
                ? section.files.join(', ')
                : section.commandlines.join(', ');
            final tgt = section.targets.isNotEmpty
                ? ' → ${section.targets.join(', ')}'
                : '';
            print('      - $desc$tgt');
          }
        }
        if (config.precompileSections.isNotEmpty) {
          print('    precompile: ${config.precompileSections.length} sections');
        }
        if (config.postcompileSections.isNotEmpty) {
          print(
            '    postcompile: ${config.postcompileSections.length} sections',
          );
        }
      } else {
        print('    compiler: (no config)');
      }
      return ItemResult.success(
        path: projectPath,
        name: context.name,
        message: 'config shown',
      );
    }

    final cmdOpts = _getCmdOpts(args);

    // Parse target filter from CLI
    final targetFilter = <String>[];
    final targetsArg = cmdOpts['targets'];
    if (targetsArg is String) {
      targetFilter.addAll(targetsArg.split(',').map((s) => s.trim()));
    } else if (targetsArg is List) {
      for (final t in targetsArg) {
        targetFilter.addAll(t.toString().split(',').map((s) => s.trim()));
      }
    }

    // Parse executable filter from CLI
    final executableFilter = <String>[];
    final executableArg = cmdOpts['executable'];
    if (executableArg is String) {
      executableFilter.addAll(executableArg.split(',').map((s) => s.trim()));
    } else if (executableArg is List) {
      for (final e in executableArg) {
        executableFilter.addAll(e.toString().split(',').map((s) => s.trim()));
      }
    }

    // Load workspace config then merge project config
    var config =
        _CompilerConfig.loadFromYaml(context.executionRoot) ??
        const _CompilerConfig();
    final projectConfig = _CompilerConfig.loadFromYaml(projectPath);
    if (projectConfig != null) {
      config = config.merge(projectConfig);
    }
    if (targetFilter.isNotEmpty) {
      config = config.merge(_CompilerConfig(targetFilter: targetFilter));
    }
    if (executableFilter.isNotEmpty) {
      config = config.merge(
        _CompilerConfig(executableFilter: executableFilter),
      );
    }

    if (config.compileSections.isEmpty) {
      if (args.verbose) print('  No compile sections configured');
      return ItemResult.success(
        path: projectPath,
        name: context.name,
        message: 'no compile sections',
      );
    }

    final currentPlatform = PlatformUtils.getCurrentPlatform();
    if (args.verbose) print('  Current platform: $currentPlatform');

    // Create placeholder context for general placeholder resolution
    // (folder, nature, path placeholders from ExecutePlaceholderResolver).
    final placeholderCtx = ExecutePlaceholderContext.fromCommandContext(
      context,
      findWorkspaceRoot(projectPath),
    );

    final savedDir = Directory.current.path;
    Directory.current = projectPath;

    try {
      var compilationCount = 0;

      // Precompile
      for (final section in config.precompileSections) {
        await _runCommandSection(
          section: section,
          currentPlatform: currentPlatform,
          projectPath: projectPath,
          sectionName: 'precompile',
          args: args,
          placeholderCtx: placeholderCtx,
        );
      }

      // Compile
      for (final section in config.compileSections) {
        if (section.platforms.isNotEmpty) {
          final matches = section.platforms.any(
            (pl) => PlatformUtils.matchesPlatform(pl, currentPlatform),
          );
          if (!matches) {
            if (args.verbose) {
              print(
                '  Skipping compile section (platform: '
                '${section.platforms.join(', ')})',
              );
            }
            continue;
          }
        }

        var targets = section.targets.isNotEmpty
            ? _expandTargets(section.targets)
            : [currentPlatform];

        if (config.targetFilter.isNotEmpty) {
          targets = targets.where((t) {
            return config.targetFilter.any(
              (f) => PlatformUtils.matchesPlatform(f, t),
            );
          }).toList();
          if (targets.isEmpty) {
            if (args.verbose) print('  No targets match filter');
            continue;
          }
        }

        // Get files to compile, applying executable filter
        var files = section.files.toList();
        if (config.executableFilter.isNotEmpty) {
          files = files.where((f) {
            final fileName = p.basename(f);
            return config.executableFilter.any(
              (filter) => fileName == filter || f.endsWith(filter),
            );
          }).toList();
          if (files.isEmpty) {
            if (args.verbose) print('  No files match executable filter');
            continue;
          }
        }

        for (final file in files) {
          for (final target in targets) {
            final success = section.isBuiltinCommand
                ? await _compileFileBuiltin(
                    file: file,
                    targetPlatform: target,
                    currentPlatform: currentPlatform,
                    commandTemplates: section.commands,
                    projectPath: projectPath,
                    args: args,
                    placeholderCtx: placeholderCtx,
                  )
                : await _compileFile(
                    file: file,
                    targetPlatform: target,
                    currentPlatform: currentPlatform,
                    commandTemplates: section.commandlines,
                    projectPath: projectPath,
                    args: args,
                    placeholderCtx: placeholderCtx,
                  );
            if (success) compilationCount++;
          }
        }
      }

      // Postcompile
      for (final section in config.postcompileSections) {
        await _runCommandSection(
          section: section,
          currentPlatform: currentPlatform,
          projectPath: projectPath,
          sectionName: 'postcompile',
          args: args,
          placeholderCtx: placeholderCtx,
        );
      }

      if (compilationCount > 0) {
        print('  Completed $compilationCount compilation(s)');
      }

      return ItemResult.success(
        path: projectPath,
        name: context.name,
        message: '$compilationCount compilations',
      );
    } catch (e) {
      return ItemResult.failure(
        path: projectPath,
        name: context.name,
        error: 'Compilation failed: $e',
      );
    } finally {
      Directory.current = savedDir;
    }
  }

  bool _hasCompilerConfig(String dir) {
    final file = File('$dir/buildkit.yaml');
    if (!file.existsSync()) return false;
    try {
      final yaml = loadYaml(file.readAsStringSync()) as YamlMap?;
      return yaml != null && yaml['compiler'] is YamlMap;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _getCmdOpts(CliArgs args) {
    for (final cmd in args.commands) {
      if (cmd == 'compiler' || cmd == 'c' || cmd == 'comp') {
        final cmdArgs = args.commandArgs[cmd];
        if (cmdArgs != null) return cmdArgs.options;
      }
    }
    return args.extraOptions;
  }

  Future<bool> _runCommandSection({
    required CommandSection section,
    required String currentPlatform,
    required String projectPath,
    required String sectionName,
    required CliArgs args,
    required ExecutePlaceholderContext placeholderCtx,
  }) async {
    if (section.platforms.isNotEmpty) {
      final matches = section.platforms.any(
        (pl) => PlatformUtils.matchesPlatform(pl, currentPlatform),
      );
      if (!matches) {
        if (args.verbose) {
          print(
            '  Skipping $sectionName (platform: '
            '${section.platforms.join(', ')})',
          );
        }
        return true;
      }
    }

    if (section.isBuiltinCommand) {
      for (final commandRef in section.commands) {
        if (args.dryRun) {
          print('  [DRY RUN] $sectionName (builtin): $commandRef');
          continue;
        }
        if (args.verbose) print('  $sectionName (builtin): $commandRef');

        final builtinCommands = BuiltinCommands(
          projectPath: projectPath,
          rootPath: findWorkspaceRoot(projectPath),
          verbose: args.verbose,
          dryRun: args.dryRun,
        );

        if (!builtinCommands.isBuiltin(commandRef)) {
          print('  Error: "$commandRef" is not a recognized built-in command.');
          return false;
        }

        final result = await builtinCommands.execute(commandRef);
        if (!result) {
          print('  Error: $sectionName built-in command failed: $commandRef');
        }
      }
      return true;
    }

    for (final commandTemplate in section.commandlines) {
      // Resolve general placeholders (folder, nature, path, etc.)
      // before compiler-specific platform replacements.
      var command = ExecutePlaceholderResolver.resolveCommand(
        commandTemplate,
        placeholderCtx,
        skipUnknown: true,
      );
      command = command
          .replaceAll(
            r'${current-os}',
            PlatformUtils.getTargetOS(currentPlatform),
          )
          .replaceAll(
            r'${current-arch}',
            PlatformUtils.getTargetArch(currentPlatform),
          )
          .replaceAll(
            r'${current-platform}',
            PlatformUtils.vsCodeToDartTarget(currentPlatform),
          )
          .replaceAll(r'${current-platform-vs}', currentPlatform);

      if (script_utils.isStdinCommand(command)) {
        final parsed = script_utils.parseStdinCommand(command);
        if (parsed != null) {
          final expandedCmd = _replaceEnvVars(parsed.command);
          final result = await script_utils.executeWithStdin(
            command: expandedCmd,
            stdinContent: parsed.stdinContent,
            environment: Platform.environment,
            dryRun: args.dryRun,
            verbose: args.verbose,
          );
          if (!result) {
            print('  Error: $sectionName stdin command failed');
          }
          continue;
        }
      }

      command = _replaceEnvVars(command);

      if (args.dryRun) {
        print('  [DRY RUN] $sectionName: $command');
        continue;
      }
      if (args.verbose) print('  $sectionName: $command');

      final result = await ProcessRunner.runShell(
        command,
        environment: Platform.environment,
      );
      if (result.stdout.isNotEmpty) stdout.write(result.stdout);
      if (result.stderr.isNotEmpty) stderr.write(result.stderr);
      if (result.exitCode != 0) {
        print('  Error: $sectionName command failed (exit ${result.exitCode})');
      }
    }
    return true;
  }

  Future<bool> _compileFile({
    required String file,
    required String targetPlatform,
    required String currentPlatform,
    required List<String> commandTemplates,
    required String projectPath,
    required CliArgs args,
    required ExecutePlaceholderContext placeholderCtx,
  }) async {
    final filePath = p.normalize(file);
    final fileName = p.basenameWithoutExtension(filePath);
    final fileBasename = p.basename(filePath);
    final fileExtension = p.extension(filePath);
    final fileDir = p.dirname(filePath);

    final targetOS = PlatformUtils.getTargetOS(targetPlatform);
    final targetArch = PlatformUtils.getTargetArch(targetPlatform);
    final targetDart = PlatformUtils.vsCodeToDartTarget(targetPlatform);
    final currentOS = PlatformUtils.getTargetOS(currentPlatform);
    final currentArch = PlatformUtils.getTargetArch(currentPlatform);

    if (!args.dryRun) {
      print('  Compiling $fileName for $targetPlatform');
    }

    for (final template in commandTemplates) {
      var command = _resolvePlaceholders(
        template,
        filePath: filePath,
        fileName: fileName,
        fileBasename: fileBasename,
        fileExtension: fileExtension,
        fileDir: fileDir,
        targetOS: targetOS,
        targetArch: targetArch,
        targetDart: targetDart,
        targetPlatform: targetPlatform,
        currentOS: currentOS,
        currentArch: currentArch,
        currentPlatform: currentPlatform,
      );

      if (script_utils.isStdinCommand(command)) {
        final parsed = script_utils.parseStdinCommand(command);
        if (parsed != null) {
          if (args.dryRun) {
            print(
              '  [DRY RUN] compile stdin ($targetPlatform): '
              '${parsed.command}',
            );
            continue;
          }
          if (args.verbose) {
            print('    Command (stdin): ${parsed.command}');
          }
          final result = await script_utils.executeWithStdin(
            command: _replaceEnvVars(parsed.command),
            stdinContent: parsed.stdinContent,
            workingDirectory: Directory.current.path,
            environment: Platform.environment,
            dryRun: args.dryRun,
            verbose: args.verbose,
          );
          if (!result) {
            print(
              '  Error: Compilation failed for $fileName ($targetPlatform)',
            );
            return false;
          }
          continue;
        }
      }

      command = _replaceEnvVars(command);

      if (args.dryRun) {
        print('  [DRY RUN] compile ($targetPlatform): $command');
        continue;
      }

      if (args.verbose) {
        print('    Command: $command');
      }

      final result = await ProcessRunner.runShell(
        command,
        workingDirectory: Directory.current.path,
        environment: Platform.environment,
      );
      if (result.stdout.isNotEmpty) stdout.write(result.stdout);
      if (result.stderr.isNotEmpty) stderr.write(result.stderr);
      if (result.exitCode != 0) {
        print('  Error: Compilation failed for $fileName ($targetPlatform)');
        return false;
      }
    }
    return true;
  }

  Future<bool> _compileFileBuiltin({
    required String file,
    required String targetPlatform,
    required String currentPlatform,
    required List<String> commandTemplates,
    required String projectPath,
    required CliArgs args,
    required ExecutePlaceholderContext placeholderCtx,
  }) async {
    final filePath = p.normalize(file);
    final fileName = p.basenameWithoutExtension(filePath);
    final fileBasename = p.basename(filePath);
    final fileExtension = p.extension(filePath);
    final fileDir = p.dirname(filePath);

    final targetOS = PlatformUtils.getTargetOS(targetPlatform);
    final targetArch = PlatformUtils.getTargetArch(targetPlatform);
    final targetDart = PlatformUtils.vsCodeToDartTarget(targetPlatform);
    final currentOS = PlatformUtils.getTargetOS(currentPlatform);
    final currentArch = PlatformUtils.getTargetArch(currentPlatform);

    if (!args.dryRun) {
      print('  Compiling $fileName for $targetPlatform (builtin)');
    }

    for (final template in commandTemplates) {
      // Resolve general placeholders (folder, nature, path, etc.)
      // before compiler-specific file/target placeholders.
      final preResolved = ExecutePlaceholderResolver.resolveCommand(
        template,
        placeholderCtx,
        skipUnknown: true,
      );
      var command = _resolvePlaceholders(
        preResolved,
        filePath: filePath,
        fileName: fileName,
        fileBasename: fileBasename,
        fileExtension: fileExtension,
        fileDir: fileDir,
        targetOS: targetOS,
        targetArch: targetArch,
        targetDart: targetDart,
        targetPlatform: targetPlatform,
        currentOS: currentOS,
        currentArch: currentArch,
        currentPlatform: currentPlatform,
      );

      if (args.dryRun) {
        print('  [DRY RUN] compile builtin ($targetPlatform): $command');
        continue;
      }

      final builtinCommands = BuiltinCommands(
        projectPath: projectPath,
        rootPath: findWorkspaceRoot(projectPath),
        verbose: args.verbose,
        dryRun: args.dryRun,
      );

      if (!builtinCommands.isBuiltin(command)) {
        print('  Error: "$command" is not a recognized built-in command.');
        return false;
      }
      if (!await builtinCommands.execute(command)) {
        print('  Error: Compilation failed for $fileName ($targetPlatform)');
        return false;
      }
    }
    return true;
  }

  String _resolvePlaceholders(
    String template, {
    required String filePath,
    required String fileName,
    required String fileBasename,
    required String fileExtension,
    required String fileDir,
    required String targetOS,
    required String targetArch,
    required String targetDart,
    required String targetPlatform,
    required String currentOS,
    required String currentArch,
    required String currentPlatform,
  }) {
    return template
        .replaceAll(r'${file}', filePath)
        .replaceAll(r'${file.path}', filePath)
        .replaceAll(r'${file.name}', fileName)
        .replaceAll(r'${file.basename}', fileBasename)
        .replaceAll(r'${file.extension}', fileExtension)
        .replaceAll(r'${file.dir}', fileDir)
        .replaceAll(r'${target-os}', targetOS)
        .replaceAll(r'${target-arch}', targetArch)
        .replaceAll(r'${target-platform}', targetDart)
        .replaceAll(r'${target-platform-vs}', targetPlatform)
        .replaceAll(r'${current-os}', currentOS)
        .replaceAll(r'${current-arch}', currentArch)
        .replaceAll(r'${current-platform}', currentPlatform)
        .replaceAll(r'${current-platform-vs}', currentPlatform)
        .replaceAll('[file]', filePath)
        .replaceAll('[file.name]', fileName)
        .replaceAll('[target-os]', targetOS)
        .replaceAll('[target-arch]', targetArch)
        .replaceAll('[target-platform]', targetDart)
        .replaceAll('[target-platform-vs]', targetPlatform);
  }

  List<String> _expandTargets(List<String> targets) {
    final expanded = <String>[];
    for (final target in targets) {
      expanded.addAll(PlatformUtils.normalizePlatform(target));
    }
    return expanded;
  }

  String _replaceEnvVars(String command) {
    var result = command;
    result = result.replaceAllMapped(RegExp(r'\$(\w+)'), (match) {
      final varName = match.group(1)!;
      if (varName.startsWith('{')) return match.group(0)!;
      return Platform.environment[varName] ?? '';
    });
    result = result.replaceAllMapped(RegExp(r'\[(\w+)\]'), (match) {
      final varName = match.group(1)!;
      return Platform.environment[varName] ?? '';
    });
    return result;
  }
}
