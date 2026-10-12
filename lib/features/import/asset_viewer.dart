import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

import 'package:work_photos/core/utils/duration_format.dart';
import 'package:work_photos/features/import/asset_info_sheet.dart';
import 'package:work_photos/widgets/thumbnail.dart';

/// 全屏查看导入相册中的单张 / 多张照片（[AlbumBrowser] 网格点击触发）。
///
/// 以 [PageView] 横向浏览 [assets]（默认停在当前点击的张数 [initialIndex]），
/// 支持双指缩放（[InteractiveViewer]）。缩略图复用 [Thumbnail]，size 取较大值以贴近原图清晰度。
Future<void> showAssetViewer(
  BuildContext context,
  List<pm.AssetEntity> assets,
  int initialIndex,
) {
  if (assets.isEmpty) return Future.value();
  return showDialog<void>(
    context: context,
    builder: (ctx) =>
        _AssetViewerPage(assets: assets, initialIndex: initialIndex),
  );
}

class _AssetViewerPage extends StatefulWidget {
  final List<pm.AssetEntity> assets;
  final int initialIndex;

  const _AssetViewerPage({
    required this.assets,
    required this.initialIndex,
  });

  @override
  State<_AssetViewerPage> createState() => _AssetViewerPageState();
}

class _AssetViewerPageState extends State<_AssetViewerPage> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.assets.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text('${_index + 1} / ${widget.assets.length}'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '详细信息',
            onPressed: () =>
                showAssetInfoSheet(context, widget.assets[_index]),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
        ),
        body: PageView.builder(
          controller: _pageController,
          itemCount: widget.assets.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) {
            final pm.AssetEntity asset = widget.assets[i];
            final bool isVideo = asset.type == pm.AssetType.video;
            final String? dur = isVideo ? formatDuration(asset.videoDuration) : null;
            return InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Thumbnail(entity: asset, size: 2000),
                    // 视频预览：中央播放三角 + 底部时长（导入前预览不支持
                    // 内嵌播放，避免引入重依赖；时长与类型标识足够判断）。
                    if (isVideo)
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow,
                            size: 36, color: Colors.white),
                      ),
                    if (isVideo && dur != null)
                      Positioned(
                        bottom: 24,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('视频 · $dur',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12)),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
