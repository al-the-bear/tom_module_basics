/// Tom Test Kit v2 — Test result tracking tool using tom_build_base v2.
///
/// This file defines the testkit tool using the v2 CLI framework.
library;

import 'package:tom_build_base/tom_build_base_v2.dart';

import '../version.versioner.dart';

// =============================================================================
// Command Options
// =============================================================================

/// Options for :baseline command.
const baselineOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'comment',
    abbr: 'c',
    description: 'Short label shown in the baseline column header',
    valueName: 'text',
  ),
  OptionDefinition.option(
    name: 'file',
    description: 'Output file path (overrides default doc/baseline_<ts>.csv)',
    valueName: 'path',
  ),
  OptionDefinition.option(
    name: 'test-args',
    description: 'Additional arguments passed to dart test',
    valueName: 'args',
  ),
];

/// Options for :test command.
const testOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'comment',
    abbr: 'c',
    description: 'Short label shown in the run column header',
    valueName: 'text',
  ),
  OptionDefinition.option(
    name: 'file',
    description: 'Tracking file to update (instead of most recent)',
    valueName: 'path',
  ),
  OptionDefinition.flag(
    name: 'baseline',
    description: 'Create baseline if no tracking file exists',
  ),
  OptionDefinition.flag(
    name: 'failed',
    description: 'Re-run only failed tests (X/OK, X/X) from last run',
  ),
  OptionDefinition.flag(
    name: 'mismatched',
    description: 'Re-run tests that don\'t match expectation (X/OK, OK/X)',
  ),
  OptionDefinition.flag(
    name: 'no-update',
    description: 'Run tests without updating baseline; print summary only',
  ),
  OptionDefinition.option(
    name: 'test-args',
    description: 'Additional arguments passed to dart test',
    valueName: 'args',
  ),
];

/// Options for analysis commands.
const analysisOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'output',
    description: 'Output format: plain, csv, json, md (or <format>:<filename>)',
    valueName: 'format',
  ),
  OptionDefinition.option(
    name: 'baseline-file',
    description: 'Use a specific baseline file',
    valueName: 'path',
  ),
];

/// Options for diff commands.
const diffOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'output',
    description: 'Output format: plain, csv, json, md (or <format>:<filename>)',
    valueName: 'format',
  ),
  OptionDefinition.option(
    name: 'baseline-file',
    description: 'Use a specific baseline file',
    valueName: 'path',
  ),
  OptionDefinition.flag(
    name: 'full',
    description: 'Include full details from last_testrun.json',
  ),
  OptionDefinition.option(
    name: 'report',
    description: 'Generate detailed Markdown report to file',
    valueName: 'filename',
  ),
];

/// Options for :trim command.
const trimOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'baseline-file',
    description: 'Use a specific baseline file',
    valueName: 'path',
  ),
];

/// Options for :reset command.
const resetOptions = <OptionDefinition>[
  OptionDefinition.flag(
    name: 'force',
    description: 'Skip confirmation prompts',
  ),
];

// =============================================================================
// Command Definitions
// =============================================================================

/// Run commands (execute dart test).
const baselineCommand = CommandDefinition(
  name: 'baseline',
  description: 'Create a new baseline tracking file',
  options: baselineOptions,
  worksWithNatures: {DartProjectFolder},
  supportsProjectTraversal: true,
  examples: [
    'testkit :baseline',
    'testkit :baseline -c "v2.0 release"',
    'testkit :baseline --test-args="--tags e2e"',
    'testkit :baseline -r',
  ],
);

const testCommand = CommandDefinition(
  name: 'test',
  description: 'Run tests and append results to the tracking file',
  options: testOptions,
  worksWithNatures: {DartProjectFolder},
  supportsProjectTraversal: true,
  examples: [
    'testkit :test',
    'testkit :test --failed',
    'testkit :test -c "bugfix"',
  ],
);

/// Analysis commands (read-only).
const runsCommand = CommandDefinition(
  name: 'runs',
  description: 'List run timestamps in the tracking file',
  options: analysisOptions,
  worksWithNatures: {DartProjectFolder},
  supportsProjectTraversal: true,
);

const statusCommand = CommandDefinition(
  name: 'status',
  description: 'Quick summary — pass/fail counts, regressions/fixes',
  options: analysisOptions,
  worksWithNatures: {DartProjectFolder},
  supportsProjectTraversal: true,
);

const basediffCommand = CommandDefinition(
  name: 'basediff',
  description: 'Diff baseline vs latest run',
  options: diffOptions,
  worksWithNatures: {DartProjectFolder},
  supportsProjectTraversal: true,
);

const lastdiffCommand = CommandDefinition(
  name: 'lastdiff',
  description: 'Diff previous run vs latest run',
  options: diffOptions,
  worksWithNatures: {DartProjectFolder},
  supportsProjectTraversal: true,
);

const diffCommand = CommandDefinition(
  name: 'diff',
  description: 'Diff two arbitrary runs by timestamp',
  options: diffOptions,
  worksWithNatures: {DartProjectFolder},
  supportsProjectTraversal: true,
  examples: ['testkit :diff 0211_1430', 'testkit :diff 0211_1430 0212_0900'],
);

const historyCommand = CommandDefinition(
  name: 'history',
  description: 'Show all results for a test across runs',
  options: analysisOptions,
  worksWithNatures: {DartProjectFolder},
  supportsProjectTraversal: true,
  examples: ['testkit :history "parser"', 'testkit :history ID001'],
);

const flakyCommand = CommandDefinition(
  name: 'flaky',
  description: 'List tests with inconsistent results',
  options: analysisOptions,
  worksWithNatures: {DartProjectFolder},
  supportsProjectTraversal: true,
);

const crossreferenceCommand = CommandDefinition(
  name: 'crossreference',
  description: 'Map tests to source files',
  aliases: ['crossref', 'xref'],
  options: analysisOptions,
  worksWithNatures: {DartProjectFolder},
  supportsProjectTraversal: true,
);

/// Maintenance commands.
const trimCommand = CommandDefinition(
  name: 'trim',
  description: 'Keep only the last N runs',
  options: trimOptions,
  worksWithNatures: {DartProjectFolder},
  supportsProjectTraversal: true,
  examples: ['testkit :trim 5', 'testkit :trim 10 -r'],
);

const resetCommand = CommandDefinition(
  name: 'reset',
  description: 'Delete all tracking files',
  options: resetOptions,
  worksWithNatures: {DartProjectFolder},
  supportsProjectTraversal: true,
  examples: ['testkit :reset', 'testkit :reset --force'],
);

// =============================================================================
// Tool Definition
// =============================================================================

/// Testkit tool definition.
final testkitTool = ToolDefinition(
  name: 'testkit',
  description: 'Test result tracking for Dart projects',
  version: TestKitVersionInfo.version,
  mode: ToolMode.multiCommand,
  helpTopics: defaultHelpTopics,
  features: const NavigationFeatures(
    projectTraversal: true,
    gitTraversal: false,
    recursiveScan: true,
    interactiveMode: true, // TUI mode
    dryRun: false,
    jsonOutput: false,
    verbose: true,
  ),
  globalOptions: const [
    OptionDefinition.flag(
      name: 'tui',
      description: 'Run in TUI mode (interactive)',
    ),
  ],
  commands: const [
    // Run commands
    baselineCommand,
    testCommand,
    // Analysis commands
    runsCommand,
    statusCommand,
    basediffCommand,
    lastdiffCommand,
    diffCommand,
    historyCommand,
    flakyCommand,
    crossreferenceCommand,
    // Maintenance commands
    trimCommand,
    resetCommand,
  ],
  helpFooter: '''
Tracking File:
  Baseline: doc/baseline_<MMDD_HHMM>.csv
  :test appends a result column to the most recent baseline file.
  Raw JSON: doc/last_testrun.json

Result Format:
  OK/OK (pass), X/OK (regression), X/X (known fail),
  OK/X (progress), -/OK (skip), --/OK (absent)
''',
);
