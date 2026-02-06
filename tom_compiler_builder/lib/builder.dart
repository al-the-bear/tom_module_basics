import 'package:build/build.dart';

import 'src/compiler_builder.dart';

/// Builder factory function for build_runner integration
Builder compilerBuilder(BuilderOptions options) {
  final config = CompilerBuilderConfig.fromOptions(options.config);
  return CompilerBuilder(config);
}
