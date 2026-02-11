import 'package:flutter/material.dart';

import '../pick/model/model_catalog.dart';

class AppSettings extends ChangeNotifier {
  bool _enableSingleTapPreview = false;
  bool _enableAdvancedScore = false;
  ScoreModelType _selectedModel = ScoreModelType.legacyNonAi;
  final Map<ScoreModelType, String> _downloadedModelPaths = {};

  bool get enableSingleTapPreview => _enableSingleTapPreview;
  bool get enableAdvancedScore => _enableAdvancedScore;
  ScoreModelType get selectedModel => _selectedModel;

  bool isModelDownloaded(ScoreModelType type) {
    return _downloadedModelPaths.containsKey(type);
  }

  String? modelPathOf(ScoreModelType type) {
    return _downloadedModelPaths[type];
  }

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

  void setSelectedModel(ScoreModelType type) {
    if (type == _selectedModel) {
      return;
    }
    _selectedModel = type;
    notifyListeners();
  }

  void markModelDownloaded({
    required ScoreModelType type,
    required String modelPath,
  }) {
    final previous = _downloadedModelPaths[type];
    if (previous == modelPath) {
      return;
    }
    _downloadedModelPaths[type] = modelPath;
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
