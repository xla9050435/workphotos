import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:work_photos/data/models/photo.dart';
import 'package:work_photos/features/classify/category_style.dart';
import 'package:work_photos/features/me/settings_provider.dart';
import 'package:work_photos/providers/selection_provider.dart';
import 'package:work_photos/widgets/thumbnail.dart';

/// 照片网格单元（B4）。
///
/// 视觉区分：
/// - 未用：原色缩略图，无边框；
/// - 已用：原色缩略图 + 彩色薄边框（颜色可在「我的 → 设置」中从 Google
///   推荐色板选择，明显但不遮挡画面）；
/// - 多选选中：主题色 3px 边框 + 左上角勾选标记。
/// 点击进入详情页（或多选态下切换选中）；长按进入多选。
/// 已用状态切换统一在详情页操作。
class PhotoGridItem extends ConsumerWidget {
  final Photo photo;
  /// 当前筛选上下文下的全部照片 id（用于详情页左右滑动切换）。
  final List<int> photoIds;
  /// 本照片在 [photoIds] 中的下标。
  final int index;

  const PhotoGridItem({
    super.key,
    required this.photo,
    required this.photoIds,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Set<int> selectedIds = ref.watch(selectionProvider);
    final bool isSelected =
        photo.id != null && selectedIds.contains(photo.id);
    final bool isUsed = photo.isUsed;
    // 已用照片边框颜色：用户可在「我的 → 设置」中从 Google 推荐色板选择。
    final Color usedBorder =
        parseColorHex(ref.watch(settingsProvider).usedBorderHex);

    return GestureDetector(
      onLongPress: () => _toggleSelection(ref),
      onTap: () {
        if (selectedIds.isNotEmpty) {
          _toggleSelection(ref);
        } else if (photo.id != null) {
          // B6：非多选态点击进入详情页（位于 Shell 之外的 /photo/:id 路由），
          // 通过 extra 传递同上下文照片 id 列表与下标，支持左右滑动切换。
          context.push(
            '/photo/${photo.id}',
            extra: <String, dynamic>{
              'ids': photoIds,
              'index': index,
            },
          );
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // 缩略图：一律显示原始彩色（已移除原灰度处理）。
          PhotoThumbnail(photo: photo, size: 200),
          // 已用态：彩色薄边框（颜色在设置中选择）；未用态无边框。
          // 原「已用/未用」右上角角标已移除（遮挡视野），已用状态切换
          // 统一走详情页的「标为已用/未用」按钮。
          // 多选选中态：主题色边框 + scrim 遮罩 + 左上角勾选标记。
          // M3 Selection 指南：选中项用「勾选标记 + scrim 遮罩」表达，
          // 半透明遮罩（primary 12%，≈ press state layer）保证与未选项
          // 有明显区分而不遮挡内容。
          if (isSelected)
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                ),
              ),
            )
          else if (isUsed)
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: usedBorder, width: 3),
              ),
            ),
          // 多选勾选标记。
          if (isSelected)
            Positioned(
              top: 4,
              left: 4,
              child: Icon(Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary, size: 20),
            ),
          // 备注指示：有备注时在左下角显示一个浅色小图标。
          if (photo.note != null && photo.note!.isNotEmpty)
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.note,
                  size: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),
            ),
          // 视频角标：右下角播放图标 + 时长（与左下角备注图标错开）。
          if (photo.isVideo)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.play_arrow, size: 12, color: Colors.white),
                    if (photo.durationLabel != null) ...<Widget>[
                      const SizedBox(width: 2),
                      Text(
                        photo.durationLabel!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _toggleSelection(WidgetRef ref) {
    if (photo.id == null) return;
    final Set<int> current = Set<int>.from(ref.read(selectionProvider));
    if (current.contains(photo.id)) {
      current.remove(photo.id);
    } else {
      current.add(photo.id!);
    }
    ref.read(selectionProvider.notifier).state = current;
  }
}
