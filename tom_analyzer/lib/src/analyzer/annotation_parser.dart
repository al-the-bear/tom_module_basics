// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/element/element.dart';

import '../model/model.dart';

/// Parses analyzer annotations into model representations.
class AnnotationParser {
  List<AnnotationInfo> parseAll(Iterable<ElementAnnotation> annotations) {
    return annotations.map(_parse).toList();
  }

  AnnotationInfo _parse(ElementAnnotation annotation) {
    final element = annotation.element;
    final name = element?.displayName ?? annotation.toSource();
    final libraryUri = element?.librarySource?.uri.toString();
    final qualifiedName = libraryUri == null ? name : '$libraryUri.$name';

    return AnnotationInfo(
      name: name,
      qualifiedName: qualifiedName,
    );
  }
}
