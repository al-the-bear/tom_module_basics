/// External tool adapter for Tom Test Kit TUI.
///
/// Wraps an external CLI tool as a [TuiCommand], running it as a
/// subprocess and piping output through a [TuiOutputParser].
library;

import 'dart:convert';
import 'dart:io';

import 'tui_command.dart';
import 'tui_output_parser.dart';

/// Wraps an external CLI tool as a [TuiCommand].
///
/// The adapter runs the tool as a subprocess and applies a
/// [TuiOutputParser] to convert stdout/stderr into TUI events.
class ExternalToolAdapter extends TuiCommand {
  @override
  final String label;

  @override
  final String description;

  @override
  final String id;

  /// The executable to run (e.g. 'dart', 'flutter').
  final String executable;

  /// Builds the argument list from the project path and command args.
  final List<String> Function(String projectPath, Map<String, String> args)
      argsBuilder;

  /// Factory that creates a fresh parser for each execution.
  final TuiOutputParser Function() parserFactory;

  ExternalToolAdapter({
    required this.id,
    required this.label,
    required this.description,
    required this.executable,
    required this.argsBuilder,
    required this.parserFactory,
  });

  @override
  Future<TuiCommandResult> execute({
    required String projectPath,
    required TuiCommandSink sink,
    Map<String, String> args = const {},
  }) async {
    final parser = parserFactory();
    final processArgs = argsBuilder(projectPath, args);

    sink.phaseStarted('Running $executable', totalSteps: null);
    sink.log('> $executable ${processArgs.join(' ')}',
        level: TuiLogLevel.debug);

    final process = await Process.start(
      executable,
      processArgs,
      workingDirectory: projectPath,
    );

    // Pipe stdout through parser
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      final events = parser.parseLine(line);
      for (final event in events) {
        _forwardEvent(event, sink);
      }
    });

    // Pipe stderr through parser
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      final events = parser.parseLine(line, isStderr: true);
      for (final event in events) {
        _forwardEvent(event, sink);
      }
    });

    final exitCode = await process.exitCode;
    final result = parser.finalize(exitCode);
    sink.done(summary: result.summary);
    return result;
  }

  /// Forward a parsed event to the command sink.
  void _forwardEvent(TuiCommandEvent event, TuiCommandSink sink) {
    switch (event) {
      case TuiPhaseStarted(:final phaseName, :final totalSteps):
        sink.phaseStarted(phaseName, totalSteps: totalSteps);
      case TuiProgressUpdate(:final current, :final total, :final detail):
        sink.progress(current, total, detail: detail);
      case TuiLogEvent(:final message, :final level):
        sink.log(message, level: level);
      case TuiTestResultEvent(:final testName, :final outcome, :final detail):
        sink.testResult(testName, outcome, detail: detail);
      case TuiDoneEvent(:final summary):
        sink.done(summary: summary);
    }
  }
}
