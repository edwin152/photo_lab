import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
