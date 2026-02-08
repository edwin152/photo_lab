import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import 'pick_constants.dart';
import 'pick_models.dart';
import 'pick_repository.dart';
import 'pick_selection_page.dart';
import 'pick_shared_widgets.dart';
import 'pick_swipe_page.dart';

class PickPage extends StatefulWidget {
  const PickPage({super.key, required this.title});

  final String title;

  @override
  State<PickPage> createState() => _PickPageState();
}

class _PickPageState extends State<PickPage> {
  final PickRepository _repository = PickRepository.instance;
  PickSession? _session;
  List<PickPhoto> _photos = [];
  List<PickGroupSummary> _groupSummaries = [];
  bool _loading = true;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    setState(() {
      _loading = true;
      _permissionDenied = false;
    });
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      setState(() {
        _permissionDenied = true;
        _loading = false;
      });
      return;
    }
    final session = await _repository.fetchActiveSession();
    if (!mounted) {
      return;
    }
    if (session == null) {
      setState(() {
        _session = null;
        _photos = [];
        _groupSummaries = [];
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openSelection();
      });
      return;
    }
    _session = session;
    await _refreshData();
  }

  Future<void> _refreshData() async {
    if (_session == null) {
      return;
    }
    final photos = await _repository.fetchPhotos(_session!.id);
    final summaries = await _repository.fetchGroupSummaries(_session!.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _photos = photos;
      _groupSummaries = summaries;
      _loading = false;
    });
  }

  Future<void> _openSelection() async {
    final selectedAssetIds = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(builder: (_) => const PickSelectionPage()),
    );
    if (selectedAssetIds == null || selectedAssetIds.isEmpty) {
      return;
    }
    final session = await _repository.createSession();
    await _repository.addPhotos(
      sessionId: session.id,
      assetIds: selectedAssetIds,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _session = session;
    });
    await _refreshData();
  }

  Future<void> _openSwipe(PickFilter filter) async {
    if (_session == null) {
      return;
    }
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PickSwipePage(
          sessionId: _session!.id,
          filter: filter,
          allPhotos: _photos,
        ),
      ),
    );
    if (result == true) {
      await _refreshData();
    }
  }

  Future<void> _confirmDeletePending() async {
    if (_session == null) {
      return;
    }
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除待删除照片'),
          content: const Text('是否要删除所有待删除照片？此操作不可撤回。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (shouldDelete != true) {
      return;
    }
    final pendingIds = _photos
        .where((photo) => photo.groupName == groupPendingDelete)
        .map((photo) => photo.assetId)
        .toList();
    if (pendingIds.isEmpty) {
      return;
    }
    await PhotoManager.editor.deleteWithIds(pendingIds);
    await _repository.removePhotosByGroup(
      sessionId: _session!.id,
      groupName: groupPendingDelete,
    );
    if (!mounted) {
      return;
    }
    await _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = _photos.length;
    final ungroupedCount = _photos
        .where((photo) => photo.groupName == null)
        .length;
    final groupedCount = totalCount - ungroupedCount;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: _openSelection,
            tooltip: '重新选择照片',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _permissionDenied
          ? const _PermissionHint()
          : _session == null
          ? _EmptyState(onPick: _openSelection)
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SectionTitle(title: '筛选入口'),
                  _EntryTile(
                    title: '全部',
                    subtitle: '共 $totalCount 张',
                    icon: Icons.photo,
                    onTap: () => _openSwipe(const PickFilter.all()),
                  ),
                  _EntryTile(
                    title: '未分组',
                    subtitle: '待处理 $ungroupedCount 张',
                    icon: Icons.filter_none,
                    onTap: () => _openSwipe(const PickFilter.ungrouped()),
                  ),
                  _EntryTile(
                    title: '已分组',
                    subtitle: '共 $groupedCount 张',
                    icon: Icons.folder_open,
                    onTap: () => _openSwipe(const PickFilter.grouped()),
                  ),
                  const SizedBox(height: 16),
                  _SectionTitle(title: '分组列表'),
                  if (_groupSummaries.isEmpty)
                    const EmptyGroupHint()
                  else
                    ..._groupSummaries.map(
                      (group) => _EntryTile(
                        title: group.groupName,
                        subtitle: '${group.count} 张',
                        icon: group.groupName == groupPendingDelete
                            ? Icons.delete_outline
                            : Icons.bookmark_outline,
                        onTap: () =>
                            _openSwipe(PickFilter.group(group.groupName)),
                        onLongPress: group.groupName == groupPendingDelete
                            ? _confirmDeletePending
                            : null,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _PermissionHint extends StatelessWidget {
  const _PermissionHint();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('需要访问相册权限才能进行评选，请在系统设置中开启。', textAlign: TextAlign.center),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_library_outlined, size: 64),
          const SizedBox(height: 16),
          const Text('暂无正在评选的照片'),
          const SizedBox(height: 16),
          FilledButton(onPressed: onPick, child: const Text('选择照片开始评选')),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.onLongPress,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}
