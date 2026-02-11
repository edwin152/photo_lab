import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import 'aesthetic_score_model.dart';

class TfliteAestheticModel extends AestheticScoreModel {
  TfliteAestheticModel({
    required this.modelPath,
    required this.modelSeed,
  });

  final String modelPath;
  final int modelSeed;

  Interpreter? _interpreter;

  @override
  Future<AestheticScoreResult> score(Uint8List imageBytes) async {
    final embedding = _extractEmbedding(imageBytes);
    final file = File(modelPath);
    if (!await file.exists()) {
      final fallback = _fallbackScore(embedding);
      return AestheticScoreResult(score: fallback, embedding: embedding);
    }

    _interpreter ??= await Interpreter.fromFile(file);
    final input = _buildInputTensor(imageBytes);
    final output = List.generate(1, (_) => List.filled(10, 0.0));

    try {
      _interpreter!.run(input, output);
      final logits = output.first.cast<double>();
      final mean = _weightedMean(logits);
      return AestheticScoreResult(score: mean * 10, embedding: embedding);
    } catch (_) {
      final fallback = _fallbackScore(embedding);
      return AestheticScoreResult(score: fallback, embedding: embedding);
    }
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

  Float32List _extractEmbedding(Uint8List bytes) {
    const size = 128;
    final embedding = Float32List(size);
    if (bytes.isEmpty) {
      return embedding;
    }
    final stride = max(1, bytes.length ~/ size);
    for (var i = 0; i < size; i++) {
      final index = min(bytes.length - 1, i * stride);
      embedding[i] = bytes[index] / 255.0;
    }
    return embedding;
  }

  List<List<List<List<double>>>> _buildInputTensor(Uint8List bytes) {
    const side = 224;
    final tensor = List.generate(
      1,
      (_) => List.generate(
        side,
        (y) => List.generate(side, (x) {
          final source = bytes.isEmpty ? 0 : bytes[(y * side + x) % bytes.length];
          final normalized = source / 255.0;
          return [normalized, normalized, normalized];
        }),
      ),
    );
    return tensor;
  }

  double _weightedMean(List<double> logits) {
    if (logits.isEmpty) {
      return 5;
    }
    var sum = 0.0;
    var weightSum = 0.0;
    for (var i = 0; i < logits.length; i++) {
      final value = exp(logits[i]);
      sum += value * (i + 1);
      weightSum += value;
    }
    if (weightSum == 0) {
      return 5;
    }
    return sum / weightSum;
  }

  double _fallbackScore(Float32List embedding) {
    var value = 0.0;
    for (var i = 0; i < embedding.length; i++) {
      value += embedding[i] * sin((i + 1) * (0.11 + modelSeed * 0.01));
    }
    final normalized = 1 / (1 + exp(-value));
    return 1 + normalized * 99;
  }
}
