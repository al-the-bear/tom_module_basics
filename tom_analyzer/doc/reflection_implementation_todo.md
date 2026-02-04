# Tom Analyzer Reflection Implementation Plan

This document outlines the phased implementation plan for the reflection functionality in `tom_analyzer`. Each step references sections in [reflection_implementation.md](reflection_implementation.md) and [reflection_user_guide.md](reflection_user_guide.md).

---

## Phase 1: Core Runtime Library

**Goal:** Create the runtime types that generated code will use.

### 1.1 Base Trait Interfaces

| Step | Description | Reference |
|------|-------------|-----------|
| 1.1.1 | Implement `Element` base trait with `name`, `qualifiedName`, `libraryUri`, `package`, `kind`, and annotation methods | [Trait Interfaces → Element](reflection_implementation.md#element) (L35-200) |
| 1.1.2 | Implement `ElementKind` enum | [Trait Interfaces → Element](reflection_implementation.md#element) (L85-100) |
| 1.1.3 | Implement `ElementFilter` and `ElementProcessor` classes | [Trait Interfaces → Element](reflection_implementation.md#element) (L102-200) |

### 1.2 Typed Trait

| Step | Description | Reference |
|------|-------------|-----------|
| 1.2.1 | Implement `Typed<T>` trait with `reflectedType`, `isSubtypeOf`, `isAssignableFrom`, collection factories | [Trait Interfaces → Typed<T>](reflection_implementation.md#typedt) (L302-408) |
| 1.2.2 | Implement `TypedFilter` and `TypedProcessor` classes | [Trait Interfaces → Typed<T>](reflection_implementation.md#typedt) |

### 1.3 Invokable Trait

| Step | Description | Reference |
|------|-------------|-----------|
| 1.3.1 | Implement `Invokable` trait with `invoke`, `invokeWithNamedArgs`, `invokeWithMap` | [Trait Interfaces → Invokable](reflection_implementation.md#invokable) (L410-506) |
| 1.3.2 | Implement parameter handling (positional, named, spread) | [Trait Interfaces → Invokable](reflection_implementation.md#invokable) |
| 1.3.3 | Implement `InvokableFilter` and `InvokableProcessor` classes | [Trait Interfaces → Invokable](reflection_implementation.md#invokable) |

### 1.4 OwnedElement Trait

| Step | Description | Reference |
|------|-------------|-----------|
| 1.4.1 | Implement `OwnedElement` trait with `owner`, `isGlobal`, `isInherited`, `declaringClass` | [Trait Interfaces → OwnedElement](reflection_implementation.md#ownedelement) (L508-616) |
| 1.4.2 | Implement `OwnedElementFilter` and `OwnedElementProcessor` classes | [Trait Interfaces → OwnedElement](reflection_implementation.md#ownedelement) |

### 1.5 GenericElement Trait

| Step | Description | Reference |
|------|-------------|-----------|
| 1.5.1 | Implement `GenericElement` trait with `typeParameters`, `isGeneric`, `instantiate` | [Trait Interfaces → GenericElement](reflection_implementation.md#genericelement) (L618-688) |
| 1.5.2 | Implement `GenericElementFilter` and `GenericElementProcessor` classes | [Trait Interfaces → GenericElement](reflection_implementation.md#genericelement) |

### 1.6 Accessible Trait

| Step | Description | Reference |
|------|-------------|-----------|
| 1.6.1 | Implement `Accessible<T>` trait with `getValue`, `setValue`, `canRead`, `canWrite` | [Trait Interfaces → Accessible](reflection_implementation.md#accessible) (L690-760) |
| 1.6.2 | Implement `AccessibleFilter` and `AccessibleProcessor` classes | [Trait Interfaces → Accessible](reflection_implementation.md#accessible) |

---

## Phase 2: Core Type Mirrors

**Goal:** Implement the main type mirrors for classes, enums, mixins, extensions.

### 2.1 TypeMirror Base

| Step | Description | Reference |
|------|-------------|-----------|
| 2.1.1 | Implement `TypeMirror<T>` base class combining `Element`, `Typed<T>`, `GenericElement` | [Core Types → TypeMirror<T>](reflection_implementation.md#typemirror) (L765-784) |

### 2.2 ClassMirror

| Step | Description | Reference |
|------|-------------|-----------|
| 2.2.1 | Implement `ClassMirror<T>` with modifiers (`isAbstract`, `isSealed`, `isFinal`, `isMixin`, `isInterface`) | [Core Types → ClassMirror<T>](reflection_implementation.md#classmirror) (L786-986) |
| 2.2.2 | Implement type hierarchy (`superclass`, `interfaces`, `mixins`, `allSupertypes`) | [Core Types → ClassMirror<T>](reflection_implementation.md#classmirror) |
| 2.2.3 | Implement member getters (`constructors`, `methods`, `fields`, `getters`, `setters`) | [Core Types → ClassMirror<T>](reflection_implementation.md#classmirror) |
| 2.2.4 | Implement filter/process methods (`filterMethods`, `processMethods`, etc.) | [Core Types → ClassMirror<T>](reflection_implementation.md#classmirror) |
| 2.2.5 | Implement factory constructors vs static methods distinction | [Core Types → Factory Constructors vs Static Methods](reflection_implementation.md#factory-constructors-vs-static-methods) (L988-1021) |
| 2.2.6 | Implement `newInstance()`, `newInstanceNamed()` convenience methods | [Core Types → ClassMirror<T>](reflection_implementation.md#classmirror) |

### 2.3 EnumMirror, MixinMirror, ExtensionTypeMirror

| Step | Description | Reference |
|------|-------------|-----------|
| 2.3.1 | Implement `EnumMirror<T>` with `values`, `valueOf(String)`, `byIndex(int)` | [Core Types → EnumMirror<T>, MixinMirror<T>, ExtensionTypeMirror<T>](reflection_implementation.md#enummirror-mixinmirror-extensiontypemirror) (L1023-1058) |
| 2.3.2 | Implement `MixinMirror<T>` with `superclassConstraints`, `on` | [Core Types → EnumMirror<T>, MixinMirror<T>, ExtensionTypeMirror<T>](reflection_implementation.md#enummirror-mixinmirror-extensiontypemirror) |
| 2.3.3 | Implement `ExtensionTypeMirror<T>` with `representationType`, `erases` | [Core Types → EnumMirror<T>, MixinMirror<T>, ExtensionTypeMirror<T>](reflection_implementation.md#enummirror-mixinmirror-extensiontypemirror) |

### 2.4 ExtensionMirror

| Step | Description | Reference |
|------|-------------|-----------|
| 2.4.1 | Implement `ExtensionMirror` with `on` (extended type), `appliesTo()` | [Core Types → ExtensionMirror](reflection_implementation.md#extensionmirror) (L1060-1116) |
| 2.4.2 | Implement extension method invocation on ClassMirror | [Generated Output Structure → Extension Methods on ClassMirror](reflection_implementation.md#extension-methods-on-classmirror) (L2560-2588) |

### 2.5 TypeAliasMirror

| Step | Description | Reference |
|------|-------------|-----------|
| 2.5.1 | Implement `TypeAliasMirror` with `aliasedType` | [Core Types → TypeAliasMirror](reflection_implementation.md#typealiasmirror) (L1118-1133) |

---

## Phase 3: Member Mirrors

**Goal:** Implement mirrors for methods, fields, constructors, parameters.

### 3.1 MemberMirror Base

| Step | Description | Reference |
|------|-------------|-----------|
| 3.1.1 | Implement `MemberMirror` base combining `Element`, `OwnedElement` | [Member Mirrors → MemberMirror (Base)](reflection_implementation.md#membermirror-base) (L1139-1167) |
| 3.1.2 | Implement modifiers (`isStatic`, `isPrivate`, `isConst`, `isFinal`, `isLate`) | [Member Mirrors → MemberMirror (Base)](reflection_implementation.md#membermirror-base) |

### 3.2 MethodMirror

| Step | Description | Reference |
|------|-------------|-----------|
| 3.2.1 | Implement `MethodMirror<R>` with `returnType`, `parameters`, `isAsync`, `isGenerator` | [Member Mirrors → MethodMirror<R>](reflection_implementation.md#methodmirror) (L1169-1197) |
| 3.2.2 | Implement `Invokable` for method invocation | [Member Mirrors → MethodMirror<R>](reflection_implementation.md#methodmirror) |

### 3.3 FieldMirror

| Step | Description | Reference |
|------|-------------|-----------|
| 3.3.1 | Implement `FieldMirror<T>` with `fieldType`, `isLate`, `hasInitializer` | [Member Mirrors → FieldMirror<T>](reflection_implementation.md#fieldmirror) (L1199-1232) |
| 3.3.2 | Implement `Accessible<T>` for field access | [Member Mirrors → FieldMirror<T>](reflection_implementation.md#fieldmirror) |

### 3.4 GetterMirror and SetterMirror

| Step | Description | Reference |
|------|-------------|-----------|
| 3.4.1 | Implement `GetterMirror<T>` with read access | [Member Mirrors → GetterMirror<T>](reflection_implementation.md#gettermirror) (L1234-1258) |
| 3.4.2 | Implement `SetterMirror<T>` with write access | [Member Mirrors → SetterMirror<T>](reflection_implementation.md#settermirror) (L1260-1284) |

### 3.5 ConstructorMirror

| Step | Description | Reference |
|------|-------------|-----------|
| 3.5.1 | Implement `ConstructorMirror<T>` with `isFactory`, `isConst`, `isNamed`, `redirectedConstructor` | [Member Mirrors → ConstructorMirror<T>](reflection_implementation.md#constructormirror) (L1286-1311) |
| 3.5.2 | Implement `Invokable` for instance creation | [Member Mirrors → ConstructorMirror<T>](reflection_implementation.md#constructormirror) |

### 3.6 ParameterMirror

| Step | Description | Reference |
|------|-------------|-----------|
| 3.6.1 | Implement `ParameterMirror<T>` with `type`, `isRequired`, `isNamed`, `isOptional`, `defaultValue` | [Member Mirrors → ParameterMirror<T>](reflection_implementation.md#parametermirror) (L1313-1351) |

### 3.7 AnnotationMirror

| Step | Description | Reference |
|------|-------------|-----------|
| 3.7.1 | Implement `AnnotationMirror` with `annotationType`, `value`, `arguments` | [Member Mirrors → AnnotationMirror](reflection_implementation.md#annotationmirror) (L1353-1385) |

### 3.8 TypeParameterMirror

| Step | Description | Reference |
|------|-------------|-----------|
| 3.8.1 | Implement `TypeParameterMirror` with `bound`, `defaultType`, `variance` | [Member Mirrors → TypeParameterMirror](reflection_implementation.md#typeparametermirror) (L1387-1405) |

---

## Phase 4: Global Members and ReflectionApi

**Goal:** Implement top-level member handling and the main API entry point.

### 4.1 Global Members

| Step | Description | Reference |
|------|-------------|-----------|
| 4.1.1 | Implement global method handling (top-level functions) with `isGlobal: true` | [Global Members](reflection_implementation.md#global-members) (L1407-1430) |
| 4.1.2 | Implement global field/getter/setter handling | [Global Members](reflection_implementation.md#global-members) |

### 4.2 ReflectionApi

| Step | Description | Reference |
|------|-------------|-----------|
| 4.2.1 | Implement `ReflectionApi` core with all collections (`allClasses`, `allEnums`, `allMixins`, etc.) | [ReflectionApi](reflection_implementation.md#reflectionapi) (L1432-1678) |
| 4.2.2 | Implement type lookup (`findClassByType<T>()`, `findClassByName(String)`, etc.) | [ReflectionApi](reflection_implementation.md#reflectionapi) |
| 4.2.3 | Implement global member access (`allGlobalMethods`, `findGlobalMethod`, etc.) | [ReflectionApi](reflection_implementation.md#reflectionapi) |
| 4.2.4 | Implement filter methods (`filterClasses`, `filterMethods`, etc.) | [ReflectionApi](reflection_implementation.md#reflectionapi) |
| 4.2.5 | Implement process methods (`processClasses`, `processMethods`, etc.) | [ReflectionApi](reflection_implementation.md#reflectionapi) |
| 4.2.6 | Implement `reflect(instance)` for runtime reflection | [ReflectionApi](reflection_implementation.md#reflectionapi) |

### 4.3 Scoped APIs

| Step | Description | Reference |
|------|-------------|-----------|
| 4.3.1 | Implement `PackageApi` for package-scoped reflection | [Scoped APIs → PackageApi](reflection_implementation.md#packageapi) (L1682-1716) |
| 4.3.2 | Implement `LibraryApi` for library-scoped reflection | [Scoped APIs → LibraryApi](reflection_implementation.md#libraryapi) (L1718-1749) |
| 4.3.3 | Connect scoped APIs via `reflectionApi.forPackage()`, `reflectionApi.forLibrary()` | [Scoped APIs](reflection_implementation.md#scoped-apis) |

---

## Phase 5: Filters and Processors

**Goal:** Implement specialized filter and processor classes.

### 5.1 Type-Specific Filters

| Step | Description | Reference |
|------|-------------|-----------|
| 5.1.1 | Implement `ClassFilter` with `isAbstract`, `isMixin`, `implements`, `extends_`, `mixes` | [Filters → ClassFilter](reflection_implementation.md#classfilter) (L1755-1807) |
| 5.1.2 | Implement `MethodFilter` with `returnsType`, `returnsVoid`, `hasParameter`, `parameterCount` | [Filters → MethodFilter](reflection_implementation.md#methodfilter) (L1809-1849) |
| 5.1.3 | Implement `FieldFilter` with `ofType`, `isFinal`, `isLate`, `isConst` | [Filters → FieldFilter](reflection_implementation.md#fieldfilter) (L1851-1891) |
| 5.1.4 | Implement `TypeFilter` for TypeMirror hierarchy queries | [Filters → TypeFilter](reflection_implementation.md#typefilter-for-typemirror-hierarchy) (L1893-1927) |

### 5.2 Processors

| Step | Description | Reference |
|------|-------------|-----------|
| 5.2.1 | Implement `TypeProcessor` with type-specific dispatch | [Processors → TypeProcessor](reflection_implementation.md#typeprocessor) (L1933-1961) |
| 5.2.2 | Implement `MemberProcessor` with member-specific dispatch | [Processors → MemberProcessor](reflection_implementation.md#memberprocessor) (L1963-1992) |

---

## Phase 6: Name Resolution and Errors

**Goal:** Implement name resolution logic and error handling.

### 6.1 Name Resolution

| Step | Description | Reference |
|------|-------------|-----------|
| 6.1.1 | Implement short name vs qualified name lookup | [Name Resolution → Short Names vs Qualified Names](reflection_implementation.md#short-names-vs-qualified-names) (L1996-2026) |
| 6.1.2 | Implement ambiguity detection and error reporting | [Name Resolution → AmbiguousNameError](reflection_implementation.md#ambiguousnameerror) (L2028-2042) |

### 6.2 Error Types

| Step | Description | Reference |
|------|-------------|-----------|
| 6.2.1 | Implement `AmbiguousNameError` | [Name Resolution → AmbiguousNameError](reflection_implementation.md#ambiguousnameerror) (L2028-2042) |
| 6.2.2 | Implement `ReadOnlyFieldError` | [Name Resolution → ReadOnlyFieldError](reflection_implementation.md#readonlyfielderror) (L2044-2059) |

---

## Phase 7: Code Generator

**Goal:** Implement the generator that produces `.r.dart` files.

### 7.1 Configuration Parsing

| Step | Description | Reference |
|------|-------------|-----------|
| 7.1.1 | Parse `tom_analyzer.yaml` configuration | [User Guide → Configuration file](reflection_user_guide.md#configuration-file) |
| 7.1.2 | Parse `entry_points` and resolve to files | [User Guide → Basic configuration](reflection_user_guide.md#basic-configuration) |
| 7.1.3 | Parse `output` with base name normalization (add `.r.dart`) | [User Guide → Output file naming](reflection_user_guide.md#output-file-naming) |
| 7.1.4 | Parse `defaults` section (global exclude/include packages, annotations) | [User Guide → Global defaults](reflection_user_guide.md#global-defaults) |
| 7.1.5 | Parse `filters` section with `include`/`exclude` logic | [User Guide → Filtering configuration](reflection_user_guide.md#filtering-configuration) |
| 7.1.6 | Parse `dependency_config` section | [User Guide → dependency_config](reflection_user_guide.md#dependency_config) |
| 7.1.7 | Parse `coverage_config` section | [User Guide → coverage_config](reflection_user_guide.md#coverage_config) |

### 7.2 Entry Point Analysis

| Step | Description | Reference |
|------|-------------|-----------|
| 7.2.1 | Use Dart analyzer to resolve entry point imports | [Project Hierarchy → Entry Point Reachability](reflection_implementation.md#1-entry-point-reachability-default) (L3003-3017) |
| 7.2.2 | Build reachability graph from entry points (imports only, not exports) | [User Guide → Analyzer vs Reflection](reflection_user_guide.md#analyzer-vs-reflection) |
| 7.2.3 | Track all reachable types and their dependencies | [Project Hierarchy → Single Reflection File Per Entry Point](reflection_implementation.md#single-reflection-file-per-entry-point) (L2979-2999) |

### 7.3 Filter Application

| Step | Description | Reference |
|------|-------------|-----------|
| 7.3.1 | Apply global `exclude_packages` to remove packages | [User Guide → Global defaults](reflection_user_guide.md#global-defaults) |
| 7.3.2 | Apply global `include_packages` to add non-reachable packages | [User Guide → Global defaults](reflection_user_guide.md#global-defaults) |
| 7.3.3 | Apply global `include_annotations` to add annotated elements | [User Guide → Global defaults](reflection_user_guide.md#global-defaults) |
| 7.3.4 | Process filters in order (include expands, exclude shrinks) | [User Guide → Filter processing rules](reflection_user_guide.md#filter-processing-rules) |
| 7.3.5 | Implement glob pattern matching for packages, paths, types | [User Guide → Pattern syntax](reflection_user_guide.md#pattern-syntax) |
| 7.3.6 | Implement annotation matching (short name, qualified, field patterns) | [User Guide → Annotation matching](reflection_user_guide.md#annotation-matching) |
| 7.3.7 | Implement element inclusion/exclusion (hide/show style) | [User Guide → Individual element inclusion/exclusion](reflection_user_guide.md#individual-element-inclusionexclusion) |

### 7.4 Dependency Resolution

| Step | Description | Reference |
|------|-------------|-----------|
| 7.4.1 | Apply `superclasses` config (depth, external_depth, exclude_types) | [User Guide → dependency_config](reflection_user_guide.md#dependency_config) |
| 7.4.2 | Apply `interfaces` config (enabled, external) | [User Guide → dependency_config](reflection_user_guide.md#dependency_config) |
| 7.4.3 | Apply `mixins` config (enabled, external) | [User Guide → dependency_config](reflection_user_guide.md#dependency_config) |
| 7.4.4 | Apply `type_arguments` config (generics) | [User Guide → dependency_config](reflection_user_guide.md#dependency_config) |
| 7.4.5 | Apply `type_annotations` config (field types, parameter types) | [User Guide → dependency_config](reflection_user_guide.md#dependency_config) |
| 7.4.6 | Track external package depth for dependency limits | [Scope Filtering → Transitive Dependency Inclusion](reflection_implementation.md#transitive-dependency-inclusion) (L2863-2873) |

### 7.5 Coverage Determination

| Step | Description | Reference |
|------|-------------|-----------|
| 7.5.1 | Determine which types get full invoker coverage | [User Guide → coverage_config](reflection_user_guide.md#coverage_config) |
| 7.5.2 | Apply `instance_members` pattern/annotation filters | [User Guide → coverage_config](reflection_user_guide.md#coverage_config) |
| 7.5.3 | Apply `constructors` pattern filter (e.g., `from*`) | [User Guide → coverage_config](reflection_user_guide.md#coverage_config) |
| 7.5.4 | Apply `top_level` config for global members | [User Guide → coverage_config](reflection_user_guide.md#coverage_config) |
| 7.5.5 | Mark types as declarations-only (negative invoker index) for metadata-only types | [Scope Filtering → Negative Invoker Index Convention](reflection_implementation.md#negative-invoker-index-convention) (L2684-2693) |

### 7.6 Code Generation

| Step | Description | Reference |
|------|-------------|-----------|
| 7.6.1 | Generate package imports with prefixes | [Generated Output Structure → Structure Overview](reflection_implementation.md#structure-overview) (L2359-2400) |
| 7.6.2 | Generate bit flag constants | [Generated Output Structure → Structure Overview](reflection_implementation.md#structure-overview) (L2359-2400) |
| 7.6.3 | Generate package/library structure arrays | [Generated Output Structure → Structure Overview](reflection_implementation.md#structure-overview) |
| 7.6.4 | Generate type data arrays (classes, enums, mixins) | [Generated Output Structure → Compact Index-Based Format](reflection_implementation.md#compact-index-based-format) (L2346-2357) |
| 7.6.5 | Generate member data arrays with invoker indices | [Generated Output Structure → Compact Index-Based Format](reflection_implementation.md#compact-index-based-format) |
| 7.6.6 | Generate invoker closures for methods, constructors, fields | [Invocation Strategy](reflection_implementation.md#invocation-strategy) (L2923-2942) |
| 7.6.7 | Generate extension method entries on ClassMirror | [Generated Output Structure → Extension Methods on ClassMirror](reflection_implementation.md#extension-methods-on-classmirror) (L2560-2588) |
| 7.6.8 | Generate `reflectionApi` singleton instantiation | [ReflectionApi](reflection_implementation.md#reflectionapi) |
| 7.6.9 | Write output to configured path (base name + `.r.dart`) | [User Guide → Output file naming](reflection_user_guide.md#output-file-naming) |

---

## Phase 8: Multi-Entry-Point Support

**Goal:** Handle multiple entry points with combined or separate output.

| Step | Description | Reference |
|------|-------------|-----------|
| 8.1 | Detect multiple entry points in configuration | [User Guide → Multi-entry-point behavior](reflection_user_guide.md#multi-entry-point-behavior) |
| 8.2 | Without `output`: generate separate `.r.dart` per entry point | [User Guide → Multi-entry-point behavior](reflection_user_guide.md#multi-entry-point-behavior) |
| 8.3 | With `output`: merge reachable sets from all entry points | [User Guide → Multi-entry-point behavior](reflection_user_guide.md#multi-entry-point-behavior) |
| 8.4 | Apply filters once to combined set | [User Guide → Multi-entry-point behavior](reflection_user_guide.md#multi-entry-point-behavior) |
| 8.5 | Generate single combined output file | [User Guide → Multi-entry-point behavior](reflection_user_guide.md#multi-entry-point-behavior) |

---

## Phase 9: CLI Integration

**Goal:** Expose reflection generation via CLI and build_runner.

### 9.1 CLI Command

| Step | Description | Reference |
|------|-------------|-----------|
| 9.1.1 | Implement `tom_analyzer reflect` command | [User Guide → CLI usage](reflection_user_guide.md#cli-usage) |
| 9.1.2 | Parse `--config`, `--entry`, `--output` arguments | [User Guide → CLI usage](reflection_user_guide.md#cli-usage) |
| 9.1.3 | Normalize output path (add `.r.dart`, remove `.dart`) | [User Guide → Output file naming](reflection_user_guide.md#output-file-naming) |

### 9.2 build_runner Integration

| Step | Description | Reference |
|------|-------------|-----------|
| 9.2.1 | Implement `tom_analyzer_reflection` builder | [User Guide → build_runner usage](reflection_user_guide.md#build_runner-usage) |
| 9.2.2 | Read options from `build.yaml` | [User Guide → build_runner usage](reflection_user_guide.md#build_runner-usage) |
| 9.2.3 | Integrate with build_runner lifecycle | [User Guide → build_runner usage](reflection_user_guide.md#build_runner-usage) |

---

## Phase 10: Testing and Validation

**Goal:** Comprehensive testing of all functionality.

| Step | Description | Reference |
|------|-------------|-----------|
| 10.1 | Unit tests for all trait interfaces | [Trait Interfaces](reflection_implementation.md#trait-interfaces) |
| 10.2 | Unit tests for all mirror types | [Core Types](reflection_implementation.md#core-types), [Member Mirrors](reflection_implementation.md#member-mirrors) |
| 10.3 | Unit tests for filters and processors | [Filters](reflection_implementation.md#filters), [Processors](reflection_implementation.md#processors) |
| 10.4 | Integration tests for code generation | [Generated Output Structure](reflection_implementation.md#generated-output-structure) |
| 10.5 | Integration tests for filter/dependency/coverage configs | [User Guide → Filtering configuration](reflection_user_guide.md#filtering-configuration) |
| 10.6 | End-to-end tests with sample projects | [Usage Examples](reflection_implementation.md#usage-examples) (L2061-2340) |
| 10.7 | Performance tests with large codebases | [Project Hierarchy → Size Estimation](reflection_implementation.md#size-estimation) (L3135-3147) |

---

## Implementation Order Summary

| Phase | Priority | Dependency | Estimated Effort |
|-------|----------|------------|------------------|
| 1. Core Runtime Library | P0 | None | Medium |
| 2. Core Type Mirrors | P0 | Phase 1 | Large |
| 3. Member Mirrors | P0 | Phase 2 | Medium |
| 4. Global Members & ReflectionApi | P0 | Phase 3 | Medium |
| 5. Filters and Processors | P1 | Phase 4 | Medium |
| 6. Name Resolution & Errors | P1 | Phase 4 | Small |
| 7. Code Generator | P0 | Phase 4 | Large |
| 8. Multi-Entry-Point | P1 | Phase 7 | Small |
| 9. CLI Integration | P1 | Phase 7 | Small |
| 10. Testing | P0 | All | Large |

**Critical Path:** Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 7

---

## Notes

- **Private members** are excluded from reflection output. See [Private Members](reflection_implementation.md#private-members) (L2961-2965).
- **No `dart:mirrors`** - all invocation uses statically generated closures. See [Invocation Strategy](reflection_implementation.md#invocation-strategy) (L2923-2942).
- **Compact format** is essential for large codebases. See [Compact Index-Based Format](reflection_implementation.md#compact-index-based-format) (L2346-2357).
- **Known limitations** are documented. See [Known Limitations](reflection_implementation.md#known-limitations) (L3149-3161).
