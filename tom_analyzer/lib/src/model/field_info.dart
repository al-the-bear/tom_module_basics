part of 'model.dart';

/// Represents a field declaration.
class FieldInfo extends VariableElement {
  @override
  final String id;

  @override
  final String name;

  @override
  final String qualifiedName;

  final TypeDeclaration? declaringType;
  final LibraryInfo? owningLibrary;

  @override
  LibraryInfo get library => declaringType?.library ?? owningLibrary!;

  @override
  final FileInfo sourceFile;

  @override
  final SourceLocation location;

  @override
  final String? documentation;

  @override
  final List<AnnotationInfo> annotations;

  @override
  final TypeReference type;

  @override
  final bool isFinal;

  @override
  final bool isConst;

  @override
  final bool isLate;

  @override
  final bool isStatic;

  final bool hasInitializer;

  FieldInfo({
    required this.id,
    required this.name,
    required this.qualifiedName,
    this.declaringType,
    this.owningLibrary,
    required this.sourceFile,
    required this.location,
    required this.type,
    this.documentation,
    this.annotations = const [],
    this.isFinal = false,
    this.isConst = false,
    this.isLate = false,
    this.isStatic = false,
    this.hasInitializer = false,
  });
}
