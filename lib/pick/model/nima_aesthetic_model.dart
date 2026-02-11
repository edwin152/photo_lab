import 'tflite_aesthetic_model_base.dart';

/// NIMA aesthetic model (Google) powered by TensorFlow Lite.
class NimaAestheticModel extends TfliteAestheticModelBase {
  NimaAestheticModel()
    : super(
        modelAssetPath: 'assets/models/nima_aesthetic.tflite',
        inputSize: 224,
        embeddingSize: 128,
      );

  @override
  String get modelName => 'NIMA (Google)';
}
