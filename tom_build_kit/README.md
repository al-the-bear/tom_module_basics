# Tom Build Kit

Pipeline-based build orchestration for the Tom workspace. Run build pipelines and tool commands in sequence with a unified CLI.

## Features

- **Pipeline execution** - Define and run named build pipelines from `buildkit.yaml`
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
| `:versioner` | Generate version.versioner.dart from pubspec.yaml |
| `:compiler` | Compile Dart to native executables |
| `:runner` | Run build_runner for code generation |
| `:astgen` | Generate AST files for D4rt |
| `:d4rtgen` | Generate D4rt bridge code |
| `:cleanup` | Clean build artifacts |
| `:execute` | Execute shell command in each traversed folder |

## Execute Command

Run shell commands in every traversed folder with placeholder support:

```bash
# Echo folder name in each git repo
buildkit -i :execute "echo ${folder.name}"

# Run dart pub get only in dart projects
buildkit -i :execute --condition dart.exists "dart pub get"

# Conditional output based on project type
buildkit -i :execute "echo ${dart.publishable?(Publishable):(Not publishable)}"

# Git status in all repos  
buildkit -i :execute --condition git.exists "git status"
```

**Available placeholders:**
- Path: `${root}`, `${folder}`, `${folder.name}`, `${folder.relative}`
- Platform: `${current-os}`, `${current-arch}`, `${current-platform}`
- Nature existence: `${dart.exists}`, `${flutter.exists}`, `${git.exists}`
- Dart: `${dart.name}`, `${dart.version}`, `${dart.publishable}`
- Git: `${git.branch}`, `${git.remote}`, `${git.dirty}`

**Ternary syntax:** `${condition?(true-value):(false-value)}`

## Git Commands

Manage git repositories across the entire workspace with a single command:

| Command | Description | Traversal |
|---------|-------------|-----------|
| `:gitstatus` | Show status of all repositories | inner-first (default) |
| `:gitcommit` | Commit and push all repos with same message | inner-first (fixed) |
| `:gitpull` | Pull latest from all repositories | outer-first (fixed) |
| `:gitsync` | Full sync: stash, fetch, merge, push | outer-first (fixed) |
| `:gitbranch` | Manage branches across repos | inner-first (fixed) |
| `:gittag` | Manage tags across repos | inner-first (fixed) |
| `:gitcheckout` | Checkout branch/tag/commit | outer-first (fixed) |
| `:gitreset` | Reset repos to specific state | outer-first (fixed) |
| `:gitclean` | Remove untracked files | inner-first (fixed) |
| `:gitprune` | Remove stale remote-tracking branches | outer-first (fixed) |
| `:gitstash` | Stash uncommitted changes | inner-first (fixed) |
| `:gitunstash` | Restore stashed changes | outer-first (fixed) |
| `:gitcompare` | Compare current branch with another | inner-first (fixed) |
| `:gitmerge` | Merge branch into current branch | inner-first (fixed) |
| `:gitsquash` | Squash merge branch into current | inner-first (fixed) |
| `:gitrebase` | Rebase current branch onto another | inner-first (fixed) |
| `:git` | Run arbitrary git commands | requires -i/-o |

```bash
# Check status of all repos
bk :gitstatus

# Commit all repos with same message
bk :gitcommit -m "Add feature X"

# Full sync (stash, pull, push)
bk :gitsync

# Create branch in all repos
bk :gitbranch -c feature/new

# Run arbitrary git command
bk :git -i -- log --oneline -5
```

## Pipeline Configuration

Define pipelines in `buildkit.yaml`:

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

- [doc/buildkit_user_guide.md](doc/buildkit_user_guide.md) — BuildKit orchestrator: pipelines, commands, scanning, security
- [doc/tools_user_guide.md](doc/tools_user_guide.md) — Individual tool reference: versioner, cleanup, compiler, runner, dependencies, versionbump, pubget

