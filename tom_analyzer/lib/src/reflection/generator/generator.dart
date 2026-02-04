/// Reflection code generator module.
///
/// This module provides the code generator that produces `.r.dart` files
/// containing reflection data structures and invokers.
library;

export 'entry_point_analyzer.dart' show AnalysisResult, EntryPointAnalyzer;
export 'filter_matcher.dart'
    show
        AnnotationPattern,
        DefaultsMatcher,
        FilterMatcher,
        GlobMatcher,
        InclusionResolver;
export 'reflection_config.dart';
export 'reflection_generator.dart' show ReflectionGenerator;
