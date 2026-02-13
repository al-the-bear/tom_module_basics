/// Unit tests for issuekit configuration loading.
@TestOn('vm')
library;

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:tom_issue_kit/src/config/issuekit_config.dart';

void main() {
  group('IK-CFG-1: IssueTrackingConfig [2026-02-13]', () {
    test('IK-CFG-1: Parse valid config', () {
      final config = IssueTrackingConfig.tryParse({
        'issues_repo': 'al-the-bear/tom_issues',
        'tests_repo': 'al-the-bear/tom_tests',
        'default_severity': 'high',
        'default_reporter': 'alexis',
      });

      expect(config, isNotNull);
      expect(config!.issuesRepo, 'al-the-bear/tom_issues');
      expect(config.testsRepo, 'al-the-bear/tom_tests');
      expect(config.defaultSeverity, 'high');
      expect(config.defaultReporter, 'alexis');
    });

    test('IK-CFG-2: Parse config with defaults', () {
      final config = IssueTrackingConfig.tryParse({
        'issues_repo': 'owner/issues',
        'tests_repo': 'owner/tests',
      });

      expect(config, isNotNull);
      expect(config!.defaultSeverity, 'normal');
      expect(config.defaultReporter, isNull);
    });

    test('IK-CFG-3: Return null for missing required fields', () {
      expect(IssueTrackingConfig.tryParse(null), isNull);
      expect(IssueTrackingConfig.tryParse({}), isNull);
      expect(
        IssueTrackingConfig.tryParse({'issues_repo': 'owner/repo'}),
        isNull,
      );
      expect(
        IssueTrackingConfig.tryParse({'tests_repo': 'owner/repo'}),
        isNull,
      );
    });

    test('IK-CFG-4: Extract owner and repo name from repo string', () {
      expect(
        IssueTrackingConfig.getOwner('al-the-bear/tom_issues'),
        'al-the-bear',
      );
      expect(
        IssueTrackingConfig.getRepoName('al-the-bear/tom_issues'),
        'tom_issues',
      );
      expect(IssueTrackingConfig.getOwner('invalid'), isNull);
      expect(IssueTrackingConfig.getRepoName('invalid'), isNull);
    });

    test('IK-CFG-5: Owner and repo accessors on config', () {
      final config = IssueTrackingConfig(
        issuesRepo: 'al-the-bear/tom_issues',
        testsRepo: 'al-the-bear/tom_tests',
      );

      expect(config.issuesOwner, 'al-the-bear');
      expect(config.issuesRepoName, 'tom_issues');
      expect(config.testsOwner, 'al-the-bear');
      expect(config.testsRepoName, 'tom_tests');
    });
  });

  group('IK-CFG-2: ProjectConfig [2026-02-13]', () {
    test('IK-CFG-6: Parse valid project config', () {
      final config = ProjectConfig.tryParse({
        'project_id': 'D4',
        'name': 'Tom D4rt',
      });

      expect(config, isNotNull);
      expect(config!.projectId, 'D4');
      expect(config.projectName, 'Tom D4rt');
    });

    test('IK-CFG-7: Return null for missing project_id', () {
      expect(ProjectConfig.tryParse(null), isNull);
      expect(ProjectConfig.tryParse({}), isNull);
      expect(ProjectConfig.tryParse({'name': 'Test'}), isNull);
    });

    test('IK-CFG-8: Validate project ID format', () {
      expect(ProjectConfig(projectId: 'D4').isValidProjectId, isTrue);
      expect(ProjectConfig(projectId: 'ABC').isValidProjectId, isTrue);
      expect(ProjectConfig(projectId: 'ABCD').isValidProjectId, isTrue);
      expect(ProjectConfig(projectId: 'D4G').isValidProjectId, isTrue);

      // Invalid: too short, too long, lowercase
      expect(ProjectConfig(projectId: 'A').isValidProjectId, isFalse);
      expect(ProjectConfig(projectId: 'ABCDE').isValidProjectId, isFalse);
      expect(ProjectConfig(projectId: 'd4').isValidProjectId, isFalse);
      expect(ProjectConfig(projectId: 'D-4').isValidProjectId, isFalse);
    });
  });

  group('IK-CFG-3: GitHubAuthConfig [2026-02-13]', () {
    test('IK-CFG-9: Resolve token from direct value', () {
      final config = GitHubAuthConfig(
        token: 'ghp_test_token',
      );

      expect(config.resolveToken(), 'ghp_test_token');
    });

    test('IK-CFG-10: Resolve token from environment variable', () {
      // This test uses the default GITHUB_TOKEN env var
      // If set in the environment, it should resolve
      final config = GitHubAuthConfig();
      final token = config.resolveToken();
      // Token may or may not be set, just ensure no error
      expect(token, isA<String?>());
    });

    test('IK-CFG-11: Resolve token from file', () async {
      // Create a temp file with a token
      final tempDir = Directory.systemTemp.createTempSync('issuekit_test_');
      final tokenFile = File(path.join(tempDir.path, 'token.txt'));
      await tokenFile.writeAsString('ghp_file_token\n');

      try {
        final config = GitHubAuthConfig(
          tokenFile: tokenFile.path,
        );

        expect(config.resolveToken(), 'ghp_file_token');
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('IK-CFG-12: Return null when no token available', () {
      final config = GitHubAuthConfig(
        envVariable: 'NONEXISTENT_VAR_FOR_TEST_${DateTime.now().millisecondsSinceEpoch}',
        tokenFile: '/nonexistent/path/token.txt',
      );

      expect(config.resolveToken(), isNull);
    });

    test('IK-CFG-13: Parse from map with defaults', () {
      final config = GitHubAuthConfig.tryParse(null);
      expect(config, isNotNull);
      expect(config!.envVariable, 'GITHUB_TOKEN');
    });

    test('IK-CFG-14: Parse from map with custom values', () {
      final config = GitHubAuthConfig.tryParse({
        'token': 'ghp_direct',
        'token_file': '/path/to/token',
        'env_variable': 'CUSTOM_TOKEN_VAR',
      });

      expect(config, isNotNull);
      expect(config!.token, 'ghp_direct');
      expect(config.tokenFile, '/path/to/token');
      expect(config.envVariable, 'CUSTOM_TOKEN_VAR');
    });
  });

  group('IK-CFG-4: IssueKitConfig [2026-02-13]', () {
    test('IK-CFG-15: isValid returns true when issueTracking is set', () {
      final config = IssueKitConfig(
        issueTracking: IssueTrackingConfig(
          issuesRepo: 'owner/issues',
          testsRepo: 'owner/tests',
        ),
      );

      expect(config.isValid, isTrue);
    });

    test('IK-CFG-16: isValid returns false when issueTracking is null', () {
      const config = IssueKitConfig();
      expect(config.isValid, isFalse);
    });

    test('IK-CFG-17: Load from workspace directory', () async {
      // Create a temp workspace with tom_workspace.yaml
      final tempDir = Directory.systemTemp.createTempSync('issuekit_ws_');
      final workspaceYaml = File(path.join(tempDir.path, 'tom_workspace.yaml'));

      await workspaceYaml.writeAsString('''
issue_tracking:
  issues_repo: test-owner/test-issues
  tests_repo: test-owner/test-tests
  default_severity: high
''');

      try {
        final config = await IssueKitConfig.load(tempDir.path);

        expect(config.isValid, isTrue);
        expect(config.issueTracking!.issuesRepo, 'test-owner/test-issues');
        expect(config.issueTracking!.testsRepo, 'test-owner/test-tests');
        expect(config.issueTracking!.defaultSeverity, 'high');
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('IK-CFG-18: Load project config from project directory', () async {
      final tempDir = Directory.systemTemp.createTempSync('issuekit_proj_');
      final projectYaml = File(path.join(tempDir.path, 'tom_project.yaml'));

      await projectYaml.writeAsString('''
project_id: IK
name: Tom Issue Kit
''');

      try {
        final config = await IssueKitConfig.loadProject(tempDir.path);

        expect(config, isNotNull);
        expect(config!.projectId, 'IK');
        expect(config.projectName, 'Tom Issue Kit');
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('IK-CFG-19: Return null when project yaml missing', () async {
      final tempDir = Directory.systemTemp.createTempSync('issuekit_empty_');

      try {
        final config = await IssueKitConfig.loadProject(tempDir.path);
        expect(config, isNull);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
