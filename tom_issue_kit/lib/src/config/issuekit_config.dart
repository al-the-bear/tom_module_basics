/// Configuration loading for issuekit.
///
/// Reads configuration from tom_workspace.yaml (workspace level) and
/// tom_project.yaml (project level).
library;

import 'dart:io';

import 'package:path/path.dart' as path;

/// Issue tracking configuration from tom_workspace.yaml.
class IssueTrackingConfig {
  /// Constructor.
  const IssueTrackingConfig({
    required this.issuesRepo,
    required this.testsRepo,
    this.defaultSeverity = 'normal',
    this.defaultReporter,
  });

  /// The GitHub repository for issues (e.g., 'al-the-bear/tom_issues').
  final String issuesRepo;

  /// The GitHub repository for test entries (e.g., 'al-the-bear/tom_tests').
  final String testsRepo;

  /// Default severity for new issues.
  final String defaultSeverity;

  /// Default reporter name.
  final String? defaultReporter;

  /// Parse from a map (from YAML).
  static IssueTrackingConfig? tryParse(Map<String, dynamic>? map) {
    if (map == null) return null;

    final issuesRepo = map['issues_repo'] as String?;
    final testsRepo = map['tests_repo'] as String?;

    if (issuesRepo == null || testsRepo == null) {
      return null;
    }

    return IssueTrackingConfig(
      issuesRepo: issuesRepo,
      testsRepo: testsRepo,
      defaultSeverity: (map['default_severity'] as String?) ?? 'normal',
      defaultReporter: map['default_reporter'] as String?,
    );
  }

  /// Get the owner component of a repo string (e.g., 'al-the-bear' from
  /// 'al-the-bear/tom_issues').
  static String? getOwner(String repoString) {
    final parts = repoString.split('/');
    if (parts.length != 2) return null;
    return parts[0];
  }

  /// Get the repo name component of a repo string (e.g., 'tom_issues' from
  /// 'al-the-bear/tom_issues').
  static String? getRepoName(String repoString) {
    final parts = repoString.split('/');
    if (parts.length != 2) return null;
    return parts[1];
  }

  /// Get owner from issues repo.
  String? get issuesOwner => getOwner(issuesRepo);

  /// Get repo name from issues repo.
  String? get issuesRepoName => getRepoName(issuesRepo);

  /// Get owner from tests repo.
  String? get testsOwner => getOwner(testsRepo);

  /// Get repo name from tests repo.
  String? get testsRepoName => getRepoName(testsRepo);
}

/// Project configuration from tom_project.yaml.
class ProjectConfig {
  /// Constructor.
  const ProjectConfig({
    required this.projectId,
    this.projectName,
  });

  /// The project ID (2-4 uppercase characters, e.g., 'D4', 'BK', 'IK').
  final String projectId;

  /// The full project name.
  final String? projectName;

  /// Parse from a map (from YAML).
  static ProjectConfig? tryParse(Map<String, dynamic>? map) {
    if (map == null) return null;

    final projectId = map['project_id'] as String?;
    if (projectId == null) return null;

    return ProjectConfig(
      projectId: projectId,
      projectName: map['name'] as String?,
    );
  }

  /// Validate the project ID format.
  ///
  /// Returns true if the ID is 2-4 uppercase characters.
  bool get isValidProjectId {
    if (projectId.length < 2 || projectId.length > 4) return false;
    return RegExp(r'^[A-Z0-9]+$').hasMatch(projectId);
  }
}

/// GitHub authentication configuration.
class GitHubAuthConfig {
  /// Constructor.
  const GitHubAuthConfig({
    this.token,
    this.tokenFile,
    this.envVariable = 'GITHUB_TOKEN',
  });

  /// Direct token value (not recommended for storage in config files).
  final String? token;

  /// Path to a file containing the token.
  final String? tokenFile;

  /// Environment variable name to check for token (default: GITHUB_TOKEN).
  final String envVariable;

  /// Parse from a map (from YAML).
  static GitHubAuthConfig? tryParse(Map<String, dynamic>? map) {
    if (map == null) return GitHubAuthConfig();

    return GitHubAuthConfig(
      token: map['token'] as String?,
      tokenFile: map['token_file'] as String?,
      envVariable: (map['env_variable'] as String?) ?? 'GITHUB_TOKEN',
    );
  }

  /// Resolve the actual token value.
  ///
  /// Resolution order:
  /// 1. Direct token value (if set)
  /// 2. Environment variable (GITHUB_TOKEN by default)
  /// 3. Token file contents (if file exists)
  ///
  /// Returns null if no token can be resolved.
  String? resolveToken() {
    // 1. Direct token
    if (token != null && token!.isNotEmpty) {
      return token;
    }

    // 2. Environment variable
    final envToken = Platform.environment[envVariable];
    if (envToken != null && envToken.isNotEmpty) {
      return envToken;
    }

    // 3. Token file
    if (tokenFile != null) {
      final file = File(tokenFile!);
      if (file.existsSync()) {
        final contents = file.readAsStringSync().trim();
        if (contents.isNotEmpty) {
          return contents;
        }
      }
    }

    return null;
  }
}

/// Complete issuekit configuration.
class IssueKitConfig {
  /// Constructor.
  const IssueKitConfig({
    this.issueTracking,
    this.auth,
    this.projectConfigs = const {},
  });

  /// Issue tracking configuration from tom_workspace.yaml.
  final IssueTrackingConfig? issueTracking;

  /// GitHub authentication configuration.
  final GitHubAuthConfig? auth;

  /// Project configurations by project path.
  final Map<String, ProjectConfig> projectConfigs;

  /// Check if the configuration is valid for issuekit operations.
  bool get isValid => issueTracking != null;

  /// Get the resolved GitHub token.
  String? get token => auth?.resolveToken();

  /// Load configuration from a workspace root.
  ///
  /// Reads tom_workspace.yaml for issue_tracking configuration.
  static Future<IssueKitConfig> load(String workspaceRoot) async {
    final workspaceYaml = File(path.join(workspaceRoot, 'tom_workspace.yaml'));

    IssueTrackingConfig? issueTracking;
    GitHubAuthConfig? auth;

    if (workspaceYaml.existsSync()) {
      final contents = await workspaceYaml.readAsString();
      final yaml = _parseYaml(contents);

      if (yaml is Map<String, dynamic>) {
        issueTracking = IssueTrackingConfig.tryParse(
          yaml['issue_tracking'] as Map<String, dynamic>?,
        );
        auth = GitHubAuthConfig.tryParse(
          yaml['github_auth'] as Map<String, dynamic>?,
        );
      }
    }

    // If no auth config, use defaults
    auth ??= const GitHubAuthConfig();

    return IssueKitConfig(
      issueTracking: issueTracking,
      auth: auth,
    );
  }

  /// Load project configuration from a project directory.
  ///
  /// Reads tom_project.yaml for project_id.
  static Future<ProjectConfig?> loadProject(String projectPath) async {
    final projectYaml = File(path.join(projectPath, 'tom_project.yaml'));

    if (!projectYaml.existsSync()) {
      return null;
    }

    final contents = await projectYaml.readAsString();
    final yaml = _parseYaml(contents);

    if (yaml is Map<String, dynamic>) {
      return ProjectConfig.tryParse(yaml);
    }

    return null;
  }

  /// Simple YAML parser for basic key-value structures.
  ///
  /// This is a basic implementation that handles simple nested maps.
  /// For production, consider using the yaml package.
  static dynamic _parseYaml(String contents) {
    final result = <String, dynamic>{};
    Map<String, dynamic>? currentSection;

    final lines = contents.split('\n');

    for (final line in lines) {
      // Skip empty lines and comments
      if (line.trim().isEmpty || line.trim().startsWith('#')) {
        continue;
      }

      // Count leading spaces
      final leadingSpaces = line.length - line.trimLeft().length;
      final trimmedLine = line.trim();

      // Check if this is a section header (ends with :)
      if (trimmedLine.endsWith(':') && !trimmedLine.contains(': ')) {
        final key = trimmedLine.substring(0, trimmedLine.length - 1);
        if (leadingSpaces == 0) {
          // Top-level section
          currentSection = <String, dynamic>{};
          result[key] = currentSection;
        } else if (currentSection != null) {
          // Nested section
          final nestedSection = <String, dynamic>{};
          currentSection[key] = nestedSection;
        }
      } else if (trimmedLine.contains(': ')) {
        // Key-value pair
        final colonIndex = trimmedLine.indexOf(': ');
        final key = trimmedLine.substring(0, colonIndex);
        var value = trimmedLine.substring(colonIndex + 2);

        // Remove quotes if present
        if ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'"))) {
          value = value.substring(1, value.length - 1);
        }

        // Parse value type
        dynamic parsedValue;
        if (value.toLowerCase() == 'true') {
          parsedValue = true;
        } else if (value.toLowerCase() == 'false') {
          parsedValue = false;
        } else if (int.tryParse(value) != null) {
          parsedValue = int.parse(value);
        } else if (double.tryParse(value) != null) {
          parsedValue = double.parse(value);
        } else {
          parsedValue = value;
        }

        if (leadingSpaces > 0 && currentSection != null) {
          currentSection[key] = parsedValue;
        } else {
          result[key] = parsedValue;
        }
      }
    }

    return result;
  }
}
