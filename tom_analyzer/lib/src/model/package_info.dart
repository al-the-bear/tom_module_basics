part of 'model.dart';

class PackageInfo extends ContainerElement {
  @override
  final String id;

  @override
  final String name;

  @override
  final String? documentation;

  @override
  final List<AnnotationInfo> annotations;

  final String? version;
  final String rootPath;
  final List<LibraryInfo> libraries;
  final Map<String, PackageInfo> dependencies;
  final Map<String, PackageInfo> devDependencies;
  final bool isRoot;
  final Map<String, dynamic>? pubspecMetadata;
  final AnalysisResult analysisResult;

  PackageInfo({
    required this.id,
    required this.name,
    required this.rootPath,
    required this.analysisResult,
    this.documentation,
    this.annotations = const [],
    this.version,
    this.libraries = const [],
    this.dependencies = const {},
    this.devDependencies = const {},
    this.isRoot = false,
    this.pubspecMetadata,
  });
}
