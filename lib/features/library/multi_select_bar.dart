import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:work_photos/data/models/photo.dart';
import 'package:work_photos/features/classify/assign_category_sheet.dart';
import 'package:work_photos/features/share/share_panel.dart';
import 'package:work_photos/providers/photo_provider.dart';
import 'package:work_photos/providers/selection_provider.dart';

/// 多选操作栏（照片网格底部，B4）。
///
/// 支持：标记已用 / 未用、归入分类；预留"分享"按钮（B5 接入）。
class MultiSelectBar extends ConsumerWidget {
  const MultiSelectBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Set<int> selected = ref.watch(selectionProvider);
    if (selected.isEmpty) return const SizedBox.shrink();

    return BottomAppBar(
      child: Row(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('已选 ${selected.length}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Spacer(),
          IconButton(
            tooltip: '标记为已用',
            icon: const Icon(Icons.check_circle),
            onPressed: () => _mark(ref, true),
          ),
          IconButton(
            tooltip: '标记为未用',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => _mark(ref, false),
          ),
          IconButton(
            tooltip: '归入分类',
            icon: const Icon(Icons.label),
            onPressed: () {
              AssignCategorySheet.show(context, selected.toList());
            },
          ),
          IconButton(
            tooltip: '分享',
            icon: const Icon(Icons.share),
            onPressed: () {
              // B5：把当前选中的 Photos 传入分享面板。
              final AsyncValue<List<Photo>> allAsync =
                  ref.read(photoListProvider(const PhotoFilter()));
              final List<Photo> chosen = allAsync.valueOrNull
                      ?.where((Photo p) =>
                          p.id != null && selected.contains(p.id))
                      .toList() ??
                  <Photo>[];
              if (chosen.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('没有可分享的照片')),
                );
                return;
              }
              SharePanel.show(context, chosen);
            },
          ),
          IconButton(
            tooltip: '删除',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  /// 删除前二次确认：区分「删除文件」与「仅删除导入数据」两种模式。
  ///
  /// - 删除文件：从设备相册永久删除原图 + 移除本软件引用记录；
  /// - 仅删除导入数据：保留设备原图，只移除本软件引用记录。
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final Set<int> selected = ref.read(selectionProvider);
    if (selected.isEmpty) return;

    final bool? deleteFile = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除选中的 ${selected.length} 张照片'),
        content: const Text(
          '请选择删除方式：\n\n'
          '• 删除文件：从设备相册中永久删除原图，并移除本软件的引用记录。\n'
          '• 仅删除导入数据：保留设备上的原图，只移除本软件的引用记录。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('仅删除数据'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('删除文件'),
          ),
        ],
      ),
    );
    if (deleteFile == null) return; // 取消

    // 取出选中的完整 Photo 对象（携带 mediaRef，供删除设备文件使用）。
    final AsyncValue<List<Photo>> allAsync =
        ref.read(photoListProvider(const PhotoFilter()));
    final List<Photo> chosen = allAsync.valueOrNull
            ?.where((Photo p) => p.id != null && selected.contains(p.id))
            .toList() ??
        <Photo>[];
    if (chosen.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可删除的照片')),
      );
      return;
    }

    final res = await ref
        .read(photoRepositoryProvider)
        .deletePhotos(chosen, deleteFiles: deleteFile);
    ref.read(selectionProvider.notifier).state = <int>{};
    if (!context.mounted) return;

    final String msg = deleteFile
        ? (res.deviceFailed == 0
            ? '已删除 ${res.dbDeleted} 张照片（设备原图与引用数据均删除）'
            : '已移除 ${res.dbDeleted} 条引用数据；其中 ${res.deviceFailed} 张设备原图删除失败（可能权限不足）')
        : '已移除 ${res.dbDeleted} 条引用数据（设备原图保留）';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _mark(WidgetRef ref, bool used) async {
    final repo = ref.read(photoRepositoryProvider);
    final Set<int> selected = ref.read(selectionProvider);
    for (final int id in selected) {
      await repo.markUsed(id, used);
    }
  }
}
