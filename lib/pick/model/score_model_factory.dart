import 'aesthetic_score_model.dart';
import 'mobilenetv3_large_aesthetic_model.dart';
import 'model_catalog.dart';
import 'tflite_aesthetic_model.dart';

AestheticScoreModel createScoreModel({
  required ScoreModelType type,
  String? modelPath,
}) {
  switch (type) {
    case ScoreModelType.legacyNonAi:
      return MobileNetV3LargeAestheticModel();
    case ScoreModelType.nima:
      return TfliteAestheticModel(modelPath: modelPath ?? '', modelSeed: 1);
    case ScoreModelType.ava:
      return TfliteAestheticModel(modelPath: modelPath ?? '', modelSeed: 2);
    case ScoreModelType.mobilenetLite:
      return TfliteAestheticModel(modelPath: modelPath ?? '', modelSeed: 3);
  }
}
