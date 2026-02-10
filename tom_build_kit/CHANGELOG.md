## 1.4.0

### Features

- **`--modules` / `-m` navigation option** — Filter projects/repositories to specific git modules. Comma-separated list of module names (e.g., `--modules tom_module_d4rt,tom_module_basics`). Use "root" or "tom" for main repository.
- All 17 git tools now support modules filtering (`gitstatus`, `gitcommit`, `gitpull`, `gitsync`, `gitbranch`, `gittag`, `gitcheckout`, `gitreset`, `gitclean`, `gitprune`, `gitstash`, `gitunstash`, `git`, `gitcompare`, `gitmerge`, `gitsquash`, `gitrebase`).
- `ToolBase.findProjects()` now accepts `modules` parameter for include filtering.
- `buildkit` CLI supports `--modules` / `-m` option.

## 1.0.0

- Initial version.
