// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/element/element.dart' as analyzer;
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart' as analyzer_types;

import '../model/model.dart';
import '../serialization/id_generator.dart';

/// Resolves analyzer Dart types into model [TypeReference] values.
class TypeResolver {
  final IdGenerator idGenerator;
  final TypeDeclaration? Function(analyzer.Element element)? resolveElement;

  TypeResolver({
    required this.idGenerator,
    this.resolveElement,
  });

  TypeReference resolve(analyzer_types.DartType type) {
    if (type is analyzer_types.FunctionType) {
      return TypeReference(
        id: idGenerator.nextId('type'),
        name: type.getDisplayString(withNullability: true),
        qualifiedName: type.getDisplayString(withNullability: true),
        isFunction: true,
        isNullable: type.nullabilitySuffix == NullabilitySuffix.question,
        functionType: FunctionTypeInfo(
          id: idGenerator.nextId('functionType'),
          returnType: resolve(type.returnType),
          typeParameters: type.typeFormals.map(_typeParameter).toList(),
          parameters: type.parameters.map(_parameter).toList(),
        ),
      );
    }

    if (type is analyzer_types.TypeParameterType) {
      return TypeReference(
        id: idGenerator.nextId('type'),
        name: type.getDisplayString(withNullability: true),
        qualifiedName: type.getDisplayString(withNullability: true),
        isTypeParameter: true,
        typeParameterBound: resolve(type.bound),
      );
    }

    if (type is analyzer_types.InterfaceType) {
      final element = type.element;
      final qualified = _qualifiedName(element);
      final resolved = resolveElement?.call(element);
      return TypeReference(
        id: idGenerator.nextId('type'),
        name: element.name,
        qualifiedName: qualified,
        typeArguments: type.typeArguments.map(resolve).toList(),
        isNullable: type.nullabilitySuffix == NullabilitySuffix.question,
        resolvedElement: resolved,
      );
    }

    return TypeReference(
      id: idGenerator.nextId('type'),
      name: type.getDisplayString(withNullability: true),
      qualifiedName: type.getDisplayString(withNullability: true),
      isDynamic: type is analyzer_types.DynamicType,
      isVoid: type is analyzer_types.VoidType,
    );
  }

  TypeParameterInfo _typeParameter(analyzer.TypeParameterElement element) {
    return TypeParameterInfo(
      id: idGenerator.nextId('typeParam'),
      name: element.name,
      bound: element.bound != null ? resolve(element.bound!) : null,
    );
  }

  ParameterInfo _parameter(analyzer.ParameterElement element) {
    return ParameterInfo(
      id: idGenerator.nextId('param'),
      name: element.name,
      type: resolve(element.type),
      isRequired: element.isRequiredNamed || element.isRequiredPositional,
      isNamed: element.isNamed,
      isPositional: element.isPositional,
      hasDefaultValue: element.hasDefaultValue,
      defaultValue: element.defaultValueCode,
    );
  }

  String _qualifiedName(analyzer.Element element) {
    final libraryUri = element.librarySource?.uri.toString() ?? '';
    final name = element.displayName;
    return '$libraryUri.$name';
  }
}
