import 'dart:io';

import 'package:yaml/yaml.dart';

/// A single step within a pipeline phase (precore, core, or postcore).
class PipelineStep {
  /// Commands to execute in this step.
  final List<String> commands;

  /// Platforms this step applies to.
  /// Empty list means all platforms.
  final List<String> platforms;

  PipelineStep({
    required this.commands,
    this.platforms = const [],
  });

  /// Parse a step from YAML.
  factory PipelineStep.fromYaml(YamlMap yaml) {
    final commands = <String>[];
    final commandsYaml = yaml['commands'];
    if (commandsYaml is YamlList) {
      commands.addAll(commandsYaml.map((e) => e.toString()));
    } else if (commandsYaml is String) {
      commands.add(commandsYaml);
    }

    final platforms = <String>[];
    final platformsYaml = yaml['platforms'];
    if (platformsYaml is YamlList) {
      platforms.addAll(platformsYaml.map((e) => e.toString()));
    }

    return PipelineStep(
      commands: commands,
      platforms: platforms,
    );
  }

  /// Check if this step should run on the current platform.
  bool shouldRunOnCurrentPlatform() {
    if (platforms.isEmpty) return true;

    final current = _getCurrentPlatformId();
    
    for (final platform in platforms) {
      // Support glob-like patterns (e.g., "linux-*", "darwin-*")
      if (platform.contains('*')) {
        final pattern = RegExp('^${platform.replaceAll('*', '.*')}\$');
        if (pattern.hasMatch(current)) return true;
      } else if (platform == 'macos' || platform == 'darwin') {
        // Alias support
        if (current.startsWith('darwin')) return true;
      } else if (platform == 'linux') {
        if (current.startsWith('linux')) return true;
      } else if (platform == 'windows' || platform == 'win32') {
        if (current.startsWith('win32')) return true;
      } else if (platform == current) {
        return true;
      }
    }

    return false;
  }

  /// Get the current platform identifier (e.g., "darwin-arm64", "linux-x64").
  static String _getCurrentPlatformId() {
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

  static String _getCurrentArch() {
    // Dart doesn't expose architecture directly, but we can infer it
    // from the Dart executable path or use process info
    final dartExe = Platform.resolvedExecutable;
    if (dartExe.contains('arm64') || dartExe.contains('aarch64')) {
      return 'arm64';
    }
    if (dartExe.contains('arm')) {
      return 'armhf';
    }
    // Default to x64 for most desktop platforms
    return 'x64';
  }
}
