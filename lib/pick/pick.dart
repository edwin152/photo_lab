import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_view/photo_view.dart';

import 'pick_models.dart';
import 'pick_repository.dart';

const String groupConfirmed = '确认';
const String groupPendingDelete = '待删除';

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
                    const _EmptyGroupHint()
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

class _EmptyGroupHint extends StatelessWidget {
  const _EmptyGroupHint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Text('暂无分组结果，快去滑动卡片吧。'),
    );
  }
}

class PickFilter {
  const PickFilter._(this.type, this.groupName);

  const PickFilter.all() : this._(PickFilterType.all, null);

  const PickFilter.ungrouped() : this._(PickFilterType.ungrouped, null);

  const PickFilter.grouped() : this._(PickFilterType.grouped, null);

  const PickFilter.group(String groupName)
    : this._(PickFilterType.group, groupName);

  final PickFilterType type;
  final String? groupName;
}

enum PickFilterType { all, ungrouped, grouped, group }

class PickSwipePage extends StatefulWidget {
  const PickSwipePage({
    super.key,
    required this.sessionId,
    required this.filter,
    required this.allPhotos,
  });

  final int sessionId;
  final PickFilter filter;
  final List<PickPhoto> allPhotos;

  @override
  State<PickSwipePage> createState() => _PickSwipePageState();
}

class _PickSwipePageState extends State<PickSwipePage>
    with SingleTickerProviderStateMixin {
  final PickRepository _repository = PickRepository.instance;
  final List<_SwipeAction> _actions = [];
  final Map<String, AssetEntity> _assets = {};
  List<PickPhoto> _photos = [];
  bool _loading = true;
  Offset _dragOffset = Offset.zero;
  late AnimationController _controller;
  Animation<Offset>? _animation;
  static const double _swipeThreshold = 120;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _controller.addListener(() {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
    _loadAssets();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadAssets() async {
    final filtered = widget.allPhotos.where((photo) {
      switch (widget.filter.type) {
        case PickFilterType.all:
          return true;
        case PickFilterType.ungrouped:
          return photo.groupName == null;
        case PickFilterType.grouped:
          return photo.groupName != null;
        case PickFilterType.group:
          return photo.groupName == widget.filter.groupName;
      }
    }).toList();
    final assetIds = filtered.map((photo) => photo.assetId).toList();
    final assetFutures = assetIds.map((id) => AssetEntity.fromId(id));
    final assets = (await Future.wait(
      assetFutures,
    )).whereType<AssetEntity>().toList();
    for (final asset in assets) {
      _assets[asset.id] = asset;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _photos = filtered;
      _loading = false;
    });
  }

  PickPhoto? get _currentPhoto {
    if (_photos.isEmpty) {
      return null;
    }
    if (_actions.length >= _photos.length) {
      return null;
    }
    return _photos[_actions.length];
  }

  AssetEntity? _assetForPhoto(PickPhoto photo) => _assets[photo.assetId];

  Future<void> _handleDecision(String groupName) async {
    final photo = _currentPhoto;
    if (photo == null) {
      return;
    }
    await _repository.updateGroup(photoId: photo.id, groupName: groupName);
    _actions.add(
      _SwipeAction(
        photoId: photo.id,
        previousGroup: photo.groupName,
        newGroup: groupName,
      ),
    );
    setState(() {
      _photos = _photos
          .map(
            (item) => item.id == photo.id
                ? item.copyWith(groupName: groupName)
                : item,
          )
          .toList();
    });
  }

  Future<void> _undo() async {
    if (_actions.isEmpty) {
      return;
    }
    final last = _actions.removeLast();
    if (last.previousGroup == null) {
      await _repository.resetGroup(photoId: last.photoId);
    } else {
      await _repository.updateGroup(
        photoId: last.photoId,
        groupName: last.previousGroup!,
      );
    }
    setState(() {
      _photos = _photos
          .map(
            (item) => item.id == last.photoId
                ? item.copyWith(groupName: last.previousGroup)
                : item,
          )
          .toList();
      _dragOffset = Offset.zero;
    });
  }

  void _animateTo(Offset target, {required VoidCallback onComplete}) {
    _controller.stop();
    _animation = Tween<Offset>(
      begin: _dragOffset,
      end: target,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller
      ..reset()
      ..forward().whenComplete(() {
        onComplete();
        setState(() {
          _dragOffset = Offset.zero;
          _animation = null;
        });
      });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_dragOffset.dx > _swipeThreshold) {
      _animateTo(
        Offset(500, _dragOffset.dy),
        onComplete: () => _handleDecision(groupConfirmed),
      );
    } else if (_dragOffset.dx < -_swipeThreshold) {
      _animateTo(
        Offset(-500, _dragOffset.dy),
        onComplete: () => _handleDecision(groupPendingDelete),
      );
    } else {
      _animateTo(Offset.zero, onComplete: () {});
    }
  }

  Future<void> _openPreview(PickPhoto photo) async {
    final asset = _assetForPhoto(photo);
    if (asset == null) {
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PickPreviewPage(asset: asset)));
  }

  @override
  Widget build(BuildContext context) {
    final photo = _currentPhoto;
    final asset = photo == null ? null : _assetForPhoto(photo);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pop(_actions.isNotEmpty);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_titleForFilter(widget.filter)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_actions.isNotEmpty),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _photos.isEmpty
            ? const _EmptyGroupHint()
            : Column(
                children: [
                  Expanded(
                    child: Center(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final maxWidth = max(0.0, constraints.maxWidth - 32);
                          final maxHeight = max(
                            0.0,
                            constraints.maxHeight - 32,
                          );
                          final size = Size(
                            min(maxWidth, 360),
                            min(maxHeight, 520),
                          );
                          return Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              if (photo != null && asset != null)
                                _buildCard(
                                  size: size,
                                  asset: asset,
                                  photo: photo,
                                  dragOffset: _animation?.value ?? _dragOffset,
                                  swipeThreshold: _swipeThreshold,
                                  onPanUpdate: _onPanUpdate,
                                  onPanEnd: _onPanEnd,
                                  onDoubleTap: () => _openPreview(photo),
                                )
                              else
                                const Text('没有更多照片了'),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  _SwipeActionsBar(
                    onUndo: _actions.isEmpty ? null : _undo,
                    remaining: _photos.length - _actions.length,
                  ),
                ],
              ),
      ),
    );
  }

  String _titleForFilter(PickFilter filter) {
    switch (filter.type) {
      case PickFilterType.all:
        return '全部照片';
      case PickFilterType.ungrouped:
        return '未分组';
      case PickFilterType.grouped:
        return '已分组';
      case PickFilterType.group:
        return filter.groupName ?? '分组';
    }
  }
}

class _SwipeActionsBar extends StatelessWidget {
  const _SwipeActionsBar({required this.onUndo, required this.remaining});

  final VoidCallback? onUndo;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          FilledButton.tonalIcon(
            onPressed: onUndo,
            icon: const Icon(Icons.undo),
            label: const Text('撤回'),
          ),
          Text('剩余 $remaining 张'),
        ],
      ),
    );
  }
}

class _SwipeAction {
  _SwipeAction({
    required this.photoId,
    required this.previousGroup,
    required this.newGroup,
  });

  final int photoId;
  final String? previousGroup;
  final String newGroup;
}

Widget _buildCard({
  required Size size,
  required AssetEntity asset,
  required PickPhoto photo,
  required Offset dragOffset,
  required double swipeThreshold,
  required GestureDragUpdateCallback onPanUpdate,
  required GestureDragEndCallback onPanEnd,
  required VoidCallback onDoubleTap,
}) {
  final rotation = dragOffset.dx / size.width * 0.3;
  final swipeProgress = (dragOffset.dx.abs() / swipeThreshold).clamp(0.0, 1.0);
  final isDragging = dragOffset.dx.abs() > 4;
  final actionLabel = dragOffset.dx > 0
      ? groupConfirmed
      : dragOffset.dx < 0
      ? groupPendingDelete
      : '';
  final hintLabel = swipeProgress >= 1 ? '松手$actionLabel' : '继续滑动$actionLabel';
  final baseColor = dragOffset.dx > 0
      ? Colors.green
      : dragOffset.dx < 0
      ? Colors.red
      : Colors.transparent;
  final overlayColor = baseColor.withValues(alpha: 0.2 + 0.6 * swipeProgress);
  return GestureDetector(
    onPanUpdate: onPanUpdate,
    onPanEnd: onPanEnd,
    onDoubleTap: onDoubleTap,
    child: Transform.translate(
      offset: dragOffset,
      child: Transform.rotate(
        angle: rotation,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size.width,
              height: size.height,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AssetEntityImage(
                  asset,
                  fit: BoxFit.cover,
                  isOriginal: false,
                ),
              ),
            ),
            if (isDragging)
              Positioned(
                top: 24,
                left: dragOffset.dx > 0 ? 24 : null,
                right: dragOffset.dx < 0 ? 24 : null,
                child: Transform.rotate(
                  angle: dragOffset.dx > 0 ? -0.2 : 0.2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.08),
                      border: Border.all(color: baseColor, width: 3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      hintLabel,
                      style: TextStyle(
                        color: baseColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            if (isDragging)
              Positioned(
                left: dragOffset.dx > 0 ? 0 : null,
                right: dragOffset.dx < 0 ? 0 : null,
                top: size.height * 0.5 - 20,
                child: Opacity(
                  opacity: swipeProgress,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: overlayColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '释放',
                      style: TextStyle(
                        color: baseColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class PickSelectionPage extends StatefulWidget {
  const PickSelectionPage({super.key});

  @override
  State<PickSelectionPage> createState() => _PickSelectionPageState();
}

class _PickSelectionPageState extends State<PickSelectionPage> {
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _currentAlbum;
  List<AssetEntity> _assets = [];
  List<AssetEntity> _sourceAssets = [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _ascending = false;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      return;
    }
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: false,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _albums = albums;
      _currentAlbum = albums.isNotEmpty ? albums.first : null;
    });
    await _loadAssets();
  }

  Future<void> _loadAssets() async {
    if (_currentAlbum == null) {
      setState(() {
        _assets = [];
        _sourceAssets = [];
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
    });
    final assets = await _currentAlbum!.getAssetListPaged(page: 0, size: 200);
    if (!mounted) {
      return;
    }
    setState(() {
      _sourceAssets = assets;
      _assets = _applyOrder(assets);
      _loading = false;
    });
  }

  List<AssetEntity> _applyOrder(List<AssetEntity> assets) {
    return _ascending ? assets.reversed.toList() : List.of(assets);
  }

  void _toggleSelection(String assetId) {
    setState(() {
      if (_selected.contains(assetId)) {
        _selected.remove(assetId);
      } else {
        _selected.add(assetId);
      }
    });
  }

  void _toggleOrder() {
    setState(() {
      _ascending = !_ascending;
      _assets = _applyOrder(_sourceAssets);
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_assets.isNotEmpty && _selected.length == _assets.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(_assets.map((asset) => asset.id));
      }
    });
  }

  void _submit() {
    Navigator.of(context).pop(_selected.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择照片'),
        actions: [
          IconButton(
            tooltip: _ascending ? '按时间倒序' : '按时间正序',
            icon: Icon(_ascending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: _assets.isEmpty ? null : _toggleOrder,
          ),
          if (_albums.isNotEmpty)
            DropdownButtonHideUnderline(
              child: DropdownButton<AssetPathEntity>(
                value: _currentAlbum,
                items: _albums
                    .map(
                      (album) => DropdownMenuItem(
                        value: album,
                        child: Text(album.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _currentAlbum = value;
                  });
                  _loadAssets();
                },
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _assets.isEmpty
          ? const Center(child: Text('当前相册没有照片'))
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _assets.length,
              itemBuilder: (context, index) {
                final asset = _assets[index];
                final isSelected = _selected.contains(asset.id);
                return GestureDetector(
                  onTap: () => _toggleSelection(asset.id),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AssetEntityImage(
                          asset,
                          fit: BoxFit.cover,
                          isOriginal: false,
                        ),
                      ),
                      if (isSelected)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              TextButton(
                onPressed: _assets.isEmpty ? null : _toggleSelectAll,
                child: Text(
                  _selected.length == _assets.length && _assets.isNotEmpty
                      ? '取消全选'
                      : '全选',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _selected.isEmpty ? null : _submit,
                  child: Text('开始评选（${_selected.length}）'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PickPreviewPage extends StatefulWidget {
  const PickPreviewPage({super.key, required this.asset});

  final AssetEntity asset;

  @override
  State<PickPreviewPage> createState() => _PickPreviewPageState();
}

class _PickPreviewPageState extends State<PickPreviewPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: FutureBuilder<Uint8List?>(
              future: widget.asset.originBytes,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.data != null) {
                  return PhotoView(
                    imageProvider: MemoryImage(snapshot.data!),
                    backgroundDecoration: const BoxDecoration(
                      color: Colors.black,
                    ),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 3.0,
                  );
                }
                if (snapshot.connectionState == ConnectionState.done) {
                  return const _ImagePlaceholder();
                }
                return const _ImageLoadingPlaceholder();
              },
            ),
          ),
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class AssetEntityImage extends StatefulWidget {
  final AssetEntity asset;
  final BoxFit? fit;
  final bool isOriginal;

  const AssetEntityImage(
    this.asset, {
    super.key,
    this.fit,
    required this.isOriginal,
  });

  @override
  State<AssetEntityImage> createState() => _AssetEntityImageState();
}

class _AssetEntityImageState extends State<AssetEntityImage> {
  late Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadBytes();
  }

  @override
  void didUpdateWidget(covariant AssetEntityImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id ||
        oldWidget.isOriginal != widget.isOriginal) {
      _future = _loadBytes();
    }
  }

  Future<Uint8List?> _loadBytes() {
    return widget.isOriginal
        ? widget.asset.originBytes
        : widget.asset.thumbnailDataWithSize(const ThumbnailSize.square(500));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            fit: widget.fit ?? BoxFit.cover,
            gaplessPlayback: true,
          );
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return const _ImagePlaceholder();
        }
        return const _ImageLoadingPlaceholder();
      },
    );
  }
}

class _ImageLoadingPlaceholder extends StatelessWidget {
  const _ImageLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.black45),
      ),
    );
  }
}
