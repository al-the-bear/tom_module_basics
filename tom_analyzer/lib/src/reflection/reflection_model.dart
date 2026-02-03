import '../model/model.dart';

class ReflectionModel {
  final AnalysisResult analysisResult;

  ReflectionModel(this.analysisResult);

  factory ReflectionModel.fromAnalysis(AnalysisResult analysisResult) {
    return ReflectionModel(analysisResult);
  }
}
