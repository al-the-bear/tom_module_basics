import 'package:tom_build_kit/tom_build_kit.dart';

void main(List<String> args) async {
  final tool = GitCompareTool()..autoInnerFirst = true;
  await tool.run(args);
}
