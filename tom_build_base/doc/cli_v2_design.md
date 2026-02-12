# Tom Build Base v2 — CLI Framework Design

## Overview

This document describes the v2 architecture for `tom_build_base`, which will provide a unified foundation for all Tom Framework CLI tools. The v2 implementation will coexist with v1 in a separate source tree (`lib/src_v2/`) with a separate barrel export (`tom_build_base_v2.dart`), allowing gradual migration tool by tool.

### Goals

1. **Unify CLI patterns** across all Tom tools (buildkit, testkit, issuekit, d4rtgen, astgen, etc.)
2. **Declarative tool/command definitions** with automatic help generation
3. **Flexible folder traversal** with configurable "natures" for different folder types
4. **Support multiple tool modes**: simple CLI, multi-command, REPL, TUI, stdin/pipe
5. **Per-command filtering** without requiring full navigation support
6. **Consistent version/help handling** across all tools

---

## Tool Types Supported

### 1. Simple CLI Tool
Single-purpose tool with options but no subcommands.
- Example: `versioner`, `compiler`, `cleanup`, `astgen`, `d4rtgen`

### 2. Multi-Command Tool
Tool with `:command` subcommands (pipeline on command line).
- Example: `buildkit`, `testkit`, `issuekit`

### 3. REPL Tool
Interactive interpreter with persistent state.
- Example: `dcli`, `d4rt`, `tom`
- Supports: sessions, replay files, custom commands

### 4. TUI Tool
Full-screen terminal UI with interactive menus.
- Example: `testkit --tui`
- TUI actively triggers traversal logic multiple times

### 5. Stdin/Pipe Mode
Accepts input from stdin for batch processing.
- Example: `d4rt --stdin`, `dcli --stdin`
- May auto-wrap code in `main()` or prefix imports

### 6. Guide Mode
Step-by-step interactive prompts for complex operations.
- Example: `gitstatus --guide`, `gitmerge --guide`

---

## Per-Command Project Filtering

### Problem Statement
Even if a tool doesn't support full navigation options (`--scan`, `--recursive`, etc.), commands should be able to filter which projects they run on during traversal using `--project`/`--include` and `--exclude`.

### Design

```dart
/// Indicates a command supports per-command project filtering.
abstract class SupportsProjectFilter {
  /// Projects to include (glob patterns or project IDs).
  /// When traversing globally specified projects, run only in these.
  List<String> get includeProjects;
  
  /// Projects to exclude (glob patterns or project IDs).
  /// Skip these projects during traversal.
  List<String> get excludeProjects;
}
```

**CLI syntax:**
```bash
# Global navigation, per-command filtering
buildkit -s . -r :versioner --project=tom_* :compiler --exclude=tom_test_*

# shorthand: -p for --project, -x for --exclude  
buildkit -s . :cleanup -p tom_build_* :runner -x "*_test"
```

**Validation:**
- Commands must declare if they support these flags via `CommandDefinition`
- If a command does NOT support filtering but user specifies `--project` or `--exclude`, emit error:
  ```
  Error: :mycommand does not support --project/--exclude filtering.
  ```

---

## Standard CLI Features

### Version Output
Supported variations (all tools):
```
version, -version, --version, -V, -v
```

**Implementation:**
- `isVersionCommand(args)` — detect version request (already in v1)
- `ToolDefinition.version` — version string from generated `version.g.dart`
- Automatic format: `<toolname> <version>` or `<toolname> <version-long>`

### Help Output
Supported variations (all tools):
```
help, -help, --help, -h
```

**Features:**
- Tool-level help: `mytool help`
- Command-level help: `mytool help :command` or `mytool :command --help`
- Auto-generated from `ToolDefinition` and `CommandDefinition`

### Test Project Support
```bash
--test        # Include zom_* projects in traversal
--test-only   # Only traverse zom_* projects
```

**Use case:** Run builds/tests only on test projects during development.

---

## Folder Scanning Architecture

### FsFolder (Filesystem Folder)
Represents a directory during the scan phase. Contains:
- `path` — absolute path
- `name` — directory name  
- `exists` — whether folder exists
- `children` — lazy list of child FsFolders

### RunFolder (Processing Folder)
Represents a folder during the execution phase with detected "natures".

### Folder Natures

A single FsFolder can have multiple natures (e.g., a folder can be BOTH a GitFolder AND a DartProjectFolder). Commands specify which natures they require.

| Nature | Detection | Key Files |
|--------|-----------|-----------|
| `RootFolder` | Workspace or sub-workspace root | `tom_workspace.yaml`, `tom.code-workspace`, `buildkit_master.yaml` |
| `GitFolder` | Git repository | `.git/` directory or file |
| `VsCodeExtensionFolder` | VS Code extension project | `package.json` with `engines.vscode` |
| `DartProjectFolder` | Any Dart project | `pubspec.yaml` |
| `FlutterProjectFolder` | Flutter app/package | `pubspec.yaml` with `sdk: flutter` |
| `DartPackageFolder` | Dart package (lib only) | `pubspec.yaml`, `lib/src/`, no `bin/` |
| `DartConsoleFolder` | Dart CLI application | `pubspec.yaml`, `bin/` |
| `TypeScriptFolder` | TypeScript project | `tsconfig.json` |
| `JavaScriptFolder` | JavaScript project | `package.json` (no tsconfig) |
| `PythonFolder` | Python project | `pyproject.toml`, `setup.py`, or `setup.cfg` |
| `JavaFolder` | Java project (Maven/Gradle) | `pom.xml` or `build.gradle` |

### CommandContext

```dart
class CommandContext {
  final FsFolder fsFolder;
  final List<RunFolder> natures;
  
  /// Get a specific folder nature, throws if not present.
  T getFolderNature<T extends RunFolder>() {
    return natures.whereType<T>().first;
  }
  
  /// Check if folder has a specific nature.
  bool hasNature<T extends RunFolder>() {
    return natures.whereType<T>().isNotEmpty;
  }
  
  /// Get nature or null if not present.
  T? tryGetNature<T extends RunFolder>() {
    final matches = natures.whereType<T>();
    return matches.isNotEmpty ? matches.first : null;
  }
}
```

### Example Usage

```dart
class GitStatusCommand extends CommandBase {
  @override
  Set<Type> get requiredNatures => {GitFolder};
  
  @override
  Future<bool> execute(CommandContext ctx) async {
    final git = ctx.getFolderNature<GitFolder>();
    // Use git.currentBranch, git.hasUncommittedChanges, etc.
  }
}

class CompilerCommand extends CommandBase {
  @override
  Set<Type> get requiredNatures => {DartConsoleFolder};
  
  @override
  Future<bool> execute(CommandContext ctx) async {
    final dart = ctx.getFolderNature<DartConsoleFolder>();
    // Access dart.binaries, dart.mainFile, etc.
  }
}
```

---

## Project IDs

Short mnemonics for projects, defined in `buildkit.yaml`:

```yaml
# In project's buildkit.yaml
project-id: BB    # tom_build_base
project-id: D4    # tom_d4rt  
project-id: D4G   # tom_d4rt_generator
project-id: TK    # tom_test_kit
```

**Usage:**
- Anywhere project names are accepted: `--project=BB,D4G`
- Can be mixed: `--project=tom_core_*,BB,D4`
- Extracted during workspace scan and stored in project metadata

**Resolution:**
```dart
class ProjectIdResolver {
  final Map<String, String> _idToPath;  // BB -> /path/to/tom_build_base
  
  /// Resolve a pattern that may contain project IDs.
  List<String> resolve(String pattern, List<String> availableProjects) {
    if (_idToPath.containsKey(pattern)) {
      return [_idToPath[pattern]!];
    }
    // Fall through to glob matching
    return _globMatch(pattern, availableProjects);
  }
}
```

---

## ToolDefinition and CommandDefinition

### ToolDefinition

```dart
class ToolDefinition {
  /// Tool name (e.g., 'buildkit', 'testkit')
  final String name;
  
  /// Short description for help
  final String description;
  
  /// Version string (from version.g.dart)
  final String version;
  
  /// Tool mode (simple, multiCommand, repl, tui)
  final ToolMode mode;
  
  /// Whether tool supports stdin mode
  final bool supportsStdin;
  
  /// Stdin mode help text (shown in --help)
  final String? stdinHelp;
  
  /// Global options (for simple tool or global context)
  final List<OptionDefinition> globalOptions;
  
  /// Commands (for multi-command tools)
  final List<CommandDefinition> commands;
  
  /// Navigation options this tool supports
  final NavigationConfig navigationConfig;
  
  /// Whether to include zom_* test projects by default
  final bool includeTestProjects;
}

enum ToolMode {
  simple,       // Single-purpose tool
  multiCommand, // :command subcommands
  repl,         // Interactive REPL
  tui,          // Terminal UI
}
```

### CommandDefinition

```dart
class CommandDefinition {
  /// Command name (without : prefix)
  final String name;
  
  /// Short description
  final String description;
  
  /// Aliases (e.g., 'ls' for 'list')
  final List<String> aliases;
  
  /// Command-specific options
  final List<OptionDefinition> options;
  
  /// Folder natures this command requires
  final Set<Type> requiredNatures;
  
  /// Whether command supports per-command --project/--exclude
  final bool supportsProjectFilter;
  
  /// Whether command needs workspace traversal at all
  final bool requiresTraversal;
  
  /// Allowed navigation options when run standalone
  /// (null = same as tool default)
  final NavigationConfig? standaloneNavigationConfig;
  
  /// Examples for help text
  final List<String> examples;
}
```

### OptionDefinition

```dart
class OptionDefinition {
  final String name;
  final String? abbr;
  final String description;
  final bool isFlag;
  final String? defaultValue;
  final List<String>? allowed;
  final bool negatable;
  final bool mandatory;
}
```

---

## Standalone Command Mode

Commands can run as standalone executables (separate binary):

```dart
// bin/cleanup.dart
final tool = CleanupTool()
  ..standaloneMode = true;
await tool.run(args);
```

**Standalone differences:**
- All options specified directly (no `:command` prefix needed)
- May have different default navigation options
- Auto-inject flags (e.g., `gitstatus` auto-adds `--inner-first-git`)

```dart
class CommandDefinition {
  /// When true, command accepts all options directly in standalone mode
  final bool canRunStandalone;
  
  /// Different navigation defaults for standalone mode
  final NavigationConfig? standaloneNavigationConfig;
}
```

---

## REPL, TUI, and Stdin Integration

### REPL Tools

```dart
abstract class ReplToolBase {
  String get toolName;
  String get toolVersion;
  
  /// Register bridges with interpreter
  void registerBridges(D4rt d4rt);
  
  /// Create REPL state
  ReplState createReplState();
  
  /// Handle custom commands
  Future<bool> handleCommand(String line);
  
  /// Get help sections
  List<String> getHelpSections();
}
```

REPL tools use tom_build_base for:
- Initial argument parsing (`--help`, `--version`, `-session`, etc.)
- Session/history management infrastructure
- Help text generation

### TUI Tools

```dart
abstract class TuiToolBase {
  /// Initial setup (parse args, show main menu)
  Future<void> initialize(List<String> args);
  
  /// TUI can trigger traversal multiple times with different settings
  Future<List<String>> runTraversal(NavigationConfig config);
  
  /// Access project metadata
  ProjectMetadata getProjectInfo(String path);
}
```

TUI tools use tom_build_base in two phases:
1. **Startup**: Parse initial args, determine workspace root
2. **Interactive**: Trigger traversal logic on demand with user-selected settings

### Stdin Mode

```dart
class ToolDefinition {
  /// Whether tool supports stdin mode
  final bool supportsStdin;
  
  /// Help text for stdin mode (included in --help output)
  final String? stdinHelp;
}
```

Stdin mode integration in help:
```
Options:
  --stdin    Read and execute source code from stdin
             (auto-prefixes imports, wraps in main if needed)
```

---

## Common Patterns from Existing Tools

### Patterns from buildkit/testkit/d4rtgen/astgen

| Pattern | Usage | v2 Support |
|---------|-------|------------|
| `isHelpCommand(args)` | Detect help before parsing | ✅ Keep |
| `isVersionCommand(args)` | Detect version before parsing | ✅ Keep |
| `preprocessRootFlag(args)` | Handle bare `-R` | ✅ Keep |
| `addNavigationOptions(parser)` | Standard nav options | ✅ Keep |
| `parseNavigationArgs(results)` | Parse nav from ArgResults | ✅ Keep |
| `resolveExecutionRoot(navArgs)` | Find workspace root | ✅ Keep |
| `navArgs.withDefaults()` | Apply default scan/recursive | ✅ Keep |
| `ProcessingResult` | Track success/failure/files | ✅ Keep |
| `ProjectNavigator` | Unified traversal | ✅ Keep |
| `_commandHelp` map | Per-command help | ⬆️ CommandDefinition |
| `_commandAliases` map | Command aliases | ⬆️ CommandDefinition |
| `_extractSubcommandAndSplit()` | Parse :command | ⬆️ Framework |
| `switch (subcommand)` dispatch | Command routing | ⬆️ Framework |
| `ToolBase` class | Common tool infrastructure | ⬆️ Framework |
| `--list` flag | List-only mode | ✅ Keep |
| `--show` flag | Show config | ✅ Keep |
| `--dry-run` flag | Preview mode | ✅ Keep |
| `--verbose` flag | Verbose output | ✅ Keep |

### Tool-Specific Options to Generalize

| Option | Tools | Generalization |
|--------|-------|----------------|
| `--config <path>` | d4rtgen, astgen | Standard config option |
| `--dump-config` | d4rtgen, astgen | Debug option |
| `--force` | cleanup, testkit | Confirmation bypass |
| `--guide` | git* tools | Interactive mode flag |
| `--details` | gitstatus | Verbosity level |
| `--output <format>` | testkit | Output format |
| `--comment` | testkit | Annotation option |
| `--no-fetch` | gitstatus | Skip network ops |

---

## Analysis: Common CLI Packages

### Dart CLI Packages on pub.dev

| Package | Weekly Downloads | Purpose | Consideration |
|---------|------------------|---------|---------------|
| `args` | ~4.8M | Argument parsing | ✅ Already using, keep |
| `cli_util` | ~2.1M | CLI utilities | Consider for process utils |
| `io` | ~1.8M | I/O utilities | Already using via Dart SDK |
| `completion` | ~78K | Shell completions | ❌ Low priority |
| `interact` | ~45K | Interactive prompts | Consider for guide mode |
| `dcli` (external) | ~35K | Shell scripting | ❌ Name conflict with our tool |
| `commander` | ~12K | CLI framework | ❌ Too opinionated |
| `boss` | ~8K | CLI framework | ❌ Low adoption |
| `console` | ~6K | Console utilities | Consider for TUI |
| `prompts` | ~4K | User prompts | Consider for guide mode |

### Recommendation

**Keep:**
- `args` — mature, well-maintained, sufficient for our needs

**Consider:**
- `interact` or `prompts` — for guide mode interactive prompts
- `console` — for TUI mode terminal control

**Avoid:**
- Heavy frameworks that impose structure — we want flexibility
- Low-download packages — maintenance risk

**Custom:**
- Build our own framework on top of `args`
- More control, better integration with our patterns

---

## Migration Strategy

### Phase 1: v2 Infrastructure
1. Create `lib/src_v2/` directory
2. Create `lib/tom_build_base_v2.dart` barrel export
3. Implement core classes:
   - `ToolDefinition`, `CommandDefinition`, `OptionDefinition`
   - `FsFolder`, `RunFolder`, folder natures
   - `CommandContext`
   - Enhanced `NavigationConfig` with per-command filtering

### Phase 2: Framework Scaffolding
1. Implement `ToolRunner` — handles version/help, command routing
2. Implement `CommandRunner` — handles per-command options
3. Implement help generation from definitions
4. Implement folder nature detection

### Phase 3: Migration (Tool by Tool)
1. Start with simple tool: `cleanup` or `versioner`
2. Migrate multi-command tool: `testkit`
3. Migrate complex tool: `buildkit`
4. Migrate REPL tools: document integration points

---

## File Structure

```
tom_build_base/
├── lib/
│   ├── tom_build_base.dart           # v1 barrel (unchanged)
│   ├── tom_build_base_v2.dart        # v2 barrel (new)
│   └── src/
│       ├── (existing v1 code)
│       └── v2/
│           ├── core/
│           │   ├── tool_definition.dart
│           │   ├── command_definition.dart
│           │   ├── option_definition.dart
│           │   └── tool_mode.dart
│           ├── folder/
│           │   ├── fs_folder.dart
│           │   ├── run_folder.dart
│           │   ├── command_context.dart
│           │   └── natures/
│           │       ├── git_folder.dart
│           │       ├── dart_project_folder.dart
│           │       ├── flutter_folder.dart
│           │       ├── vscode_extension_folder.dart
│           │       └── ...
│           ├── runner/
│           │   ├── tool_runner.dart
│           │   ├── command_runner.dart
│           │   └── help_generator.dart
│           ├── filter/
│           │   ├── project_filter.dart
│           │   └── project_id_resolver.dart
│           └── navigation/
│               └── navigation_config_v2.dart
└── doc/
    ├── build_base_user_guide.md      # v1 docs
    ├── cli_tools_navigation.md       # v1 docs
    └── cli_v2_design.md              # This document
```

---

## Open Questions

1. **Backward compatibility**: Should v2 tools fall back to v1 APIs for certain features?
2. **Configuration format**: Should we introduce a declarative YAML format for tool definitions?
3. **Plugin system**: Should commands be pluggable at runtime?
4. **Shell completion**: Worth adding `--completion` to generate shell completions?
5. **Parallel execution**: Should traversal support parallel command execution?

---

## Next Steps

1. Review this design with stakeholders
2. Prototype `FsFolder`/`RunFolder` and folder natures
3. Implement `ToolDefinition`/`CommandDefinition` classes
4. Migrate one simple tool as proof of concept
5. Iterate based on learnings
