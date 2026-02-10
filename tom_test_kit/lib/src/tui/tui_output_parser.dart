/// TUI output parser for external tool integration.
///
/// Provides the protocol line parser and the passthrough fallback
/// for tools that cannot be adapted.
library;

import 'tui_command.dart';

/// Converts raw output lines from an external tool into TUI events.
///
/// Implementations are tool-specific. The TUI ships with parsers for
/// common output formats.
abstract class TuiOutputParser {
  /// Parse a single output line.
  ///
  /// Returns a list of events (may be empty if the line is not relevant).
  List<TuiCommandEvent> parseLine(String line, {bool isStderr = false});

  /// Called when the process exits. Returns a final result.
  TuiCommandResult finalize(int exitCode);
}

/// Parses lines that follow the TUI output protocol.
///
/// Protocol lines are prefixed with `##TUI:` tags:
/// ```
/// ##TUI:PHASE <name> [<total>]
/// ##TUI:PROGRESS <current> <total> [<detail>]
/// ##TUI:LOG <level> <message>
/// ##TUI:TEST <outcome> <name> [<detail>]
/// ##TUI:DONE [<summary>]
/// ```
class TuiProtocolParser extends TuiOutputParser {
  int _passedCount = 0;
  int _failedCount = 0;
  int _skippedCount = 0;
  final _stopwatch = Stopwatch();

  TuiProtocolParser() {
    _stopwatch.start();
  }

  @override
  List<TuiCommandEvent> parseLine(String line, {bool isStderr = false}) {
    if (isStderr) {
      return [TuiLogEvent(line, level: TuiLogLevel.warning)];
    }

    if (!line.startsWith('##TUI:')) {
      return [TuiLogEvent(line)];
    }

    final rest = line.substring(6); // After '##TUI:'

    if (rest.startsWith('PHASE ')) {
      return _parsePhase(rest.substring(6));
    } else if (rest.startsWith('PROGRESS ')) {
      return _parseProgress(rest.substring(9));
    } else if (rest.startsWith('LOG ')) {
      return _parseLog(rest.substring(4));
    } else if (rest.startsWith('TEST ')) {
      return _parseTest(rest.substring(5));
    } else if (rest.startsWith('DONE')) {
      final summary = rest.length > 5 ? rest.substring(5).trim() : null;
      return [TuiDoneEvent(summary: summary)];
    }

    return [TuiLogEvent(line)];
  }

  List<TuiCommandEvent> _parsePhase(String text) {
    final parts = text.split(' ');
    final name = parts.first;
    final total = parts.length > 1 ? int.tryParse(parts[1]) : null;
    return [TuiPhaseStarted(name, totalSteps: total)];
  }

  List<TuiCommandEvent> _parseProgress(String text) {
    final parts = text.split(' ');
    if (parts.length < 2) return [];
    final current = int.tryParse(parts[0]) ?? 0;
    final total = int.tryParse(parts[1]) ?? 0;
    final detail = parts.length > 2 ? parts.sublist(2).join(' ') : null;
    return [TuiProgressUpdate(current, total, detail: detail)];
  }

  List<TuiCommandEvent> _parseLog(String text) {
    final spaceIndex = text.indexOf(' ');
    if (spaceIndex == -1) return [TuiLogEvent(text)];

    final levelStr = text.substring(0, spaceIndex).toUpperCase();
    final message = text.substring(spaceIndex + 1);
    final level = switch (levelStr) {
      'DEBUG' => TuiLogLevel.debug,
      'WARNING' => TuiLogLevel.warning,
      'ERROR' => TuiLogLevel.error,
      _ => TuiLogLevel.info,
    };
    return [TuiLogEvent(message, level: level)];
  }

  List<TuiCommandEvent> _parseTest(String text) {
    final spaceIndex = text.indexOf(' ');
    if (spaceIndex == -1) return [];

    final outcomeStr = text.substring(0, spaceIndex).toUpperCase();
    final rest = text.substring(spaceIndex + 1);

    final outcome = switch (outcomeStr) {
      'PASSED' => TuiTestOutcome.passed,
      'FAILED' => TuiTestOutcome.failed,
      'SKIPPED' => TuiTestOutcome.skipped,
      _ => TuiTestOutcome.error,
    };

    switch (outcome) {
      case TuiTestOutcome.passed:
        _passedCount++;
      case TuiTestOutcome.failed:
        _failedCount++;
      case TuiTestOutcome.skipped:
        _skippedCount++;
      case TuiTestOutcome.error:
        _failedCount++;
    }

    return [TuiTestResultEvent(rest, outcome)];
  }

  @override
  TuiCommandResult finalize(int exitCode) {
    _stopwatch.stop();
    return TuiCommandResult(
      success: exitCode == 0 || exitCode == 1 && _failedCount == 0,
      summary:
          '$_passedCount passed, $_failedCount failed, $_skippedCount skipped',
      passedCount: _passedCount,
      failedCount: _failedCount,
      skippedCount: _skippedCount,
      elapsed: _stopwatch.elapsed,
    );
  }
}

/// Passthrough parser for tools with unknown output formats.
///
/// All stdout lines become INFO log events; all stderr lines become
/// WARNING events. Progress is not tracked — only a spinner is shown.
class PassthroughParser extends TuiOutputParser {
  final _stopwatch = Stopwatch();

  PassthroughParser() {
    _stopwatch.start();
  }

  @override
  List<TuiCommandEvent> parseLine(String line, {bool isStderr = false}) {
    final level = isStderr ? TuiLogLevel.warning : TuiLogLevel.info;
    return [TuiLogEvent(line, level: level)];
  }

  @override
  TuiCommandResult finalize(int exitCode) {
    _stopwatch.stop();
    return TuiCommandResult(
      success: exitCode == 0,
      summary: exitCode == 0 ? 'Completed successfully' : 'Exited with $exitCode',
      elapsed: _stopwatch.elapsed,
    );
  }
}
