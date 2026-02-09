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
              title: const Text('评分显示模式'),
              subtitle: Text(
                settings.showAdvancedScore
                    ? '显示 1-100 高级分数'
                    : '显示 1-5 简化分数',
              ),
              value: settings.showAdvancedScore,
              onChanged: settings.setShowAdvancedScore,
            ),
          ],
        ),
      ),
    );
  }
}
