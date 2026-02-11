import '../../settings/score_model_option.dart';
import 'aesthetic_score_model.dart';
import 'mobilenetv3_large_aesthetic_model.dart';
import 'nima_tflite_aesthetic_model.dart';

class AestheticModelFactory {
  AestheticModelFactory._();

  static final AestheticScoreModel _mobileNet = MobileNetV3LargeAestheticModel();
  static final AestheticScoreModel _nimaTflite = NimaTfliteAestheticModel();

  static AestheticScoreModel fromOption(ScoreModelOption option) {
    switch (option) {
      case ScoreModelOption.mobilenetV3Large:
        return _mobileNet;
      case ScoreModelOption.nimaTflite:
        return _nimaTflite;
    }
  }
}
