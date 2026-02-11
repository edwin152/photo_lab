import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'aesthetic_score_model.dart';

abstract class TfliteAestheticModelBase extends AestheticScoreModel {
  TfliteAestheticModelBase({
    required this.modelAssetPath,
    required this.inputSize,
    required this.embeddingSize,
  });

  final String modelAssetPath;
  final int inputSize;
  final int embeddingSize;

  Interpreter? _interpreter;

  Future<void> _ensureInterpreter() async {
    if (_interpreter != null) {
      return;
    }
    _interpreter = await Interpreter.fromAsset(modelAssetPath);
  }

  @override
  Future<AestheticScoreResult> score(Uint8List imageBytes) async {
    if (imageBytes.isEmpty) {
      return AestheticScoreResult(
        score: 1,
        embedding: Float32List(embeddingSize),
      );
    }

    try {
      await _ensureInterpreter();
      final input = _buildInputTensor(imageBytes);
      final output = List.generate(1, (_) => List<double>.filled(1, 0));
      _interpreter!.run(input, output);
      final raw = output[0][0];
      final score = _normalizeTo100(raw);
      return AestheticScoreResult(
        score: score,
        embedding: _buildEmbeddingFromImage(imageBytes),
      );
    } catch (_) {
      return AestheticScoreResult(
        score: _fallbackScore(imageBytes),
        embedding: _buildEmbeddingFromImage(imageBytes),
      );
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

  List<List<List<List<double>>>> _buildInputTensor(Uint8List imageBytes) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      return List.generate(
        1,
        (_) => List.generate(
          inputSize,
          (_) => List.generate(inputSize, (_) => List<double>.filled(3, 0)),
        ),
      );
    }

    final resized = img.copyResize(
      decoded,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.cubic,
    );

    final input = List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (y) => List.generate(inputSize, (x) {
          final pixel = resized.getPixel(x, y);
          return <double>[
            (pixel.r - 127.5) / 127.5,
            (pixel.g - 127.5) / 127.5,
            (pixel.b - 127.5) / 127.5,
          ];
        }),
      ),
    );
    return input;
  }

  Float32List _buildEmbeddingFromImage(Uint8List imageBytes) {
    final embedding = Float32List(embeddingSize);
    final step = max(1, imageBytes.length ~/ embeddingSize);
    for (var i = 0; i < embeddingSize; i++) {
      final start = i * step;
      if (start >= imageBytes.length) {
        break;
      }
      final end = min(start + step, imageBytes.length);
      var sum = 0;
      for (var j = start; j < end; j++) {
        sum += imageBytes[j];
      }
      final count = max(1, end - start);
      embedding[i] = sum / (count * 255.0);
    }
    return embedding;
  }

  double _normalizeTo100(double raw) {
    final normalized = 1 / (1 + exp(-raw));
    return 1 + normalized * 99;
  }

  double _fallbackScore(Uint8List imageBytes) {
    if (imageBytes.isEmpty) {
      return 1;
    }
    final sampleSize = min(4096, imageBytes.length);
    var sum = 0;
    for (var i = 0; i < sampleSize; i++) {
      sum += imageBytes[i];
    }
    final avg = sum / sampleSize;
    return 1 + (avg / 255.0) * 99;
  }
}
