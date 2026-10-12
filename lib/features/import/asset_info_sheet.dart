import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

import 'package:work_photos/core/utils/duration_format.dart';

/// 导入页：选中某张照片/视频后，以底部弹层展示其详细元数据。
///
/// 数据来自 [pm.AssetEntity]（标题 / 拍摄时间 / 尺寸 / 类型 / 相对路径），
/// 文件大小需解析原文件后读取（失败则降级不显示）。
Future<void> showAssetInfoSheet(
  BuildContext context,
  pm.AssetEntity entity,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _AssetInfoSheet(entity: entity),
  );
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final double kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final double mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  return '${(mb / 1024).toStringAsFixed(2)} GB';
}

class _AssetInfoSheet extends StatelessWidget {
  final pm.AssetEntity entity;

  const _AssetInfoSheet({required this.entity});

  Future<_InfoData> _load() async {
    String? size;
    try {
      final File? file = await entity.file;
      if (file != null) size = _formatBytes(await file.length());
    } catch (_) {
      size = null;
    }
    final DateTime dt = entity.createDateTime;
    String p2(int n) => n.toString().padLeft(2, '0');
    final String date =
        '${dt.year}-${p2(dt.month)}-${p2(dt.day)} ${p2(dt.hour)}:${p2(dt.minute)}';
    final bool isVideo = entity.type == pm.AssetType.video;
    return _InfoData(
      title: entity.title,
      date: date,
      dimension: '${entity.width} × ${entity.height}',
      mime: entity.mimeType,
      path: entity.relativePath,
      size: size,
      duration: isVideo ? formatDuration(entity.videoDuration) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(widget.entity.type == pm.AssetType.video ? '视频信息' : '照片信息',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            FutureBuilder<_InfoData>(
              future: _load(),
              builder: (ctx, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final _InfoData d = snap.data!;
                final List<List<String>> rows = <List<String>>[
                  <String>['标题', d.title ?? '—'],
                  <String>['拍摄时间', d.date],
                  if (d.duration != null) <String>['时长', d.duration!],
                  <String>['尺寸', d.dimension],
                  <String>['文件大小', d.size ?? '—'],
                  <String>['类型', d.mime ?? '—'],
                  <String>['相对路径', d.path ?? '—'],
                ];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final List<String> r in rows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            SizedBox(
                              width: 72,
                              child: Text(r[0],
                                  style: TextStyle(color: scheme.onSurfaceVariant)),
                            ),
                            Expanded(
                              child: Text(r[1]),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoData {
  final String? title;
  final String date;
  final String dimension;
  final String? mime;
  final String? path;
  final String? size;
  final String? duration;

  const _InfoData({
    this.title,
    required this.date,
    required this.dimension,
    this.mime,
    this.path,
    this.size,
    this.duration,
  });
}
