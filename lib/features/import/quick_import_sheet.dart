import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

import 'package:work_photos/core/utils/duration_format.dart';
import 'package:work_photos/data/models/category.dart';
import 'package:work_photos/features/classify/category_sort.dart';
import 'package:work_photos/features/import/import_controller.dart';
import 'package:work_photos/providers/category_provider.dart';
import 'package:work_photos/providers/photo_provider.dart';
import 'package:work_photos/widgets/thumbnail.dart';

/// 弹出「快速导入」底部弹窗（相机拍摄完成后识别到的新增媒体）。
///
/// [assets] 为首批新增项（1 张或多张）；
/// [albumLabel] 为写入来源相册名（用于 ImportItem 记录，可空）；
/// [onCaptureMore] 为「继续拍摄」回调：返回一批新的新增项（连拍），返回
/// null / 空表示取消或未识别到。为 null 时不显示「继续拍摄」按钮。
///
/// 返回成功导入的条数；用户点「取消」/关闭则返回 null。
Future<int?> showQuickImportSheet(
  BuildContext context, {
  required List<pm.AssetEntity> assets,
  required String? albumLabel,
  Future<List<pm.AssetEntity>?> Function()? onCaptureMore,
}) {
  return showModalBottomSheet<int>(
    context: context,
    // 挂在根 Navigator 上：
    // 1) 返回键：返回拦截（BackButtonListener）只对根 Navigator 上的可 pop 路由让路，
    //    弹层挂根 Navi 才能在「多选态按返回」时先关弹层、而不是清空多选；
    // 2) 视觉：分支 Navigator 上弹层盖不住底部 NavigationBar，根 Navi 才能盖满整屏。
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (BuildContext ctx) => _QuickImportSheet(
      assets: assets,
      albumLabel: albumLabel,
      onCaptureMore: onCaptureMore,
    ),
  );
}

class _QuickImportSheet extends ConsumerStatefulWidget {
  final List<pm.AssetEntity> assets;
  final String? albumLabel;
  final Future<List<pm.AssetEntity>?> Function()? onCaptureMore;

  const _QuickImportSheet({
    required this.assets,
    required this.albumLabel,
    this.onCaptureMore,
  });

  @override
  ConsumerState<_QuickImportSheet> createState() => _QuickImportSheetState();
}

class _QuickImportSheetState extends ConsumerState<_QuickImportSheet> {
  /// 待导入资产（可变：支持「继续拍摄」连拍追加）。initState 从 widget.assets 拷一份。
  late List<pm.AssetEntity> _assets;

  /// 已选分类 id（勾子时级联加入祖先）。可为空：不选就只导入、不分配分类。
  final Set<int> _selectedCategoryIds = <int>{};

  /// 导入进行中。
  bool _importing = false;

  /// 连拍（继续拍摄 → 识别中）进行中。
  bool _capturingMore = false;

  /// 任一操作进行中：用于禁用按钮 + 挡返回键。
  bool get _busy => _importing || _capturingMore;

  @override
  void initState() {
    super.initState();
    _assets = List<pm.AssetEntity>.of(widget.assets);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// 拍摄时间文本（YYYY-MM-DD HH:mm）。
  static String _dateText(DateTime dt) =>
      '${dt.year}-${_two(dt.month)}-${_two(dt.day)} '
      '${_two(dt.hour)}:${_two(dt.minute)}';

  /// 继续拍摄：拉起相机再拍一批，去重后追加到待导入列表。
  ///
  /// 连拍为什么按 id 去重：每次拍摄都以「当前时间 - 2s」为基线做时间戳筛选，
  /// 两次拍摄间隔可能小于 2s（或上一张的 createDateTime 落在本批基线之后），
  /// 导致同一条 asset 在前后两批的新增扫描里都命中。直接拼接会重复展示、
  /// 进而重复入库。按 asset.id 过滤掉已在列表中的项即可。
  Future<void> _continueCapture() async {
    final Future<List<pm.AssetEntity>?> Function()? cb = widget.onCaptureMore;
    if (_busy || cb == null) return;
    setState(() => _capturingMore = true);
    try {
      final List<pm.AssetEntity>? more = await cb();
      if (!mounted) return;
      if (more == null || more.isEmpty) return;
      final Set<String> known = _assets.map((a) => a.id).toSet();
      final List<pm.AssetEntity> fresh = more
          .where((pm.AssetEntity a) => !known.contains(a.id))
          .toList();
      if (fresh.isNotEmpty) {
        setState(() => _assets = <pm.AssetEntity>[..._assets, ...fresh]);
      }
    } finally {
      if (mounted) setState(() => _capturingMore = false);
    }
  }

  /// 切换分类勾选：勾选级联全部祖先；取消只撤自身。
  void _toggleCategory(int cid) {
    final List<Category> flat =
        ref.read(categoryListProvider).valueOrNull ?? const <Category>[];
    setState(() {
      if (_selectedCategoryIds.contains(cid)) {
        // 取消：只撤自身，不向下级联（与「归入分类」面板一致，行为可预期）。
        _selectedCategoryIds.remove(cid);
      } else {
        // 勾子级联父：分类是树形归属，子隐含属于父；只记子会让「按父分类
        // 筛选」漏掉这些照片。故勾选时把自身及所有祖先一起加入选择集。
        _selectedCategoryIds.add(cid);
        _selectedCategoryIds.addAll(categoryAncestorIds(flat, cid));
      }
    });
  }

  /// 复用既有导入链路：转成引用式 ImportItem 后批量写入（不复制字节），
  /// 导入成功后拿回 photo id，按选中分类逐个分配，再关闭回传导入条数。
  Future<void> _confirmImport() async {
    if (_busy || _assets.isEmpty) return;
    setState(() => _importing = true);
    final repo = ref.read(photoRepositoryProvider);
    final ImportController controller = ImportController(repo);
    // 先导入并拿回新插入的 photo id（为分类分配所需，见 importFromAlbumIds）。
    final List<int> ids = await controller.importAssetsReturningIds(
      _assets,
      album: widget.albumLabel,
    );
    if (ids.isNotEmpty && _selectedCategoryIds.isNotEmpty) {
      // 直接按 UI 勾选集分配：勾子时已级联加入祖先，正常流程含父；
      // 用户若显式取消某父，则只撤该父（与「归入分类」取消语义一致）。
      final Set<int> targets = Set<int>.of(_selectedCategoryIds);
      for (final int pid in ids) {
        for (final int cid in targets) {
          await repo.assignCategory(pid, cid);
        }
      }
    }
    if (!mounted) return;
    // 关闭并回传导入条数，由调用方展示结果提示。
    Navigator.of(context).pop(ids.length);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int count = _assets.length;

    // 分类数据：树序 + 缩进（用 treeOrdered 而非 sortedCategoryListProvider，
    // 后者扁平按名排序、无父子层级）。子分类在 chip 上显示成「父 / 子」，
    // 避免用缩进在横向 chip 里不好看的问题。
    final AsyncValue<List<Category>> catsAsync =
        ref.watch(categoryListProvider);
    final String sortMode = ref.watch(categorySortModeProvider);
    final List<Category> flat = catsAsync.valueOrNull ?? const <Category>[];
    final List<Category> display = treeOrdered(flat, sortMode: sortMode);
    final Map<int, Category> byId = <int, Category>{
      for (final Category c in flat)
        if (c.id != null) c.id!: c,
    };
    String chipLabel(Category c) {
      final Category? parent = c.parentId == null ? null : byId[c.parentId];
      return parent == null ? c.name : '${parent.name} / ${c.name}';
    }

    final Widget body = SafeArea(
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
            // 工具栏：继续拍摄（连拍）。仅当提供了回调时显示。
            if (widget.onCaptureMore != null) ...<Widget>[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: _capturingMore
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_camera_outlined),
                  label: Text(_capturingMore ? '识别中…' : '继续拍摄'),
                  onPressed: _busy ? null : _continueCapture,
                ),
              ),
            ],
            // 分类选择（可选）：树序、横向滚动的 FilterChip。
            if (display.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text('分类（可选，勾选子类会一并选中其父类）',
                  style:
                      TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              const SizedBox(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    for (final Category c in display)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(chipLabel(c)),
                          selected: _selectedCategoryIds.contains(c.id),
                          onSelected: (_busy || c.id == null)
                              ? null
                              : (_) => _toggleCategory(c.id!),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            // 上限高度 + shrinkWrap：少量新增时贴合内容，多量时可滚动，避免溢出。
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: count,
                  separatorBuilder: (BuildContext _, int __) =>
                      const Divider(height: 1),
                  itemBuilder: (BuildContext ctx, int i) {
                    final pm.AssetEntity a = _assets[i];
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
                    icon: _importing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_importing ? '导入中…' : '导入'),
                    onPressed: _busy ? null : _confirmImport,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    // _busy（导入 / 继续拍摄期间）禁止系统返回键关闭弹层：此时导入其实已在
    // 写库，若弹层被关掉，调用方会当成用户取消（拿到 null）。弹层路由可被根
    // Navigator.maybePop() 触达，故 PopScope 在这一层有效——与 Shell 页
    // PopScope 失效（popRoute 直接 return false、从不进 maybePop）不是一回事。
    // 已知边界：只挡【系统返回键】；点外部(barrier)/下拉(drag) 走
    // Navigator.pop()，不经 popDisposition，PopScope 拦不住（本次不做）。
    return PopScope(
      canPop: !_busy,
      child: body,
    );
  }
}
