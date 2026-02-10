import 'package:tom_build_kit/src/commands/gitunstash_tool.dart';

void main(List<String> args) async {
  final tool = GitUnstashTool()..autoOuterFirst = true;
  await tool.run(args);
}
