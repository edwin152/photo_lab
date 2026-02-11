import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import 'pick_constants.dart';
import 'pick_models.dart';
import 'pick_repository.dart';
import 'pick_selection_page.dart';
import 'pick_shared_widgets.dart';
import 'pick_swipe_page.dart';
import '../settings/app_settings.dart';
import 'model/aesthetic_score_model.dart';
import 'model/mobilenetv3_large_aesthetic_model.dart';
import 'model/nima_aesthetic_model.dart';

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
  bool _scoring = false;
  int _scoreCompleted = 0;
  int _scoreTotal = 0;

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
    
    // 验证照片在系统中是否还存在，过滤掉已删除的照片
    final validPhotos = <PickPhoto>[];
    for (final photo in photos) {
      final asset = await AssetEntity.fromId(photo.assetId);
      if (asset != null) {
        validPhotos.add(photo);
      }
    }
    
    final summaries = await _repository.fetchGroupSummaries(_session!.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _photos = validPhotos;
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

  Future<void> _runAiScore() async {
    if (_session == null || _scoring) {
      return;
    }
    final settings = AppSettingsScope.of(context);
    final scoreModel = _buildScoreModel(settings.scoreModelType);
    final photosToScore = _photos.where((photo) => photo.tag1 == null).toList();
    if (photosToScore.isEmpty) {
      return;
    }
    setState(() {
      _scoring = true;
      _scoreCompleted = 0;
      _scoreTotal = photosToScore.length;
    });
    for (var i = 0; i < photosToScore.length; i++) {
      final photo = photosToScore[i];
      final asset = await AssetEntity.fromId(photo.assetId);
      final bytes = await asset?.thumbnailDataWithSize(
        const ThumbnailSize.square(512),
      );
      final result = await scoreModel.score(bytes ?? Uint8List(0));
      final score = result.roundedScore;
      await _repository.updateTags(photoId: photo.id, tag1: score);
      if (!mounted) {
        return;
      }
      setState(() {
        _scoreCompleted = i + 1;
        _photos = _photos
            .map(
              (item) => item.id == photo.id ? item.copyWith(tag1: score) : item,
            )
            .toList();
      });
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _scoring = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final totalCount = _photos.length;
    final ungroupedCount = _photos
        .where((photo) => photo.groupName == null)
        .length;
    final groupedCount = totalCount - ungroupedCount;
    final scoreBuckets = _buildScoreBuckets(
      photos: _photos,
      advanced: settings.enableAdvancedScore,
    );
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
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _refreshData,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
                            subtitle: group.groupName == groupPendingDelete
                                ? '${group.count} 张 · 长按删除照片'
                                : '${group.count} 张',
                            icon: group.groupName == groupPendingDelete
                                ? Icons.delete_outline
                                : Icons.bookmark_outline,
                            onTap: () =>
                                _openSwipe(PickFilter.group(group.groupName)),
                            onLongPress: group.groupName == groupPendingDelete
                                ? _confirmDeletePending
                                : null,
                            backgroundColor: group.groupName == groupConfirmed
                                ? Colors.green.withValues(alpha: 0.3)
                                : group.groupName == groupPendingDelete
                                ? Colors.red.withValues(alpha: 0.3)
                                : null,
                          ),
                        ),
                      const SizedBox(height: 16),
                      _SectionTitle(title: 'AI 评分分组'),
                      if (scoreBuckets.every((bucket) => bucket.count == 0))
                        const EmptyGroupHint()
                      else
                        ...scoreBuckets.where((bucket) => bucket.count > 0).map(
                          (bucket) {
                            return _EntryTile(
                              title: bucket.label,
                              subtitle: '',
                              icon: Icons.auto_awesome,
                              onTap: () => _openSwipe(
                                PickFilter.scoreRange(
                                  label: bucket.label,
                                  minScore: bucket.minScore,
                                  maxScore: bucket.maxScore,
                                ),
                              ),
                              customSubtitle: _buildScoreBucketSubtitle(
                                ungroupedCount: bucket.ungroupedCount,
                                confirmedCount: bucket.confirmedCount,
                                pendingDeleteCount: bucket.pendingDeleteCount,
                                totalCount: bucket.count,
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _AiScoreActionCard(
                          scoring: _scoring,
                          completed: _scoreCompleted,
                          total: _scoreTotal,
                          modelName: settings.scoreModelType.label,
                          onPressed: _scoring || _photos.isEmpty
                              ? null
                              : _runAiScore,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }


  AestheticScoreModel _buildScoreModel(ScoreModelType type) {
    switch (type) {
      case ScoreModelType.mobileNetV3:
        return MobileNetV3LargeAestheticModel();
      case ScoreModelType.nima:
        return NimaAestheticModel();
    }
  }
}

List<_ScoreBucket> _buildScoreBuckets({
  required List<PickPhoto> photos,
  required bool advanced,
}) {
  final ranges = <_ScoreBucket>[
    const _ScoreBucket(label: '1', minScore: 1, maxScore: 20),
    const _ScoreBucket(label: '2', minScore: 21, maxScore: 40),
    const _ScoreBucket(label: '3', minScore: 41, maxScore: 60),
    const _ScoreBucket(label: '4', minScore: 61, maxScore: 80),
    const _ScoreBucket(label: '5', minScore: 81, maxScore: 100),
  ];
  if (advanced) {
    return ranges.map((bucket) {
      final stats = _countScoreInRangeByGroup(
        photos,
        bucket.minScore,
        bucket.maxScore,
      );
      return bucket.copyWith(
        label: '${bucket.minScore}-${bucket.maxScore}',
        count: stats['total']!,
        ungroupedCount: stats['ungrouped']!,
        confirmedCount: stats['confirmed']!,
        pendingDeleteCount: stats['pendingDelete']!,
      );
    }).toList();
  }
  return ranges.map((bucket) {
    final stats = _countScoreInRangeByGroup(
      photos,
      bucket.minScore,
      bucket.maxScore,
    );
    return bucket.copyWith(
      count: stats['total']!,
      ungroupedCount: stats['ungrouped']!,
      confirmedCount: stats['confirmed']!,
      pendingDeleteCount: stats['pendingDelete']!,
    );
  }).toList();
}

Map<String, int> _countScoreInRangeByGroup(
  List<PickPhoto> photos,
  int minScore,
  int maxScore,
) {
  final inRange = photos.where(
    (photo) =>
        photo.tag1 != null &&
        photo.tag1! >= minScore &&
        photo.tag1! <= maxScore,
  );
  final ungrouped = inRange.where((photo) => photo.groupName == null).length;
  final confirmed = inRange
      .where((photo) => photo.groupName == groupConfirmed)
      .length;
  final pendingDelete = inRange
      .where((photo) => photo.groupName == groupPendingDelete)
      .length;
  return {
    'total': inRange.length,
    'ungrouped': ungrouped,
    'confirmed': confirmed,
    'pendingDelete': pendingDelete,
  };
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
    this.onTap,
    this.onLongPress,
    this.backgroundColor,
    this.customSubtitle,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? backgroundColor;
  final Widget? customSubtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: backgroundColor,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: customSubtitle ?? Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

Widget _buildScoreBucketSubtitle({
  required int ungroupedCount,
  required int confirmedCount,
  required int pendingDeleteCount,
  required int totalCount,
}) {
  final spans = <InlineSpan>[];

  if (ungroupedCount > 0) {
    spans.add(
      TextSpan(
        text: '$ungroupedCount 未确认',
        style: const TextStyle(color: Colors.grey),
      ),
    );
  }

  if (confirmedCount > 0) {
    if (spans.isNotEmpty) {
      spans.add(const TextSpan(text: ' · '));
    }
    spans.add(
      TextSpan(
        text: '$confirmedCount 已确认',
        style: const TextStyle(color: Colors.green),
      ),
    );
  }

  if (pendingDeleteCount > 0) {
    if (spans.isNotEmpty) {
      spans.add(const TextSpan(text: ' · '));
    }
    spans.add(
      TextSpan(
        text: '$pendingDeleteCount 待删除',
        style: const TextStyle(color: Colors.red),
      ),
    );
  }

  if (spans.isEmpty) {
    return Text('$totalCount 张');
  }

  return Text.rich(TextSpan(children: spans));
}

class _ScoreBucket {
  const _ScoreBucket({
    required this.label,
    required this.minScore,
    required this.maxScore,
    this.count = 0,
    this.ungroupedCount = 0,
    this.confirmedCount = 0,
    this.pendingDeleteCount = 0,
  });

  final String label;
  final int minScore;
  final int maxScore;
  final int count;
  final int ungroupedCount;
  final int confirmedCount;
  final int pendingDeleteCount;

  _ScoreBucket copyWith({
    String? label,
    int? count,
    int? ungroupedCount,
    int? confirmedCount,
    int? pendingDeleteCount,
  }) {
    return _ScoreBucket(
      label: label ?? this.label,
      minScore: minScore,
      maxScore: maxScore,
      count: count ?? this.count,
      ungroupedCount: ungroupedCount ?? this.ungroupedCount,
      confirmedCount: confirmedCount ?? this.confirmedCount,
      pendingDeleteCount: pendingDeleteCount ?? this.pendingDeleteCount,
    );
  }
}

class _AiScoreActionCard extends StatelessWidget {
  const _AiScoreActionCard({
    required this.scoring,
    required this.completed,
    required this.total,
    required this.modelName,
    required this.onPressed,
  });

  final bool scoring;
  final int completed;
  final int total;
  final String modelName;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : completed / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('当前模型：$modelName', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        if (scoring)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '评分中：$completed / $total',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress),
            ],
          )
        else
          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('开始 AI 评分'),
          ),
      ],
    );
  }
}
