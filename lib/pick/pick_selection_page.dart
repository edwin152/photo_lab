import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import 'pick_assets.dart';

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
