import 'package:flutter/material.dart';

class AppSettings extends ChangeNotifier {
  bool _enableDoubleTapPreview = true;
  bool _enableSingleTapPreview = false;

  bool get enableDoubleTapPreview => _enableDoubleTapPreview;
  bool get enableSingleTapPreview => _enableSingleTapPreview;

  void setEnableDoubleTapPreview(bool value) {
    if (_enableDoubleTapPreview == value) {
      return;
    }
    _enableDoubleTapPreview = value;
    notifyListeners();
  }

  void setEnableSingleTapPreview(bool value) {
    if (_enableSingleTapPreview == value) {
      return;
    }
    _enableSingleTapPreview = value;
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
