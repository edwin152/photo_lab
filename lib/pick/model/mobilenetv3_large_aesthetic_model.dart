import 'tflite_aesthetic_model_base.dart';

/// MobileNetV3 aesthetic model powered by TensorFlow Lite.
class MobileNetV3LargeAestheticModel extends TfliteAestheticModelBase {
  MobileNetV3LargeAestheticModel()
    : super(
        modelAssetPath: 'assets/models/mobilenetv3_aesthetic.tflite',
        inputSize: 224,
        embeddingSize: 128,
      );

  @override
  String get modelName => 'MobileNetV3';
}
