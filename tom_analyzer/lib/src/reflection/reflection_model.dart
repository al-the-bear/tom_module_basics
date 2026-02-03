import '../model/model.dart';

/// Bridge model between static analysis and reflection output.
class ReflectionModel {
  final AnalysisResult analysisResult;

  ReflectionModel(this.analysisResult);

  factory ReflectionModel.fromAnalysis(AnalysisResult analysisResult) {
    return ReflectionModel(analysisResult);
  }
}
