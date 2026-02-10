import 'package:tom_build_kit/tom_build_kit.dart';

void main(List<String> args) async {
  final tool = GitSquashTool()..autoInnerFirst = true;
  await tool.run(args);
}
