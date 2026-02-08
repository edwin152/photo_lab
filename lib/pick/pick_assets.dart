import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class AssetEntityImage extends StatefulWidget {
  const AssetEntityImage(
    this.asset, {
    super.key,
    this.fit,
    required this.isOriginal,
  });

  final AssetEntity asset;
  final BoxFit? fit;
  final bool isOriginal;

  @override
  State<AssetEntityImage> createState() => _AssetEntityImageState();
}

class _AssetEntityImageState extends State<AssetEntityImage> {
  static final Map<String, Uint8List> _thumbnailCache = {};
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
    if (widget.isOriginal) {
      return widget.asset.originBytes;
    }
    final cached = _thumbnailCache[widget.asset.id];
    if (cached != null) {
      return Future.value(cached);
    }
    return widget.asset
        .thumbnailDataWithSize(const ThumbnailSize.square(500))
        .then((bytes) {
          if (bytes != null) {
            _thumbnailCache[widget.asset.id] = bytes;
          }
          return bytes;
        });
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
          return const ImagePlaceholder();
        }
        return const ImageLoadingPlaceholder();
      },
    );
  }
}

class ImageLoadingPlaceholder extends StatelessWidget {
  const ImageLoadingPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class ImagePlaceholder extends StatelessWidget {
  const ImagePlaceholder({super.key});

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
