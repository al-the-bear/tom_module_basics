/// Buildkit v2 — Build orchestration tool using tom_build_base v2.
///
/// This file defines the buildkit tool using the v2 CLI framework.
library;

import 'package:tom_build_base/tom_build_base_v2.dart';

import '../version.g.dart';

// =============================================================================
// Common Options
// =============================================================================

/// Options for versioner command.
const versionerOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'output',
    abbr: 'O',
    description: 'Output file path relative to project',
    defaultValue: 'lib/src/version.g.dart',
    valueName: 'path',
  ),
  OptionDefinition.flag(
    name: 'no-git',
    description: 'Skip git commit hash in version file',
  ),
  OptionDefinition.option(
    name: 'version',
    description: 'Override version string (instead of pubspec.yaml)',
    valueName: 'version',
  ),
  OptionDefinition.option(
    name: 'variable-prefix',
    description: 'Prefix for generated class name (e.g., "myApp" → MyAppVersionInfo)',
    valueName: 'name',
  ),
];

/// Options for bumpversion command.
const bumpversionOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'type',
    description: 'Version bump type: major, minor, patch, build (default: build)',
    valueName: 'type',
  ),
  OptionDefinition.option(
    name: 'set',
    description: 'Set version to specific value',
    valueName: 'version',
  ),
  OptionDefinition.flag(
    name: 'cascade',
    description: 'Bump dependents when bumping a dependency',
  ),
];

/// Options for compiler command.
const compilerOptions = <OptionDefinition>[
  OptionDefinition.multi(
    name: 'target',
    abbr: 't',
    description: 'Target platform(s) for cross-compilation',
    valueName: 'platform',
  ),
  OptionDefinition.flag(
    name: 'skip-precompile',
    description: 'Skip precompile steps',
  ),
  OptionDefinition.flag(
    name: 'skip-postcompile',
    description: 'Skip postcompile steps',
  ),
];

/// Options for runner command.
const runnerOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'builder',
    description: 'Run only specific builder(s)',
    valueName: 'name',
  ),
  OptionDefinition.flag(
    name: 'delete-conflicting-outputs',
    description: 'Delete conflicting outputs without prompting',
  ),
];

/// Options for cleanup command.
const cleanupOptions = <OptionDefinition>[
  OptionDefinition.flag(
    name: 'full',
    description: 'Full cleanup (includes .dart_tool, pubspec.lock)',
  ),
  OptionDefinition.flag(
    name: 'generated',
    description: 'Clean only generated files (*.g.dart, *.freezed.dart)',
  ),
];

/// Options for dependencies command.
const dependenciesOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'depth',
    description: 'Maximum dependency tree depth',
    valueName: 'n',
  ),
  OptionDefinition.flag(
    name: 'flat',
    description: 'Show flat list instead of tree',
  ),
];

/// Options for publisher command.
const publisherOptions = <OptionDefinition>[
  OptionDefinition.flag(
    name: 'check',
    description: 'Check publishability without publishing',
  ),
  OptionDefinition.flag(
    name: 'force',
    abbr: 'f',
    description: 'Force publish even with warnings',
  ),
];

/// Options for pubget/pubupdate commands.
const pubOptions = <OptionDefinition>[
  OptionDefinition.flag(
    name: 'offline',
    description: 'Use cached packages',
  ),
];

// =============================================================================
// Git Command Options
// =============================================================================

/// Options for gitstatus command.
const gitstatusOptions = <OptionDefinition>[
  OptionDefinition.flag(
    name: 'short',
    description: 'Show short status format',
  ),
  OptionDefinition.flag(
    name: 'porcelain',
    description: 'Machine-readable output',
  ),
];

/// Options for gitcommit command.
const gitcommitOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'message',
    abbr: 'm',
    description: 'Commit message',
    valueName: 'msg',
  ),
  OptionDefinition.flag(
    name: 'amend',
    description: 'Amend last commit',
  ),
  OptionDefinition.flag(
    name: 'push',
    description: 'Push after commit',
  ),
  OptionDefinition.flag(
    name: 'all',
    abbr: 'a',
    description: 'Stage all modified files',
  ),
];

/// Options for gitpull command.
const gitpullOptions = <OptionDefinition>[
  OptionDefinition.flag(
    name: 'rebase',
    description: 'Rebase instead of merge',
  ),
  OptionDefinition.flag(
    name: 'ff-only',
    description: 'Fast-forward only',
  ),
];

/// Options for gitbranch command.
const gitbranchOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'create',
    abbr: 'c',
    description: 'Create new branch',
    valueName: 'name',
  ),
  OptionDefinition.option(
    name: 'delete',
    abbr: 'd',
    description: 'Delete branch',
    valueName: 'name',
  ),
  OptionDefinition.flag(
    name: 'all',
    abbr: 'a',
    description: 'Show all branches (including remotes)',
  ),
];

/// Options for gittag command.
const gittagOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'create',
    abbr: 'c',
    description: 'Create new tag',
    valueName: 'name',
  ),
  OptionDefinition.option(
    name: 'message',
    abbr: 'm',
    description: 'Tag message (creates annotated tag)',
    valueName: 'msg',
  ),
  OptionDefinition.option(
    name: 'delete',
    abbr: 'd',
    description: 'Delete tag',
    valueName: 'name',
  ),
  OptionDefinition.flag(
    name: 'push',
    description: 'Push tags after creating',
  ),
];

/// Options for gitcheckout command.
const gitcheckoutOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'branch',
    abbr: 'b',
    description: 'Branch to checkout',
    valueName: 'name',
  ),
  OptionDefinition.flag(
    name: 'create',
    abbr: 'c',
    description: 'Create branch if it doesn\'t exist',
  ),
];

/// Options for gitreset command.
const gitresetOptions = <OptionDefinition>[
  OptionDefinition.flag(
    name: 'hard',
    description: 'Hard reset (discard changes)',
  ),
  OptionDefinition.flag(
    name: 'soft',
    description: 'Soft reset (keep changes staged)',
  ),
  OptionDefinition.option(
    name: 'to',
    description: 'Reset to specific commit/ref',
    valueName: 'ref',
  ),
];

/// Options for gitclean command.
const gitcleanOptions = <OptionDefinition>[
  OptionDefinition.flag(
    name: 'directories',
    abbr: 'd',
    description: 'Remove untracked directories too',
  ),
  OptionDefinition.flag(
    name: 'force',
    abbr: 'f',
    description: 'Force removal',
  ),
];

/// Options for gitsync command.
const gitsyncOptions = <OptionDefinition>[
  OptionDefinition.flag(
    name: 'rebase',
    description: 'Rebase instead of merge when pulling',
  ),
];

/// Options for gitprune command.
const gitpruneOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'remote',
    description: 'Remote to prune (default: origin)',
    valueName: 'name',
  ),
];

/// Options for gitstash command.
const gitstashOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'message',
    abbr: 'm',
    description: 'Stash message',
    valueName: 'msg',
  ),
  OptionDefinition.flag(
    name: 'include-untracked',
    abbr: 'u',
    description: 'Include untracked files',
  ),
];

/// Options for gitunstash command.
const gitunstashOptions = <OptionDefinition>[
  OptionDefinition.flag(
    name: 'pop',
    description: 'Pop stash (remove after applying)',
  ),
  OptionDefinition.option(
    name: 'index',
    description: 'Stash index to restore',
    valueName: 'n',
  ),
];

/// Options for gitcompare command.
const gitcompareOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'base',
    description: 'Base branch/ref to compare against',
    valueName: 'ref',
  ),
  OptionDefinition.flag(
    name: 'stat',
    description: 'Show diffstat only',
  ),
];

/// Options for gitmerge command.
const gitmergeOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'branch',
    abbr: 'b',
    description: 'Branch to merge from',
    valueName: 'name',
  ),
  OptionDefinition.flag(
    name: 'no-ff',
    description: 'Create merge commit even for fast-forward',
  ),
  OptionDefinition.flag(
    name: 'squash',
    description: 'Squash commits before merging',
  ),
];

/// Options for gitsquash command.
const gitsquashOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'count',
    abbr: 'n',
    description: 'Number of commits to squash',
    valueName: 'n',
  ),
  OptionDefinition.option(
    name: 'message',
    abbr: 'm',
    description: 'Squash commit message',
    valueName: 'msg',
  ),
];

/// Options for gitrebase command.
const gitrebaseOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'onto',
    description: 'Rebase onto branch',
    valueName: 'branch',
  ),
  OptionDefinition.flag(
    name: 'interactive',
    abbr: 'i',
    description: 'Interactive rebase',
  ),
  OptionDefinition.flag(
    name: 'continue',
    description: 'Continue rebase after resolving conflicts',
  ),
  OptionDefinition.flag(
    name: 'abort',
    description: 'Abort rebase',
  ),
];

/// Options for git passthrough command.
const gitOptions = <OptionDefinition>[
  // Git passthrough takes all arguments after --
];

// =============================================================================
// Other Command Options
// =============================================================================

/// Options for buildsorter command.
const buildsorterOptions = <OptionDefinition>[
  OptionDefinition.flag(
    name: 'show',
    description: 'Show sorted order without executing',
  ),
];

/// Options for dcli command.
const dcliOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'init-source',
    description: 'Custom init source file',
    valueName: 'file',
  ),
  OptionDefinition.flag(
    name: 'no-init-source',
    description: 'Skip loading init source',
  ),
];

/// Options for define command.
const defineOptions = <OptionDefinition>[];

/// Options for undefine command.
const undefineOptions = <OptionDefinition>[];

/// Options for defines listing command.
const definesOptions = <OptionDefinition>[];

// =============================================================================
// Command Definitions - Build Tools
// =============================================================================

const versionerCommand = CommandDefinition(
  name: 'versioner',
  description: 'Generate version.g.dart files with build metadata',
  aliases: ['v', 'ver'],
  options: versionerOptions,
  supportsProjectTraversal: true,
  supportsGitTraversal: false,
  requiresTraversal: true,
  canRunStandalone: true,
  examples: [
    'buildkit :versioner',
    'buildkit :versioner --output lib/src/version.g.dart',
    'buildkit :versioner --variable-prefix myApp',
  ],
);

const bumpversionCommand = CommandDefinition(
  name: 'bumpversion',
  description: 'Bump pubspec.yaml versions across projects',
  aliases: ['bump'],
  options: bumpversionOptions,
  supportsProjectTraversal: true,
  supportsGitTraversal: false,
  requiresTraversal: false,
  canRunStandalone: true,
  examples: [
    'buildkit :bumpversion --type=minor',
    'bumpversion --set=2.0.0',
  ],
);

const compilerCommand = CommandDefinition(
  name: 'compiler',
  description: 'Cross-platform Dart compilation',
  aliases: ['c', 'comp'],
  options: compilerOptions,
  supportsProjectTraversal: true,
  supportsGitTraversal: false,
  requiresTraversal: false,
  canRunStandalone: true,
  examples: [
    'buildkit :compiler',
    'compiler --target=linux-x64',
  ],
);

const runnerCommand = CommandDefinition(
  name: 'runner',
  description: 'Build_runner wrapper with builder filtering',
  aliases: ['run'],
  options: runnerOptions,
  supportsProjectTraversal: true,
  supportsGitTraversal: false,
  requiresTraversal: false,
  canRunStandalone: true,
  examples: [
    'buildkit :runner',
    'runner --builder=freezed',
  ],
);

const cleanupCommand = CommandDefinition(
  name: 'cleanup',
  description: 'Clean generated and temporary files',
  aliases: ['clean', 'cl'],
  options: cleanupOptions,
  supportsProjectTraversal: true,
  supportsGitTraversal: false,
  requiresTraversal: false,
  canRunStandalone: true,
  examples: [
    'buildkit :cleanup',
    'cleanup --full',
  ],
);

const dependenciesCommand = CommandDefinition(
  name: 'dependencies',
  description: 'Dependency tree visualization',
  aliases: ['deps'],
  options: dependenciesOptions,
  supportsProjectTraversal: true,
  supportsGitTraversal: false,
  requiresTraversal: false,
  canRunStandalone: true,
  examples: [
    'buildkit :dependencies',
    'dependencies --depth=2',
  ],
);

const publisherCommand = CommandDefinition(
  name: 'publisher',
  description: 'Show publishing status for all projects',
  aliases: ['pub'],
  options: publisherOptions,
  supportsProjectTraversal: true,
  supportsGitTraversal: false,
  requiresTraversal: false,
  canRunStandalone: true,
  examples: [
    'buildkit :publisher',
    'publisher --check',
  ],
);

const pubgetCommand = CommandDefinition(
  name: 'pubget',
  description: 'Run dart pub get on projects',
  aliases: ['pg'],
  options: pubOptions,
  supportsProjectTraversal: true,
  supportsGitTraversal: false,
  requiresTraversal: false,
  examples: [
    'buildkit :pubget',
  ],
);

const pubgetallCommand = CommandDefinition(
  name: 'pubgetall',
  description: 'Shortcut for :pubget --scan . --recursive',
  aliases: ['pga'],
  options: pubOptions,
  requiresTraversal: false,
  supportsProjectTraversal: false,
  examples: [
    'buildkit :pubgetall',
  ],
);

const pubupdateCommand = CommandDefinition(
  name: 'pubupdate',
  description: 'Run dart pub upgrade on projects',
  aliases: ['pu'],
  options: pubOptions,
  supportsProjectTraversal: true,
  supportsGitTraversal: false,
  requiresTraversal: false,
  examples: [
    'buildkit :pubupdate',
  ],
);

const pubupdateallCommand = CommandDefinition(
  name: 'pubupdateall',
  description: 'Shortcut for :pubupdate --scan . --recursive',
  aliases: ['pua'],
  options: pubOptions,
  requiresTraversal: false,
  supportsProjectTraversal: false,
  examples: [
    'buildkit :pubupdateall',
  ],
);

const buildsorterCommand = CommandDefinition(
  name: 'buildsorter',
  description: 'Show projects in dependency build order',
  aliases: ['sort'],
  options: buildsorterOptions,
  supportsProjectTraversal: true,
  supportsGitTraversal: false,
  requiresTraversal: false,
  canRunStandalone: true,
  examples: [
    'buildkit :buildsorter',
  ],
);

// =============================================================================
// Command Definitions - Git Tools
// =============================================================================

const gitCommand = CommandDefinition(
  name: 'git',
  description: 'Run git commands in each repository',
  aliases: [],
  options: gitOptions,
  supportsProjectTraversal: false,
  supportsGitTraversal: true,
  defaultGitOrder: null, // User must specify -i or -o
  requiresTraversal: false,
  canRunStandalone: true,
  examples: [
    'buildkit :git -i -- log --oneline -5',
    'buildkit :git -o -- stash list',
  ],
);

const gitstatusCommand = CommandDefinition(
  name: 'gitstatus',
  description: 'Show git status for all repositories',
  aliases: ['gs'],
  options: gitstatusOptions,
  supportsProjectTraversal: false,
  supportsGitTraversal: true,
  defaultGitOrder: GitTraversalOrder.innerFirst,
  requiresTraversal: false,
  canRunStandalone: true,
  examples: [
    'buildkit :gitstatus',
    'gitstatus --short',
  ],
);

const gitcommitCommand = CommandDefinition(
  name: 'gitcommit',
  description: 'Commit and push all repositories',
  aliases: ['gc'],
  options: gitcommitOptions,
  supportsProjectTraversal: false,
  supportsGitTraversal: true,
  defaultGitOrder: GitTraversalOrder.innerFirst, // Fixed: inner first
  requiresTraversal: false,
  canRunStandalone: true,
  examples: [
    'buildkit :gitcommit -m "feat: add feature"',
    'gitcommit --amend',
  ],
);

const gitpullCommand = CommandDefinition(
  name: 'gitpull',
  description: 'Pull latest from all repositories',
  aliases: ['gpl'],
  options: gitpullOptions,
  supportsProjectTraversal: false,
  supportsGitTraversal: true,
  defaultGitOrder: GitTraversalOrder.outerFirst, // Fixed: outer first
  requiresTraversal: false,
  canRunStandalone: true,
  examples: [
    'buildkit :gitpull',
    'gitpull --rebase',
  ],
);

const gitbranchCommand = CommandDefinition(
  name: 'gitbranch',
  description: 'Branch management across repositories',
  aliases: ['gb'],
  options: gitbranchOptions,
  supportsProjectTraversal: false,
  supportsGitTraversal: true,
  defaultGitOrder: GitTraversalOrder.innerFirst, // Fixed: inner first
  requiresTraversal: false,
  canRunStandalone: true,
  examples: [
    'buildkit :gitbranch',
    'gitbranch --create feature-x',
  ],
);

const gittagCommand = CommandDefinition(
  name: 'gittag',
  description: 'Tag management across repositories',
  aliases: ['gt'],
  options: gittagOptions,
  supportsProjectTraversal: false,
  supportsGitTraversal: true,
  defaultGitOrder: GitTraversalOrder.innerFirst, // Fixed: inner first
  requiresTraversal: false,
  canRunStandalone: true,
  examples: [
    'buildkit :gittag',
    'gittag --create v1.0.0 --push',
  ],
);

const gitcheckoutCommand = CommandDefinition(
  name: 'gitcheckout',
  description: 'Checkout branches/tags across repositories',
  aliases: ['gco'],
  options: gitcheckoutOptions,
  supportsProjectTraversal: false,
  supportsGitTraversal: true,
  defaultGitOrder: GitTraversalOrder.outerFirst, // Fixed: outer first
  requiresTraversal: false,
  canRunStandalone: true,
  examples: [
    'buildkit :gitcheckout --branch=main',
  ],
);

const gitresetCommand = CommandDefinition(
  name: 'gitreset',
  description: 'Reset repositories to specific state',
  aliases: ['grst'],
  options: gitresetOptions,
  supportsProjectTraversal: false,
  supportsGitTraversal: true,
  defaultGitOrder: GitTraversalOrder.outerFirst, // Fixed: outer first
  requiresTraversal: false,
  canRunStandalone: true,
  examples: [
    'buildkit :gitreset --hard',
  ],
);

const gitcleanCommand = CommandDefinition(
  name: 'gitclean',
  description: 'Clean untracked files from repositories',
  aliases: ['gcl'],
  options: gitcleanOptions,
  supportsProjectTraversal: false,
  supportsGitTraversal: true,
  defaultGitOrder: GitTraversalOrder.innerFirst, // Fixed: inner first
  requiresTraversal: false,
  canRunStandalone: true,
  examples: [
    'buildkit :gitclean -df',
  ],
);

const gitsyncCommand = CommandDefinition(
  name: 'gitsync',
  description: 'Sync (fetch + merge/rebase) all repositories',
  aliases: ['gsync'],
  options: gitsyncOptions,
  supportsProjectTraversal: false,
  supportsGitTraversal: true,
  defaultGitOrder: GitTraversalOrder.outerFirst, // Fixed: outer first
  requiresTraversal: false,
  canRunStandalone: true,
  examples: [
    'buildkit :gitsync',
  ],
);

const gitpruneCommand = CommandDefinition(
  name: 'gitprune',
  description: 'Remove stale remote-tracking branches',
  aliases: ['gpr'],
  options: gitpruneOptions,
  supportsProjectTraversal: false,
  supportsGitTraversal: true,
  defaultGitOrder: GitTraversalOrder.outerFirst, // Fixed: outer first
  requiresTraversal: false,
  canRunStandalone: true,
  examples: [
    'buildkit :gitprune',
  ],
);

const gitstashCommand = CommandDefinition(
  name: 'gitstash',
  description: 'Stash uncommitted changes across repositories',
  aliases: ['gst'],
  options: gitstashOptions,
  supportsProjectTraversal: false,
  supportsGitTraversal: true,
  defaultGitOrder: GitTraversalOrder.innerFirst, // Fixed: inner first
  requiresTraversal: false,
  canRunStandalone: true,
  examples: [
    'buildkit :gitstash -m "wip"',
  ],
);

const gitunstashCommand = CommandDefinition(
  name: 'gitunstash',
  description: 'Restore stashed changes across repositories',
  aliases: ['gust'],
  options: gitunstashOptions,
  supportsProjectTraversal: false,
  supportsGitTraversal: true,
  defaultGitOrder: GitTraversalOrder.outerFirst, // Fixed: outer first (reverse)
  requiresTraversal: false,
  canRunStandalone: true,
  examples: [
    'buildkit :gitunstash --pop',
  ],
);

const gitcompareCommand = CommandDefinition(
  name: 'gitcompare',
  description: 'Compare branches across repositories',
  aliases: ['gcmp'],
  options: gitcompareOptions,
  supportsProjectTraversal: false,
  supportsGitTraversal: true,
  defaultGitOrder: GitTraversalOrder.innerFirst, // Fixed: inner first
  requiresTraversal: false,
  canRunStandalone: true,
  examples: [
    'buildkit :gitcompare --base=main',
  ],
);

const gitmergeCommand = CommandDefinition(
  name: 'gitmerge',
  description: 'Merge branches across repositories',
  aliases: ['gm'],
  options: gitmergeOptions,
  supportsProjectTraversal: false,
  supportsGitTraversal: true,
  defaultGitOrder: GitTraversalOrder.innerFirst, // Fixed: inner first
  requiresTraversal: false,
  canRunStandalone: true,
  examples: [
    'buildkit :gitmerge --branch=feature-x',
  ],
);

const gitsquashCommand = CommandDefinition(
  name: 'gitsquash',
  description: 'Squash commits across repositories',
  aliases: ['gsq'],
  options: gitsquashOptions,
  supportsProjectTraversal: false,
  supportsGitTraversal: true,
  defaultGitOrder: GitTraversalOrder.innerFirst, // Fixed: inner first
  requiresTraversal: false,
  canRunStandalone: true,
  examples: [
    'buildkit :gitsquash -n 3 -m "combined commit"',
  ],
);

const gitrebaseCommand = CommandDefinition(
  name: 'gitrebase',
  description: 'Rebase across repositories',
  aliases: ['grb'],
  options: gitrebaseOptions,
  supportsProjectTraversal: false,
  supportsGitTraversal: true,
  defaultGitOrder: GitTraversalOrder.innerFirst, // Fixed: inner first
  requiresTraversal: false,
  canRunStandalone: true,
  examples: [
    'buildkit :gitrebase --onto=main',
  ],
);

// =============================================================================
// Command Definitions - Other
// =============================================================================

const dcliCommand = CommandDefinition(
  name: 'dcli',
  description: 'Execute Dart scripts via dcli',
  aliases: [],
  options: dcliOptions,
  supportsProjectTraversal: true,
  supportsGitTraversal: false,
  requiresTraversal: false,
  examples: [
    'buildkit :dcli ~s/build_hook.dart',
    'buildkit :dcli "print(DateTime.now())"',
  ],
);

const defineCommand = CommandDefinition(
  name: 'define',
  description: 'Define a reusable macro',
  aliases: [],
  options: defineOptions,
  requiresTraversal: false,
  supportsProjectTraversal: false,
  examples: [
    'buildkit define cv=:versioner :compiler',
  ],
);

const undefineCommand = CommandDefinition(
  name: 'undefine',
  description: 'Remove a macro',
  aliases: [],
  options: undefineOptions,
  requiresTraversal: false,
  supportsProjectTraversal: false,
  examples: [
    'buildkit undefine cv',
  ],
);

const definesCommand = CommandDefinition(
  name: 'defines',
  description: 'List all defined macros',
  aliases: [],
  options: definesOptions,
  requiresTraversal: false,
  supportsProjectTraversal: false,
  examples: [
    'buildkit defines',
  ],
);

// =============================================================================
// Tool Definition
// =============================================================================

/// Buildkit tool definition.
final buildkitTool = ToolDefinition(
  name: 'buildkit',
  description: 'Pipeline-based build orchestration tool',
  version: BuildkitVersionInfo.version,
  mode: ToolMode.multiCommand,
  features: const NavigationFeatures(
    projectTraversal: true,
    gitTraversal: true,
    recursiveScan: true,
    interactiveMode: false,
    dryRun: true,
    jsonOutput: false,
    verbose: true,
  ),
  globalOptions: const [
    OptionDefinition.flag(
      name: 'list',
      abbr: 'l',
      description: 'List available pipelines and commands',
    ),
    OptionDefinition.flag(
      name: 'workspace-recursion',
      abbr: 'w',
      description: 'Shell out to sub-workspaces instead of skipping',
    ),
  ],
  commands: [
    // Build tools
    versionerCommand,
    bumpversionCommand,
    compilerCommand,
    runnerCommand,
    cleanupCommand,
    dependenciesCommand,
    publisherCommand,
    buildsorterCommand,
    // Pub commands
    pubgetCommand,
    pubgetallCommand,
    pubupdateCommand,
    pubupdateallCommand,
    // Git tools
    gitCommand,
    gitstatusCommand,
    gitcommitCommand,
    gitpullCommand,
    gitbranchCommand,
    gittagCommand,
    gitcheckoutCommand,
    gitresetCommand,
    gitcleanCommand,
    gitsyncCommand,
    gitpruneCommand,
    gitstashCommand,
    gitunstashCommand,
    gitcompareCommand,
    gitmergeCommand,
    gitsquashCommand,
    gitrebaseCommand,
    // Other
    dcliCommand,
    defineCommand,
    undefineCommand,
    definesCommand,
  ],
  helpFooter: '''
Execution Modes:
  Project Mode (default): Runs from current directory with -s . -r -b defaults
  Workspace Mode:         Runs from workspace root (triggered by -R, -s <path>, -i, -o)

Pipeline Execution:
  Pipelines are defined in buildkit_master.yaml or buildkit.yaml under buildkit.pipelines.
  Run a pipeline by name: buildkit <pipeline-name>

Macros:
  define <name>=<commands>  Define a reusable macro
  undefine <name>           Remove a macro
  defines                   List all defined macros
  @name [args]              Expand macro

Configuration:
  buildkit_master.yaml — Workspace-level configuration
  buildkit.yaml        — Project-level configuration
''',
);
