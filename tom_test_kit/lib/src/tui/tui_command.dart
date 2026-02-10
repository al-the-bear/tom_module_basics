/// TUI command interface for Tom Test Kit.
///
/// Defines the abstract interface for commands that run inside the TUI,
/// including the event sink for progress reporting and the result type.
library;

/// Log level for TUI output messages.
enum TuiLogLevel {
  /// Diagnostic detail, shown only in verbose mode.
  debug,

  /// Normal informational output.
  info,

  /// Potential issue that doesn't prevent completion.
  warning,

  /// Error that may cause the command to fail.
  error,
}

/// Outcome of a single test execution.
enum TuiTestOutcome {
  /// Test passed.
  passed,

  /// Test failed.
  failed,

  /// Test was skipped.
  skipped,

  /// Test encountered an error (crash, timeout, etc.).
  error,
}

/// A structured event emitted by a running command.
sealed class TuiCommandEvent {
  const TuiCommandEvent();
}

/// A phase has started (e.g. "Compiling", "Running tests").
class TuiPhaseStarted extends TuiCommandEvent {
  final String phaseName;
  final int? totalSteps;
  const TuiPhaseStarted(this.phaseName, {this.totalSteps});
}

/// Progress within the current phase.
class TuiProgressUpdate extends TuiCommandEvent {
  final int current;
  final int total;
  final String? detail;
  const TuiProgressUpdate(this.current, this.total, {this.detail});
}

/// A single log line.
class TuiLogEvent extends TuiCommandEvent {
  final String message;
  final TuiLogLevel level;
  const TuiLogEvent(this.message, {this.level = TuiLogLevel.info});
}

/// A single test result.
class TuiTestResultEvent extends TuiCommandEvent {
  final String testName;
  final TuiTestOutcome outcome;
  final String? detail;
  const TuiTestResultEvent(this.testName, this.outcome, {this.detail});
}

/// The command is complete.
class TuiDoneEvent extends TuiCommandEvent {
  final String? summary;
  const TuiDoneEvent({this.summary});
}

/// Receives events from a running command and forwards them to the TUI.
class TuiCommandSink {
  final List<TuiCommandEvent> _events = [];
  final void Function()? _onEvent;

  /// Creates a new command sink.
  ///
  /// [onEvent] is called whenever a new event is added, allowing the
  /// TUI to trigger a redraw.
  TuiCommandSink({void Function()? onEvent}) : _onEvent = onEvent;

  /// All events received so far.
  List<TuiCommandEvent> get events => List.unmodifiable(_events);

  /// Number of events received.
  int get length => _events.length;

  /// Report that a phase has started.
  void phaseStarted(String phaseName, {int? totalSteps}) {
    _add(TuiPhaseStarted(phaseName, totalSteps: totalSteps));
  }

  /// Report progress within the current phase.
  void progress(int current, int total, {String? detail}) {
    _add(TuiProgressUpdate(current, total, detail: detail));
  }

  /// Report a single line of output.
  void log(String message, {TuiLogLevel level = TuiLogLevel.info}) {
    _add(TuiLogEvent(message, level: level));
  }

  /// Report a test result.
  void testResult(String testName, TuiTestOutcome outcome, {String? detail}) {
    _add(TuiTestResultEvent(testName, outcome, detail: detail));
  }

  /// Report that the command is complete.
  void done({String? summary}) {
    _add(TuiDoneEvent(summary: summary));
  }

  void _add(TuiCommandEvent event) {
    _events.add(event);
    _onEvent?.call();
  }
}

/// Result returned when a command finishes.
class TuiCommandResult {
  /// Whether the command completed successfully.
  final bool success;

  /// Human-readable summary of the result.
  final String summary;

  /// Number of passed tests (for test-oriented commands).
  final int passedCount;

  /// Number of failed tests.
  final int failedCount;

  /// Number of skipped tests.
  final int skippedCount;

  /// Total elapsed time.
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

/// A command that can be executed inside the TUI.
///
/// Commands stream progress via [TuiCommandSink] and return a
/// [TuiCommandResult] when complete.
abstract class TuiCommand {
  /// Display name shown in the menu and header.
  String get label;

  /// Short description shown in the status bar when selected.
  String get description;

  /// Unique identifier for registry lookup.
  String get id;

  /// Execute the command.
  ///
  /// [projectPath] is the resolved project root.
  /// [sink] receives structured events for TUI display.
  /// [args] are additional command-specific arguments.
  Future<TuiCommandResult> execute({
    required String projectPath,
    required TuiCommandSink sink,
    Map<String, String> args = const {},
  });
}
