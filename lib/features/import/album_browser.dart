import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

import 'package:work_photos/core/utils/duration_format.dart';
import 'package:work_photos/core/utils/media_count_label.dart';
import 'package:work_photos/features/me/settings_provider.dart';
import 'package:work_photos/widgets/continuous_grid_delegate.dart';
import 'package:work_photos/widgets/grid_drag_select_controller.dart';
import 'package:work_photos/widgets/pinch_column_tracker.dart';
import 'package:work_photos/widgets/thumbnail.dart';

/// 相册显示名：系统「全部照片」相册在 Android 上固定叫 "Recent"，
/// 统一显示为中文「最近」，避免界面出现英文。
String albumDisplayName(pm.AssetPathEntity album) =>
    album.isAll ? '最近' : album.name;

/// 分组计数文案：统计图片 / 视频构成后交给 [mediaCountLabel]（与相册页同口径）。
String _assetGroupCountLabel(List<pm.AssetEntity> assets) {
  final int videos =
      assets.where((pm.AssetEntity a) => a.type == pm.AssetType.video).length;
  return mediaCountLabel(
    imageCount: assets.length - videos,
    videoCount: videos,
  );
}

/// 视频时长角标：半透明深色底 + 播放三角 + 「m:ss」。
///
/// 深色底与浅色图标不随主题切换（媒体信息浮层的通用惯例，
/// 保证任意缩略图上的可读性）。
class _VideoDurationBadge extends StatelessWidget {
  final Duration duration;

  const _VideoDurationBadge({required this.duration});

  @override
  Widget build(BuildContext context) {
    final String? label = formatDuration(duration);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.play_arrow, size: 12, color: Colors.white),
          if (label != null) ...<Widget>[
            const SizedBox(width: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 相册 / 资产浏览 UI（只读枚举，不拷贝）。
///
/// 纯展示组件：接收相册列表、按天分组后的资产、选中态等，并通过回调上报交互。
/// 状态（相册加载、选中、分页、排序）由父级 [ImportPage] 持有。
///
/// 布局：
/// - 顶部选择栏：相册下拉 + 排序下拉（白色背景，下方细分割线）；
/// - 主体：按天分组的 [CustomScrollView]（日期头 + 3 列网格）；滚动接近底部
///   时经 [onLoadMore] 触发分页加载更多。
class AlbumBrowser extends ConsumerStatefulWidget {
  final List<pm.AssetPathEntity> albums;
  final Map<String, int> albumCounts;
  final pm.AssetPathEntity? currentAlbum;
  final LinkedHashMap<String, List<pm.AssetEntity>> grouped;
  final bool sortNewToOld;
  final Set<pm.AssetEntity> selected;
  final bool loadingMore;
  final ValueChanged<pm.AssetPathEntity> onSelectAlbum;
  final ValueChanged<bool> onSelectSort;
  final ValueChanged<pm.AssetEntity> onToggleAsset;
  /// 滑动连选「加模式」命中时调用：仅添加选中，由父级 [ImportPage] 实现。
  final ValueChanged<pm.AssetEntity> onSelectAsset;
  /// 滑动连选「减模式」命中时调用：仅移除选中，由父级 [ImportPage] 实现。
  final ValueChanged<pm.AssetEntity> onRemoveAsset;
  /// 日期头「全选」：把该组全部资产加入选择集。
  final ValueChanged<List<pm.AssetEntity>> onSelectGroup;
  final void Function(List<pm.AssetEntity> assets, int index) onViewAsset;
  final VoidCallback onLoadMore;

  const AlbumBrowser({
    super.key,
    required this.albums,
    required this.albumCounts,
    required this.currentAlbum,
    required this.grouped,
    required this.sortNewToOld,
    required this.selected,
    required this.loadingMore,
    required this.onSelectAlbum,
    required this.onSelectSort,
    required this.onToggleAsset,
    required this.onSelectAsset,
    required this.onRemoveAsset,
    required this.onSelectGroup,
    required this.onViewAsset,
    required this.onLoadMore,
  });

  @override
  ConsumerState<AlbumBrowser> createState() => _AlbumBrowserState();
}

class _AlbumBrowserState extends ConsumerState<AlbumBrowser>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  /// 每个资产格的 GlobalKey（按 AssetEntity.id），供滑动连选命中测试。
  final Map<String, GlobalKey> _itemKeys = <String, GlobalKey>{};

  /// id -> 资产对象，连选命中后经回调上报。
  final Map<String, pm.AssetEntity> _assetById = <String, pm.AssetEntity>{};

  // —— 网格滚动视口的 key：自动滚动时用它取视口在屏幕上的矩形，
  // 以判定指针是否进入上/下边缘触发区。
  final GlobalKey _scrollViewKey = GlobalKey();

  // —— 拖动连选共享状态机（T2.2，R4 纵列连选）——
  // 与相册页 photo_grid_page 共用同一套语义（GridDragSelectController）。
  late final GridDragSelectController<pm.AssetEntity> _dragSelect =
      GridDragSelectController<pm.AssetEntity>(
    hasSelection: () => widget.selected.isNotEmpty,
    hitTest: _hitAsset,
    rowMembersOf: _rowMembersOf,
    isSelected: (pm.AssetEntity asset) => widget.selected.contains(asset),
    onAdd: widget.onSelectAsset,
    onRemove: widget.onRemoveAsset,
    scrollController: _scrollController,
    viewportKey: _scrollViewKey,
    onStateChanged: () {
      if (mounted) setState(() {}); // physics 随连选状态刷新
    },
  );

  // —— 双指捏合调节列数 ——（学系统相册：捏合图片变小排版变密）
  /// 单指时透明，不影响连选/滚动；第二指按下即进入捏合并终止连选。
  /// 布局由连续列数值 [_displayColumnsF] 逐帧驱动（R10）；
  /// 列数跨会话持久化（R3）：初始取自设置，捏合收敛后写回。
  late final PinchColumnTracker _pinchTracker = PinchColumnTracker(
    initialColumns: ref.read(settingsProvider).gridColumns,
    onColumnsChanged: (_) {},
    onColumnsContinuous: _onPinchColumns,
    onPinchStateChanged: _onPinchStateChanged,
  );

  /// 当前布局使用的连续列数值（捏合中随手指连续变化，松手后收敛到整数）。
  double _displayColumnsF = 3;
  /// 捏合结束后的收敛动画（连续值 → 最近整数）：整会话复用单个控制器。
  late final AnimationController _settleAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  /// 收敛起止值（动画监听器读取；forward 前写入）。
  double _settleFrom = 3;
  int _settleTarget = 3;
  /// 距底部小于该阈值（px）即触发分页加载更多。
  static const double _loadMoreThreshold = 600;

  /// 捏合过程中每帧上报的连续列数：直接驱动布局（列宽随手指连续过渡）。
  void _onPinchColumns(double columnsF) {
    _settleAnim.stop();
    if (!mounted) return;
    setState(() => _displayColumnsF = columnsF);
  }

  /// 捏合进入/结束：结束时把连续列数平滑收敛到最近整数
  /// （系统开启「减少动态效果」时瞬时收敛，R7 reduce-motion），
  /// 并把最终整数列数持久化（R3：跨会话保留）。
  void _onPinchStateChanged(bool pinching) {
    if (!mounted) return;
    if (pinching) {
      _settleAnim.stop();
      setState(() {});
      return;
    }
    final int target = _pinchTracker.columns;
    final double from = _displayColumnsF;
    final bool reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion || (from - target).abs() < 0.01) {
      _displayColumnsF = target.toDouble();
      setState(() {});
      _persistColumns();
      return;
    }
    _settleFrom = from;
    _settleTarget = target;
    _settleAnim.forward(from: 0);
  }

  /// 收敛动画逐帧回调：连续值沿 easeOutCubic 逼近目标整数。
  void _onSettleTick() {
    if (!mounted) return;
    const Curve curve = Curves.easeOutCubic;
    setState(() {
      _displayColumnsF = _settleFrom +
          (_settleTarget - _settleFrom) * curve.transform(_settleAnim.value);
    });
  }

  /// 收敛动画完成：锁定整数列数并持久化。
  void _onSettleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    _displayColumnsF = _settleTarget.toDouble();
    _persistColumns();
    setState(() {});
  }

  /// 把捏合得到的最终列数写入持久化设置（R3：跨会话保留）。
  void _persistColumns() {
    ref.read(settingsProvider.notifier).setGridColumns(_pinchTracker.columns);
  }

  /// 命中测试：返回指针下的资产（含其屏幕矩形，供纵列连选通道判定）。
  GridHit<pm.AssetEntity>? _hitAsset(Offset global) {
    for (final MapEntry<String, GlobalKey> entry in _itemKeys.entries) {
      final RenderBox? box =
          entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final Rect rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(global)) {
        final pm.AssetEntity? asset = _assetById[entry.key];
        if (asset == null) continue;
        return GridHit<pm.AssetEntity>(item: asset, rect: rect);
      }
    }
    return null;
  }

  /// 返回与 [asset] 同一行的全部资产（含自身），用于纵向整行连选。
  ///
  /// 为什么按 rect.top 判同行：网格列数可变（捏合缩放走连续列数 R10），按
  /// index 换算「整行」在非整数列数、或存在分组头部时会算错；直接用每个格子
  /// 渲染后的屏幕矩形 top 判定同行，与具体布局解耦、更稳。
  ///
  /// 只统计当前已布局（能取到 RenderBox）的格子：滚出屏幕的取不到 rect，跳过
  /// 即可、不抛异常；若自身格子都取不到（异常态），返回自身单元素，退回单格。
  List<pm.AssetEntity> _rowMembersOf(pm.AssetEntity asset) {
    final RenderBox? selfBox =
        _itemKeys[asset.id]?.currentContext?.findRenderObject() as RenderBox?;
    if (selfBox == null) return <pm.AssetEntity>[asset];
    final double top = selfBox.localToGlobal(Offset.zero).dy;
    final List<(double, pm.AssetEntity)> row = <(double, pm.AssetEntity)>[];
    for (final MapEntry<String, GlobalKey> e in _itemKeys.entries) {
      final RenderBox? box =
          e.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final Offset off = box.localToGlobal(Offset.zero);
      if ((off.dy - top).abs() < 1.0) {
        final pm.AssetEntity? a = _assetById[e.key];
        if (a != null) row.add((off.dx, a));
      }
    }
    if (row.isEmpty) return <pm.AssetEntity>[asset];
    row.sort((a, b) => a.$1.compareTo(b.$1));
    return row.map((e) => e.$2).toList();
  }

  @override
  void initState() {
    super.initState();
    _displayColumnsF = ref.read(settingsProvider).gridColumns.toDouble();
    _settleAnim.addListener(_onSettleTick);
    _settleAnim.addStatusListener(_onSettleStatus);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final double max = _scrollController.position.maxScrollExtent;
    final double px = _scrollController.position.pixels;
    if (max - px <= _loadMoreThreshold) {
      widget.onLoadMore();
    }
  }

  @override
  void dispose() {
    _settleAnim.dispose();
    _dragSelect.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = ref.watch(settingsProvider);
    // 设置异步加载完成 / 设置页重置后回读列数：
    // 仅在静止（非捏合、非收敛动画中）时覆盖，避免与手势/动画互抢（R3）。
    if (!_pinchTracker.pinching &&
        !_settleAnim.isAnimating &&
        _pinchTracker.columns != settings.gridColumns) {
      _pinchTracker.applyColumns(settings.gridColumns);
      _displayColumnsF = settings.gridColumns.toDouble();
    }
    return Column(
      children: <Widget>[
        // 相册 / 排序选择栏（surface 底，下方 outlineVariant 细分割线，
        // 与页面底形成层次 —— M3 语义色角色）。
        Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: DropdownButton<pm.AssetPathEntity>(
                  isExpanded: true,
                  value: widget.currentAlbum,
                  hint: const Text('选择相册'),
                  underline: const SizedBox.shrink(),
                  items: widget.albums.map((pm.AssetPathEntity album) {
                    final int? count = widget.albumCounts[album.id];
                    return DropdownMenuItem<pm.AssetPathEntity>(
                      value: album,
                      child: Text(
                        count == null
                            ? albumDisplayName(album)
                            : '${albumDisplayName(album)} ($count)',
                      ),
                    );
                  }).toList(),
                  onChanged: (pm.AssetPathEntity? album) {
                    if (album != null) widget.onSelectAlbum(album);
                  },
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<bool>(
                value: widget.sortNewToOld,
                underline: const SizedBox.shrink(),
                items: const <DropdownMenuItem<bool>>[
                  DropdownMenuItem<bool>(
                    value: true,
                    child: Text('时间 新→旧'),
                  ),
                  DropdownMenuItem<bool>(
                    value: false,
                    child: Text('时间 旧→新'),
                  ),
                ],
                onChanged: (bool? v) {
                  if (v != null) widget.onSelectSort(v);
                },
              ),
            ],
          ),
        ),
        // M3：分割线用 outlineVariant（微妙的边框/分隔角色）。
        Divider(
          height: 1,
          thickness: 1,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        // 按天分组的资产滚动视图（外包 Listener：选择态按住拖动即连选，
        // 期间禁用滚动避免手势竞争；非选择态不干预，滚动/触底加载照常）。
        Expanded(
          child: Listener(
            // 连选 + 捏合手势层（与相册页同一套语义）：单指拖动 → 连选；
            // 双指 → 捏合调节列数（终止连选、禁滚）。
            behavior: HitTestBehavior.translucent,
            onPointerDown: (PointerDownEvent e) {
              _pinchTracker.handleDown(e.pointer, e.position);
              if (_pinchTracker.pinching) {
                _dragSelect.end(); // 进入捏合：终止连选
                return;
              }
              _dragSelect.onPointerDown(e.position);
            },
            onPointerMove: (PointerMoveEvent e) {
              _pinchTracker.handleMove(e.pointer, e.position);
              if (_pinchTracker.pinching) return;
              _dragSelect.onPointerMove(e.position);
            },
            onPointerUp: (PointerUpEvent e) {
              _pinchTracker.handleUp(e.pointer);
              _dragSelect.end();
            },
            onPointerCancel: (PointerCancelEvent e) {
              _pinchTracker.handleUp(e.pointer);
              _dragSelect.end();
            },
            child: widget.grouped.isEmpty
                ? const Center(
                    child: Text('该相册暂无媒体，或尚未授权。'))
                : CustomScrollView(
                    key: _scrollViewKey,
                    controller: _scrollController,
                    physics: _dragSelect.selecting || _pinchTracker.pinching
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    slivers: <Widget>[
                    for (final MapEntry<String, List<pm.AssetEntity>> entry
                        in widget.grouped.entries) ...<Widget>[
                      // 日期头：左侧 4px 圆角色条 + 粗体日期 + 当天张数。
                      SliverToBoxAdapter(
                        child: Container(
                          color: Theme.of(context).colorScheme.surface,
                          // 垂直 padding 取 4（而非 8）：日期头恒定高度 =
                          // 48（「全选」按钮占位）+ 4×2 = 56dp。取 4 是为了让
                          // 未选中态尽量贴近原有的紧凑观感（改前约 36dp）。
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 4,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _assetGroupCountLabel(entry.value),
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              // 多选态下提供「全选」：一键选中该日期组全部照片。
                              // M3 触控目标：交互元素点击区至少 48x48dp。
                              const Spacer(),
                              // 关键：按钮始终渲染，只用 Visibility 控制可见性，
                              // 靠 maintainSize 让它在「不可见」时仍然占住 48x48。
                              //
                              // 为什么不能用 `if (widget.selected.isNotEmpty)` 直接
                              // 插入：未选中时这行的高度由旁边 fontSize:15 的日期
                              // 文字决定（约 20dp），一旦有选中项，插入的 TextButton
                              // 带 minimumSize: Size(48,48)，Row 高度就从 20dp 撑到
                              // 48dp，下面所有网格整体下移约 28dp——用户看到的就是
                              // 「点一下照片选中，照片整体往下挪」。
                              // 恒定占位后，行高与选中态无关，选中/取消都不位移。
                              // 日期头的恒定高度 = 48（本按钮占位）+ 4×2（容器
                              // 垂直 padding）= 56dp；padding 取 4 而不是 8，
                              // 是为了让未选中态尽量贴近原有的紧凑观感（约 36dp）。
                              //
                              // 也不要为了消位移把 minimumSize 改小（32dp 之类）：
                              // 既违反 M3 的 48x48 触控目标、点击变难，也仍会留下
                              // 12dp 的跳动。位移必须靠「恒定占位」解决。
                              Visibility(
                                visible: widget.selected.isNotEmpty,
                                maintainSize: true,
                                maintainAnimation: true,
                                maintainState: true,
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                  ),
                                  onPressed: () =>
                                      widget.onSelectGroup(entry.value),
                                  child: const Text('全选'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // 当天照片：3 列网格。
                      SliverPadding(
                        padding: const EdgeInsets.all(2),
                        sliver: SliverGrid(
                          gridDelegate: ContinuousColumnsGridDelegate(
                            // 连续列数 → 列宽随手指连续过渡（R10）；
                            // 收敛到整数后与 FixedCrossAxisCount 布局一致。
                            columnsF: _displayColumnsF,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (BuildContext context, int index) {
                              final pm.AssetEntity asset = entry.value[index];
                              final bool isSel =
                                  widget.selected.contains(asset);
                              // 记录格子 key 与资产映射，供滑动连选命中测试。
                              _assetById[asset.id] = asset;
                              return Stack(
                                key: _itemKeys.putIfAbsent(
                                    asset.id, () => GlobalKey()),
                                fit: StackFit.expand,
                                children: <Widget>[
                                  // 点击整张图 → 全屏查看；长按 → 进入多选。
                                  GestureDetector(
                                    onTap: () =>
                                        widget.onViewAsset(entry.value, index),
                                    onLongPress: () =>
                                        widget.onToggleAsset(asset),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: <Widget>[
                                        Thumbnail(entity: asset, size: 200),
                                        if (isSel)
                                          Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                                width: 3,
                                              ),
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withValues(alpha: 0.12),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // 右上角按钮 → 切换选中（与全屏查看互不干扰）。
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () =>
                                          widget.onToggleAsset(asset),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: isSel
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .surface
                                                  .withValues(alpha: 0.9),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isSel
                                              ? Icons.check
                                              : Icons.add,
                                          size: 18,
                                          color: isSel
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .onPrimary
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // 视频角标：左下角播放图标 + 时长
                                  // （Google 相册语义：时长在右下角，此处避开
                                  // 右上角选择按钮，放右下角）。
                                  if (asset.type == pm.AssetType.video)
                                    Positioned(
                                      bottom: 4,
                                      right: 4,
                                      child: _VideoDurationBadge(
                                        duration: asset.videoDuration,
                                      ),
                                    ),
                                ],
                              );
                            },
                            childCount: entry.value.length,
                            // T4.1/R6：关掉 keep-alive，减少滚动开销。
                            addAutomaticKeepAlives: false,
                          ),
                        ),
                      ),
                    ],
                    if (widget.loadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                  ],
                ),
            ),
        ),
      ],
    );
  }
}
