import 'package:flutter/material.dart';

class EmptyGroupHint extends StatelessWidget {
  const EmptyGroupHint({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Text('暂无分组结果，快去滑动卡片吧。'),
    );
  }
}
