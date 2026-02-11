import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
                settings.enableAdvancedScore
                    ? '显示高级分组（1-100区间）'
                    : '显示基础分组（1-5）；实际评分始终为1-100',
              ),
              value: settings.enableAdvancedScore,
              onChanged: settings.setEnableAdvancedScore,
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('AI 评分模型'),
              subtitle: Text(
                '手动选择模型，不会自动切换。当前：${settings.scoreModelType.label}',
              ),
            ),
            ...ScoreModelType.values.map(
              (model) => RadioListTile<ScoreModelType>(
                contentPadding: EdgeInsets.zero,
                title: Text(model.label),
                subtitle: Text(model.description),
                value: model,
                groupValue: settings.scoreModelType,
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  settings.setScoreModelType(value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
