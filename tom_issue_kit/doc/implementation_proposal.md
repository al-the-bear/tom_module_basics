# issuekit Implementation Proposal

## Documentation Status: ✅ Ready

Both docs are comprehensive and consistent with:
- Clear terminology (@issues/@tests/@code)
- All 24 commands documented with examples
- State machine and workflows defined
- Configuration format specified

---

## Infrastructure from tom_build_base (reusable)

| Component | Use in issuekit |
|-----------|-----------------|
| `ProjectNavigator` | `:scan`, `:link`, `:check` — traverse projects to find @code tests |
| `NavigationConfig` | Disable unused features (build order, modules filter) |
| `WorkspaceNavigationArgs` | Standard `-s`, `-r`, `-R` option parsing |
| `addNavigationOptions()` | Add to ArgParser for project traversal commands |
| `ProcessingResult` | Track success/failure across multi-project runs |
| `resolveExecutionRoot()` | Find workspace root |
| `getToolHelpHeader()`/`getToolHelpFooter()` | Consistent help formatting |
| `isHelpCommand()`/`isVersionCommand()` | Standard command detection |

## Patterns from testkit (copy directly)

| Pattern | Apply to issuekit |
|---------|-------------------|
| `_commandHelp` map | Per-command help text for 24 commands |
| `_commandAliases` map | Abbreviations (e.g., `ls` → `list`) |
| `_extractSubcommandAndSplit()` | Parse `:command` from args |
| `switch (subcommand)` dispatch | Route to `*Command.run()` handlers |
| Global + command nav args merging | Navigation options before or after subcommand |

---

## New Components to Create

| Component | Purpose |
|-----------|---------|
| **`GitHubIssuesClient`** | Low-level GitHub API wrapper (REST/GraphQL) |
| **`IssuesRepo`** | tom_issues operations (@issues) |
| **`TestsRepo`** | tom_tests operations (@tests) |
| **`IssueIdParser`** | Parse/validate `TI-123`, `TT-456` formats |
| **`IssuekitConfig`** | Load `issuekit.yaml` (repos, labels, token path) |
| **`StateTransition`** | State machine validation (NEW→ASSIGNED→etc.) |
| **`LinkBarParser`** | Parse/update `// TI:` link bar in .dart files |
| **`TestSyncService`** | Match @code test results to @issues/@tests |
| **`SnapshotExporter`** | Export both repos to backup JSON |

## Suggested Package Dependencies

```yaml
dependencies:
  args: ^2.4.0
  path: ^1.9.0
  tom_build_base:
    path: ../tom_build_base
  http: ^1.2.0          # GitHub API calls
  json_annotation: ^4.8.0
  glob: ^2.1.0          # Pattern matching
```

---

## Factoring for Reuse

Consider creating **`tom_github_client`** package:

- Generic GitHub Issues CRUD (create, read, update, close, reopen)
- Label management
- Comment operations  
- Search API wrapper
- Authentication (token from file/env)
- Rate limiting handling

This would be reusable by issuekit, future tools, and GitHub Actions integrations.

---

## Implementation Order Suggestion

1. **Phase 1 — Skeleton**: `bin/issuekit.dart` with command routing, help, version (copy testkit pattern)
2. **Phase 2 — Config**: `IssuekitConfig` loading and validation
3. **Phase 3 — GitHub client**: `GitHubIssuesClient` with auth/API
4. **Phase 4 — Core commands**: `:new`, `:list`, `:show` (basic CRUD)
5. **Phase 5 — State commands**: `:assign`, `:start`, `:close`, `:reopen`
6. **Phase 6 — Traversal**: `:scan`, `:link`, `:check` using ProjectNavigator
7. **Phase 7 — Sync**: `:sync`, `:nightly` (coordinate @issues/@tests/@code)
8. **Phase 8 — Export/backup**: `:export`, `:import`, `:snapshot`
