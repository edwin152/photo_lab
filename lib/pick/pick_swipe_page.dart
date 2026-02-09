import 'dart:math';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../settings/app_settings.dart';
import 'pick_assets.dart';
import 'pick_constants.dart';
import 'pick_models.dart';
import 'pick_preview_page.dart';
import 'pick_repository.dart';
import 'pick_shared_widgets.dart';

class PickFilter {
  const PickFilter._(
    this.type, {
    this.groupName,
    this.scoreLabel,
    this.minScore,
    this.maxScore,
  });

  const PickFilter.all() : this._(PickFilterType.all);

  const PickFilter.ungrouped() : this._(PickFilterType.ungrouped);

  const PickFilter.grouped() : this._(PickFilterType.grouped);

  const PickFilter.group(String groupName)
    : this._(PickFilterType.group, groupName: groupName);

  const PickFilter.scoreRange({
    required String label,
    required int minScore,
    required int maxScore,
  }) : this._(
         PickFilterType.scoreRange,
         scoreLabel: label,
         minScore: minScore,
         maxScore: maxScore,
       );

  final PickFilterType type;
  final String? groupName;
  final String? scoreLabel;
  final int? minScore;
  final int? maxScore;
}

enum PickFilterType { all, ungrouped, grouped, group, scoreRange }

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
    with TickerProviderStateMixin {
  final PickRepository _repository = PickRepository.instance;
  final List<_SwipeAction> _actions = [];
  final Map<String, AssetEntity> _assets = {};
  List<PickPhoto> _photos = [];
  bool _loading = true;
  Offset _dragOffset = Offset.zero;
  late AnimationController _controller;
  Animation<Offset>? _animation;
  bool _isResetting = false;
  double _resetStartBackgroundProgress = 0.0;
  static const double _swipeReleaseDistance = 100;

  // 飞出卡片的独立动画
  late AnimationController _exitController;
  Animation<Offset>? _exitAnimation;
  PickPhoto? _exitingPhoto;
  AssetEntity? _exitingAsset;
  Offset _exitingStartOffset = Offset.zero;

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
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _exitController.addListener(() {
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
    _exitController.dispose();
    super.dispose();
  }

  Future<void> _loadAssets() async {
    var filtered = widget.allPhotos.where((photo) {
      switch (widget.filter.type) {
        case PickFilterType.all:
          return true;
        case PickFilterType.ungrouped:
          return photo.groupName == null;
        case PickFilterType.grouped:
          return photo.groupName != null;
        case PickFilterType.group:
          return photo.groupName == widget.filter.groupName;
        case PickFilterType.scoreRange:
          final score = photo.tag1;
          if (score == null) {
            return false;
          }
          return score >= (widget.filter.minScore ?? 1) &&
              score <= (widget.filter.maxScore ?? 100);
      }
    }).toList();

    // 对于AI评分分组，如果有未确认的照片，只展示未确认的
    if (widget.filter.type == PickFilterType.scoreRange) {
      final ungrouped = filtered
          .where((photo) => photo.groupName == null)
          .toList();
      if (ungrouped.isNotEmpty) {
        filtered = ungrouped;
      }
    }

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

  PickPhoto? get _nextPhoto {
    final nextIndex = _actions.length + 1;
    if (_photos.isEmpty || nextIndex >= _photos.length) {
      return null;
    }
    return _photos[nextIndex];
  }

  AssetEntity? _assetForPhoto(PickPhoto photo) => _assets[photo.assetId];

  Future<void> _handleDecision(String groupName) async {
    final photo = _currentPhoto;
    if (photo == null) {
      return;
    }
    // 先同步更新 UI 状态，避免闪烁
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
    // 在后台更新数据库
    await _repository.updateGroup(photoId: photo.id, groupName: groupName);
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
    _isResetting = target == Offset.zero;
    if (_isResetting) {
      _resetStartBackgroundProgress =
          (_dragOffset.dx.abs() / _swipeReleaseDistance).clamp(0.0, 1.0);
    }
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
          _isResetting = false;
        });
      });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += Offset(details.delta.dx, 0);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_dragOffset.dx > _swipeReleaseDistance) {
      // 立即开始飞出动画并更新列表
      _startExitAnimation(const Offset(500, 0), groupName: groupConfirmed);
    } else if (_dragOffset.dx < -_swipeReleaseDistance) {
      _startExitAnimation(const Offset(-500, 0), groupName: groupPendingDelete);
    } else {
      _animateTo(Offset.zero, onComplete: () {});
    }
  }

  void _startExitAnimation(Offset target, {required String groupName}) {
    final photo = _currentPhoto;
    final asset = photo == null ? null : _assetForPhoto(photo);
    if (photo == null || asset == null) {
      return;
    }

    // 保存正在飞出的卡片信息
    _exitingPhoto = photo;
    _exitingAsset = asset;
    _exitingStartOffset = _dragOffset;

    // 立即更新照片列表，让下一张卡片成为当前卡片
    _handleDecision(groupName);

    // 重置当前卡片的拖动状态
    setState(() {
      _dragOffset = Offset.zero;
      _animation = null;
      _isResetting = false;
    });

    // 启动飞出卡片的动画
    _exitController.stop();
    _exitAnimation = Tween<Offset>(
      begin: _exitingStartOffset,
      end: target,
    ).animate(CurvedAnimation(parent: _exitController, curve: Curves.easeOut));
    _exitController
      ..reset()
      ..forward().whenComplete(() {
        setState(() {
          _exitingPhoto = null;
          _exitingAsset = null;
          _exitAnimation = null;
        });
      });
  }

  Future<void> _openPreview(PickPhoto photo) async {
    final asset = _assetForPhoto(photo);
    if (asset == null) {
      return;
    }
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            PickPreviewPage(asset: asset),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const curve = Curves.easeInOut;
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: curve,
            reverseCurve: curve,
          );
          return ScaleTransition(
            scale: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
            child: FadeTransition(opacity: curvedAnimation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photo = _currentPhoto;
    final nextPhoto = _nextPhoto;
    final asset = photo == null ? null : _assetForPhoto(photo);
    final nextAsset = nextPhoto == null ? null : _assetForPhoto(nextPhoto);
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
            ? const EmptyGroupHint()
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
                          final cardWidth = min(
                            min(maxWidth, maxHeight * 3 / 4),
                            360.0,
                          );
                          final size = Size(cardWidth, cardWidth * 4 / 3);
                          final activeOffset = _animation?.value ?? _dragOffset;
                          final swipeProgress =
                              (activeOffset.dx.abs() / _swipeReleaseDistance)
                                  .clamp(0.0, 1.0);
                          final backgroundProgress = _isResetting
                              ? (_resetStartBackgroundProgress +
                                        (1 - _resetStartBackgroundProgress) *
                                            _controller.value)
                                    .clamp(0.0, 1.0)
                              : swipeProgress;
                          final settings = AppSettingsScope.of(context);
                          final useSingleTapPreview =
                              settings.enableSingleTapPreview;
                          return Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              if (nextPhoto != null && nextAsset != null)
                                _buildUnifiedCard(
                                  key: ValueKey(nextPhoto.id),
                                  size: size,
                                  asset: nextAsset,
                                  photo: nextPhoto,
                                  isBackground: true,
                                  backgroundProgress: backgroundProgress,
                                  dragOffset: Offset.zero,
                                  swipeThreshold: _swipeReleaseDistance,
                                  onPanUpdate: null,
                                  onPanEnd: null,
                                  onDoubleTap: null,
                                  onTap: null,
                                  useAdvancedScore: settings.enableAdvancedScore,
                                ),
                              if (photo != null && asset != null)
                                _buildUnifiedCard(
                                  key: ValueKey(photo.id),
                                  size: size,
                                  asset: asset,
                                  photo: photo,
                                  isBackground: false,
                                  backgroundProgress: 1.0,
                                  dragOffset: activeOffset,
                                  swipeThreshold: _swipeReleaseDistance,
                                  onPanUpdate: _onPanUpdate,
                                  onPanEnd: _onPanEnd,
                                  onDoubleTap: useSingleTapPreview
                                      ? null
                                      : () => _openPreview(photo),
                                  onTap: useSingleTapPreview
                                      ? () => _openPreview(photo)
                                      : null,
                                  useAdvancedScore: settings.enableAdvancedScore,
                                )
                              else
                                const Text('没有更多照片了'),
                              // 飞出的卡片渲染在最顶层
                              if (_exitingPhoto != null &&
                                  _exitingAsset != null)
                                _buildUnifiedCard(
                                  key: ValueKey('exiting_${_exitingPhoto!.id}'),
                                  size: size,
                                  asset: _exitingAsset!,
                                  photo: _exitingPhoto!,
                                  isBackground: false,
                                  backgroundProgress: 1.0,
                                  dragOffset:
                                      _exitAnimation?.value ??
                                      _exitingStartOffset,
                                  swipeThreshold: _swipeReleaseDistance,
                                  onPanUpdate: null,
                                  onPanEnd: null,
                                  onDoubleTap: null,
                                  onTap: null,
                                  useAdvancedScore: settings.enableAdvancedScore,
                                ),
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
      case PickFilterType.scoreRange:
        return '评分 ${filter.scoreLabel ?? ''}'.trim();
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

int _convertToBasicScore(int advancedScore) {
  if (advancedScore <= 20) return 1;
  if (advancedScore <= 40) return 2;
  if (advancedScore <= 60) return 3;
  if (advancedScore <= 80) return 4;
  return 5;
}

Widget _buildUnifiedCard({
  Key? key,
  required Size size,
  required AssetEntity asset,
  required PickPhoto photo,
  required bool isBackground,
  required double backgroundProgress,
  required Offset dragOffset,
  required double swipeThreshold,
  required GestureDragUpdateCallback? onPanUpdate,
  required GestureDragEndCallback? onPanEnd,
  required VoidCallback? onDoubleTap,
  required VoidCallback? onTap,
  required bool useAdvancedScore,
}) {
  final borderRadius = BorderRadius.circular(20);

  // 计算前景卡片的参数
  final rotation = isBackground ? 0.0 : dragOffset.dx / size.width * 0.3;
  final swipeProgress = (dragOffset.dx.abs() / swipeThreshold).clamp(0.0, 1.0);
  final isDragging = !isBackground && dragOffset.dx.abs() > 4;
  final isReady = swipeProgress >= 1;
  final baseColor = dragOffset.dx > 0
      ? Colors.green
      : dragOffset.dx < 0
      ? Colors.red
      : Colors.transparent;

  // 根据分组状态决定阴影颜色
  Color shadowColor;
  if (isDragging) {
    shadowColor = baseColor.withValues(alpha: 0.2 + 0.4 * swipeProgress);
  } else if (photo.groupName == groupPendingDelete) {
    shadowColor = Colors.red.withValues(alpha: 0.6);
  } else if (photo.groupName == groupConfirmed) {
    shadowColor = Colors.green.withValues(alpha: 0.6);
  } else {
    shadowColor = Colors.black26;
  }

  // 背景卡片的阴影颜色，随 progress 逐渐变深
  final backgroundShadowColor = isBackground
      ? Colors.black.withValues(alpha: 0.06 + 0.06 * backgroundProgress)
      : shadowColor;

  // 背景卡片的参数
  final scale = isBackground ? (0.5 + 0.5 * backgroundProgress) : 1.0;
  final opacity = isBackground ? backgroundProgress : 1.0;

  // 统一的结构：所有卡片都用相同的根 widget 类型
  return Opacity(
    key: key,
    opacity: opacity,
    child: Transform.scale(
      scale: scale,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: onPanUpdate,
        onPanEnd: onPanEnd,
        onDoubleTap: onDoubleTap,
        onTap: onTap,
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
                    boxShadow: [
                      BoxShadow(
                        color: backgroundShadowColor,
                        blurRadius: isBackground
                            ? 6 + 12 * backgroundProgress
                            : 18,
                        offset: isBackground
                            ? Offset(0, 2 + 4 * backgroundProgress)
                            : const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: backgroundShadowColor.withValues(
                          alpha: isBackground
                              ? backgroundProgress * 0.35
                              : 0.35,
                        ),
                        blurRadius: isBackground
                            ? 4 + 8 * backgroundProgress
                            : 12,
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                  child: RepaintBoundary(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: borderRadius,
                      ),
                      child: ClipRRect(
                        borderRadius: borderRadius,
                        child: AssetEntityImage(
                          asset,
                          key: ValueKey(asset.id),
                          fit: BoxFit.contain,
                          isOriginal: false,
                        ),
                      ),
                    ),
                  ),
                ),
                // 显示 tag1 在右上角
                if (photo.tag1 != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        useAdvancedScore
                            ? '${photo.tag1}'
                            : '${_convertToBasicScore(photo.tag1!)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                if (isDragging)
                  Positioned.fill(
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: isReady ? 1 : 0,
                        duration: const Duration(milliseconds: 120),
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            dragOffset.dx > 0 ? Icons.check : Icons.close,
                            color: baseColor,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
