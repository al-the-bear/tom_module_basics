import 'package:tom_build_kit/src/commands/gitstash_tool.dart';

void main(List<String> args) async {
  final tool = GitStashTool()..autoInnerFirst = true;
  await tool.run(args);
}
