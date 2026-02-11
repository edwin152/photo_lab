import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'model_catalog.dart';

class ModelDownloadManager {
  const ModelDownloadManager._();

  static Future<String> downloadModel(ScoreModelDefinition definition) async {
    if (!definition.requiresDownload || definition.downloadUrl == null) {
      throw ArgumentError('该模型不支持下载。');
    }
    final modelsDir = await _modelsDirectory();
    final targetPath = p.join(modelsDir.path, definition.fileName);
    final response = await http.get(Uri.parse(definition.downloadUrl!));
    if (response.statusCode != 200) {
      throw StateError('下载失败，状态码: ${response.statusCode}');
    }
    final file = File(targetPath);
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return targetPath;
  }

  static Future<String?> findDownloadedModel(ScoreModelDefinition definition) async {
    if (!definition.requiresDownload) {
      return null;
    }
    final modelsDir = await _modelsDirectory();
    final targetPath = p.join(modelsDir.path, definition.fileName);
    final file = File(targetPath);
    if (await file.exists()) {
      return targetPath;
    }
    return null;
  }

  static Future<Directory> _modelsDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(p.join(root.path, 'score_models'));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }
}
