/// Tom Issue Kit v2 — Issue tracking tool using tom_build_base v2.
///
/// This file defines the issuekit tool using the v2 CLI framework.
library;

import 'package:tom_build_base/tom_build_base_v2.dart';

import '../version.versioner.dart';

// =============================================================================
// Common Options
// =============================================================================

/// Output format options for commands that support multiple output formats.
const outputOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'output',
    description:
        'Output format: plain (default), csv, json, md, '
        'or <format>:<filename>',
    valueName: 'format',
  ),
];

/// Traversal options for workspace scanning commands.
const traversalOptions = <OptionDefinition>[...outputOptions];

// =============================================================================
// Issue Management Command Options
// =============================================================================

/// Options for :new command.
const newOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'severity',
    description: 'Severity: critical, high, normal (default), low',
    valueName: 'level',
  ),
  OptionDefinition.option(
    name: 'context',
    description: 'Where/how the problem was discovered',
    valueName: 'text',
  ),
  OptionDefinition.option(
    name: 'expected',
    description: 'Expected behavior',
    valueName: 'text',
  ),
  OptionDefinition.option(
    name: 'symptom',
    description: 'Observable symptoms (defaults to title)',
    valueName: 'text',
  ),
  OptionDefinition.option(
    name: 'tags',
    description: 'Comma-separated tags',
    valueName: 't1,t2,...',
  ),
  OptionDefinition.option(
    name: 'project',
    description: 'Pre-assign to a project (skips NEW → ASSIGNED)',
    valueName: 'name',
  ),
  OptionDefinition.option(
    name: 'reporter',
    description: 'Reporter name (default: configured user)',
    valueName: 'name',
  ),
];

/// Options for :edit command.
const editOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'title',
    description: 'Update issue title',
    valueName: 'text',
  ),
  OptionDefinition.option(
    name: 'severity',
    description: 'Update severity: critical, high, normal, low',
    valueName: 'level',
  ),
  OptionDefinition.option(
    name: 'context',
    description: 'Update discovery context',
    valueName: 'text',
  ),
  OptionDefinition.option(
    name: 'expected',
    description: 'Update expected behavior',
    valueName: 'text',
  ),
  OptionDefinition.option(
    name: 'symptom',
    description: 'Update observable symptoms',
    valueName: 'text',
  ),
  OptionDefinition.option(
    name: 'tags',
    description: 'Replace tags (comma-separated)',
    valueName: 't1,t2,...',
  ),
  OptionDefinition.option(
    name: 'project',
    description: 'Reassign to a different project',
    valueName: 'name',
  ),
  OptionDefinition.option(
    name: 'module',
    description: 'Update module',
    valueName: 'name',
  ),
  OptionDefinition.option(
    name: 'assignee',
    description: 'Update assignee',
    valueName: 'name',
  ),
];

/// Options for :analyze command.
const analyzeOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'root-cause',
    description: 'Explanation of the root cause',
    valueName: 'text',
  ),
  OptionDefinition.option(
    name: 'project',
    description: 'Identified target project (triggers assignment)',
    valueName: 'name',
  ),
  OptionDefinition.option(
    name: 'module',
    description: 'Identified target module within the project',
    valueName: 'name',
  ),
  OptionDefinition.option(
    name: 'note',
    description: 'Additional analysis notes',
    valueName: 'text',
  ),
];

/// Options for :assign command.
const assignOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'project',
    description: 'Target project (required)',
    valueName: 'name',
  ),
  OptionDefinition.option(
    name: 'module',
    description: 'Target module within the project',
    valueName: 'name',
  ),
  OptionDefinition.option(
    name: 'assignee',
    description: 'Person or entity responsible for the fix',
    valueName: 'name',
  ),
];

/// Options for :resolve command.
const resolveOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'fix',
    description: 'Short description of the fix applied',
    valueName: 'text',
  ),
  OptionDefinition.option(
    name: 'note',
    description: 'Additional notes',
    valueName: 'text',
  ),
];

/// Options for :reopen command.
const reopenOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'note',
    description: 'Reason for reopening',
    valueName: 'text',
  ),
];

// =============================================================================
// Discovery and Query Command Options
// =============================================================================

/// Options for :list command.
const listOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'state',
    description:
        'Filter by state: new, analyzed, assigned, testing, '
        'verifying, resolved',
    valueName: 'state',
  ),
  OptionDefinition.option(
    name: 'severity',
    description: 'Filter by severity: critical, high, normal, low',
    valueName: 'level',
  ),
  OptionDefinition.option(
    name: 'project',
    description: 'Filter by assigned project',
    valueName: 'name',
  ),
  OptionDefinition.option(
    name: 'tags',
    description: 'Filter by tags/labels',
    valueName: 't1,t2',
  ),
  OptionDefinition.option(
    name: 'reporter',
    description: 'Filter by reporter (e.g., copilot)',
    valueName: 'name',
  ),
  OptionDefinition.flag(
    name: 'all',
    description: 'Include closed issues (default: only open)',
  ),
  OptionDefinition.option(
    name: 'sort',
    description: 'Sort by: created, severity, state, project',
    valueName: 'field',
  ),
  OptionDefinition.option(
    name: 'output',
    description: 'Output format: plain, csv, json, md, or <format>:<file>',
    valueName: 'format',
  ),
  OptionDefinition.option(
    name: 'repo',
    description: 'Which tracker to list from: issues (default), tests',
    valueName: 'issues|tests',
  ),
];

/// Options for :search command.
const searchOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'output',
    description: 'Output format',
    valueName: 'format',
  ),
  OptionDefinition.option(
    name: 'repo',
    description: 'Which tracker to search: issues (default), tests',
    valueName: 'issues|tests',
  ),
];

/// Options for :scan command.
const scanOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'project',
    description: 'Only scan within a specific project',
    valueName: 'name',
  ),
  OptionDefinition.option(
    name: 'state',
    description: 'Only scan for issues in a specific state',
    valueName: 'state',
  ),
  OptionDefinition.flag(
    name: 'missing-tests',
    description: 'Show issues with only stub test entries (no dart test yet)',
  ),
  OptionDefinition.option(
    name: 'output',
    description: 'Output format: plain, csv, json, md',
    valueName: 'format',
  ),
];

// =============================================================================
// Test Management Command Options
// =============================================================================

/// Options for :promote command.
const promoteOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'issue',
    description: 'Issue number to link to (required)',
    valueName: 'number',
  ),
  OptionDefinition.flag(
    name: 'dry-run',
    description: 'Show what would change without modifying files',
  ),
];

/// Options for :validate command.
const validateOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'project',
    description: 'Only validate a specific project',
    valueName: 'name',
  ),
  OptionDefinition.flag(
    name: 'fix',
    description: 'Automatically fix simple conflicts',
  ),
];

/// Options for :link command.
const linkOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'test-id',
    description: 'The dart test ID to link (required)',
    valueName: 'id',
  ),
  OptionDefinition.option(
    name: 'test-file',
    description: 'Path to the test file (optional)',
    valueName: 'path',
  ),
  OptionDefinition.option(
    name: 'note',
    description: 'Reason for the explicit link',
    valueName: 'text',
  ),
];

// =============================================================================
// Workflow Integration Command Options
// =============================================================================

/// Options for :sync command.
const syncOptions = <OptionDefinition>[
  OptionDefinition.flag(
    name: 'auto',
    description: 'Automatically apply state transitions and reopens',
  ),
  OptionDefinition.option(
    name: 'project',
    description: 'Only sync issues for a specific project',
    valueName: 'name',
  ),
  OptionDefinition.flag(
    name: 'dry-run',
    description: 'Show what would change without applying',
  ),
];

/// Options for :aggregate command.
const aggregateOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'output',
    description: 'Output format: plain, csv, json, md, or <format>:<file>',
    valueName: 'format',
  ),
];

/// Options for :export command.
const exportOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'output',
    description: 'Output format: csv, json, md, or <format>:<file> (required)',
    valueName: 'format',
  ),
  OptionDefinition.option(
    name: 'state',
    description: 'Filter by state',
    valueName: 'state',
  ),
  OptionDefinition.option(
    name: 'severity',
    description: 'Filter by severity',
    valueName: 'level',
  ),
  OptionDefinition.option(
    name: 'project',
    description: 'Filter by project',
    valueName: 'name',
  ),
  OptionDefinition.option(
    name: 'tags',
    description: 'Filter by tags',
    valueName: 't1,t2',
  ),
  OptionDefinition.flag(name: 'all', description: 'Include closed issues'),
  OptionDefinition.option(
    name: 'repo',
    description: 'Which tracker to export from: issues (default), tests',
    valueName: 'issues|tests',
  ),
];

/// Options for :import command.
const importOptions = <OptionDefinition>[
  OptionDefinition.flag(
    name: 'dry-run',
    description: 'Show what would be created without actually creating',
  ),
  OptionDefinition.option(
    name: 'repo',
    description: 'Which tracker to import into: issues (default), tests',
    valueName: 'issues|tests',
  ),
];

/// Options for :init command.
const initOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'repo',
    description: 'Which tracker(s) to initialize: issues, tests, both',
    valueName: 'issues|tests|both',
  ),
  OptionDefinition.flag(
    name: 'force',
    description: 'Overwrite existing labels and templates',
  ),
];

/// Options for :snapshot command.
const snapshotOptions = <OptionDefinition>[
  OptionDefinition.flag(
    name: 'issues-only',
    description: 'Only snapshot issues from tom_issues',
  ),
  OptionDefinition.flag(
    name: 'tests-only',
    description: 'Only snapshot test entries from tom_tests',
  ),
  OptionDefinition.option(
    name: 'output',
    description: 'Output directory (default: tom_tests/snapshots/)',
    valueName: 'dir',
  ),
];

/// Options for :run-tests command.
const runTestsOptions = <OptionDefinition>[
  OptionDefinition.flag(
    name: 'wait',
    description: 'Wait for the workflow to complete (polls status)',
  ),
];

// =============================================================================
// Command Definitions
// =============================================================================

// Issue Management Commands
const newCommand = CommandDefinition(
  name: 'new',
  description: 'Create a new issue in tom_issues via GitHub API',
  options: newOptions,
  requiresTraversal: false,
  supportsProjectTraversal: false,
  examples: [
    'issuekit :new "Memory leak in server"',
    'issuekit :new "Parser crash" --severity high --tags "parser,crash"',
    'issuekit :new "Timeout issue" --project tom_d4rt',
  ],
);

const editCommand = CommandDefinition(
  name: 'edit',
  description: 'Edit an existing issue\'s fields',
  options: editOptions,
  requiresTraversal: false,
  supportsProjectTraversal: false,
  examples: [
    'issuekit :edit 42 --severity critical',
    'issuekit :edit 42 --project tom_basics --module collections',
  ],
);

const analyzeCommand = CommandDefinition(
  name: 'analyze',
  description: 'Record analysis results (root cause, affected project)',
  options: analyzeOptions,
  requiresTraversal: false,
  supportsProjectTraversal: false,
  examples: [
    'issuekit :analyze 42 --root-cause "Missing null check" '
        '--project tom_d4rt --module parser',
    'issuekit :analyze 42 --note "Needs more investigation"',
  ],
);

const assignCommand = CommandDefinition(
  name: 'assign',
  description: 'Assign an issue to a project (creates stub test ID)',
  options: assignOptions,
  requiresTraversal: false,
  supportsProjectTraversal: false,
  examples: [
    'issuekit :assign 42 --project tom_d4rt',
    'issuekit :assign 42 --project tom_d4rt --module parser',
  ],
);

const testingCommand = CommandDefinition(
  name: 'testing',
  description: 'Mark that a reproduction test has been created',
  options: [],
  worksWithNatures: {DartProjectFolder},
  supportsProjectTraversal: true,
  examples: ['issuekit :testing 42'],
);

const verifyCommand = CommandDefinition(
  name: 'verify',
  description: 'Check if linked tests pass — move to VERIFYING if all pass',
  options: [],
  worksWithNatures: {DartProjectFolder},
  supportsProjectTraversal: true,
  examples: ['issuekit :verify 42'],
);

const resolveCommand = CommandDefinition(
  name: 'resolve',
  description: 'Confirm the original issue is fixed after verification',
  options: resolveOptions,
  requiresTraversal: false,
  supportsProjectTraversal: false,
  examples: ['issuekit :resolve 42 --fix "Added null check in parser"'],
);

const closeCommand = CommandDefinition(
  name: 'close',
  description: 'Close and archive a resolved issue',
  options: [],
  requiresTraversal: false,
  supportsProjectTraversal: false,
  examples: ['issuekit :close 42'],
);

const reopenCommand = CommandDefinition(
  name: 'reopen',
  description: 'Reopen a closed or resolved issue',
  options: reopenOptions,
  requiresTraversal: false,
  supportsProjectTraversal: false,
  examples: ['issuekit :reopen 42 --note "Regression detected"'],
);

// Discovery and Querying Commands
const listCommand = CommandDefinition(
  name: 'list',
  description: 'List issues with filtering and sorting',
  options: listOptions,
  requiresTraversal: false,
  supportsProjectTraversal: false,
  examples: [
    'issuekit :list --state new',
    'issuekit :list --project tom_d4rt --severity high',
    'issuekit :list --reporter copilot',
  ],
);

const showCommand = CommandDefinition(
  name: 'show',
  description: 'Show full details of one issue',
  options: [],
  worksWithNatures: {DartProjectFolder},
  supportsProjectTraversal: true,
  examples: ['issuekit :show 42'],
);

const searchCommand = CommandDefinition(
  name: 'search',
  description: 'Full-text search across all issues',
  options: searchOptions,
  requiresTraversal: false,
  supportsProjectTraversal: false,
  examples: [
    'issuekit :search "RangeError"',
    'issuekit :search "parser" --repo tests',
  ],
);

const scanCommand = CommandDefinition(
  name: 'scan',
  description: 'Scan workspace for tests linked to issues via ID convention',
  options: scanOptions,
  worksWithNatures: {DartProjectFolder},
  supportsProjectTraversal: true,
  examples: [
    'issuekit :scan 42',
    'issuekit :scan --missing-tests',
    'issuekit :scan --project tom_d4rt',
  ],
);

const summaryCommand = CommandDefinition(
  name: 'summary',
  description: 'Dashboard: counts by state, severity, project',
  options: outputOptions,
  requiresTraversal: false,
  supportsProjectTraversal: false,
  examples: ['issuekit :summary', 'issuekit :summary --output=md:summary.md'],
);

// Test Management Commands
const promoteCommand = CommandDefinition(
  name: 'promote',
  description: 'Promote a regular test to issue-linked (insert issue number)',
  options: promoteOptions,
  worksWithNatures: {DartProjectFolder},
  supportsProjectTraversal: true,
  examples: [
    'issuekit :promote D4-PAR-15 --issue 42',
    'issuekit :promote D4-PAR-15 --issue 42 --dry-run',
  ],
);

const validateCommand = CommandDefinition(
  name: 'validate',
  description: 'Check test ID uniqueness across the workspace',
  options: validateOptions,
  worksWithNatures: {DartProjectFolder},
  supportsProjectTraversal: true,
  examples: ['issuekit :validate', 'issuekit :validate --project tom_d4rt'],
);

const linkCommand = CommandDefinition(
  name: 'link',
  description: 'Explicitly link a test to an issue (override for non-standard)',
  options: linkOptions,
  requiresTraversal: false,
  supportsProjectTraversal: false,
  examples: ['issuekit :link 42 --test-id "legacy_parser_test"'],
);

// Workflow Integration Commands
const syncCommand = CommandDefinition(
  name: 'sync',
  description: 'Sync issue states with test results — detect fixes/regressions',
  options: syncOptions,
  worksWithNatures: {DartProjectFolder},
  supportsProjectTraversal: true,
  examples: [
    'issuekit :sync --dry-run',
    'issuekit :sync --auto',
    'issuekit :sync --project tom_d4rt',
  ],
);

const aggregateCommand = CommandDefinition(
  name: 'aggregate',
  description: 'Aggregate testkit baselines into tom_tests consolidated view',
  options: aggregateOptions,
  worksWithNatures: {DartProjectFolder},
  supportsProjectTraversal: true,
  examples: [
    'issuekit :aggregate',
    'issuekit :aggregate --output=json:report.json',
  ],
);

const exportCommand = CommandDefinition(
  name: 'export',
  description: 'Export issues as CSV, JSON, or Markdown',
  options: exportOptions,
  requiresTraversal: false,
  supportsProjectTraversal: false,
  examples: [
    'issuekit :export --output=csv:issues.csv',
    'issuekit :export --state testing --output=json:testing.json',
  ],
);

const importCommand = CommandDefinition(
  name: 'import',
  description: 'Import issues from a file',
  options: importOptions,
  requiresTraversal: false,
  supportsProjectTraversal: false,
  examples: [
    'issuekit :import issues.json',
    'issuekit :import backup.csv --dry-run',
  ],
);

const initCommand = CommandDefinition(
  name: 'init',
  description: 'Initialize repos for issue tracking (set up labels, templates)',
  options: initOptions,
  requiresTraversal: false,
  supportsProjectTraversal: false,
  examples: [
    'issuekit :init',
    'issuekit :init --repo issues',
    'issuekit :init --force',
  ],
);

const snapshotCommand = CommandDefinition(
  name: 'snapshot',
  description: 'Export issues to timestamped JSON files for backup',
  options: snapshotOptions,
  requiresTraversal: false,
  supportsProjectTraversal: false,
  examples: ['issuekit :snapshot', 'issuekit :snapshot --issues-only'],
);

const runTestsCommand = CommandDefinition(
  name: 'run-tests',
  description: 'Trigger nightly test workflow in tom_tests via GitHub API',
  options: runTestsOptions,
  requiresTraversal: false,
  supportsProjectTraversal: false,
  examples: ['issuekit :run-tests', 'issuekit :run-tests --wait'],
);

// =============================================================================
// Tool Definition
// =============================================================================

/// Issuekit tool definition.
final issuekitTool = ToolDefinition(
  name: 'issuekit',
  description: 'Issue tracking CLI for the Tom Framework',
  version: IssueKitVersionInfo.version,
  mode: ToolMode.multiCommand,
  helpTopics: defaultHelpTopics,
  features: const NavigationFeatures(
    projectTraversal: true,
    gitTraversal: false,
    recursiveScan: true,
    interactiveMode: false,
    dryRun: false,
    jsonOutput: false,
    verbose: true,
  ),
  globalOptions: const [],
  commands: const [
    // Issue Management
    newCommand,
    editCommand,
    analyzeCommand,
    assignCommand,
    testingCommand,
    verifyCommand,
    resolveCommand,
    closeCommand,
    reopenCommand,
    // Discovery and Querying
    listCommand,
    showCommand,
    searchCommand,
    scanCommand,
    summaryCommand,
    // Test Management
    promoteCommand,
    validateCommand,
    linkCommand,
    // Workflow Integration
    syncCommand,
    aggregateCommand,
    exportCommand,
    importCommand,
    initCommand,
    snapshotCommand,
    runTestsCommand,
  ],
  helpFooter: '''
Configuration:
  tom_workspace.yaml (workspace level) — issues_repo, tests_repo
  tom_project.yaml (project level) — project_id

Repositories:
  tom_issues — Public issue intake (@issues)
  tom_tests — Test entries (@tests), baselines, snapshots

Documentation:
  issue_tracking.md — Concept and workflow
  issuekit_command_reference.md — Full command reference
''',
);
