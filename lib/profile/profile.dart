import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../pick/model/model_catalog.dart';
import '../pick/model/model_download_manager.dart';
import '../settings/app_settings.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<String> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    return '版本号：${info.version}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            const _PreviewSettingsCard(),
            const SizedBox(height: 12),
            const _ScoreModelSettingsCard(),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {},
                  child: const Text('检查更新'),
                ),
              ),
            ),
            FutureBuilder<String>(
              future: _loadVersion(),
              builder: (context, snapshot) {
                final text = snapshot.data ?? '版本号：加载中...';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewSettingsCard extends StatelessWidget {
  const _PreviewSettingsCard();

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('单击卡片预览'),
              subtitle: Text(
                settings.enableSingleTapPreview
                    ? '已启用单击预览'
                    : '关闭时改为双击预览',
              ),
              value: settings.enableSingleTapPreview,
              onChanged: settings.setEnableSingleTapPreview,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('AI 评分展示'),
              subtitle: Text(
                settings.enableAdvancedScore ? '显示高级评分（1-100）' : '显示基础评分（1-5）',
              ),
              value: settings.enableAdvancedScore,
              onChanged: settings.setEnableAdvancedScore,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreModelSettingsCard extends StatefulWidget {
  const _ScoreModelSettingsCard();

  @override
  State<_ScoreModelSettingsCard> createState() => _ScoreModelSettingsCardState();
}

class _ScoreModelSettingsCardState extends State<_ScoreModelSettingsCard> {
  final Set<ScoreModelType> _downloading = <ScoreModelType>{};

  bool _restored = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restored) {
      return;
    }
    _restored = true;
    _restoreDownloadedState();
  }

  Future<void> _restoreDownloadedState() async {
    final settings = AppSettingsScope.of(context);
    for (final definition in scoreModelDefinitions.where((item) => item.requiresDownload)) {
      final path = await ModelDownloadManager.findDownloadedModel(definition);
      if (path != null) {
        settings.markModelDownloaded(type: definition.type, modelPath: path);
      }
    }
  }

  Future<void> _downloadModel({
    required BuildContext context,
    required AppSettings settings,
    required ScoreModelDefinition definition,
  }) async {
    setState(() {
      _downloading.add(definition.type);
    });
    try {
      final path = await ModelDownloadManager.downloadModel(definition);
      settings.markModelDownloaded(type: definition.type, modelPath: path);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${definition.title} 下载完成')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${definition.title} 下载失败：$error')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _downloading.remove(definition.type);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('评分模型', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '支持 TensorFlow Lite 模型下载与切换',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            ...scoreModelDefinitions.map((definition) {
              final selected = settings.selectedModel == definition.type;
              final downloading = _downloading.contains(definition.type);
              final downloaded = settings.isModelDownloaded(definition.type);
              final canSelect = !definition.requiresDownload || downloaded;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(definition.title),
                subtitle: Text(definition.description),
                leading: Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? Theme.of(context).colorScheme.primary : null,
                ),
                trailing: definition.requiresDownload
                    ? downloading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : TextButton(
                              onPressed: downloaded
                                  ? null
                                  : () => _downloadModel(
                                      context: context,
                                      settings: settings,
                                      definition: definition,
                                    ),
                              child: Text(downloaded ? '已下载' : '下载'),
                            )
                    : const Text('内置'),
                onTap: canSelect
                    ? () => settings.setSelectedModel(definition.type)
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('请先下载 ${definition.title} 模型')),
                        );
                      },
              );
            }),
          ],
        ),
      ),
    );
  }
}
