enum ScoreModelOption {
  mobilenetV3Large,
  nimaTflite,
}

extension ScoreModelOptionLabel on ScoreModelOption {
  String get label {
    switch (this) {
      case ScoreModelOption.mobilenetV3Large:
        return 'MobileNetV3 (内置基线)';
      case ScoreModelOption.nimaTflite:
        return 'NIMA (TensorFlow Lite)';
    }
  }

  String get description {
    switch (this) {
      case ScoreModelOption.mobilenetV3Large:
        return '无需模型文件，快速评分（1-100）。';
      case ScoreModelOption.nimaTflite:
        return 'Google 开源美学评分模型，使用 TensorFlow Lite 推理（1-100）。';
    }
  }
}
