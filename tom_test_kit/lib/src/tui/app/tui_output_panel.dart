/// Output panel component for the Test Kit TUI.
///
/// Renders command progress (phase, progress bar, test results, log).
library;

import 'package:utopia_tui/utopia_tui.dart';

import '../tui_command.dart';

/// Visual state of the output panel.
enum OutputPanelState {
  /// No command has run yet — show welcome message.
  idle,

  /// A command is currently running.
  running,

  /// A command has finished — show results.
  finished,
}

/// Renders the TUI output panel: progress bar, test results, log lines.
class TuiOutputPanel extends TuiComponent {
  OutputPanelState state = OutputPanelState.idle;

  /// Current phase name.
  String currentPhase = '';

  /// Progress numerator.
  int progressCurrent = 0;

  /// Progress denominator.
  int progressTotal = 0;

  /// Visible log/result lines (most recent at end).
  final List<OutputLine> lines = [];

  /// Final result summary.
  String? resultSummary;

  /// Command result (set when finished).
  TuiCommandResult? result;

  /// Spinner for running state.
  final _spinner = TuiSpinner(style: const TuiStyle(fg: 39));

  /// Maximum log lines to keep in memory.
  static const _maxLines = 500;

  /// Reset the panel to idle state.
  void reset() {
    state = OutputPanelState.idle;
    currentPhase = '';
    progressCurrent = 0;
    progressTotal = 0;
    lines.clear();
    resultSummary = null;
    result = null;
  }

  /// Process a command event and update state.
  void processEvent(TuiCommandEvent event) {
    switch (event) {
      case TuiPhaseStarted(:final phaseName, :final totalSteps):
        currentPhase = phaseName;
        if (totalSteps != null) progressTotal = totalSteps;
        state = OutputPanelState.running;

      case TuiProgressUpdate(:final current, :final total, :final detail):
        progressCurrent = current;
        progressTotal = total;
        if (detail != null) {
          _addLine(detail, style: const TuiStyle(fg: 250));
        }

      case TuiLogEvent(:final message, :final level):
        final style = switch (level) {
          TuiLogLevel.debug => const TuiStyle(fg: 244),
          TuiLogLevel.info => const TuiStyle(fg: 252),
          TuiLogLevel.warning => const TuiStyle(fg: 214),
          TuiLogLevel.error => const TuiStyle(fg: 196, bold: true),
        };
        _addLine(message, style: style);

      case TuiTestResultEvent(:final testName, :final outcome):
        final (icon, style) = switch (outcome) {
          TuiTestOutcome.passed => (
              '\u2713',
              const TuiStyle(fg: 34),
            ), // green check
          TuiTestOutcome.failed => (
              '\u2717',
              const TuiStyle(fg: 196, bold: true),
            ), // red X
          TuiTestOutcome.skipped => (
              '\u2192',
              const TuiStyle(fg: 214),
            ), // arrow
          TuiTestOutcome.error => (
              '!',
              const TuiStyle(fg: 196, bold: true),
            ),
        };
        _addLine('$icon $testName', style: style);

      case TuiDoneEvent(:final summary):
        resultSummary = summary;
        state = OutputPanelState.finished;
    }
  }

  void _addLine(String text, {TuiStyle? style}) {
    lines.add(OutputLine(text, style: style ?? const TuiStyle()));
    if (lines.length > _maxLines) {
      lines.removeRange(0, lines.length - _maxLines);
    }
  }

  /// Tick the spinner.
  void tick() {
    if (state == OutputPanelState.running) {
      _spinner.tick();
    }
  }

  /// Scroll offset for log lines (0 = bottom, positive = scrolled up).
  int scrollOffset = 0;

  /// Scroll up by one line.
  void scrollUp() {
    if (scrollOffset < lines.length - 1) scrollOffset++;
  }

  /// Scroll down by one line.
  void scrollDown() {
    if (scrollOffset > 0) scrollOffset--;
  }

  @override
  void paintSurface(TuiSurface surface, TuiRect rect) {
    if (rect.isEmpty) return;
    surface.clearRect(rect.x, rect.y, rect.width, rect.height);

    switch (state) {
      case OutputPanelState.idle:
        _paintIdle(surface, rect);
      case OutputPanelState.running:
        _paintRunning(surface, rect);
      case OutputPanelState.finished:
        _paintFinished(surface, rect);
    }
  }

  void _paintIdle(TuiSurface surface, TuiRect rect) {
    const style = TuiStyle(fg: 245);
    surface.putText(rect.x + 2, rect.y + 1, 'Select a command from the menu',
        style: style);
    surface.putText(rect.x + 2, rect.y + 2, 'and press Enter to run it.',
        style: style);
    surface.putText(rect.x + 2, rect.y + 4,
        'Use arrow keys to navigate, Ctrl+C to quit.', style: style);
  }

  void _paintRunning(TuiSurface surface, TuiRect rect) {
    var y = rect.y;
    final w = rect.width;

    // Phase + spinner
    final spinnerStr = _spinner.render();
    final phaseText = ' $spinnerStr $currentPhase';
    surface.putTextClip(rect.x, y, phaseText, w);
    y++;

    // Progress bar (if we have a total)
    if (progressTotal > 0 && y < rect.bottom) {
      final progress = TuiProgressBar(
        value: progressCurrent / progressTotal,
        barStyle: const TuiStyle(fg: 250),
        fillStyle: const TuiStyle(fg: 39),
      );
      final countText = ' $progressCurrent/$progressTotal';
      final barWidth = w - countText.length - 1;
      if (barWidth > 5) {
        TuiProgressBarView(progress).paintSurface(
          surface,
          TuiRect(x: rect.x, y: y, width: barWidth, height: 1),
        );
        surface.putText(rect.x + barWidth, y, countText,
            style: const TuiStyle(fg: 250));
      }
      y++;
    }

    // Separator
    if (y < rect.bottom) {
      y++;
    }

    // Log lines (scrollable, most recent at bottom)
    _paintLogLines(surface, rect.x, y, w, rect.bottom - y);
  }

  void _paintFinished(TuiSurface surface, TuiRect rect) {
    var y = rect.y;
    final w = rect.width;

    // Result summary
    if (resultSummary != null) {
      final isSuccess = result?.success ?? true;
      final summaryStyle = isSuccess
          ? const TuiStyle(fg: 34, bold: true)
          : const TuiStyle(fg: 196, bold: true);
      final icon = isSuccess ? '\u2713' : '\u2717';
      surface.putTextClip(
          rect.x, y, ' $icon $resultSummary', w,
          style: summaryStyle);
      y++;
    }

    // Elapsed time
    if (result != null && y < rect.bottom) {
      final elapsed = _formatDuration(result!.elapsed);
      surface.putText(rect.x + 1, y, 'Elapsed: $elapsed',
          style: const TuiStyle(fg: 245));
      y++;
    }

    // Separator
    if (y < rect.bottom) {
      y++;
    }

    // Log lines
    _paintLogLines(surface, rect.x, y, w, rect.bottom - y);
  }

  void _paintLogLines(
      TuiSurface surface, int x, int y, int width, int maxLines) {
    if (maxLines <= 0 || lines.isEmpty) return;

    // Calculate visible range
    final totalLines = lines.length;
    final visibleCount = maxLines.clamp(0, totalLines);
    final endIndex = totalLines - scrollOffset;
    final startIndex = (endIndex - visibleCount).clamp(0, totalLines);

    for (var i = startIndex; i < endIndex && (y + i - startIndex) < y + maxLines; i++) {
      final line = lines[i];
      final lineY = y + (i - startIndex);
      surface.putTextClip(x + 1, lineY, line.text, width - 1,
          style: line.style);
    }
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    }
    return '${d.inSeconds}.${(d.inMilliseconds.remainder(1000) ~/ 100)}s';
  }
}

/// A single line of output with optional styling.
class OutputLine {
  /// The text content.
  final String text;

  /// Style to apply when rendering.
  final TuiStyle style;

  /// Creates an output line.
  OutputLine(this.text, {this.style = const TuiStyle()});
}
