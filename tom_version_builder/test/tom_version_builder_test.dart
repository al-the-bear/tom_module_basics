import 'package:test/test.dart';
import 'package:tom_version_builder/tom_version_builder.dart';

void main() {
  group('VersionBuilderConfig', () {
    test('creates with required output path', () {
      final config = VersionBuilderConfig(output: 'lib/src/version.g.dart');

      expect(config.output, equals('lib/src/version.g.dart'));
      expect(config.includeGitCommit, isTrue);
    });

    test('creates with custom values', () {
      final config = VersionBuilderConfig(
        output: 'lib/version.dart',
        includeGitCommit: false,
      );

      expect(config.output, equals('lib/version.dart'));
      expect(config.includeGitCommit, isFalse);
    });
  });
}
