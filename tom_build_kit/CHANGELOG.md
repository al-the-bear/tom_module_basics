## 1.6.0

### Features

- **`:status` command** — New internal command showing buildkit version, binary status, and git state.
  - Source version display (version, build number, git commit, build time, Dart SDK)
  - Binary currency check for all 25 buildkit tools (runs `<tool> --version`)
  - Categorizes tools as current, outdated, unavailable, or non-conformant
  - Git status with pending changes and unpushed commits
  - Supports `--json` for structured output
  - Supports `--verbose` to show individual file/commit details
  - Supports `--skip-binaries` and `--skip-git` flags
  - Uses standard navigation options for git repo traversal

## 1.5.0

### Bug Fixes

- **`pubgetall` / `pubupdateall` showing 0 projects** — These commands now correctly run once at workspace level with their own project discovery instead of being invoked per-project.
- **Progress line not clearing** — Fixed progress display in `pubget` and `pubupdate` commands by padding output to 120 chars and flushing stdout immediately.
- **Build order path normalization** — Fixed `computeBuildOrder()` filtering out all projects due to non-normalized paths.

### Features

- **`ownDiscoveryCommands`** — New pattern in `buildkit.dart` for commands that do their own project discovery (e.g., `pubgetall`, `pubupdateall`).
- **`--no-recursive` support** — Respects the new negatable `--recursive` flag from tom_build_base v1.6.0.

## 1.4.0

### Features

- **`--modules` / `-m` navigation option** — Filter projects/repositories to specific git modules. Comma-separated list of module names (e.g., `--modules tom_module_d4rt,tom_module_basics`). Use "root" or "tom" for main repository.
- All 17 git tools now support modules filtering (`gitstatus`, `gitcommit`, `gitpull`, `gitsync`, `gitbranch`, `gittag`, `gitcheckout`, `gitreset`, `gitclean`, `gitprune`, `gitstash`, `gitunstash`, `git`, `gitcompare`, `gitmerge`, `gitsquash`, `gitrebase`).
- `ToolBase.findProjects()` now accepts `modules` parameter for include filtering.
- `buildkit` CLI supports `--modules` / `-m` option.

## 1.0.0

- Initial version.
