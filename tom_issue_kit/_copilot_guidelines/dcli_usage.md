# DCli Usage Guidelines

Guidelines for using the DCli library for shell-like operations in tom_issue_kit.

## Overview

tom_issue_kit uses DCli for test scanning, file operations, git integration, and configuration file management.

## Import

```dart
import 'package:dcli/dcli.dart';
```

## Common Patterns in tom_issue_kit

### 1. Test Scanner (test_scanner.dart)

```dart
// Find test files in project
find('*_test.dart', recursive: true, workingDirectory: testDir)
  .forEach((file) {
    final content = read(file.pathTo).toList();
    scanForTestIds(file.pathTo, content);
  });

// Read file content for parsing
if (exists(testFile) && isFile(testFile)) {
  final lines = read(testFile).toList();
}
```

### 2. Baseline Management

```dart
// Find latest baseline file
final docDir = truepath(projectRoot, 'doc');
if (exists(docDir) && isDirectory(docDir)) {
  final baselines = find('baseline_*.csv', workingDirectory: docDir)
    .toList()
    ..sort((a, b) => b.pathTo.compareTo(a.pathTo));
  return baselines.firstOrNull?.pathTo;
}
```

### 3. Configuration Loading

```dart
// Load workspace config
final configPath = truepath(workspaceRoot, '.tom', 'issue_tracking.yaml');
if (exists(configPath)) {
  final content = read(configPath).toList().join('\n');
  return parseConfig(content);
}
```

### 4. Git Operations

```dart
// Get current branch
final branch = 'git branch --show-current'.firstLine;

// Check for uncommitted changes
final status = 'git status --porcelain'.toList();
final hasChanges = status.isNotEmpty;

// Get remote URL
final remote = 'git remote get-url origin'.firstLine;
```

### 5. Project Discovery

```dart
// Find all projects in workspace
find('pubspec.yaml', recursive: true, workingDirectory: workspaceRoot)
  .forEach((pubspec) {
    final projectDir = dirname(pubspec.pathTo);
    if (isValidProject(projectDir)) {
      projects.add(projectDir);
    }
  });
```

## Issue-Tracking Patterns

### Scanning for Test IDs

```dart
// Parse test files for issue-linked tests
void scanTestFile(String path) {
  final lines = read(path).toList();
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.contains(testIdPattern)) {
      final match = parseTestId(line, i + 1);  // 1-based line number
      if (match != null) matches.add(match);
    }
  }
}
```

### Workspace Root Detection

```dart
// Find workspace root (directory with tom_workspace.yaml)
String? findWorkspaceRoot(String startDir) {
  var current = truepath(startDir);
  while (current != rootPath) {
    if (exists(join(current, 'tom_workspace.yaml'))) {
      return current;
    }
    current = dirname(current);
  }
  return null;
}
```

## Best Practices

1. **Use `read().toList()`** for file content that needs line-by-line processing
2. **Use `truepath()`** for all path construction
3. **Check `exists()` before file operations** - configs may be optional
4. **Use `find()` with patterns** instead of manual directory listing
5. **Use `.firstLine`** for single-line command output (git branch, version, etc.)

## Related Documentation

- [DCli Overview](../../../../_copilot_guidelines/d4rt/dcli_overview.md) - General DCli documentation
- [DCli Scripting Guide](../../../../_copilot_guidelines/d4rt/dcli_scripting_guide.md) - Complete API reference
- [DCli Repository](../../dcli/) - Source code and examples
