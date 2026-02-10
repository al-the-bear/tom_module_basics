import 'package:tom_build_kit/src/commands/gitprune_tool.dart';

void main(List<String> args) async {
  final tool = GitPruneTool()..autoOuterFirst = true;
  await tool.run(args);
}
