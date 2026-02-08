import 'package:flutter/material.dart';

class WatermarkPage extends StatelessWidget {
  const WatermarkPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(
        child: Text('功能正在开发。', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
