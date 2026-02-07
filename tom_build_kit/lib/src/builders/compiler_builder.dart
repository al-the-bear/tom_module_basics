import 'dart:async';
import 'dart:io';

import 'package:build/build.dart';

/// Configuration for a command section (precompile, postcompile).
class CommandSection {
  /// Command line templates with placeholders.
  final List<String> commandlines;

  /// Platforms where these commands RUN (current platform filter).
  final List<String> platforms;

  CommandSection({
    required this.commandlines,
    List<String>? platforms,
  }) : platforms = platforms ?? [];

  /// Parse from JSON/YAML structure.
  factory CommandSection.fromJson(dynamic json) {
    if (json is! Map) {
      throw ArgumentError('CommandSection must be a map');
    }

    final commandlineRaw = json['commandline'];
    List<String> commandlines;
    if (commandlineRaw is String) {
      commandlines = [commandlineRaw];
    } else if (commandlineRaw is List) {
      commandlines = commandlineRaw.map((e) => e.toString()).toList();
    } else {
      throw ArgumentError('commandline must be a string or list');
    }

    if (commandlines.isEmpty) {
      throw ArgumentError('commandline cannot be empty');
    }

    final platformsRaw = json['platforms'];
    List<String>? platforms;
    if (platformsRaw is String) {
      platforms = [platformsRaw];
    } else if (platformsRaw is List) {
      platforms = platformsRaw.map((e) => e.toString()).toList();
    }

    return CommandSection(
      commandlines: commandlines,
      platforms: platforms,
    );
  }
}

/// Configuration for a single compilation section.
class CompileSection {
  /// Command line templates with placeholders.
  final List<String> commandlines;

  /// List of source files to compile.
  final List<String> files;

  /// Target platforms to compile FOR (cross-compilation targets).
  final List<String> targets;

  /// Platforms where this compilation RUNS (current platform filter).
  final List<String> platforms;

  CompileSection({
    required this.commandlines,
    required this.files,
    List<String>? targets,
    List<String>? platforms,
  })  : targets = targets ?? [],
        platforms = platforms ?? [];

  /// Parse from JSON/YAML structure.
  factory CompileSection.fromJson(dynamic json) {
    if (json is! Map) {
      throw ArgumentError('CompileSection must be a map');
    }

    final commandlineRaw = json['commandline'];
    List<String> commandlines;
    if (commandlineRaw is String) {
      commandlines = [commandlineRaw];
    } else if (commandlineRaw is List) {
      commandlines = commandlineRaw.map((e) => e.toString()).toList();
    } else {
      throw ArgumentError('commandline must be a string or list');
    }

    if (commandlines.isEmpty) {
      throw ArgumentError('commandline cannot be empty');
    }

    final filesRaw = json['files'];
    List<String> files;
    if (filesRaw is String) {
      files = [filesRaw];
    } else if (filesRaw is List) {
      files = filesRaw.map((e) => e.toString()).toList();
    } else {
      throw ArgumentError('files must be a string or list');
    }

    if (files.isEmpty) {
      throw ArgumentError('files cannot be empty');
    }

    final targetsRaw = json['targets'];
    List<String>? targets;
    if (targetsRaw is String) {
      targets = [targetsRaw];
    } else if (targetsRaw is List) {
      targets = targetsRaw.map((e) => e.toString()).toList();
    }

    final platformsRaw = json['platforms'];
    List<String>? platforms;
    if (platformsRaw is String) {
      platforms = [platformsRaw];
    } else if (platformsRaw is List) {
      platforms = platformsRaw.map((e) => e.toString()).toList();
    }

    return CompileSection(
      commandlines: commandlines,
      files: files,
      targets: targets,
      platforms: platforms,
    );
  }
}

/// Configuration for the compiler builder.
class CompilerBuilderConfig {
  final List<CommandSection> precompile;
  final List<CompileSection> compiles;
  final List<CommandSection> postcompile;

  const CompilerBuilderConfig({
    this.precompile = const [],
    required this.compiles,
    this.postcompile = const [],
  });

  /// Load from build.yaml options.
  factory CompilerBuilderConfig.fromOptions(Map<String, dynamic> options) {
    final precompileSections = <CommandSection>[];
    final precompileRaw = options['precompile'];
    if (precompileRaw is List) {
      for (final item in precompileRaw) {
        precompileSections.add(CommandSection.fromJson(item));
      }
    }

    final compileSections = <CompileSection>[];
    final compilesRaw = options['compiles'];
    if (compilesRaw is List) {
      for (final item in compilesRaw) {
        compileSections.add(CompileSection.fromJson(item));
      }
    }

    final postcompileSections = <CommandSection>[];
    final postcompileRaw = options['postcompile'];
    if (postcompileRaw is List) {
      for (final item in postcompileRaw) {
        postcompileSections.add(CommandSection.fromJson(item));
      }
    }

    return CompilerBuilderConfig(
      precompile: precompileSections,
      compiles: compileSections,
      postcompile: postcompileSections,
    );
  }
}

/// Build_runner builder for compilation.
///
/// Note: This builder validates configuration during build_runner runs.
/// The actual compilation is done by the CLI tool (CompilerTool).
class CompilerBuilder implements Builder {
  final CompilerBuilderConfig config;

  CompilerBuilder(this.config);

  @override
  Map<String, List<String>> get buildExtensions => {
        r'$lib$': ['.compiler.done'],
      };

  @override
  Future<void> build(BuildStep buildStep) async {
    log.info('Compiler builder configured with '
        '${config.compiles.length} compile sections');

    for (final section in config.compiles) {
      _validateSection(section);
    }
  }

  void _validateSection(CompileSection section) {
    for (final commandline in section.commandlines) {
      if (!commandline.contains(r'${file}') &&
          !commandline.contains('[file]')) {
        log.warning(
            'Command line should contain \${file} or [file] placeholder');
      }
    }

    for (final file in section.files) {
      if (!file.contains('*') && !File(file).existsSync()) {
        log.warning('Source file not found: $file');
      }
    }
  }
}
