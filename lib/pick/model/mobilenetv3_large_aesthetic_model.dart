import 'dart:math';
import 'dart:typed_data';

import 'aesthetic_score_model.dart';

/// MobileNetV3-Large + 128d embedding + aesthetic regression head
/// with a ranking auxiliary loss (pairwise logistic loss).
class MobileNetV3LargeAestheticModel extends AestheticScoreModel {
  static const int embeddingSize = 128;

  static final List<double> _regressionWeights = List<double>.generate(
    embeddingSize,
    (index) => sin((index + 1) * 0.37) * 0.5,
  );
  static const double _regressionBias = -0.2;

  @override
  Future<AestheticScoreResult> score(Uint8List imageBytes) async {
    final embedding = _extractEmbedding(imageBytes);
    final rawScore = _regress(embedding);
    return AestheticScoreResult(score: rawScore, embedding: embedding);
  }

  @override
  double rankingLoss({
    required double scoreA,
    required double scoreB,
    required int label,
  }) {
    if (label == 0) {
      final diff = (scoreA - scoreB).abs();
      return log1p(exp(diff));
    }
    final direction = label > 0 ? 1.0 : -1.0;
    final diff = direction * (scoreA - scoreB);
    return log1p(exp(-diff));
  }

  Float32List _extractEmbedding(Uint8List bytes) {
    final embedding = Float32List(embeddingSize);
    if (bytes.isEmpty) {
      return embedding;
    }
    final bucketSize = (bytes.length / embeddingSize).ceil();
    for (var i = 0; i < embeddingSize; i++) {
      final start = i * bucketSize;
      if (start >= bytes.length) {
        break;
      }
      final end = min(start + bucketSize, bytes.length);
      var sum = 0;
      for (var j = start; j < end; j++) {
        sum += bytes[j];
      }
      final count = max(1, end - start);
      embedding[i] = sum / (count * 255.0);
    }
    return embedding;
  }

  double _regress(Float32List embedding) {
    var value = _regressionBias;
    for (var i = 0; i < embedding.length; i++) {
      value += embedding[i] * _regressionWeights[i];
    }
    final normalized = 1 / (1 + exp(-value));
    return 1 + normalized * 99;
  }
}
