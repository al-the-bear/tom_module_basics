/// Main TUI application for Tom Test Kit.
///
/// Orchestrates the full-screen interactive dashboard for running
/// commands and viewing results.
library;

import 'dart:async';

import 'package:utopia_tui/utopia_tui.dart';

import '../tui_command.dart';
import '../tui_command_registry.dart';
import '../tui_module.dart';
import 'tui_menu_panel.dart';
import 'tui_output_panel.dart';

/// Focus area in the TUI layout.
enum _FocusArea { menu, output }

/// Main TUI application.
class TestKitTuiApp extends TuiApp {
  /// Command/module registry.
  final TuiCommandRegistry registry;

  /// Resolved project path.
  final String projectPath;

  // State
  late TuiMenuPanel _menu;
  final _output = TuiOutputPanel();
  _FocusArea _focus = _FocusArea.menu;
  bool _commandRunning = false;
  TuiCommandSink? _activeSink;
  TuiModule? _activeModule;
  TuiModuleContext? _activeModuleContext;
  int _processedEventCount = 0;

  TestKitTuiApp({
    required this.registry,
    required this.projectPath,
  });

  @override
  void init(TuiContext context) {
    _menu = TuiMenuPanel(
      items: registry.menuLabels,
      focused: true,
    );
  }

  @override
  Duration? get tickInterval => const Duration(milliseconds: 100);

  @override
  void onEvent(TuiEvent event, TuiContext context) {
    if (event is TuiTickEvent) {
      _output.tick();
      return;
    }

    if (event is TuiKeyEvent) {
      _handleKeyEvent(event, context);
    }
  }

  void _handleKeyEvent(TuiKeyEvent event, TuiContext context) {
    // If a module is active, let it handle events first
    if (_activeModule != null) {
      if (event.code == TuiKeyCode.escape) {
        _deactivateModule();
        return;
      }
      if (_activeModule!.onEvent(event)) return;
    }

    // Navigate with Tab between menu and output
    if (event.code == TuiKeyCode.tab) {
      _toggleFocus();
      return;
    }

    // Escape returns to menu / idle
    if (event.code == TuiKeyCode.escape) {
      if (_commandRunning) {
        // Don't cancel — just switch focus back to menu
        _focus = _FocusArea.menu;
        _updateMenuFocus();
      } else if (_output.state == OutputPanelState.finished) {
        _output.reset();
        _focus = _FocusArea.menu;
        _updateMenuFocus();
      }
      return;
    }

    switch (_focus) {
      case _FocusArea.menu:
        _handleMenuKey(event, context);
      case _FocusArea.output:
        _handleOutputKey(event);
    }
  }

  void _handleMenuKey(TuiKeyEvent event, TuiContext context) {
    if (_commandRunning) return; // Can't select while running

    switch (event.code) {
      case TuiKeyCode.arrowUp:
        _menu.moveUp();
      case TuiKeyCode.arrowDown:
        _menu.moveDown();
      case TuiKeyCode.enter:
        _executeSelected();
      default:
        // Also handle j/k for vim-style navigation
        if (event.isPrintable) {
          switch (event.char) {
            case 'k':
              _menu.moveUp();
            case 'j':
              _menu.moveDown();
          }
        }
    }
  }

  void _handleOutputKey(TuiKeyEvent event) {
    switch (event.code) {
      case TuiKeyCode.arrowUp:
        _output.scrollUp();
      case TuiKeyCode.arrowDown:
        _output.scrollDown();
      default:
        break;
    }
  }

  void _toggleFocus() {
    _focus = _focus == _FocusArea.menu ? _FocusArea.output : _FocusArea.menu;
    _updateMenuFocus();
  }

  void _updateMenuFocus() {
    _menu.focused = _focus == _FocusArea.menu;
  }

  void _executeSelected() {
    if (registry.entries.isEmpty) return;

    final entry = registry.entries[_menu.selectedIndex];

    switch (entry) {
      case TuiCommandEntry(:final command):
        _executeCommand(command);
      case TuiModuleEntry(:final module):
        _activateModule(module);
    }
  }

  void _executeCommand(TuiCommand command) {
    _commandRunning = true;
    _output.reset();
    _output.state = OutputPanelState.running;
    _output.currentPhase = 'Starting ${command.label}...';
    _focus = _FocusArea.output;
    _updateMenuFocus();

    final sink = TuiCommandSink();
    _activeSink = sink;
    _processedEventCount = 0;

    // Run command asynchronously
    unawaited(
      command
          .execute(
        projectPath: projectPath,
        sink: sink,
      )
          .then((result) {
        _output.result = result;
        _commandRunning = false;
        _activeSink = null;
      }).catchError((Object error) {
        _output.processEvent(TuiLogEvent(
          'Error: $error',
          level: TuiLogLevel.error,
        ));
        _output.state = OutputPanelState.finished;
        _output.resultSummary = 'Command failed with error';
        _commandRunning = false;
        _activeSink = null;
      }),
    );
  }

  void _activateModule(TuiModule module) {
    _activeModuleContext = TuiModuleContext(
      projectPath: projectPath,
      requestRedraw: () {}, // TUI redraws on tick anyway
      registry: registry,
    );
    module.activate(_activeModuleContext!);
    _activeModule = module;
  }

  void _deactivateModule() {
    _activeModule?.deactivate();
    _activeModule = null;
    _activeModuleContext = null;
  }

  @override
  void build(TuiContext context) {
    // Process any pending events from the active sink
    if (_activeSink != null) {
      final events = _activeSink!.events;
      for (var i = _processedEventCount; i < events.length; i++) {
        _output.processEvent(events[i]);
      }
      _processedEventCount = events.length;
    }

    final w = context.width;
    final h = context.height;

    // Layout: header (1) + content (h-2) + status bar (1)
    final headerH = 1;
    final footerH = 1;
    final contentH = h - headerH - footerH;

    // 1. Header
    _paintHeader(context.surface, w);

    // 2. Content area
    if (_activeModule != null) {
      // Module takes full content area
      _activeModule!.build(
        context.surface,
        TuiRect(x: 0, y: headerH, width: w, height: contentH),
      );
    } else {
      // Two-panel layout
      final menuWidth = _calculateMenuWidth(w);
      final outputWidth = w - menuWidth;

      // Menu panel (left)
      _menu.paintSurface(
        context.surface,
        TuiRect(x: 0, y: headerH, width: menuWidth, height: contentH),
      );

      // Output panel (right)
      final outputBorderStyle = _focus == _FocusArea.output
          ? const TuiStyle(fg: 39)
          : const TuiStyle(fg: 238);

      TuiPanelBox(
        title: _outputTitle,
        titleStyle: const TuiStyle(bold: true, fg: 252),
        borderStyle: outputBorderStyle,
        child: _output,
      ).paintSurface(
        context.surface,
        TuiRect(
            x: menuWidth, y: headerH, width: outputWidth, height: contentH),
      );
    }

    // 3. Status bar
    _paintStatusBar(context.surface, w, h);
  }

  String get _outputTitle {
    if (_commandRunning) return ' Running... ';
    if (_output.state == OutputPanelState.finished) return ' Results ';
    return ' Output ';
  }

  void _paintHeader(TuiSurface surface, int width) {
    const headerStyle = TuiStyle(bg: 240, fg: 16, bold: true);
    surface.fillRect(0, 0, width, 1, ' ', style: headerStyle);
    surface.putTextClip(0, 0, ' Tom Test Kit', width, style: headerStyle);

    final hint = _commandRunning ? ' [running]' : '';
    if (hint.isNotEmpty) {
      surface.putText(
          width - hint.length - 1, 0, hint, style: headerStyle);
    }
  }

  void _paintStatusBar(TuiSurface surface, int width, int height) {
    const sbStyle = TuiStyle(bg: 240, fg: 16);
    surface.fillRect(0, height - 1, width, 1, ' ', style: sbStyle);

    // Left: current command description
    final selectedDesc = registry.entries.isNotEmpty
        ? registry.entries[_menu.selectedIndex].description
        : '';
    surface.putTextClip(0, height - 1, ' $selectedDesc', width ~/ 2,
        style: sbStyle);

    // Right: key hints
    final hints = _commandRunning
        ? 'Tab: switch | Esc: menu | Ctrl+C: quit'
        : 'Enter: run | Tab: switch | Ctrl+C: quit';
    final hintsX = width - hints.length - 1;
    if (hintsX > 0) {
      surface.putText(hintsX, height - 1, hints, style: sbStyle);
    }
  }

  int _calculateMenuWidth(int totalWidth) {
    // Menu width: fixed at 24 or 30% of width, whichever is smaller
    final calculated = (totalWidth * 0.3).round();
    return calculated.clamp(20, 30);
  }
}
