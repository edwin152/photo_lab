import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_view/photo_view.dart';

import 'pick_assets.dart';

class PickPreviewPage extends StatefulWidget {
  const PickPreviewPage({super.key, required this.asset});

  final AssetEntity asset;

  @override
  State<PickPreviewPage> createState() => _PickPreviewPageState();
}

class _PickPreviewPageState extends State<PickPreviewPage> {
  late final PhotoViewController _photoController;

  @override
  void initState() {
    super.initState();
    _photoController = PhotoViewController();
  }

  @override
  void dispose() {
    _photoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => Navigator.of(context).pop(),
              child: FutureBuilder<Uint8List?>(
                future: widget.asset.originBytes,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.data != null) {
                    return PhotoView(
                      controller: _photoController,
                      imageProvider: MemoryImage(snapshot.data!),
                      backgroundDecoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.covered * 3.0,
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.done) {
                    return const ImagePlaceholder();
                  }
                  return const ImageLoadingPlaceholder();
                },
              ),
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
