import 'dart:async';
import 'dart:io';

import 'package:build/build.dart';

/// Configuration for a single compilation section.
class CompileSection {
  /// Command line templates with placeholders (single string or list)
  final List<String> commandlines;

  /// List of source files to compile
  final List<String> files;

  /// Target platforms to compile FOR (cross-compilation targets)
  final List<String> targets;

  /// Platforms where this compilation RUNS (current platform filter)
  final List<String> platforms;

  CompileSection({
    required this.commandlines,
    required this.files,
    List<String>? targets,
    List<String>? platforms,
  })  : targets = targets ?? [],
        platforms = platforms ?? [];

  /// Parse from JSON/YAML structure
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
  final List<CompileSection> compiles;

  const CompilerBuilderConfig({
    required this.compiles,
  });

  /// Load from build.yaml options
  factory CompilerBuilderConfig.fromOptions(Map<String, dynamic> options) {
    final compilesRaw = options['compiles'];
    if (compilesRaw == null) {
      return const CompilerBuilderConfig(compiles: []);
    }

    if (compilesRaw is! List) {
      throw ArgumentError('compiles must be a list');
    }

    final sections = <CompileSection>[];
    for (final item in compilesRaw) {
      sections.add(CompileSection.fromJson(item));
    }

    return CompilerBuilderConfig(compiles: sections);
  }
}

/// Build_runner builder for compilation.
/// Note: This builder doesn't actually run during build_runner - it just
/// validates the configuration. The actual compilation is done by the CLI tool.
class CompilerBuilder implements Builder {
  final CompilerBuilderConfig config;

  CompilerBuilder(this.config);

  @override
  Map<String, List<String>> get buildExtensions => {
        r'$lib$': ['.compiler.done'],
      };

  @override
  Future<void> build(BuildStep buildStep) async {
    // This builder is primarily for configuration validation
    // The actual compilation happens via the CLI tool
    log.info('Compiler builder configured with ${config.compiles.length} compile sections');
    
    // Validate configuration
    for (final section in config.compiles) {
      _validateSection(section);
    }
  }

  void _validateSection(CompileSection section) {
    // Validate command lines have required placeholders
    for (final commandline in section.commandlines) {
      if (!commandline.contains('\${file}') &&
          !commandline.contains('[file]')) {
        log.warning('Command line should contain \${file} or [file] placeholder');
      }
    }

    // Validate files exist (if we can check)
    for (final file in section.files) {
      if (!file.contains('*') && !File(file).existsSync()) {
        log.warning('Source file not found: $file');
      }
    }
  }
}
