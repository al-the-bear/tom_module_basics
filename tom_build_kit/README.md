# Tom Build Kit

Pipeline-based build orchestration for the Tom workspace. Run build pipelines and tool commands in sequence with a unified CLI.

## Features

- **Pipeline execution** - Define and run named build pipelines from `tom_build.yaml`
- **Direct commands** - Run build tools directly with `:command` syntax
- **Sequential execution** - Mix pipelines and commands in a single invocation
- **Project scanning** - Run pipelines across multiple projects
- **Platform filtering** - Run steps only on specific platforms
- **Dry-run mode** - Preview what would be executed

## Quick Start

```bash
# Run a pipeline
buildkit build

# Run multiple pipelines
buildkit clean build

# Run tool commands directly
buildkit :versioner :compiler

# Mix pipelines and commands
buildkit build :cleanup --all

# Scan all projects
buildkit build --scan . --recursive
```

## Usage

```
buildkit [options] <pipeline|:command> [args...] [<pipeline|:command> [args...]]...

Options:
  -h, --help         Show help
  -v, --verbose      Verbose output
  -n, --dry-run      Show what would be executed
  -l, --list         List available pipelines
  -s, --scan         Scan directory for projects
  -R, --recursive    Scan recursively into projects
  -p, --project      Project(s) to process (comma-separated, globs: tom_*_builder, ./*)
```

### Project Selection

Specify projects using `--project` with comma-separated values and glob patterns:

```bash
# Single project
buildkit build --project=my_app

# Multiple projects (comma-separated)
buildkit build --project='project1,project2'

# Glob patterns
buildkit build --project='tom_*_builder'

# Current directory children
buildkit build --project='./*'
```

## Built-in Commands

| Command | Description |
|---------|-------------|
| `:versioner` | Generate version.g.dart from pubspec.yaml |
| `:compiler` | Compile Dart to native executables |
| `:runner` | Run build_runner for code generation |
| `:astgen` | Generate AST files for D4rt |
| `:d4rtgen` | Generate D4rt bridge code |
| `:cleanup` | Clean build artifacts |

## Pipeline Configuration

Define pipelines in `tom_build.yaml`:

```yaml
buildkit:
  pipelines:
    build:
      core:
        - commands:
            - versioner
            - runner
            - compiler
```

## Documentation

See [doc/user_guide.md](doc/user_guide.md) for complete documentation including:

- Pipeline configuration reference
- Shell command variable expansion
- Platform filtering
- Project scanning behavior
- Configuration hierarchy

