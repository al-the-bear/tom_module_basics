/// Configuration types for the compiler tool.
///
/// These are pure data classes used by both the CLI tool (CompilerTool)
/// and the build.yaml configuration parser. They have no dependency on
/// `package:build` or build_runner.
library;

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
