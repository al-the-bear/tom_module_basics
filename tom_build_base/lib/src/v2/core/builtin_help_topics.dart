/// Built-in help topics available to all Tom CLI tools.
///
/// These topics are automatically registered when tools opt in.
/// Use [defaultHelpTopics] to get all built-in topics.
library;

import 'help_topic.dart';

/// All built-in help topics.
///
/// Tools can include these in their [ToolDefinition.helpTopics].
const List<HelpTopic> defaultHelpTopics = [placeholdersHelpTopic];

/// Help topic documenting placeholder and environment variable usage.
const placeholdersHelpTopic = HelpTopic(
  name: 'placeholders',
  summary: 'Variable substitution in commands and config files',
  content: _placeholdersContent,
);

const _placeholdersContent = r'''
**Placeholders**

Placeholders are variables that get replaced with actual values when a
command runs. They are resolved per folder during workspace traversal.

<cyan>**Syntax**</cyan>

  ${name}                Simple placeholder
  ${cond?(yes):(no)}     Ternary (boolean placeholders only)

<cyan>**Path Placeholders**</cyan>

  ${root}                Workspace root (absolute path)
  ${folder}              Current folder (absolute path)
  ${folder.name}         Folder basename
  ${folder.relative}     Folder relative to workspace root

<cyan>**Platform Placeholders**</cyan>

  ${current-os}          Operating system (linux, macos, windows)
  ${current-arch}        Architecture (x64, arm64, armhf)
  ${current-platform}    Combined (darwin-arm64, linux-x64, etc.)

<cyan>**Compiler Placeholders** (buildkit :compiler only)</cyan>

  ${file}                Source file path
  ${file.path}           Source file path (alias)
  ${file.name}           Source file name without extension
  ${file.basename}       Source file basename with extension
  ${file.extension}      Source file extension
  ${file.dir}            Source file directory
  ${target-os}           Target OS (linux, macos, windows)
  ${target-arch}         Target arch (x64, arm64, armhf)
  ${target-platform}     Target for dart compile (linux, macos, windows)
  ${target-platform-vs}  Target slug (linux-x64, darwin-arm64, etc.)
  ${current-platform-vs} Current platform slug

<cyan>**Nature Detection (boolean)**</cyan>

  ${dart.exists}             true if Dart project (pubspec.yaml)
  ${flutter.exists}          true if Flutter project
  ${package.exists}          true if Dart package (has lib/src/)
  ${console.exists}          true if Dart console app (has bin/)
  ${git.exists}              true if git repository
  ${typescript.exists}       true if TypeScript project
  ${vscode-extension.exists} true if VS Code extension
  ${buildkit.exists}         true if has buildkit.yaml
  ${tom-project.exists}      true if has tom_project.yaml

<cyan>**Nature Attributes**</cyan>

  ${dart.name}           Project name from pubspec.yaml
  ${dart.version}        Version from pubspec.yaml
  ${dart.publishable}    true if publishable to pub.dev (boolean)
  ${flutter.platforms}   Comma-separated platform list
  ${flutter.isPlugin}    true if Flutter plugin (boolean)
  ${git.branch}          Current branch name
  ${git.isSubmodule}     true if git submodule (boolean)
  ${git.hasChanges}      true if uncommitted changes (boolean)
  ${git.remotes}         Comma-separated remote list
  ${vscode.name}         Extension name
  ${vscode.version}      Extension version

<cyan>**Ternary Expressions**</cyan>

  Boolean placeholders support conditional substitution:

    ${dart.exists?(dart project):(not dart)}
    ${git.hasChanges?(DIRTY):(clean)}

<yellow>**Environment Variables**</yellow>

  Environment variables are resolved in YAML config files and shell
  commands. Use standard shell syntax:

    $VAR_NAME             Resolved from process environment
    $TOM_BINARY_PATH      Example: binary output directory

  In buildkit.yaml compiler commands, env vars are resolved twice:
  1. Before execution by the compiler executor ($VAR regex)
  2. By the shell when running the command (sh -c)

  Environment variables do NOT use curly braces — ${...} is reserved
  for placeholders. Use $VAR_NAME (no braces) for env vars.

<green>**Examples**</green>

  Execute command with placeholders:
    buildkit :execute "echo ${folder.name} on ${current-platform}"

  Conditional execution:
    buildkit :execute --condition dart.exists "dart analyze"

  Ternary in commands:
    buildkit :execute "echo ${dart.exists?(Dart: ${dart.name}):(not Dart)}"

  Compiler YAML using env vars:
    binaryPath: $TOM_BINARY_PATH
    commands:
      - mkdir -p $TOM_BINARY_PATH/${target-platform-vs}
      - dart compile exe ${file} -o $TOM_BINARY_PATH/${target-platform-vs}/${file.name}
''';
