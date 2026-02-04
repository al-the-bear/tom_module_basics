import '../model/model.dart';
import 'reflection_model.dart';

/// Generates reflection code from analysis results.
class ReflectionGenerator {
  String generate(ReflectionModel model) {
    final result = model.analysisResult;
    final buffer = StringBuffer();
    final libraries = result.libraries.values.toList()
      ..sort((a, b) => a.uri.toString().compareTo(b.uri.toString()));

    final importAliases = <Uri, String>{};
    var importIndex = 0;
    for (final library in libraries) {
      final uri = library.uri;
      if (!_canImport(uri)) {
        continue;
      }
      importAliases[uri] = 'lib${importIndex++}';
    }

    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// coverage:ignore-file');
    buffer.writeln("library tom_analyzer.reflection;");
    buffer.writeln();
    buffer.writeln("import 'package:tom_analyzer/tom_analyzer.dart' as ta;");
    for (final entry in importAliases.entries) {
      buffer.writeln("import '${entry.key}' as ${entry.value};");
    }
    buffer.writeln();

    buffer.writeln('final _classes = <String, ta.ClassDescriptor>{');
    for (final cls in result.allClasses..sort(_byQualifiedName)) {
      if (_isPrivate(cls.name) || !_canImport(cls.library.uri)) {
        continue;
      }
      buffer.writeln(_classDescriptor(cls, importAliases, result));
    }
    buffer.writeln('};');

    buffer.writeln('final _enums = <String, ta.MemberContainerDescriptor>{');
    for (final enm in result.allEnums..sort(_byQualifiedName)) {
      if (_isPrivate(enm.name) || !_canImport(enm.library.uri)) {
        continue;
      }
      buffer.writeln(_memberContainer(enm, TypeKindWrapper.enumType, importAliases));
    }
    buffer.writeln('};');

    buffer.writeln('final _mixins = <String, ta.MemberContainerDescriptor>{');
    for (final mix in result.allMixins..sort(_byQualifiedName)) {
      if (_isPrivate(mix.name) || !_canImport(mix.library.uri)) {
        continue;
      }
      buffer.writeln(_memberContainer(mix, TypeKindWrapper.mixinType, importAliases));
    }
    buffer.writeln('};');

    buffer.writeln('final _extensions = <String, ta.ExtensionDescriptor>{');
    for (final ext in result.allExtensions..sort(_byQualifiedName)) {
      if (_isPrivate(ext.name) || !_canImport(ext.library.uri)) {
        continue;
      }
      buffer.writeln(_extensionDescriptor(ext, importAliases));
    }
    buffer.writeln('};');

    buffer.writeln('final _extensionTypes = <String, ta.MemberContainerDescriptor>{');
    for (final extType in result.allExtensionTypes..sort(_byQualifiedName)) {
      if (_isPrivate(extType.name) || !_canImport(extType.library.uri)) {
        continue;
      }
      buffer.writeln(_memberContainer(extType, TypeKindWrapper.extensionType, importAliases));
    }
    buffer.writeln('};');

    buffer.writeln('final _typeAliases = <String, ta.TypeAliasDescriptor>{');
    for (final alias in result.allTypeAliases..sort(_byQualifiedName)) {
      if (_isPrivate(alias.name) || !_canImport(alias.library.uri)) {
        continue;
      }
      buffer.writeln(_typeAliasDescriptor(alias));
    }
    buffer.writeln('};');

    buffer.writeln('final _globals = <String, ta.GlobalDescriptor>{');
    for (final library in libraries) {
      if (!_canImport(library.uri)) {
        continue;
      }
      final alias = importAliases[library.uri];
      if (alias == null) {
        continue;
      }

      for (final variable in library.variables..sort(_byName)) {
        if (_isPrivate(variable.name)) {
          continue;
        }
        buffer.writeln(_globalVariable(variable, alias));
      }
      for (final getter in library.getters..sort(_byName)) {
        if (_isPrivate(getter.name)) {
          continue;
        }
        buffer.writeln(_globalGetter(getter, alias));
      }
      for (final setter in library.setters..sort(_byName)) {
        if (_isPrivate(setter.name)) {
          continue;
        }
        buffer.writeln(_globalSetter(setter, alias));
      }
      for (final function in library.functions..sort(_byName)) {
        if (_isPrivate(function.name)) {
          continue;
        }
        buffer.writeln(_globalFunction(function, alias));
      }
    }
    buffer.writeln('};');

    buffer.writeln('final reflectionApi = ta.ReflectionApi(');
    buffer.writeln('  classesByQualifiedName: _classes,');
    buffer.writeln('  enumsByQualifiedName: _enums,');
    buffer.writeln('  mixinsByQualifiedName: _mixins,');
    buffer.writeln('  extensionsByQualifiedName: _extensions,');
    buffer.writeln('  extensionTypesByQualifiedName: _extensionTypes,');
    buffer.writeln('  typeAliasesByQualifiedName: _typeAliases,');
    buffer.writeln('  globalsByQualifiedName: _globals,');
    buffer.writeln(');');

    return buffer.toString();
  }

  String _classDescriptor(
    ClassInfo cls,
    Map<Uri, String> importAliases,
    AnalysisResult result,
  ) {
    final alias = importAliases[cls.library.uri]!;
    final qualifiedName = cls.qualifiedName;
    final constructors = <String>[
      for (final ctor in cls.constructors..sort(_byName))
        if (!_isPrivate(ctor.name)) _constructorDescriptor(ctor, alias, cls.name),
    ];

    final methods = _methodMap(cls.methods, alias, cls.name, isStatic: false);
    final staticMethods = _methodMap(cls.methods, alias, cls.name, isStatic: true);
    final fields = _fieldMap(cls.fields, alias, cls.name, isStatic: false);
    final staticFields = _fieldMap(cls.fields, alias, cls.name, isStatic: true);
    final getters = _getterMap(cls.getters, alias, cls.name, isStatic: false);
    final staticGetters = _getterMap(cls.getters, alias, cls.name, isStatic: true);
    final setters = _setterMap(cls.setters, alias, cls.name, isStatic: false);
    final staticSetters = _setterMap(cls.setters, alias, cls.name, isStatic: true);

    final appliedExtensions = _appliedExtensions(cls, result);

    return "'${_escape(qualifiedName)}': ta.ClassDescriptor(\n"
        "  name: '${_escape(cls.name)}',\n"
        "  qualifiedName: '${_escape(qualifiedName)}',\n"
        "  libraryUri: '${_escape(cls.library.uri.toString())}',\n"
        "  package: '${_escape(cls.library.package.name)}',\n"
        "  annotations: ${_annotationList(cls.annotations)},\n"
        "  typeParameters: ${_typeParameterList(cls.typeParameters)},\n"
        "  methods: $methods,\n"
        "  staticMethods: $staticMethods,\n"
        "  fields: $fields,\n"
        "  staticFields: $staticFields,\n"
        "  getters: $getters,\n"
        "  staticGetters: $staticGetters,\n"
        "  setters: $setters,\n"
        "  staticSetters: $staticSetters,\n"
        "  superclassQualifiedName: ${_stringOrNull(cls.superclass?.qualifiedName)},\n"
        "  interfaceQualifiedNames: ${_stringList(cls.interfaces.map((e) => e.qualifiedName))},\n"
        "  mixinQualifiedNames: ${_stringList(cls.mixins.map((e) => e.qualifiedName))},\n"
        "  appliedExtensionQualifiedNames: $appliedExtensions,\n"
        "  constructors: <String, ta.ConstructorDescriptor>{\n${constructors.join()}  },\n"
        "  isInstance: (Object instance) => instance is $alias.${cls.name},\n"
        "),";
  }

  String _memberContainer(
    TypeDeclaration type,
    TypeKindWrapper kind,
    Map<Uri, String> importAliases,
  ) {
    final alias = importAliases[type.library.uri]!;
    final methods = type is ClassInfo
        ? _methodMap(type.methods, alias, type.name, isStatic: false)
        : type is EnumInfo
            ? _methodMap(type.methods, alias, type.name, isStatic: false)
            : type is MixinInfo
                ? _methodMap(type.methods, alias, type.name, isStatic: false)
                : type is ExtensionInfo
                    ? _methodMap(type.methods, alias, type.name, isStatic: false)
                    : type is ExtensionTypeInfo
                        ? _methodMap(type.methods, alias, type.name, isStatic: false)
                        : 'const {}';
    final staticMethods = type is ClassInfo
        ? _methodMap(type.methods, alias, type.name, isStatic: true)
        : 'const {}';

    final fields = type is ClassInfo
        ? _fieldMap(type.fields, alias, type.name, isStatic: false)
        : type is EnumInfo
            ? _fieldMap(type.fields, alias, type.name, isStatic: false)
            : type is MixinInfo
                ? _fieldMap(type.fields, alias, type.name, isStatic: false)
                : type is ExtensionInfo
                    ? _fieldMap(type.fields, alias, type.name, isStatic: false)
                    : type is ExtensionTypeInfo
                        ? _fieldMap(type.fields, alias, type.name, isStatic: false)
                        : 'const {}';
    final staticFields = type is ClassInfo
        ? _fieldMap(type.fields, alias, type.name, isStatic: true)
        : 'const {}';
    final getters = type is ClassInfo
        ? _getterMap(type.getters, alias, type.name, isStatic: false)
        : type is EnumInfo
            ? _getterMap(type.getters, alias, type.name, isStatic: false)
            : type is MixinInfo
                ? _getterMap(type.getters, alias, type.name, isStatic: false)
                : type is ExtensionInfo
                    ? _getterMap(type.getters, alias, type.name, isStatic: false)
                    : type is ExtensionTypeInfo
                        ? _getterMap(type.getters, alias, type.name, isStatic: false)
                        : 'const {}';
    final staticGetters = type is ClassInfo
        ? _getterMap(type.getters, alias, type.name, isStatic: true)
        : 'const {}';
    final setters = type is ClassInfo
        ? _setterMap(type.setters, alias, type.name, isStatic: false)
        : type is EnumInfo
            ? _setterMap(type.setters, alias, type.name, isStatic: false)
            : type is MixinInfo
                ? _setterMap(type.setters, alias, type.name, isStatic: false)
                : type is ExtensionInfo
                    ? _setterMap(type.setters, alias, type.name, isStatic: false)
                    : type is ExtensionTypeInfo
                        ? _setterMap(type.setters, alias, type.name, isStatic: false)
                        : 'const {}';
    final staticSetters = type is ClassInfo
        ? _setterMap(type.setters, alias, type.name, isStatic: true)
        : 'const {}';

    return "'${_escape(type.qualifiedName)}': ta.MemberContainerDescriptor(\n"
        "  kind: ta.TypeKind.${kind.name},\n"
        "  name: '${_escape(type.name)}',\n"
        "  qualifiedName: '${_escape(type.qualifiedName)}',\n"
        "  libraryUri: '${_escape(type.library.uri.toString())}',\n"
        "  package: '${_escape(type.library.package.name)}',\n"
        "  annotations: ${_annotationList(type.annotations)},\n"
        "  typeParameters: ${_typeParameterList(_typeParametersFor(type))},\n"
        "  methods: $methods,\n"
        "  staticMethods: $staticMethods,\n"
        "  fields: $fields,\n"
        "  staticFields: $staticFields,\n"
        "  getters: $getters,\n"
        "  staticGetters: $staticGetters,\n"
        "  setters: $setters,\n"
        "  staticSetters: $staticSetters,\n"
        "),";
  }

  String _extensionDescriptor(
    ExtensionInfo ext,
    Map<Uri, String> importAliases,
  ) {
    final methods = _methodMapMetadataOnly(ext.methods);
    final fields = _fieldMapMetadataOnly(ext.fields);
    final getters = _getterMapMetadataOnly(ext.getters);
    final setters = _setterMapMetadataOnly(ext.setters);

    return "'${_escape(ext.qualifiedName)}': ta.ExtensionDescriptor(\n"
        "  name: '${_escape(ext.name)}',\n"
        "  qualifiedName: '${_escape(ext.qualifiedName)}',\n"
        "  libraryUri: '${_escape(ext.library.uri.toString())}',\n"
        "  package: '${_escape(ext.library.package.name)}',\n"
        "  extendedTypeQualifiedName: '${_escape(ext.extendedType.qualifiedName)}',\n"
        "  annotations: ${_annotationList(ext.annotations)},\n"
        "  typeParameters: ${_typeParameterList(ext.typeParameters)},\n"
        "  methods: $methods,\n"
        "  fields: $fields,\n"
        "  getters: $getters,\n"
        "  setters: $setters,\n"
        "),";
  }

  String _typeAliasDescriptor(TypeAliasInfo alias) {
    return "'${_escape(alias.qualifiedName)}': ta.TypeAliasDescriptor(\n"
        "  name: '${_escape(alias.name)}',\n"
        "  qualifiedName: '${_escape(alias.qualifiedName)}',\n"
        "  libraryUri: '${_escape(alias.library.uri.toString())}',\n"
        "  package: '${_escape(alias.library.package.name)}',\n"
        "  aliasedTypeQualifiedName: '${_escape(alias.aliasedType.qualifiedName)}',\n"
        "  annotations: ${_annotationList(alias.annotations)},\n"
        "  typeParameters: ${_typeParameterList(alias.typeParameters)},\n"
        "),";
  }

  String _methodMap(
    List<MethodInfo> methods,
    String alias,
    String typeName, {
    required bool isStatic,
  }) {
    final entries = <String>[];
    for (final method in methods) {
      if (_isPrivate(method.name) || method.isStatic != isStatic) {
        continue;
      }
      entries.add(_methodDescriptor(method, alias, typeName));
    }
    if (entries.isEmpty) {
      return 'const {}';
    }
    return '<String, ta.MethodDescriptor>{\n${entries.join()}  }';
  }

  String _methodDescriptor(MethodInfo method, String alias, String typeName) {
    final invoker = method.isStatic
        ? '(List<dynamic> positional, Map<Symbol, dynamic> named) => '
            'Function.apply($alias.$typeName.${method.name}, positional, named)'
        : '(Object instance, List<dynamic> positional, Map<Symbol, dynamic> named) => '
            'Function.apply((instance as $alias.$typeName).${method.name}, positional, named)';

    return "  '${_escape(method.name)}': ta.MethodDescriptor(\n"
        "    name: '${_escape(method.name)}',\n"
        "    isStatic: ${method.isStatic},\n"
        "    typeParameters: ${_typeParameterList(method.typeParameters)},\n"
        "    parameters: ${_parameterList(method.parameters)},\n"
        "    annotations: ${_annotationList(method.annotations)},\n"
        "    invokeOn: ${method.isStatic ? 'null' : invoker},\n"
        "    invokeStatic: ${method.isStatic ? invoker : 'null'},\n"
        "  ),\n";
  }

  String _methodMapMetadataOnly(List<MethodInfo> methods) {
    final entries = <String>[];
    for (final method in methods) {
      if (_isPrivate(method.name)) {
        continue;
      }
      entries.add(_methodDescriptorMetadata(method));
    }
    if (entries.isEmpty) {
      return 'const {}';
    }
    return '<String, ta.MethodDescriptor>{\n${entries.join()}  }';
  }

  String _methodDescriptorMetadata(MethodInfo method) {
    return "  '${_escape(method.name)}': ta.MethodDescriptor(\n"
        "    name: '${_escape(method.name)}',\n"
        "    isStatic: ${method.isStatic},\n"
        "    typeParameters: ${_typeParameterList(method.typeParameters)},\n"
        "    parameters: ${_parameterList(method.parameters)},\n"
        "    annotations: ${_annotationList(method.annotations)},\n"
        "    invokeOn: null,\n"
        "    invokeStatic: null,\n"
        "  ),\n";
  }

  String _constructorDescriptor(ConstructorInfo ctor, String alias, String typeName) {
    final ctorName = ctor.name.isEmpty ? 'new' : ctor.name;
    final invoker = '(List<dynamic> positional, Map<Symbol, dynamic> named) => '
        'Function.apply($alias.$typeName.$ctorName, positional, named)';
    return "    '${_escape(ctor.name)}': ta.ConstructorDescriptor(\n"
        "      name: '${_escape(ctor.name)}',\n"
        "      isFactory: ${ctor.isFactory},\n"
        "      parameters: ${_parameterList(ctor.parameters)},\n"
        "      annotations: ${_annotationList(ctor.annotations)},\n"
        "      invoke: $invoker,\n"
        "    ),\n";
  }

  String _fieldMap(
    List<FieldInfo> fields,
    String alias,
    String typeName, {
    required bool isStatic,
  }) {
    final entries = <String>[];
    for (final field in fields) {
      if (_isPrivate(field.name) || field.isStatic != isStatic) {
        continue;
      }
      entries.add(_fieldDescriptor(field, alias, typeName));
    }
    if (entries.isEmpty) {
      return 'const {}';
    }
    return '<String, ta.FieldDescriptor>{\n${entries.join()}  }';
  }

  String _fieldDescriptor(FieldInfo field, String alias, String typeName) {
    final instanceGetter =
        '(Object instance) => (instance as $alias.$typeName).${field.name}';
    final instanceSetter = field.isFinal || field.isConst
        ? 'null'
        : '(Object instance, Object? value) { (instance as $alias.$typeName).${field.name} = value; return null; }';
    final staticGetter = '$alias.$typeName.${field.name}';
    final staticSetter = field.isFinal || field.isConst
        ? 'null'
        : '(Object? value) { $alias.$typeName.${field.name} = value; return null; }';

    return "  '${_escape(field.name)}': ta.FieldDescriptor(\n"
        "    name: '${_escape(field.name)}',\n"
        "    typeQualifiedName: '${_escape(field.type.qualifiedName)}',\n"
        "    isStatic: ${field.isStatic},\n"
        "    isFinal: ${field.isFinal},\n"
        "    isConst: ${field.isConst},\n"
        "    annotations: ${_annotationList(field.annotations)},\n"
        "    getInstance: ${field.isStatic ? 'null' : instanceGetter},\n"
        "    setInstance: ${field.isStatic ? 'null' : instanceSetter},\n"
        "    getStatic: ${field.isStatic ? '() => $staticGetter' : 'null'},\n"
        "    setStatic: ${field.isStatic ? staticSetter : 'null'},\n"
        "  ),\n";
  }

  String _fieldMapMetadataOnly(List<FieldInfo> fields) {
    final entries = <String>[];
    for (final field in fields) {
      if (_isPrivate(field.name)) {
        continue;
      }
      entries.add(_fieldDescriptorMetadata(field));
    }
    if (entries.isEmpty) {
      return 'const {}';
    }
    return '<String, ta.FieldDescriptor>{\n${entries.join()}  }';
  }

  String _fieldDescriptorMetadata(FieldInfo field) {
    return "  '${_escape(field.name)}': ta.FieldDescriptor(\n"
        "    name: '${_escape(field.name)}',\n"
        "    typeQualifiedName: '${_escape(field.type.qualifiedName)}',\n"
        "    isStatic: ${field.isStatic},\n"
        "    isFinal: ${field.isFinal},\n"
        "    isConst: ${field.isConst},\n"
        "    annotations: ${_annotationList(field.annotations)},\n"
        "    getInstance: null,\n"
        "    setInstance: null,\n"
        "    getStatic: null,\n"
        "    setStatic: null,\n"
        "  ),\n";
  }

  String _getterMap(
    List<GetterInfo> getters,
    String alias,
    String typeName, {
    required bool isStatic,
  }) {
    final entries = <String>[];
    for (final getter in getters) {
      if (_isPrivate(getter.name) || getter.isStatic != isStatic) {
        continue;
      }
      entries.add(_getterDescriptor(getter, alias, typeName));
    }
    if (entries.isEmpty) {
      return 'const {}';
    }
    return '<String, ta.GetterDescriptor>{\n${entries.join()}  }';
  }

  String _getterDescriptor(GetterInfo getter, String alias, String typeName) {
    final instanceGetter =
        '(Object instance) => (instance as $alias.$typeName).${getter.name}';
    final staticGetter = '$alias.$typeName.${getter.name}';

    return "  '${_escape(getter.name)}': ta.GetterDescriptor(\n"
        "    name: '${_escape(getter.name)}',\n"
        "    typeQualifiedName: '${_escape(getter.returnType.qualifiedName)}',\n"
        "    isStatic: ${getter.isStatic},\n"
        "    annotations: ${_annotationList(getter.annotations)},\n"
        "    getInstance: ${getter.isStatic ? 'null' : instanceGetter},\n"
        "    getStatic: ${getter.isStatic ? '() => $staticGetter' : 'null'},\n"
        "  ),\n";
  }

  String _getterMapMetadataOnly(List<GetterInfo> getters) {
    final entries = <String>[];
    for (final getter in getters) {
      if (_isPrivate(getter.name)) {
        continue;
      }
      entries.add(_getterDescriptorMetadata(getter));
    }
    if (entries.isEmpty) {
      return 'const {}';
    }
    return '<String, ta.GetterDescriptor>{\n${entries.join()}  }';
  }

  String _getterDescriptorMetadata(GetterInfo getter) {
    return "  '${_escape(getter.name)}': ta.GetterDescriptor(\n"
        "    name: '${_escape(getter.name)}',\n"
        "    typeQualifiedName: '${_escape(getter.returnType.qualifiedName)}',\n"
        "    isStatic: ${getter.isStatic},\n"
        "    annotations: ${_annotationList(getter.annotations)},\n"
        "    getInstance: null,\n"
        "    getStatic: null,\n"
        "  ),\n";
  }

  String _setterMap(
    List<SetterInfo> setters,
    String alias,
    String typeName, {
    required bool isStatic,
  }) {
    final entries = <String>[];
    for (final setter in setters) {
      if (_isPrivate(setter.name) || setter.isStatic != isStatic) {
        continue;
      }
      entries.add(_setterDescriptor(setter, alias, typeName));
    }
    if (entries.isEmpty) {
      return 'const {}';
    }
    return '<String, ta.SetterDescriptor>{\n${entries.join()}  }';
  }

  String _setterDescriptor(SetterInfo setter, String alias, String typeName) {
    final instanceSetter =
        '(Object instance, Object? value) { (instance as $alias.$typeName).${setter.name} = value; return null; }';
    final staticSetter =
        '(Object? value) { $alias.$typeName.${setter.name} = value; return null; }';

    return "  '${_escape(setter.name)}': ta.SetterDescriptor(\n"
        "    name: '${_escape(setter.name)}',\n"
        "    typeQualifiedName: '${_escape(setter.parameter.type.qualifiedName)}',\n"
        "    isStatic: ${setter.isStatic},\n"
        "    annotations: ${_annotationList(setter.annotations)},\n"
        "    setInstance: ${setter.isStatic ? 'null' : instanceSetter},\n"
        "    setStatic: ${setter.isStatic ? staticSetter : 'null'},\n"
        "  ),\n";
  }

  String _setterMapMetadataOnly(List<SetterInfo> setters) {
    final entries = <String>[];
    for (final setter in setters) {
      if (_isPrivate(setter.name)) {
        continue;
      }
      entries.add(_setterDescriptorMetadata(setter));
    }
    if (entries.isEmpty) {
      return 'const {}';
    }
    return '<String, ta.SetterDescriptor>{\n${entries.join()}  }';
  }

  String _setterDescriptorMetadata(SetterInfo setter) {
    return "  '${_escape(setter.name)}': ta.SetterDescriptor(\n"
        "    name: '${_escape(setter.name)}',\n"
        "    typeQualifiedName: '${_escape(setter.parameter.type.qualifiedName)}',\n"
        "    isStatic: ${setter.isStatic},\n"
        "    annotations: ${_annotationList(setter.annotations)},\n"
        "    setInstance: null,\n"
        "    setStatic: null,\n"
        "  ),\n";
  }

  String _globalVariable(VariableInfo variable, String alias) {
    final getter = '() => $alias.${variable.name}';
    final setter = variable.isFinal || variable.isConst
        ? 'null'
        : '(Object? value) { $alias.${variable.name} = value; return null; }';

    return "  '${_escape(variable.qualifiedName)}': ta.GlobalDescriptor(\n"
        "    kind: ta.GlobalKind.variable,\n"
        "    name: '${_escape(variable.name)}',\n"
        "    qualifiedName: '${_escape(variable.qualifiedName)}',\n"
        "    libraryUri: '${_escape(variable.library.uri.toString())}',\n"
        "    package: '${_escape(variable.library.package.name)}',\n"
        "    typeQualifiedName: '${_escape(variable.type.qualifiedName)}',\n"
        "    annotations: ${_annotationList(variable.annotations)},\n"
        "    getValue: $getter,\n"
        "    setValue: $setter,\n"
        "  ),\n";
  }

  String _globalGetter(GetterInfo getter, String alias) {
    return "  '${_escape(getter.qualifiedName)}': ta.GlobalDescriptor(\n"
        "    kind: ta.GlobalKind.getter,\n"
        "    name: '${_escape(getter.name)}',\n"
        "    qualifiedName: '${_escape(getter.qualifiedName)}',\n"
        "    libraryUri: '${_escape(getter.library.uri.toString())}',\n"
        "    package: '${_escape(getter.library.package.name)}',\n"
        "    typeQualifiedName: '${_escape(getter.returnType.qualifiedName)}',\n"
        "    annotations: ${_annotationList(getter.annotations)},\n"
        "    getValue: () => $alias.${getter.name},\n"
        "  ),\n";
  }

  String _globalSetter(SetterInfo setter, String alias) {
    return "  '${_escape(setter.qualifiedName)}': ta.GlobalDescriptor(\n"
        "    kind: ta.GlobalKind.setter,\n"
        "    name: '${_escape(setter.name)}',\n"
        "    qualifiedName: '${_escape(setter.qualifiedName)}',\n"
        "    libraryUri: '${_escape(setter.library.uri.toString())}',\n"
        "    package: '${_escape(setter.library.package.name)}',\n"
        "    typeQualifiedName: '${_escape(setter.parameter.type.qualifiedName)}',\n"
        "    annotations: ${_annotationList(setter.annotations)},\n"
        "    setValue: (Object? value) { $alias.${setter.name} = value; return null; },\n"
        "  ),\n";
  }

  String _globalFunction(FunctionInfo function, String alias) {
    return "  '${_escape(function.qualifiedName)}': ta.GlobalDescriptor(\n"
        "    kind: ta.GlobalKind.function,\n"
        "    name: '${_escape(function.name)}',\n"
        "    qualifiedName: '${_escape(function.qualifiedName)}',\n"
        "    libraryUri: '${_escape(function.library.uri.toString())}',\n"
        "    package: '${_escape(function.library.package.name)}',\n"
        "    typeQualifiedName: '${_escape(function.returnType.qualifiedName)}',\n"
        "    annotations: ${_annotationList(function.annotations)},\n"
        "    invokeFunction: (List<dynamic> positional, Map<Symbol, dynamic> named) => Function.apply($alias.${function.name}, positional, named),\n"
        "  ),\n";
  }

  String _annotationList(List<AnnotationInfo> annotations) {
    if (annotations.isEmpty) return 'const []';
    final entries = annotations.map(_annotationDescriptor).join(',\n');
    return '[\n$entries\n]';
  }

  String _annotationDescriptor(AnnotationInfo annotation) {
    return 'ta.AnnotationDescriptor('
        'name: \'${_escape(annotation.name)}\','
        'qualifiedName: \'${_escape(annotation.qualifiedName)}\','
        '${annotation.constructorName != null ? "constructorName: '${_escape(annotation.constructorName!)}'," : ''}'
        'positionalArguments: ${_literalList(annotation.positionalArguments.map((e) => e.value))},'
        'namedArguments: ${_literalMap(annotation.namedArguments.map((k, v) => MapEntry(k, v.value)))},'
        ')';
  }

  String _typeParameterList(List<TypeParameterInfo> typeParameters) {
    if (typeParameters.isEmpty) return 'const []';
    final entries = typeParameters.map((typeParam) {
      final variance = typeParam.variance?.name;
      return 'ta.TypeParameterDescriptor('
          "name: '${_escape(typeParam.name)}',"
          "boundQualifiedName: ${_stringOrNull(typeParam.bound?.qualifiedName)},"
          "variance: ${_stringOrNull(variance)}," 
          ')';
    }).join(',\n');
    return '[\n$entries\n]';
  }

  String _parameterList(List<ParameterInfo> parameters) {
    if (parameters.isEmpty) return 'const []';
    final entries = parameters.map((param) {
      return 'ta.ParameterDescriptor('
          "name: '${_escape(param.name)}',"
          "typeQualifiedName: '${_escape(param.type.qualifiedName)}',"
          'isRequired: ${param.isRequired},'
          'isNamed: ${param.isNamed},'
          'isPositional: ${param.isPositional},'
          'hasDefaultValue: ${param.hasDefaultValue},'
          'defaultValue: ${_literal(param.defaultValueParsed?.value ?? param.defaultValue)},'
          'annotations: ${_annotationList(param.annotations)},'
          ')';
    }).join(',\n');
    return '[\n$entries\n]';
  }

  String _appliedExtensions(ClassInfo cls, AnalysisResult result) {
    final matches = result.allExtensions
        .where((ext) => ext.extendedType.qualifiedName == cls.qualifiedName)
        .map((ext) => ext.qualifiedName);
    return _stringList(matches);
  }

  List<TypeParameterInfo> _typeParametersFor(TypeDeclaration type) {
    if (type is ClassInfo) return type.typeParameters;
    if (type is EnumInfo) return const [];
    if (type is MixinInfo) return type.typeParameters;
    if (type is ExtensionInfo) return type.typeParameters;
    if (type is ExtensionTypeInfo) return type.typeParameters;
    if (type is TypeAliasInfo) return type.typeParameters;
    return const [];
  }

  String _stringList(Iterable<String> values) {
    final list = values.toList()..sort();
    if (list.isEmpty) return 'const []';
    final entries = list.map((value) => "'${_escape(value)}'").join(', ');
    return '<String>[$entries]';
  }

  String _literalList(Iterable<Object?> values) {
    final entries = values.map(_literal).join(', ');
    return '<Object?>[$entries]';
  }

  String _literalMap(Map<String, Object?> values) {
    if (values.isEmpty) return 'const <String, Object?>{}';
    final entries = values.entries
        .map((entry) => "'${_escape(entry.key)}': ${_literal(entry.value)}")
        .join(', ');
    return '<String, Object?>{$entries}';
  }

  String _literal(Object? value) {
    if (value == null) return 'null';
    if (value is bool || value is int || value is double) {
      return value.toString();
    }
    if (value is String) {
      return "'${_escape(value)}'";
    }
    if (value is List) {
      return _literalList(value.cast<Object?>());
    }
    if (value is Map) {
      final mapped = value.map((key, val) => MapEntry(key.toString(), val));
      return _literalMap(mapped.cast<String, Object?>());
    }
    return "'${_escape(value.toString())}'";
  }

  String _stringOrNull(String? value) =>
      value == null ? 'null' : "'${_escape(value)}'";

  bool _canImport(Uri uri) => uri.scheme == 'package' || uri.scheme == 'dart';

  bool _isPrivate(String name) => name.startsWith('_');

  int _byQualifiedName(TypeDeclaration a, TypeDeclaration b) =>
      a.qualifiedName.compareTo(b.qualifiedName);

  int _byName(dynamic a, dynamic b) => a.name.compareTo(b.name);

  String _escape(String value) => value.replaceAll("'", r"\'");
}

enum TypeKindWrapper {
  enumType,
  mixinType,
  extensionType,
}
