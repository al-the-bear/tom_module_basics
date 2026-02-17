# Tom Issue Kit Project Guidelines

**Project:** `tom_issue_kit`  
**Type:** CLI Tool

## Essential: DCli for File/Directory Operations

> **IMPORTANT:** Use DCli for ALL file and directory manipulation. Do not use `dart:io` directly.

DCli provides Dart equivalents for Unix commands: `cp`, `mv`, `rm`, `mkdir`, `cat`, `find`, `head`, `tail`, `which`, `chmod`, `touch`, `ln -s`, and more.

| Document | Purpose |
|----------|----------|
| [DCli Overview](/_copilot_guidelines/d4rt/dcli_overview.md) | Introduction, command equivalents table, examples |
| [DCli Scripting Guide](/_copilot_guidelines/d4rt/dcli_scripting_guide.md) | Complete API reference |
| [dcli_usage.md](dcli_usage.md) | Project-specific DCli patterns |

**Quick Start:**
```dart
import 'package:dcli/dcli.dart';

// File operations: copy, move, delete, cat, read, head, tail, touch, replace
copy('src.txt', 'dst.txt');
cat('file.txt');
final lines = read('file.txt').toList();

// Directory operations: createDir, deleteDir, find, exists, isDirectory
createDir('path/to/dir', recursive: true);
find('*.dart', recursive: true).forEach((f) => print(f.path));

// Command execution
'dart --version'.run;
final output = 'ls -la'.toList();
```

## Global Guidelines

| Document | Purpose |
|----------|---------|
| [Documentation Guidelines](/_copilot_guidelines/documentation_guidelines.md) | Where to place user docs vs development docs |

## Dart Guidelines

| Document | Purpose |
|----------|---------|
| [Coding Guidelines](/_copilot_guidelines/dart/coding_guidelines.md) | Naming conventions, error handling, patterns |
| [Unit Tests](/_copilot_guidelines/dart/unit_tests.md) | Test structure, matchers, mocking patterns |
| [Examples](/_copilot_guidelines/dart/examples.md) | Example file creation guidelines |

## Project-Specific Guidelines

| Document | Purpose |
|----------|---------|
| [implementation_guidelines.md](implementation_guidelines.md) | Development workflow, TDD, test naming conventions |
| [testing.md](testing.md) | Unit and integration testing strategy |

## Key Documents

| Document | Purpose |
|----------|---------|
| [issue_tracking.md](../doc/issue_tracking.md) | Design specification — architecture, lifecycle, conventions |
| [issuekit_command_reference.md](../doc/issuekit_command_reference.md) | Command specifications — all 24 commands |
| [issuekit_implementation_todos.md](../doc/issuekit_implementation_todos.md) | Phased implementation plan |
