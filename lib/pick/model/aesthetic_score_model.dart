import 'dart:typed_data';

import 'package:flutter/foundation.dart';

@immutable
class AestheticScoreResult {
  const AestheticScoreResult({
    required this.score,
    required this.embedding,
  });

  final double score;
  final Float32List embedding;

  int get roundedScore {
    final value = score.round();
    if (value < 1) return 1;
    if (value > 100) return 100;
    return value;
  }
}

abstract class AestheticScoreModel {
  Future<AestheticScoreResult> score(Uint8List imageBytes);

  /// Ranking loss with pairwise labels.
  /// label: 1 (a better than b), -1 (b better than a), 0 (tie).
  double rankingLoss({
    required double scoreA,
    required double scoreB,
    required int label,
  });
}
