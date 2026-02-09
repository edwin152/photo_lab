import 'package:flutter/material.dart';

class AppSettings extends ChangeNotifier {
  bool _enableSingleTapPreview = false;
  bool _showAdvancedScore = false;

  bool get enableSingleTapPreview => _enableSingleTapPreview;
  bool get showAdvancedScore => _showAdvancedScore;

  void setEnableSingleTapPreview(bool value) {
    if (_enableSingleTapPreview == value) {
      return;
    }
    _enableSingleTapPreview = value;
    notifyListeners();
  }

  void setShowAdvancedScore(bool value) {
    if (_showAdvancedScore == value) {
      return;
    }
    _showAdvancedScore = value;
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
