/// TUI command registry for Tom Test Kit.
///
/// Manages registration and lookup of TUI commands and modules.
library;

import 'tui_command.dart';
import 'tui_module.dart';

/// Entry in the command registry — either a command or a module.
sealed class TuiRegistryEntry {
  String get id;
  String get label;
  String get description;
}

/// A registered command entry.
class TuiCommandEntry extends TuiRegistryEntry {
  final TuiCommand command;

  TuiCommandEntry(this.command);

  @override
  String get id => command.id;
  @override
  String get label => command.label;
  @override
  String get description => command.description;
}

/// A registered module entry.
class TuiModuleEntry extends TuiRegistryEntry {
  final TuiModule module;

  TuiModuleEntry(this.module);

  @override
  String get id => module.id;
  @override
  String get label => module.label;
  @override
  String get description => module.description;
}

/// Registry of TUI commands and modules.
///
/// Commands are simple execute-and-report workflows.
/// Modules take direct control of a TUI region.
class TuiCommandRegistry {
  final List<TuiRegistryEntry> _entries = [];

  /// All registered entries in order.
  List<TuiRegistryEntry> get entries => List.unmodifiable(_entries);

  /// Number of registered entries.
  int get length => _entries.length;

  /// Register a simple command.
  void registerCommand(TuiCommand command) {
    _entries.add(TuiCommandEntry(command));
  }

  /// Register a TUI-aware module.
  void registerModule(TuiModule module) {
    _entries.add(TuiModuleEntry(module));
  }

  /// Look up an entry by ID.
  TuiRegistryEntry? findById(String id) {
    for (final entry in _entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// Get display labels for the menu.
  List<String> get menuLabels => _entries.map((e) => e.label).toList();

  /// Get descriptions for the menu.
  List<String> get menuDescriptions =>
      _entries.map((e) => e.description).toList();
}
