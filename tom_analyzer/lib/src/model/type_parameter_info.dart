part of 'model.dart';

enum TypeParameterVariance {
  covariant,
  contravariant,
  invariant,
}

class TypeParameterInfo {
  final String id;
  final String name;
  final TypeReference? bound;
  final TypeReference? defaultType;
  final TypeParameterVariance? variance;

  const TypeParameterInfo({
    required this.id,
    required this.name,
    this.bound,
    this.defaultType,
    this.variance,
  });
}
