/// Tom Build Kit - Pipeline-based build orchestration.
///
/// This library provides the configuration and execution infrastructure
/// for build pipelines that integrate Tom build tools.
library;

// Version info
export 'src/version.g.dart';

// Pipeline infrastructure
export 'src/pipeline_config.dart';
export 'src/pipeline_executor.dart';
export 'src/pipeline_step.dart';
export 'src/builtin_commands.dart';
export 'src/pubget_command.dart';
export 'src/pubupdate_command.dart';

// Integrated tool commands
export 'src/commands/tool_base.dart';
export 'src/commands/cleanup_tool.dart';
export 'src/commands/versioner_tool.dart';
export 'src/commands/bumpversion_tool.dart';
export 'src/commands/compiler_tool.dart';
export 'src/commands/runner_tool.dart';
export 'src/commands/dependencies_tool.dart';
export 'src/commands/buildsorter_tool.dart';
export 'src/commands/publisher_tool.dart';
export 'src/commands/git_tool.dart';
export 'src/commands/gitstatus_tool.dart';
export 'src/commands/gitcommit_tool.dart';
export 'src/commands/gitpull_tool.dart';
export 'src/commands/gitbranch_tool.dart';
export 'src/commands/gittag_tool.dart';
export 'src/commands/gitclean_tool.dart';
export 'src/commands/gitcheckout_tool.dart';
export 'src/commands/gitreset_tool.dart';
export 'src/commands/gitsync_tool.dart';
export 'src/commands/gitprune_tool.dart';
export 'src/commands/gitstash_tool.dart';
export 'src/commands/gitunstash_tool.dart';
export 'src/commands/gitcompare_tool.dart';
export 'src/commands/gitmerge_tool.dart';
export 'src/commands/gitsquash_tool.dart';
export 'src/commands/gitrebase_tool.dart';
export 'src/compiler_config.dart';

// Utilities
export 'src/platform_utils.dart';
