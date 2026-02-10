/// TUI module interface for Tom Test Kit.
///
/// Modules take direct control of a TUI display region, unlike
/// simple commands that stream events. Use modules when you need
/// interactive sub-UIs (e.g. coverage viewer, test selector).
library;

import 'package:utopia_tui/utopia_tui.dart';

import 'tui_command_registry.dart';

/// Context provided to active TUI modules.
class TuiModuleContext {
  /// The resolved project path.
  final String projectPath;

  /// Request a TUI redraw (e.g. after async data arrives).
  final void Function() requestRedraw;

  /// Access the command registry to run other commands.
  final TuiCommandRegistry registry;

  TuiModuleContext({
    required this.projectPath,
    required this.requestRedraw,
    required this.registry,
  });
}

/// A module that takes direct control of a TUI region.
///
/// Unlike simple commands that stream events through [TuiCommandSink],
/// TUI modules build their own components and handle their own events.
abstract class TuiModule {
  /// Unique module identifier.
  String get id;

  /// Display name shown in the menu.
  String get label;

  /// Short description.
  String get description;

  /// Called when the module is activated (user selects it from menu).
  void activate(TuiModuleContext context);

  /// Called on each build cycle while the module is active.
  ///
  /// [surface] and [rect] define the available rendering area.
  void build(TuiSurface surface, TuiRect rect);

  /// Handle events while the module is active.
  ///
  /// Return true if the event was consumed.
  bool onEvent(TuiEvent event);

  /// Called when the module is deactivated (user navigates away).
  void deactivate();
}
