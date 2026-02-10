/// Menu panel component for the Test Kit TUI.
///
/// Displays the list of available commands with selection highlighting.
library;

import 'package:utopia_tui/utopia_tui.dart';

/// Renders the TUI command menu (left sidebar).
class TuiMenuPanel extends TuiComponent {
  /// Menu items (command/module labels).
  final List<String> items;

  /// Currently selected index.
  int selectedIndex;

  /// Whether the menu has keyboard focus.
  bool focused;

  TuiMenuPanel({
    required this.items,
    this.selectedIndex = 0,
    this.focused = true,
  });

  /// Move selection up.
  void moveUp() {
    if (selectedIndex > 0) selectedIndex--;
  }

  /// Move selection down.
  void moveDown() {
    if (selectedIndex < items.length - 1) selectedIndex++;
  }

  @override
  void paintSurface(TuiSurface surface, TuiRect rect) {
    if (rect.isEmpty) return;
    surface.clearRect(rect.x, rect.y, rect.width, rect.height);

    final borderStyle = focused
        ? const TuiStyle(fg: 39)
        : const TuiStyle(fg: 238);

    // Draw the panel border
    TuiPanelBox(
      title: ' Commands ',
      titleStyle: const TuiStyle(bold: true, fg: 252),
      borderStyle: borderStyle,
      child: _MenuContent(
        items: items,
        selectedIndex: selectedIndex,
        focused: focused,
      ),
    ).paintSurface(surface, rect);
  }
}

class _MenuContent extends TuiComponent {
  final List<String> items;
  final int selectedIndex;
  final bool focused;

  _MenuContent({
    required this.items,
    required this.selectedIndex,
    required this.focused,
  });

  @override
  void paintSurface(TuiSurface surface, TuiRect rect) {
    if (rect.isEmpty) return;

    for (var i = 0; i < items.length && i < rect.height; i++) {
      final isSelected = i == selectedIndex;
      final y = rect.y + i;

      if (isSelected) {
        // Highlighted row
        final style = focused
            ? const TuiStyle(fg: 16, bg: 39, bold: true)
            : const TuiStyle(fg: 16, bg: 245);
        // Fill the whole row with background
        surface.fillRect(rect.x, y, rect.width, 1, ' ', style: style);
        final text = ' \u25B6 ${items[i]}';
        surface.putTextClip(rect.x, y, text, rect.width, style: style);
      } else {
        final text = '   ${items[i]}';
        surface.putTextClip(rect.x, y, text, rect.width,
            style: const TuiStyle(fg: 250));
      }
    }
  }
}
