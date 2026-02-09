import 'dart:math';

import '../settings/app_settings.dart';

const int maxAdvancedScore = 100;

int generateRandomAdvancedScore({Random? random}) {
  final rng = random ?? Random();
  return rng.nextInt(maxAdvancedScore) + 1;
}

int displayScoreForSettings({
  required int advancedScore,
  required AppSettings settings,
}) {
  if (settings.showAdvancedScore) {
    return advancedScore;
  }
  return ((advancedScore - 1) / 20).floor() + 1;
}
