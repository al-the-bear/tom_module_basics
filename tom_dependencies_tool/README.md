# Tom Dependencies Tool

Dependency tree visualization tool for Dart projects. Shows dependencies from `pubspec.yaml` with overrides from `pubspec_overrides.yaml`.

## Features

- **Direct dependencies** - Show first-level dependencies (default)
- **Full tree** - Recursively show complete dependency tree with `--deep`
- **Override detection** - Display pubspec_overrides.yaml overrides in brackets
- **Flexible filtering** - Normal only, dev only, or all dependencies
- **Multi-project** - Analyze multiple projects with glob patterns
- **Circular detection** - Detect and display circular dependencies

## Quick Start

```bash
# Show dependencies for current project
dependencies

# Show only dev dependencies
dependencies --dev

# Show all dependencies (normal + dev)
dependencies --all

# Show full dependency tree
dependencies --deep

# Analyze multiple projects
dependencies --project='tom_*'
```

## Output Format

```
my_project:
   -> args: ^2.7.0                     # Normal dependency
   -> tom_build_base: path: ../...     # Path dependency
   +> test: ^1.25.6                    # Dev dependency (+>)
   +> tom_d4rt: ^1.4.0 [path: ../...]  # Override shown in brackets
```

## Options

| Option | Description |
|--------|-------------|
| `-p, --project` | Project(s) to analyze (comma-separated, globs) |
| `-s, --scan` | Directory to scan for projects |
| `-r, --recursive` | Process subprojects recursively |
| `-d, --dev` | Show only dev dependencies |
| `-a, --all` | Show both normal and dev dependencies |
| `-D, --deep` | Show full dependency tree |
| `-l, --list` | List projects without analyzing |
| `-v, --verbose` | Show detailed output |
| `-h, --help` | Show help message |

## Documentation

See [doc/user_guide.md](doc/user_guide.md) for complete documentation.
