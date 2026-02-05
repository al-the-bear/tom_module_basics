# Build Examples

These test projects demonstrate how to use the `tom_analyzer` package with `build_runner` for code analysis and reflection generation.

## Projects

| Project | Tool | Target | Description |
|---------|------|--------|-------------|
| `analyze_dart_overview` | Analyzer | dart_overview | Analyzes the dart_overview fixture |
| `reflect_dart_overview` | Generator | dart_overview | Generates reflection for dart_overview |
| `analyze_tom_core_kernel` | Analyzer | tom_core_kernel | Analyzes tom_core_kernel |
| `reflect_tom_core_kernel` | Generator | tom_core_kernel | Generates reflection for tom_core_kernel |
| `analyze_tom_core_server` | Analyzer | tom_core_server | Analyzes tom_core_server with all dependencies |
| `reflect_tom_core_server` | Generator | tom_core_server | Generates reflection for tom_core_server |

## Running Build Examples

Each project uses `build_runner` to execute the analyzer or generator:

```bash
cd <project>
dart pub get
dart run build_runner build
```

## Configuration Files

Each project contains:

- `pubspec.yaml` - Package configuration with tom_analyzer dependency
- `build.yaml` - Build configuration for the analyzer/generator
- `lib/` - Target source files or imports
