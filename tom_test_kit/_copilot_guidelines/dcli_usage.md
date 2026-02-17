# DCli Usage Guidelines

Guidelines for using the DCli library for shell-like operations in tom_test_kit.

## Overview

tom_test_kit uses DCli for test execution, file scanning, baseline management, and output processing.

## Import

```dart
import 'package:dcli/dcli.dart';
```

## Common Patterns in tom_test_kit

### 1. Running Tests

```dart
// Execute dart test
final testCmd = 'dart test --reporter=compact';
final output = testCmd.toList();

// With timeout and progress
start(testCmd, progress: Progress((line) {
  parseTestOutput(line);
}), workingDirectory: projectPath);
```

### 2. Test File Discovery

```dart
// Find all test files
find('*_test.dart', recursive: true, workingDirectory: testDir)
  .forEach((file) => testFiles.add(file.pathTo));

// Exclude certain directories
find('*_test.dart', recursive: true)
  .where((f) => !f.pathTo.contains('/generated/'))
  .forEach((file) => processTestFile(file.pathTo));
```

### 3. Baseline File Management

```dart
// Find latest baseline
final baselines = find('baseline_*.csv', workingDirectory: docDir)
  .toList()
  ..sort((a, b) => b.pathTo.compareTo(a.pathTo));
final latest = baselines.firstOrNull?.pathTo;

// Read baseline content
if (latest != null && exists(latest)) {
  final content = read(latest).toList();
}
```

### 4. Test Output Capture

```dart
// Capture test JSON output
final result = 'dart test --reporter=json'.toList();

// Parse each line
for (final line in result) {
  if (line.startsWith('{')) {
    final json = jsonDecode(line);
    processTestEvent(json);
  }
}
```

### 5. Project Detection

```dart
// Check if directory is a test project
bool isTestProject(String path) {
  final pubspec = truepath(path, 'pubspec.yaml');
  final testDir = truepath(path, 'test');
  return exists(pubspec) && exists(testDir) && isDirectory(testDir);
}
```

## Test-Specific Patterns

### Running Filtered Tests

```dart
// Run specific test file
'dart test ${truepath(testDir, specificTest)}'.run;

// Run tests matching name pattern
'dart test --name="parser"'.toList();
```

### Handling Test Failures

```dart
// Use nothrow to capture failures without exception
final result = 'dart test'.toList(nothrow: true);
final failed = result.any((line) => line.contains('FAILED'));
```

## Best Practices

1. **Use `.toList()`** to capture test output for parsing
2. **Use `nothrow: true`** - test failures are expected, don't throw
3. **Use `find()` for test discovery** instead of manual directory traversal
4. **Sort baselines by name** to get chronological ordering
5. **Use `truepath()`** for all file path construction

## Related Documentation

- [DCli Overview](../../../../_copilot_guidelines/d4rt/dcli_overview.md) - General DCli documentation
- [DCli Scripting Guide](../../../../_copilot_guidelines/d4rt/dcli_scripting_guide.md) - Complete API reference
- [DCli Repository](../../dcli/) - Source code and examples
