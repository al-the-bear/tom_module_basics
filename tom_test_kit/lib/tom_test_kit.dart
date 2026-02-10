/// Tom Test Kit — test result tracking for Dart projects.
///
/// Run `test_kit help` or `--help` for full usage information.
library;

export 'src/model/test_entry.dart';
export 'src/model/test_run.dart';
export 'src/model/tracking_file.dart';
export 'src/parser/dart_test_parser.dart';
export 'src/parser/test_description_parser.dart';
export 'src/tracking/baseline_command.dart';
export 'src/tracking/test_command.dart';
export 'src/util/file_helpers.dart';
export 'src/util/format_helpers.dart';
export 'src/util/markdown_table.dart';

// TUI framework
export 'src/tui/tui_command.dart';
export 'src/tui/tui_command_registry.dart';
export 'src/tui/tui_module.dart';
export 'src/tui/tui_output_parser.dart';
export 'src/tui/external_tool_adapter.dart';
export 'src/tui/commands/baseline_tui_command.dart';
export 'src/tui/commands/test_tui_command.dart';
export 'src/tui/app/test_kit_tui_app.dart';
export 'src/tui/app/tui_output_panel.dart';
export 'src/tui/app/tui_menu_panel.dart';
