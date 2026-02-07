/// Configuration types for the compiler tool.
///
/// These are pure data classes used by both the CLI tool (CompilerTool)
/// and the build.yaml configuration parser. They have no dependency on
/// `package:build` or build_runner.
library;

/// Configuration for a command section (precompile, postcompile).
class CommandSection {
  /// Command line templates with placeholders.
  /// Used when `commandline:` is specified — runs as shell commands.
  final List<String> commandlines;

  /// Built-in command references.
  /// Used when `command:` is specified — dispatches to built-in tools.
  final List<String> commands;

  /// Whether this section uses built-in commands (true) or shell (false).
  final bool isBuiltinCommand;

  /// Platforms where these commands RUN (current platform filter).
  final List<String> platforms;

  CommandSection({
    required this.commandlines,
    this.commands = const [],
    this.isBuiltinCommand = false,
    List<String>? platforms,
  }) : platforms = platforms ?? [];

  /// Parse from JSON/YAML structure.
  ///
  /// Supports two mutually exclusive keys:
  /// - `commandline:` — shell command templates (existing behavior)
  /// - `command:` — built-in tool references (e.g., "versioner --output ...")
  factory CommandSection.fromJson(dynamic json) {
    if (json is! Map) {
      throw ArgumentError('CommandSection must be a map');
    }

    final commandlineRaw = json['commandline'];
    final commandRaw = json['command'];

    if (commandlineRaw != null && commandRaw != null) {
      throw ArgumentError(
          'CommandSection cannot have both "commandline" and "command"');
    }

    if (commandRaw != null) {
      // Built-in command mode
      List<String> commands;
      if (commandRaw is String) {
        commands = [commandRaw];
      } else if (commandRaw is List) {
        commands = commandRaw.map((e) => e.toString()).toList();
      } else {
        throw ArgumentError('command must be a string or list');
      }
      if (commands.isEmpty) {
        throw ArgumentError('command cannot be empty');
      }

      final platformsRaw = json['platforms'];
      List<String>? platforms;
      if (platformsRaw is String) {
        platforms = [platformsRaw];
      } else if (platformsRaw is List) {
        platforms = platformsRaw.map((e) => e.toString()).toList();
      }

      return CommandSection(
        commandlines: [],
        commands: commands,
        isBuiltinCommand: true,
        platforms: platforms,
      );
    }

    // Shell commandline mode (original behavior)
    List<String> commandlines;
    if (commandlineRaw is String) {
      commandlines = [commandlineRaw];
    } else if (commandlineRaw is List) {
      commandlines = commandlineRaw.map((e) => e.toString()).toList();
    } else {
      throw ArgumentError('commandline or command must be specified');
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
  /// Used when `commandline:` is specified — runs as shell commands.
  final List<String> commandlines;

  /// Built-in command references.
  /// Used when `command:` is specified — dispatches to built-in tools.
  final List<String> commands;

  /// Whether this section uses built-in commands (true) or shell (false).
  final bool isBuiltinCommand;

  /// List of source files to compile.
  final List<String> files;

  /// Target platforms to compile FOR (cross-compilation targets).
  final List<String> targets;

  /// Platforms where this compilation RUNS (current platform filter).
  final List<String> platforms;

  CompileSection({
    required this.commandlines,
    this.commands = const [],
    this.isBuiltinCommand = false,
    required this.files,
    List<String>? targets,
    List<String>? platforms,
  })  : targets = targets ?? [],
        platforms = platforms ?? [];

  /// Parse from JSON/YAML structure.
  ///
  /// Supports two mutually exclusive keys:
  /// - `commandline:` — shell command templates (existing behavior)
  /// - `command:` — built-in tool references (e.g., "compiler --targets ...")
  factory CompileSection.fromJson(dynamic json) {
    if (json is! Map) {
      throw ArgumentError('CompileSection must be a map');
    }

    final commandlineRaw = json['commandline'];
    final commandRaw = json['command'];

    if (commandlineRaw != null && commandRaw != null) {
      throw ArgumentError(
          'CompileSection cannot have both "commandline" and "command"');
    }

    // Parse files (required for both modes)
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

    if (commandRaw != null) {
      // Built-in command mode
      List<String> commands;
      if (commandRaw is String) {
        commands = [commandRaw];
      } else if (commandRaw is List) {
        commands = commandRaw.map((e) => e.toString()).toList();
      } else {
        throw ArgumentError('command must be a string or list');
      }
      if (commands.isEmpty) {
        throw ArgumentError('command cannot be empty');
      }

      return CompileSection(
        commandlines: [],
        commands: commands,
        isBuiltinCommand: true,
        files: files,
        targets: targets,
        platforms: platforms,
      );
    }

    // Shell commandline mode (original behavior)
    List<String> commandlines;
    if (commandlineRaw is String) {
      commandlines = [commandlineRaw];
    } else if (commandlineRaw is List) {
      commandlines = commandlineRaw.map((e) => e.toString()).toList();
    } else {
      throw ArgumentError('commandline or command must be specified');
    }

    if (commandlines.isEmpty) {
      throw ArgumentError('commandline cannot be empty');
    }

    return CompileSection(
      commandlines: commandlines,
      files: files,
      targets: targets,
      platforms: platforms,
    );
  }
}
