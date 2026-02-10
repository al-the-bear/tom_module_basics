# Tom Test Kit — TUI Concept

## Overview

Tom Test Kit provides a Terminal User Interface (TUI) mode built on the `utopia_tui` package. The TUI presents a full-screen interactive dashboard for running tests, creating baselines, and watching progress in real time. It is designed to be **extensible**: new commands can be registered, external CLI tools can be wrapped, and additional modules within the Tom Tool Kit project can take direct control of TUI regions.

---

## Architecture

```
┌────────────────────────────────────────────────────────┐
│                    TestKitTuiApp                        │
│  extends TuiApp — owns state, event loop, rendering    │
├──────────────┬─────────────────────────────────────────┤
│  Menu Panel  │  Output Panel                           │
│  (commands)  │  (progress / results / log)             │
│              │                                         │
│  > Baseline  │  ┌──────────────────────────────────┐   │
│    Test      │  │ Running dart test …               │   │
│    --------  │  │ [██████████░░░░░░░░] 45/78        │   │
│    (custom)  │  │                                    │   │
│              │  │ ✓ TK-FMT-1 padTwo single digit     │   │
│              │  │ ✓ TK-FMT-2 padTwo double digit     │   │
│              │  │ ✗ TK-FMT-3 escapeMarkdownCell …    │   │
│              │  └──────────────────────────────────┘   │
├──────────────┴─────────────────────────────────────────┤
│  Status Bar — command state · elapsed · key hints      │
└────────────────────────────────────────────────────────┘
```

### Key Components

| Component | Responsibility |
|-----------|---------------|
| `TestKitTuiApp` | Top-level `TuiApp` subclass; holds command registry, active command state, renders layout |
| `TuiCommandRegistry` | Registers `TuiCommand` instances; provides ordered list displayed in menu |
| `TuiCommand` | Abstract interface every command must implement |
| `TuiCommandRunner` | Executes a `TuiCommand`, streams `TuiCommandEvent`s, manages lifecycle |
| `TuiOutputPanel` | Renders progress bar, scrollable log lines, and summary |
| `TuiMenuPanel` | Selectable command list (left sidebar) |
| `TuiStatusBar` | Bottom status bar: state label, elapsed time, key hints |

---

## TuiCommand Interface

Every TUI command implements the `TuiCommand` abstract class:

```dart
/// A command that can be executed inside the TUI.
abstract class TuiCommand {
  /// Display name shown in the menu and header.
  String get label;

  /// Short description shown in the status bar when selected.
  String get description;

  /// Unique identifier for registry lookup.
  String get id;

  /// Execute the command.
  ///
  /// The command communicates progress and results by adding events
  /// to the provided [TuiCommandSink]. The TUI renders these events
  /// in real time.
  ///
  /// [projectPath] is the resolved project root.
  /// [sink] receives structured events (see TuiCommandEvent).
  /// [args] are additional command-specific arguments.
  Future<TuiCommandResult> execute({
    required String projectPath,
    required TuiCommandSink sink,
    Map<String, String> args = const {},
  });
}
```

### TuiCommandSink & TuiCommandEvent

Commands communicate with the TUI through a structured event sink:

```dart
/// Receives events from a running command.
abstract class TuiCommandSink {
  /// Report that a phase has started (e.g. "Compiling", "Running tests").
  void phaseStarted(String phaseName, {int? totalSteps});

  /// Report progress within the current phase.
  void progress(int current, int total, {String? detail});

  /// Report a single line of output.
  void log(String message, {TuiLogLevel level = TuiLogLevel.info});

  /// Report a test result (for test-oriented commands).
  void testResult(String testName, TuiTestOutcome outcome, {String? detail});

  /// Report that the command is complete.
  void done({String? summary});
}

enum TuiLogLevel { debug, info, warning, error }

enum TuiTestOutcome { passed, failed, skipped, error }
```

### TuiCommandResult

```dart
/// Result returned when a command finishes.
class TuiCommandResult {
  final bool success;
  final String summary;
  final int passedCount;
  final int failedCount;
  final int skippedCount;
  final Duration elapsed;

  const TuiCommandResult({
    required this.success,
    required this.summary,
    this.passedCount = 0,
    this.failedCount = 0,
    this.skippedCount = 0,
    this.elapsed = Duration.zero,
  });
}
```

---

## Output Format Protocol

To enable nice progress display for any command (including external CLI tools), the TUI uses a structured **output format protocol**. Commands that run natively (in-process) use the `TuiCommandSink` API directly. External tools that can be adapted emit lines matching this protocol on stdout:

### Line-Based Protocol

Each protocol line is prefixed with a tag:

```
##TUI:PHASE <phase_name> [<total_steps>]
##TUI:PROGRESS <current> <total> [<detail>]
##TUI:LOG <level> <message>
##TUI:TEST <outcome> <test_name> [<detail>]
##TUI:DONE [<summary>]
```

| Tag | Description | Example |
|-----|-------------|---------|
| `##TUI:PHASE` | Start a named phase with optional step count | `##TUI:PHASE Running tests 78` |
| `##TUI:PROGRESS` | Update progress counter | `##TUI:PROGRESS 45 78 TK-FMT-3: escapeMarkdownCell` |
| `##TUI:LOG` | Emit a log line | `##TUI:LOG INFO Compiling...` |
| `##TUI:TEST` | Report a single test outcome | `##TUI:TEST PASSED TK-FMT-1: padTwo single digit` |
| `##TUI:DONE` | Signal completion | `##TUI:DONE 78 passed, 0 failed` |

Lines that do not match any tag are treated as plain log output at INFO level.

### Adapting test_kit.dart for TUI Output

When test_kit.dart is invoked with `--tui`, the `:baseline` and `:test` subcommands emit the line-based protocol above instead of their normal human-readable output. This allows the TUI to parse and display progress interactively.

```
test_kit :baseline --tui
test_kit :test --tui
```

The `--tui` flag:
1. Suppresses normal stdout formatting
2. Emits `##TUI:PHASE`, `##TUI:PROGRESS`, `##TUI:TEST`, and `##TUI:DONE` lines
3. Continues to send non-protocol lines to stderr (for debugging)

---

## External Tool Adapter

Not every command-line tool can be modified to emit the TUI protocol. For these cases, the TUI provides an **adapter** mechanism:

### ExternalToolAdapter

```dart
/// Wraps an external CLI tool as a TuiCommand.
///
/// The adapter runs the tool as a subprocess and applies a
/// [TuiOutputParser] to convert stdout/stderr into TuiCommandEvents.
class ExternalToolAdapter extends TuiCommand {
  @override
  final String label;
  
  @override
  final String description;
  
  @override
  final String id;

  /// The command to execute (e.g. 'dart', 'flutter').
  final String executable;

  /// Arguments passed to the executable.
  final List<String> Function(String projectPath, Map<String, String> args) argsBuilder;

  /// Parser that converts raw output lines to structured events.
  final TuiOutputParser parser;

  ExternalToolAdapter({
    required this.id,
    required this.label,
    required this.description,
    required this.executable,
    required this.argsBuilder,
    required this.parser,
  });

  @override
  Future<TuiCommandResult> execute({
    required String projectPath,
    required TuiCommandSink sink,
    Map<String, String> args = const {},
  }) async {
    // 1. Start the process
    // 2. Pipe stdout/stderr through parser
    // 3. Forward parsed events to sink
    // 4. Return result on process exit
  }
}
```

### TuiOutputParser

```dart
/// Converts raw output lines from an external tool into TUI events.
///
/// Implementations are tool-specific. The TUI ships with parsers for
/// common tools (dart test, dart analyze, flutter test).
abstract class TuiOutputParser {
  /// Parse a single output line.
  ///
  /// Returns a list of events (may be empty if the line is not relevant).
  List<TuiCommandEvent> parseLine(String line, {bool isStderr = false});

  /// Called when the process exits. Returns a final result.
  TuiCommandResult finalize(int exitCode);
}
```

### Integration Levels

External tools fall into three integration categories:

| Level | Description | Example |
|-------|-------------|---------|
| **Full** | Tool supports `--tui` flag, emits protocol lines | `test_kit :baseline --tui` |
| **Parsed** | Tool has known output format; a `TuiOutputParser` extracts progress | `dart test --reporter json` (parsed via `DartTestOutputParser`) |
| **Basic** | Unknown output format; lines are displayed as-is in a scrollable log | Any CLI tool via `PassthroughParser` |

The `PassthroughParser` provides "basic" integration for any tool:
- All stdout lines appear in the output panel as INFO log lines
- All stderr lines appear as WARNING/ERROR log lines  
- A spinner indicates the tool is running
- Exit code determines success/failure

For "parsed" integration, implement a `TuiOutputParser` for the specific tool. For example, `DartTestJsonParser` understands `dart test --reporter json` output and extracts test names, pass/fail status, and progress counts.

---

## Module/Command Extension System

The TUI is designed to be extended with additional modules and commands from within the Tom Tool Kit project ecosystem. There are two extension patterns:

### Pattern 1: Simple Command Registration

Commands that follow the standard flow (run → stream events → return result) simply implement `TuiCommand` and register with the command registry:

```dart
// In an extension module:
class AnalyzeCommand extends TuiCommand {
  @override
  String get id => 'analyze';
  @override
  String get label => 'Analyze';
  @override
  String get description => 'Run dart analyze on the project';

  @override
  Future<TuiCommandResult> execute({
    required String projectPath,
    required TuiCommandSink sink,
    Map<String, String> args = const {},
  }) async {
    sink.phaseStarted('Analyzing');
    // ... run dart analyze, parse output, send events ...
    sink.done(summary: '0 issues found');
    return TuiCommandResult(success: true, summary: '0 issues found');
  }
}

// Registration:
registry.register(AnalyzeCommand());
```

### Pattern 2: TUI-Aware Modules (Direct TUI Control)

Some commands need more control over the TUI display — for example, a code coverage viewer that shows a file tree with coverage percentages, or an interactive test selector that lets the user pick which tests to run.

These modules implement `TuiModule`:

```dart
/// A module that takes direct control of a TUI region.
///
/// Unlike simple commands that stream events through TuiCommandSink,
/// TUI modules build their own components and handle their own events.
abstract class TuiModule {
  /// Unique module identifier.
  String get id;

  /// Display name shown in the menu.
  String get label;

  /// Short description.
  String get description;

  /// Called when the module is activated (user selects it from menu).
  ///
  /// The module receives the full content area to render into.
  void activate(TuiModuleContext context);

  /// Called on each build cycle while the module is active.
  ///
  /// [surface] and [rect] define the available rendering area.
  void build(TuiSurface surface, TuiRect rect);

  /// Handle events while the module is active.
  ///
  /// Return true if the event was consumed.
  bool onEvent(TuiEvent event);

  /// Called when the module is deactivated (user navigates away).
  void deactivate();
}

/// Context provided to active TUI modules.
class TuiModuleContext {
  /// The resolved project path.
  final String projectPath;

  /// Request a TUI redraw (e.g. after async data arrives).
  final void Function() requestRedraw;

  /// Access the command registry to run other commands.
  final TuiCommandRegistry registry;

  TuiModuleContext({
    required this.projectPath,
    required this.requestRedraw,
    required this.registry,
  });
}
```

### Module Registration

Modules are registered alongside commands. The TUI menu displays both simple commands and modules, distinguished by icon or section separator:

```dart
final registry = TuiCommandRegistry();

// Built-in commands
registry.registerCommand(BaselineTuiCommand());
registry.registerCommand(TestTuiCommand());

// External tool commands
registry.registerCommand(ExternalToolAdapter(
  id: 'dart_analyze',
  label: 'Dart Analyze',
  description: 'Run static analysis',
  executable: 'dart',
  argsBuilder: (path, args) => ['analyze', path],
  parser: DartAnalyzeOutputParser(),
));

// TUI-aware modules
registry.registerModule(CoverageModule());
registry.registerModule(TestSelectorModule());
```

### Menu Structure

```
Commands:
  > Baseline        Create baseline tracking file
    Test             Run tests and update tracking
    ─────────────
    Dart Analyze     Run static analysis
    ─────────────
Modules:
    Coverage         Interactive coverage viewer
    Test Selector    Select and run specific tests
```

---

## TUI Lifecycle

```
┌──────────────────────────────────────────────────────┐
│                    Startup                            │
│  1. Parse args (--tui, project path)                 │
│  2. Build command registry                           │
│  3. Create TestKitTuiApp                             │
│  4. TuiRunner(app).run()                             │
└────────────┬─────────────────────────────────────────┘
             ▼
┌──────────────────────────────────────────────────────┐
│                   Menu / Idle                         │
│  - Arrow keys navigate command list                  │
│  - Enter executes selected command                   │
│  - Tab switches focus between menu and output        │
│  - q / Esc returns to menu from output               │
│  - Ctrl+C quits                                      │
└────────────┬─────────────────────────────────────────┘
             ▼ (Enter on command)
┌──────────────────────────────────────────────────────┐
│                 Command Running                       │
│  - Output panel shows progress bar + log             │
│  - Events stream from command → output panel         │
│  - Ctrl+C cancels running command                    │
│  - Esc returns to menu (command continues in bg)     │
└────────────┬─────────────────────────────────────────┘
             ▼ (Command finishes)
┌──────────────────────────────────────────────────────┐
│                 Results View                          │
│  - Summary: passed/failed/skipped/elapsed            │
│  - Scrollable result list                            │
│  - Enter or Esc returns to menu                      │
└──────────────────────────────────────────────────────┘
```

---

## Key Bindings

| Key | Context | Action |
|-----|---------|--------|
| `↑` / `k` | Menu | Move selection up |
| `↓` / `j` | Menu | Move selection down |
| `Enter` | Menu | Execute selected command |
| `Tab` | Global | Switch focus between menu and output |
| `↑` / `↓` | Output | Scroll through log/results |
| `Esc` | Output | Return to menu |
| `q` | Menu | Quit application |
| `Ctrl+C` | Running | Cancel running command |
| `Ctrl+C` | Menu | Quit application |

---

## Implementation Files

| File | Purpose |
|------|---------|
| `lib/src/tui/tui_command.dart` | `TuiCommand`, `TuiCommandSink`, `TuiCommandResult`, `TuiCommandEvent` |
| `lib/src/tui/tui_command_registry.dart` | `TuiCommandRegistry` — registration and lookup |
| `lib/src/tui/tui_module.dart` | `TuiModule`, `TuiModuleContext` — direct TUI control interface |
| `lib/src/tui/tui_output_parser.dart` | `TuiOutputParser`, `PassthroughParser`, protocol line parser |
| `lib/src/tui/external_tool_adapter.dart` | `ExternalToolAdapter` — wraps external CLI tools |
| `lib/src/tui/commands/baseline_tui_command.dart` | Wraps `BaselineCommand` as a `TuiCommand` |
| `lib/src/tui/commands/test_tui_command.dart` | Wraps `TestCommand` as a `TuiCommand` |
| `lib/src/tui/app/test_kit_tui_app.dart` | `TestKitTuiApp` — main TUI application |
| `lib/src/tui/app/tui_output_panel.dart` | Output panel component |
| `lib/src/tui/app/tui_menu_panel.dart` | Command menu component |
| `bin/test_kit.dart` | Updated with `--tui` flag support |

---

## Future Extensions

- **Watch mode**: Re-run tests automatically when files change
- **Multi-project dashboard**: Show status for all projects in workspace
- **Test filtering**: Interactive selection of test suites/groups before running
- **Coverage integration**: Show coverage percentages per file after test run
- **Custom themes**: User-configurable TUI theme selection
- **Notification**: Desktop notification when long-running commands complete
