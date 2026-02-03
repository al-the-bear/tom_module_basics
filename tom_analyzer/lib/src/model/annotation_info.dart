part of 'model.dart';

class AnnotationInfo {
  final String name;
  final String qualifiedName;
  final String? constructorName;
  final Map<String, ArgumentValue> namedArguments;
  final List<ArgumentValue> positionalArguments;

  const AnnotationInfo({
    required this.name,
    required this.qualifiedName,
    this.constructorName,
    this.namedArguments = const {},
    this.positionalArguments = const [],
  });
}

class ArgumentValue {
  final Object? value;

  const ArgumentValue(this.value);

  @override
  String toString() => value?.toString() ?? 'null';
}
