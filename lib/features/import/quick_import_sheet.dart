import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

import 'package:work_photos/core/utils/duration_format.dart';
import 'package:work_photos/features/import/import_controller.dart';
import 'package:work_photos/providers/photo_provider.dart';
import 'package:work_photos/widgets/thumbnail.dart';

/// 弹出「快速导入」底部弹窗（相机拍摄完成后识别到的新增媒体）。
///
/// [assets] 为按时间戳筛选出的本次新增项（1 张或多张）；
/// [albumLabel] 为写入来源相册名（用于 ImportItem 记录，可空）。
///
/// 返回成功导入的条数；用户点「取消」/关闭则返回 null。
Future<int?> showQuickImportSheet(
  BuildContext context, {
  required List<pm.AssetEntity> assets,
  required String? albumLabel,
}) {
  return showModalBottomSheet<int>(
    context: context,
    // 挂在根 Navigator 上：
    // 1) 返回键：返回拦截（BackButtonListener）只对根 Navigator 上的可 pop 路由让路，
    //    弹层挂根 Navi 才能在「多选态按返回」时先关弹层、而不是清空多选；
    // 2) 视觉：分支 Navigator 上弹层盖不住底部 NavigationBar，根 Navi 才能盖满整屏。
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (BuildContext ctx) =>
        _QuickImportSheet(assets: assets, albumLabel: albumLabel),
  );
}

class _QuickImportSheet extends ConsumerStatefulWidget {
  final List<pm.AssetEntity> assets;
  final String? albumLabel;

  const _QuickImportSheet({required this.assets, required this.albumLabel});

  @override
  ConsumerState<_QuickImportSheet> createState() => _QuickImportSheetState();
}

class _QuickImportSheetState extends ConsumerState<_QuickImportSheet> {
  /// 导入进行中守卫：防止连点重复写入。
  bool _busy = false;

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// 拍摄时间文本（YYYY-MM-DD HH:mm）。
  static String _dateText(DateTime dt) =>
      '${dt.year}-${_two(dt.month)}-${_two(dt.day)} '
      '${_two(dt.hour)}:${_two(dt.minute)}';

  /// 复用既有导入链路：转成引用式 ImportItem 后批量写入（不复制字节）。
  Future<void> _confirmImport() async {
    if (_busy || widget.assets.isEmpty) return;
    setState(() => _busy = true);
    final ImportController controller =
        ImportController(ref.read(photoRepositoryProvider));
    final int n = await controller.importAssets(
      widget.assets,
      album: widget.albumLabel,
    );
    if (!mounted) return;
    // 关闭并回传导入条数，由调用方展示结果提示。
    Navigator.of(context).pop(n);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int count = widget.assets.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('快速导入（本次新增 $count 项）',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '相机已把照片写入相册，以下为本次识别到的新增媒体。'
              '确认将以"引用"方式导入（仅记录引用，不复制文件）。',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 12),
            // 上限高度 + shrinkWrap：少量新增时贴合内容，多量时可滚动，避免溢出。
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: count,
                  separatorBuilder: (BuildContext _, int __) =>
                      const Divider(height: 1),
                  itemBuilder: (BuildContext ctx, int i) {
                    final pm.AssetEntity a = widget.assets[i];
                    final bool isVideo = a.type == pm.AssetType.video;
                    final String? dur =
                        isVideo ? formatDuration(a.videoDuration) : null;
                    final String title = a.title ?? (isVideo ? '视频' : '照片');
                    final String subtitle = dur != null
                        ? '${_dateText(a.createDateTime)} · 视频 $dur'
                        : _dateText(a.createDateTime);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: Stack(
                            fit: StackFit.expand,
                            children: <Widget>[
                              Thumbnail(entity: a, size: 56),
                              // 视频叠加播放三角，区分图文类型。
                              if (isVideo)
                                const Center(
                                  child: Icon(Icons.play_arrow,
                                      color: Colors.white, size: 24),
                                ),
                            ],
                          ),
                        ),
                      ),
                      title: Text(title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(subtitle, maxLines: 1),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_busy ? '导入中…' : '导入'),
                    onPressed: _busy ? null : _confirmImport,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
