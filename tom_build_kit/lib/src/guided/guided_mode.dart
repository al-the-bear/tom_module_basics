/// Guided mode utilities using the interact package.
///
/// Provides interactive prompts for BuildKit CLI tools.
library;

import 'package:interact/interact.dart';

/// Result of a guided mode operation.
enum GuidedResult {
  /// User completed the flow
  completed,

  /// User cancelled the operation
  cancelled,

  /// User wants to go back
  back,
}

/// Helper class for guided mode interactions.
///
/// Uses the `interact` package for cross-platform interactive prompts.
class GuidedMode {
  /// Show a single-select menu and return selected index.
  ///
  /// Returns -1 if cancelled.
  int menu(
    String prompt,
    List<String> options, {
    int defaultIndex = 0,
    bool showCancel = true,
  }) {
    final allOptions =
        showCancel ? [...options, 'Cancel'] : options;

    final result = Select(
      prompt: prompt,
      options: allOptions,
      initialIndex: defaultIndex,
    ).interact();

    // If Cancel was selected
    if (showCancel && result == allOptions.length - 1) {
      return -1;
    }

    return result;
  }

  /// Show a multi-select menu with checkboxes.
  ///
  /// Returns list of selected indices, or empty list if cancelled.
  List<int> multiSelect(
    String prompt,
    List<String> options, {
    List<bool>? defaults,
    bool showInstructions = true,
  }) {
    if (showInstructions) {
      print('  (Space to toggle, Enter to confirm)');
    }

    return MultiSelect(
      prompt: prompt,
      options: options,
      defaults: defaults ?? List.filled(options.length, false),
    ).interact();
  }

  /// Show a confirmation prompt (Y/n or y/N).
  bool confirm(String prompt, {bool defaultYes = true}) {
    return Confirm(
      prompt: prompt,
      defaultValue: defaultYes,
    ).interact();
  }

  /// Show a text input prompt.
  String input(
    String prompt, {
    String? defaultValue,
    bool Function(String)? validator,
    String? validationError,
  }) {
    return Input(
      prompt: prompt,
      defaultValue: defaultValue ?? '',
      validator: validator != null
          ? (s) {
              if (validator(s)) return true;
              throw ValidationError(validationError ?? 'Invalid input');
            }
          : null,
    ).interact();
  }

  /// Show a password input prompt (hidden text).
  String password(String prompt) {
    return Password(
      prompt: prompt,
    ).interact();
  }

  /// Show a command preview box before execution.
  void showPreview({
    required String command,
    List<String>? repositories,
    Map<String, String>? details,
  }) {
    print('');
    print('┌─ Command Preview ────────────────────────────');
    print('│');
    print('│  $command');

    if (details != null && details.isNotEmpty) {
      print('│');
      for (final entry in details.entries) {
        print('│  ${entry.key}: ${entry.value}');
      }
    }

    if (repositories != null && repositories.isNotEmpty) {
      print('│');
      print('├─ Repositories ───────────────────────────────');
      for (final repo in repositories.take(5)) {
        print('│    $repo');
      }
      if (repositories.length > 5) {
        print('│    ... and ${repositories.length - 5} more');
      }
    }

    print('│');
    print('└──────────────────────────────────────────────');
    print('');
  }

  /// Show a spinner during a long-running operation.
  ///
  /// Returns a [SpinnerState] that must be stopped when done.
  SpinnerState showSpinner(String message) {
    final spinner = Spinner(
      icon: '✓',
      rightPrompt: (done) => done ? '✓ $message' : message,
    ).interact();
    return spinner;
  }

  /// Show a success message.
  void success(String message) {
    print('✓ $message');
  }

  /// Show an error message.
  void error(String message) {
    print('✗ $message');
  }

  /// Show an info message.
  void info(String message) {
    print('ℹ $message');
  }

  /// Show a warning message.
  void warning(String message) {
    print('⚠ $message');
  }

  /// Show a section header.
  void header(String title) {
    print('');
    print('=== $title ===');
    print('');
  }

  /// Show a sub-header.
  void subHeader(String title) {
    print('');
    print('--- $title ---');
    print('');
  }

  /// Wait for Enter key to continue.
  void waitForEnter([String message = 'Press Enter to continue...']) {
    Input(prompt: message, defaultValue: '').interact();
  }
}
