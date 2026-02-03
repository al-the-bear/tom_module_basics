part of 'model.dart';

sealed class Element {
  String get id;
  String get name;
  String? get documentation;
  List<AnnotationInfo> get annotations;

  bool hasAnnotation(String annotationName) {
    return annotations.any((annotation) => annotation.name == annotationName);
  }
}

sealed class ContainerElement extends Element {
  ContainerElement();
}

sealed class DeclarationElement extends Element {
  String get qualifiedName;
  LibraryInfo get library;
  FileInfo get sourceFile;
  SourceLocation get location;
}

sealed class TypeDeclaration extends DeclarationElement {
  @override
  LibraryInfo get library;
}

sealed class ExecutableElement extends DeclarationElement {
  bool get isAsync;
  bool get isExternal;
  bool get isStatic;
  List<ParameterInfo> get parameters;
}

sealed class VariableElement extends DeclarationElement {
  TypeReference get type;
  bool get isFinal;
  bool get isConst;
  bool get isLate;
  bool get isStatic;
}
