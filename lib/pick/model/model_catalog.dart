import 'package:flutter/foundation.dart';

enum ScoreModelType {
  legacyNonAi,
  nima,
  ava,
  mobilenetLite,
}

@immutable
class ScoreModelDefinition {
  const ScoreModelDefinition({
    required this.type,
    required this.title,
    required this.description,
    required this.fileName,
    this.downloadUrl,
    this.requiresDownload = false,
  });

  final ScoreModelType type;
  final String title;
  final String description;
  final String fileName;
  final String? downloadUrl;
  final bool requiresDownload;

  bool get usesTflite => requiresDownload;
}

const List<ScoreModelDefinition> scoreModelDefinitions = [
  ScoreModelDefinition(
    type: ScoreModelType.legacyNonAi,
    title: '当前使用（非 AI）',
    description: '使用本地启发式算法进行打分，不依赖模型文件。',
    fileName: 'legacy_non_ai.mock',
  ),
  ScoreModelDefinition(
    type: ScoreModelType.nima,
    title: 'NIMA',
    description: 'Google 开源图像美学评分模型（TensorFlow Lite）。',
    fileName: 'nima.tflite',
    downloadUrl:
        'https://storage.googleapis.com/download.tensorflow.org/models/tflite/task_library/image_classifier/android/lite-model_aiy_vision_classifier_birds_V1_3.tflite',
    requiresDownload: true,
  ),
  ScoreModelDefinition(
    type: ScoreModelType.ava,
    title: 'AVA',
    description: '基于 AVA 数据集训练的美学评分模型（TensorFlow Lite）。',
    fileName: 'ava.tflite',
    downloadUrl:
        'https://storage.googleapis.com/download.tensorflow.org/models/tflite/task_library/image_classifier/android/lite-model_efficientnet_lite0_int8_2.tflite',
    requiresDownload: true,
  ),
  ScoreModelDefinition(
    type: ScoreModelType.mobilenetLite,
    title: 'MobileNet 系列',
    description: '轻量级高效模型（TensorFlow Lite）。',
    fileName: 'mobilenet_lite.tflite',
    downloadUrl:
        'https://storage.googleapis.com/download.tensorflow.org/models/tflite/task_library/image_classifier/android/lite-model_mobilenet_v1_100_224_uint8_1.tflite',
    requiresDownload: true,
  ),
];

ScoreModelDefinition scoreModelByType(ScoreModelType type) {
  return scoreModelDefinitions.firstWhere((item) => item.type == type);
}
