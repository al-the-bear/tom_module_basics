/// Wraps [TestCommand] as a [TuiCommand] for the TUI.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../model/test_entry.dart';
import '../../model/test_run.dart';
import '../../model/tracking_file.dart';
import '../../parser/dart_test_parser.dart';
import '../../parser/test_description_parser.dart';
import '../../util/file_helpers.dart';
import '../tui_command.dart';

/// TUI-integrated test command.
///
/// Runs `dart test --reporter json`, streams progress to the TUI,
/// and appends a new result column to the most recent tracking file.
class TestTuiCommand extends TuiCommand {
  @override
  String get id => 'test';

  @override
  String get label => 'Test';

  @override
  String get description =>
      'Run tests and append results to existing tracking file';

  @override
  Future<TuiCommandResult> execute({
    required String projectPath,
    required TuiCommandSink sink,
    Map<String, String> args = const {},
  }) async {
    final stopwatch = Stopwatch()..start();

    // Find the tracking file
    final trackingFilePath =
        args['file'] ?? findLatestTrackingFile(projectPath);

    if (trackingFilePath == null) {
      sink.log('No tracking file found. Run Baseline first.',
          level: TuiLogLevel.error);
      stopwatch.stop();
      sink.done(summary: 'No tracking file found');
      return TuiCommandResult(
        success: false,
        summary: 'No tracking file found',
        elapsed: stopwatch.elapsed,
      );
    }

    // Load existing tracking file
    final tracking = TrackingFile.load(trackingFilePath);
    if (tracking == null) {
      sink.log('Failed to parse tracking file: $trackingFilePath',
          level: TuiLogLevel.error);
      stopwatch.stop();
      sink.done(summary: 'Failed to parse tracking file');
      return TuiCommandResult(
        success: false,
        summary: 'Failed to parse tracking file',
        elapsed: stopwatch.elapsed,
      );
    }

    sink.log(
        'Using: ${p.relative(trackingFilePath, from: projectPath)}');

    // Run dart test
    sink.phaseStarted('Running dart test');

    final dartArgs = ['test', '--reporter', 'json'];
    final additionalArgs = args['test-args'];
    if (additionalArgs != null && additionalArgs.isNotEmpty) {
      final splitArgs = additionalArgs.split(' ');
      final forbidden = DartTestParser.findForbiddenArg(splitArgs);
      if (forbidden != null) {
        sink.log('Error: "$forbidden" cannot be used in --test-args.',
            level: TuiLogLevel.error);
        sink.log('testkit requires --reporter json for result parsing.',
            level: TuiLogLevel.error);
        sink.done(summary: 'Forbidden test arg: $forbidden');
        return TuiCommandResult(
          success: false,
          summary: 'Forbidden test arg: $forbidden',
        );
      }
      dartArgs.addAll(splitArgs);
    }

    final process = await Process.start(
      'dart',
      dartArgs,
      workingDirectory: projectPath,
    );

    final entries = <TestEntry>[];
    final run = TestRun(timestamp: DateTime.now());
    final testNames = <int, String>{};
    final testSuites = <int, String>{};
    final testSuiteMap = <int, int>{};
    final groupNames = <int, String>{};
    final testGroupMap = <int, List<int>>{};

    var passCount = 0;
    var failCount = 0;
    var skipCount = 0;
    var totalExpected = 0;
    var processed = 0;
    final rawJsonLines = <String>[];

    // Parse JSON output line by line
    await process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) {
      rawJsonLines.add(line);
      if (line.trim().isEmpty) return;

      Map<String, dynamic> json;
      try {
        json = jsonDecode(line) as Map<String, dynamic>;
      } catch (_) {
        return;
      }

      final type = json['type'] as String?;
      if (type == null) return;

      switch (type) {
        case 'suite':
          final suite = json['suite'] as Map<String, dynamic>?;
          if (suite != null) {
            testSuites[suite['id'] as int] = suite['path'] as String? ?? '';
          }

        case 'group':
          final group = json['group'] as Map<String, dynamic>?;
          if (group != null) {
            groupNames[group['id'] as int] =
                group['name'] as String? ?? '';
          }

        case 'testStart':
          final test = json['test'] as Map<String, dynamic>?;
          if (test != null) {
            final testId = test['id'] as int;
            final name = test['name'] as String? ?? '';
            testNames[testId] = name;
            testSuiteMap[testId] = test['suiteID'] as int? ?? 0;
            final gids =
                (test['groupIDs'] as List<dynamic>?)?.cast<int>() ?? [];
            testGroupMap[testId] = gids;
            totalExpected++;
          }

        case 'testDone':
          final testId = json['testID'] as int?;
          if (testId == null) return;

          final name = testNames[testId];
          if (name == null || name.isEmpty) return;
          if (name.startsWith('loading ')) return;

          final resultStr = json['result'] as String? ?? '';
          final skipped = json['skipped'] as bool? ?? false;
          final hidden = json['hidden'] as bool? ?? false;

          if (hidden) return;

          TestResult result;
          TuiTestOutcome outcome;
          if (skipped) {
            result = TestResult.skip;
            outcome = TuiTestOutcome.skipped;
            skipCount++;
          } else if (resultStr == 'success') {
            result = TestResult.ok;
            outcome = TuiTestOutcome.passed;
            passCount++;
          } else {
            result = TestResult.fail;
            outcome = TuiTestOutcome.failed;
            failCount++;
          }

          final suitePath = testSuites[testSuiteMap[testId]];
          final gids = testGroupMap[testId] ?? [];
          final (strippedName, groups) = DartTestParser.extractGroups(
            testName: name,
            groupIds: gids,
            groupNames: groupNames,
          );
          final entry = TestDescriptionParser.parse(strippedName,
              suite: suitePath, groups: groups);
          entries.add(entry);
          run.setResult(entry.fullDescription, result);

          processed++;
          sink.testResult(name, outcome);
          sink.progress(
              processed, totalExpected > 0 ? totalExpected : processed,
              detail: name);
      }
    });

    // Collect stderr
    final stderrOutput = await process.stderr
        .transform(utf8.decoder)
        .join();

    final exitCode = await process.exitCode;

    if (exitCode != 0 && exitCode != 1) {
      sink.log('dart test exited with code $exitCode',
          level: TuiLogLevel.error);
      if (stderrOutput.isNotEmpty) {
        sink.log(stderrOutput, level: TuiLogLevel.error);
      }
      stopwatch.stop();
      sink.done(summary: 'Failed (exit code $exitCode)');
      return TuiCommandResult(
        success: false,
        summary: 'dart test failed with exit code $exitCode',
        elapsed: stopwatch.elapsed,
      );
    }

    // Save raw JSON output
    await saveLastTestRunJson(projectPath, rawJsonLines);

    // Update tracking file
    sink.phaseStarted('Updating tracking file');

    tracking.addRun(run, entries);
    await tracking.write(trackingFilePath);

    final relativePath = p.relative(trackingFilePath, from: projectPath);

    stopwatch.stop();
    final totalTests = passCount + failCount + skipCount;
    final summaryText =
        '$totalTests tests '
        '($passCount passed, $failCount failed'
        '${skipCount > 0 ? ', $skipCount skipped' : ''}) → $relativePath';

    sink.log('Updated: $relativePath');
    sink.done(summary: summaryText);

    return TuiCommandResult(
      success: failCount == 0,
      summary: summaryText,
      passedCount: passCount,
      failedCount: failCount,
      skippedCount: skipCount,
      elapsed: stopwatch.elapsed,
    );
  }
}
