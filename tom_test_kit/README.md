# Tom Test Kit

Test tracking CLI for Dart projects. Run tests, track results across time, and detect regressions.

## Features

- **Test tracking** — Maintain CSV baselines with results from multiple test runs
- **Structured test naming** — Parse test IDs, dates, and expected results from descriptions
- **Regression detection** — Compare runs to identify new failures and fixes
- **Multi-project support** — Scan and test multiple packages in a workspace

## Quick Start

```bash
# Create a baseline (first run)
testkit :baseline

# Run tests and update tracking
testkit :test

# Run tests without updating baseline
testkit :test --no-update

# View current status
testkit :status

# Compare baseline to latest run
testkit :basediff
```

## Commands

| Command | Description |
|---------|-------------|
| `:baseline` | Run tests, create new baseline CSV |
| `:test` | Run tests, append results to tracking file |
| `:test --no-update` | Run tests, show summary without updating |
| `:status` | Show pass/fail summary |
| `:basediff` | Diff baseline vs latest |
| `:diff` | Diff arbitrary runs |
| `:history` | Show test result history |
| `:flaky` | List tests with inconsistent results |

## Documentation

- [doc/test_tracking.md](doc/test_tracking.md) — Full workflow and command reference
