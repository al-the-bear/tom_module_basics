/// Tom Issue Kit — Issue tracking CLI for the Tom Framework.
///
/// This library provides issue tracking functionality that bridges
/// GitHub Issues (tom_issues, tom_tests) with Dart tests in the codebase.
///
/// ## Key Components
///
/// - [IssueKitConfig] — Configuration loading from tom_workspace.yaml
/// - [IssueTrackingConfig] — Issue tracking repository configuration
/// - [ProjectConfig] — Project-level configuration from tom_project.yaml
/// - [GitHubAuthConfig] — GitHub authentication resolution
/// - [IssueService] — High-level issue operations
///
/// ## CLI Usage
///
/// The issuekit CLI is the primary interface:
///
/// ```bash
/// issuekit :list --state new           # List new issues
/// issuekit :new "Bug description"      # File a new issue
/// issuekit :scan 42                    # Find tests for issue #42
/// ```
///
/// See the command reference documentation for full CLI usage.
library;

// Configuration
export 'src/config/issuekit_config.dart';

// Services
export 'src/services/issue_service.dart';

// Utilities
export 'src/util/output_formatter.dart';

// Version info
export 'src/version.versioner.dart';

// V2 CLI framework
export 'src/v2/issuekit_executors.dart';
export 'src/v2/issuekit_tool.dart';
