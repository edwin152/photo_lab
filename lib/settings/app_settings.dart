import 'package:flutter/material.dart';

enum ScoreModelType {
  mobileNetV3,
  nima,
}

extension ScoreModelTypeX on ScoreModelType {
  String get label {
    switch (this) {
      case ScoreModelType.mobileNetV3:
        return 'MobileNetV3';
      case ScoreModelType.nima:
        return 'NIMA (Google)';
    }
  }

  String get description {
    switch (this) {
      case ScoreModelType.mobileNetV3:
        return '轻量模型，推理更快';
      case ScoreModelType.nima:
        return '美学评分模型，结果更细腻';
    }
  }
}

class AppSettings extends ChangeNotifier {
  bool _enableSingleTapPreview = false;
  bool _enableAdvancedScore = false;
  ScoreModelType _scoreModelType = ScoreModelType.mobileNetV3;

  bool get enableSingleTapPreview => _enableSingleTapPreview;
  bool get enableAdvancedScore => _enableAdvancedScore;
  ScoreModelType get scoreModelType => _scoreModelType;

  void setEnableSingleTapPreview(bool value) {
    if (_enableSingleTapPreview == value) {
      return;
    }
    _enableSingleTapPreview = value;
    notifyListeners();
  }

  void setEnableAdvancedScore(bool value) {
    if (_enableAdvancedScore == value) {
      return;
    }
    _enableAdvancedScore = value;
    notifyListeners();
  }

  void setScoreModelType(ScoreModelType value) {
    if (_scoreModelType == value) {
      return;
    }
    _scoreModelType = value;
    notifyListeners();
  }
}

class AppSettingsScope extends InheritedNotifier<AppSettings> {
  const AppSettingsScope({super.key, required AppSettings settings, required super.child})
      : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    assert(scope != null, 'AppSettingsScope not found in widget tree.');
    return scope!.notifier!;
  }
}
