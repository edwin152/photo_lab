import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'aesthetic_score_model.dart';

/// NIMA (Neural Image Assessment) aesthetic model running on TensorFlow Lite.
///
/// 默认从 assets/models/nima_mobilenet_v2.tflite 加载模型。
/// 如果模型资源不存在，则回退到简单启发式评分，避免功能不可用。
class NimaTfliteAestheticModel extends AestheticScoreModel {
  NimaTfliteAestheticModel({
    this.assetPath = 'assets/models/nima_mobilenet_v2.tflite',
  });

  final String assetPath;
  Interpreter? _interpreter;
  Future<Interpreter?>? _loadingFuture;

  @override
  Future<AestheticScoreResult> score(Uint8List imageBytes) async {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      return AestheticScoreResult(
        score: 1,
        embedding: Float32List(128),
      );
    }

    final interpreter = await _getInterpreter();
    if (interpreter == null) {
      final fallback = _fallbackScore(decoded);
      return AestheticScoreResult(score: fallback, embedding: _fallbackEmbedding(decoded));
    }

    final input = _buildInputTensor(decoded);
    final output = List.generate(1, (_) => List.filled(10, 0.0));
    interpreter.run(input, output);

    final distribution = _toProbabilityDistribution(output.first);
    var score1to10 = 0.0;
    for (var i = 0; i < distribution.length; i++) {
      score1to10 += (i + 1) * distribution[i];
    }
    final score = (score1to10 * 10).clamp(1, 100).toDouble();

    return AestheticScoreResult(
      score: score,
      embedding: _distributionToEmbedding(distribution),
    );
  }

  @override
  double rankingLoss({
    required double scoreA,
    required double scoreB,
    required int label,
  }) {
    if (label == 0) {
      final diff = (scoreA - scoreB).abs();
      return log(1 + exp(diff));
    }
    final direction = label > 0 ? 1.0 : -1.0;
    final diff = direction * (scoreA - scoreB);
    return log(1 + exp(-diff));
  }

  Future<Interpreter?> _getInterpreter() {
    _loadingFuture ??= _loadInterpreter();
    return _loadingFuture!;
  }

  Future<Interpreter?> _loadInterpreter() async {
    try {
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(assetPath, options: options);
      return _interpreter;
    } catch (error) {
      debugPrint('NIMA TFLite model load failed: $error');
      return null;
    }
  }

  List<List<List<List<double>>>> _buildInputTensor(img.Image source) {
    final square = img.copyResizeCropSquare(source, size: 224);
    final tensor = List.generate(
      1,
      (_) => List.generate(
        224,
        (y) => List.generate(224, (x) {
          final pixel = square.getPixel(x, y);
          return [
            pixel.r / 255.0,
            pixel.g / 255.0,
            pixel.b / 255.0,
          ];
        }),
      ),
    );
    return tensor;
  }

  List<double> _toProbabilityDistribution(List<dynamic> raw) {
    final values = raw.map((item) => (item as num).toDouble()).toList();
    final expValues = values.map(exp).toList();
    final expSum = expValues.fold<double>(0, (sum, item) => sum + item);
    if (expSum <= 0) {
      return List.filled(10, 0.1);
    }
    return expValues.map((value) => value / expSum).toList();
  }

  Float32List _distributionToEmbedding(List<double> distribution) {
    final embedding = Float32List(128);
    for (var i = 0; i < embedding.length; i++) {
      embedding[i] = distribution[i % distribution.length].toDouble();
    }
    return embedding;
  }

  double _fallbackScore(img.Image image) {
    var sum = 0.0;
    final sampleStep = max(1, min(image.width, image.height) ~/ 48);
    var count = 0;
    for (var y = 0; y < image.height; y += sampleStep) {
      for (var x = 0; x < image.width; x += sampleStep) {
        final pixel = image.getPixel(x, y);
        final luminance = 0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b;
        sum += luminance;
        count++;
      }
    }
    final avg = count == 0 ? 0.0 : sum / count;
    return (1 + (avg / 255.0) * 99).clamp(1, 100).toDouble();
  }

  Float32List _fallbackEmbedding(img.Image image) {
    final embedding = Float32List(128);
    final score = _fallbackScore(image) / 100.0;
    for (var i = 0; i < embedding.length; i++) {
      embedding[i] = score;
    }
    return embedding;
  }
}
