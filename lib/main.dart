import 'package:flutter/material.dart';
import './pick/pick.dart';
import './watermark/watermark.dart';
import './profile/profile.dart';

void main() {
  runApp(const PhotoLabApp());
}

class PhotoLabApp extends StatelessWidget {
  const PhotoLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photo Lab',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomeTabs(),
    );
  }
}

class HomeTabs extends StatefulWidget {
  const HomeTabs({super.key});

  @override
  State<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<HomeTabs> {
  int _currentIndex = 0;

  late final List<Widget> _pages = const [ToolsPage(), ProfilePage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: '工具',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  static final List<ToolItem> toolItems = [
    ToolItem(
      title: '照片评选',
      color: Colors.indigo,
      pageBuilder: (context) => const PickPage(title: '照片评选'),
    ),
    ToolItem(
      title: '照片水印',
      color: Colors.teal,
      pageBuilder: (context) => const WatermarkPage(title: '照片水印'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('工具')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          itemCount: toolItems.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (context, index) {
            final item = toolItems[index];
            return _ToolGridButton(item: item);
          },
        ),
      ),
    );
  }
}

class _ToolGridButton extends StatelessWidget {
  const _ToolGridButton({required this.item});

  final ToolItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: item.color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: item.pageBuilder));
        },
        child: Center(
          child: Text(
            item.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: item.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class ToolItem {
  const ToolItem({
    required this.title,
    required this.color,
    required this.pageBuilder,
  });

  final String title;
  final Color color;
  final WidgetBuilder pageBuilder;
}
