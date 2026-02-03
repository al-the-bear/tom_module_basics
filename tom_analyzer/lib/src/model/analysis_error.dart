part of 'model.dart';

enum AnalysisErrorSeverity { info, warning, error }

class AnalysisError {
  final String message;
  final AnalysisErrorSeverity severity;
  final SourceLocation? location;
  final String? code;

  const AnalysisError({
    required this.message,
    required this.severity,
    this.location,
    this.code,
  });
}
