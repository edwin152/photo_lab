import 'package:flutter/material.dart';

import 'score_model_option.dart';

class AppSettings extends ChangeNotifier {
  bool _enableSingleTapPreview = false;
  ScoreModelOption _scoreModel = ScoreModelOption.nimaTflite;

  bool get enableSingleTapPreview => _enableSingleTapPreview;
  ScoreModelOption get scoreModel => _scoreModel;

  void setEnableSingleTapPreview(bool value) {
    if (_enableSingleTapPreview == value) {
      return;
    }
    _enableSingleTapPreview = value;
    notifyListeners();
  }

  void setScoreModel(ScoreModelOption value) {
    if (_scoreModel == value) {
      return;
    }
    _scoreModel = value;
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
