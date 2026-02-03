part of 'model.dart';

class ClassStaticMembers {
  final List<MethodInfo> methods;
  final List<FieldInfo> fields;
  final List<GetterInfo> getters;
  final List<SetterInfo> setters;

  const ClassStaticMembers({
    required this.methods,
    required this.fields,
    required this.getters,
    required this.setters,
  });
}
