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

// Integrated tool commands
export 'src/commands/tool_base.dart';
export 'src/commands/cleanup_tool.dart';
export 'src/commands/versioner_tool.dart';
export 'src/commands/versionbump_tool.dart';
export 'src/commands/compiler_tool.dart';
export 'src/commands/runner_tool.dart';
export 'src/commands/dependencies_tool.dart';
export 'src/compiler_config.dart';

// Utilities
export 'src/platform_utils.dart';
