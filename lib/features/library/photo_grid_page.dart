import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:work_photos/core/utils/media_count_label.dart';
import 'package:work_photos/data/models/photo.dart';
import 'package:work_photos/features/filters/filter_bar.dart';
import 'package:work_photos/features/library/multi_select_bar.dart';
import 'package:work_photos/features/library/photo_grid_item.dart';
import 'package:work_photos/features/me/settings_provider.dart';
import 'package:work_photos/features/onboarding/gesture_coach.dart';
import 'package:work_photos/providers/photo_provider.dart';
import 'package:work_photos/providers/selection_provider.dart';
import 'package:work_photos/widgets/continuous_grid_delegate.dart';
import 'package:work_photos/widgets/back_blocker.dart';
import 'package:work_photos/widgets/grid_drag_select_controller.dart';
import 'package:work_photos/widgets/pinch_column_tracker.dart';

/// 照片网格页（B4 + B6）。
///
/// 通过 [photoListProvider]（以 [gridFilterProvider] 为 family 参数）流式刷新；
/// 支持按 分类 + 已用/未用 + 日期 + 星期几 过滤（[FilterBar]，B6）；长按网格项
/// 进入多选（见 [MultiSelectBar]）。
///
/// 多选增强：进入选择态（已有选中项）后，可在网格上**拖动**滑过更多照片，
/// 途经的照片自动加入选择集（橡皮筋式滑动多选）。
///
/// 每日日期显示：当 [settingsProvider].groupByDay 为 true（默认）时，照片按
/// [Photo.displayTime]（拍摄时间优先，缺失回退导入时间）的年月日分组，
/// 每组带日期头（今天 / 昨天 / 前天 / yyyy年M月d日）。
class PhotoGridPage extends ConsumerStatefulWidget {
  const PhotoGridPage({super.key});

  @override
  ConsumerState<PhotoGridPage> createState() => _PhotoGridPageState();
}

/// 单日分组（用于按天显示）。
class _PhotoGroup {
  final String label;
  final List<Photo> photos;

  _PhotoGroup({required this.label, required this.photos});
}

/// 分组计数文案：统计图片 / 视频构成后交给 [mediaCountLabel]（与导入页同口径）。
String _groupCountLabel(List<Photo> photos) {
  final int videos = photos.where((Photo p) => p.isVideo).length;
  return mediaCountLabel(
    imageCount: photos.length - videos,
    videoCount: videos,
  );
}

class _PhotoGridPageState extends ConsumerState<PhotoGridPage>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  // 网格滚动视口的 key：自动滚动时用它取视口在屏幕上的矩形，
  // 以判定指针是否进入上/下边缘触发区。
  final GlobalKey _scrollViewKey = GlobalKey();

  // 每个网格项的 GlobalKey，供拖动多选时做命中测试（布局无关，分组/平铺均适用）。
  final Map<int, GlobalKey> _itemKeys = <int, GlobalKey>{};

  // —— 拖动连选共享状态机（T2.2，R4 纵列连选）——
  // 相册页与导入页共用同一套语义（见 GridDragSelectController）：
  // 横向拖动连选 / 纵列连选 / 纵向空白滚动三值轴向，插值采样防跳格，
  // 加减模式跟随途经项选中态，边缘自动滚动带坐标补偿。
  late final GridDragSelectController<int> _dragSelect =
      GridDragSelectController<int>(
    hasSelection: () => ref.read(selectionProvider).isNotEmpty,
    hitTest: _hitPhoto,
    isSelected: (int id) => ref.read(selectionProvider).contains(id),
    onAdd: (int id) {
      final Set<int> current = Set<int>.from(ref.read(selectionProvider));
      if (current.add(id)) ref.read(selectionProvider.notifier).state = current;
    },
    onRemove: (int id) {
      final Set<int> current = Set<int>.from(ref.read(selectionProvider));
      if (current.remove(id)) {
        ref.read(selectionProvider.notifier).state = current;
      }
    },
    scrollController: _scrollController,
    viewportKey: _scrollViewKey,
    onStateChanged: () {
      if (mounted) setState(() {}); // physics 随连选状态刷新
    },
  );

  // —— 双指捏合调节列数 ——（学系统相册：捏合图片变小排版变密）
  // 单指时透明，不影响连选/滚动；第二指按下即进入捏合并终止连选。
  // 布局由连续列数值 [_displayColumnsF] 逐帧驱动（R10 连续缩放）；
  // 列数跨会话持久化（R3）：初始取自设置，捏合收敛后写回。
  late final PinchColumnTracker _pinchTracker = PinchColumnTracker(
    initialColumns: ref.read(settingsProvider).gridColumns,
    onColumnsChanged: (_) {},
    onColumnsContinuous: _onPinchColumns,
    onPinchStateChanged: _onPinchStateChanged,
  );

  // 当前布局使用的连续列数值（捏合中随手指连续变化，松手后收敛到整数）。
  double _displayColumnsF = 3;
  // 捏合结束后的收敛动画（连续值 → 最近整数）：整会话复用单个控制器。
  late final AnimationController _settleAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  // 收敛起止值（动画监听器读取；forward 前写入）。
  double _settleFrom = 3;
  int _settleTarget = 3;

  // —— 系统返回拦截（分支页内 PopScope 拦不到，见 BackBlocker 说明）——
  /// 多选态下：返回 = 退出多选（消费本次返回）；非多选态不拦截。
  late final BackHandler _backHandler = () {
    if (ref.read(selectionProvider).isNotEmpty) {
      ref.read(selectionProvider.notifier).state = <int>{};
      return true;
    }
    return false;
  };
  bool _backBlocked = false;

  /// 按当前选择态同步注册/注销返回拦截（build 中调用）。
  void _syncBackBlock(bool block) {
    if (block && !_backBlocked) {
      BackBlocker.push(_backHandler);
      _backBlocked = true;
    } else if (!block && _backBlocked) {
      BackBlocker.pop(_backHandler);
      _backBlocked = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _displayColumnsF = ref.read(settingsProvider).gridColumns.toDouble();
    _settleAnim.addListener(_onSettleTick);
    _settleAnim.addStatusListener(_onSettleStatus);
    // 手势引导（R13）：首次使用自动弹出（跳过/看完都写已读标记）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      GestureCoach.maybeShowOnce(context);
    });
  }

  @override
  void dispose() {
    if (_backBlocked) BackBlocker.pop(_backHandler);
    _settleAnim.dispose();
    _dragSelect.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 将 [photos] 按 [Photo.displayTime]（拍摄时间优先）的年月日分组，
  /// 保持原有顺序。
  ///
  /// 返回的分组顺序与 [photos] 中各照片首次出现的日序一致；当 [groupByDay]
  /// 为 false 时返回单组（整体作为一组，无日期头）。
  List<_PhotoGroup> _buildGroups(List<Photo> photos, bool groupByDay) {
    if (!groupByDay) {
      return <_PhotoGroup>[_PhotoGroup(label: '', photos: photos)];
    }
    final List<_PhotoGroup> groups = <_PhotoGroup>[];
    final Map<String, _PhotoGroup> index = <String, _PhotoGroup>{};
    for (final Photo p in photos) {
      final String key = _dayLabel(p.displayTime);
      final _PhotoGroup? existing = index[key];
      if (existing != null) {
        existing.photos.add(p);
      } else {
        final _PhotoGroup g = _PhotoGroup(label: key, photos: <Photo>[p]);
        index[key] = g;
        groups.add(g);
      }
    }
    return groups;
  }

  /// 将时间戳转换为日期头文本：今天 / 昨天 / 前天 / yyyy年M月d日。
  static String _dayLabel(DateTime d) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime that = DateTime(d.year, d.month, d.day);
    final int diff = today.difference(that).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    if (diff == 2) return '前天';
    return '${d.year}年${d.month}月${d.day}日';
  }

  // —— 捏合连续缩放（R10）+ 列数持久化（R3）——

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

  /// 命中测试：返回指针下的照片（含其屏幕矩形，供纵列连选通道判定）。
  ///
  /// 基于每个网格项的 GlobalKey，与具体布局无关，分组视图同样适用。
  GridHit<int>? _hitPhoto(Offset global) {
    for (final MapEntry<int, GlobalKey> entry in _itemKeys.entries) {
      final RenderBox? box =
          entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final Rect rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(global)) {
        return GridHit<int>(item: entry.key, rect: rect);
      }
    }
    return null;
  }

  /// 日期头「全选」：把该组全部照片加入选择集。
  void _selectAllGroup(_PhotoGroup group) {
    final Set<int> current = Set<int>.from(ref.read(selectionProvider));
    bool changed = false;
    for (final Photo p in group.photos) {
      final int? id = p.id;
      if (id != null && current.add(id)) changed = true;
    }
    if (changed) ref.read(selectionProvider.notifier).state = current;
  }

  @override
  Widget build(BuildContext context) {
    final PhotoFilter filter = ref.watch(gridFilterProvider);
    final AsyncValue<List<Photo>> photosAsync =
        ref.watch(photoListProvider(filter));
    final bool hasSelection = ref.watch(selectionProvider).isNotEmpty;
    final AppSettings settings = ref.watch(settingsProvider);
    final bool groupByDay = settings.groupByDay;
    // 设置异步加载完成 / 设置页重置后回读列数：
    // 仅在静止（非捏合、非收敛动画中）时覆盖，避免与手势/动画互抢（R3）。
    if (!_pinchTracker.pinching &&
        !_settleAnim.isAnimating &&
        _pinchTracker.columns != settings.gridColumns) {
      _pinchTracker.applyColumns(settings.gridColumns);
      _displayColumnsF = settings.gridColumns.toDouble();
    }
    // 多选态 → 拦截系统返回（返回=退出多选，而非退出软件）。
    _syncBackBlock(hasSelection);

    return PopScope(
      // 选择态下：返回应"退出选中界面"而非退出软件；非选择态则正常返回（到达根则退出）。
      canPop: !hasSelection,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          ref.read(selectionProvider.notifier).state = <int>{};
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('相册'),
          actions: <Widget>[
            // 全局搜索入口（R9）：独立 /search 页。
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: '搜索',
              onPressed: () => context.push('/search'),
            ),
            if (hasSelection)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: '取消多选',
                onPressed: () =>
                    ref.read(selectionProvider.notifier).state = <int>{},
              ),
          ],
          // B6：分类 + 状态 + 日期 + 星期几 筛选条。
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(48),
            child: FilterBar(),
          ),
        ),
        body: photosAsync.when(
          data: (List<Photo> photos) {
            if (photos.isEmpty) {
              return const Center(
                child: Text('暂无照片，请先到"导入"页引用导入。'),
              );
            }
            // 当前上下文的照片 id 列表，供详情页左右滑动切换使用；
            // indexById 直接映射到 ids 中的下标（而非 photos 下标），
            // 即使个别照片 id 为空也不会造成后续 index 错位。
            final List<int> ids = <int>[];
            final Map<int, int> indexById = <int, int>{};
            for (final Photo p in photos) {
              final int? id = p.id;
              if (id == null) continue;
              indexById[id] = ids.length;
              ids.add(id);
            }
            // 清理已不在当前列表中的网格项 key，避免长期使用残留。
            _itemKeys.removeWhere(
              (int id, GlobalKey k) => !indexById.containsKey(id),
            );

            final List<_PhotoGroup> groups = _buildGroups(photos, groupByDay);
            final bool showHeader = groupByDay;

            final Widget grid = Listener(
              // 连选 + 捏合手势层：Listener（原始指针）不参与手势竞技场——
              // GestureDetector 的拖动会被网格滚动在竞技中抢走导致连选失效。
              // 单指拖动 → 连选；双指 → 捏合调节列数（终止连选、禁滚）。
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
              child: CustomScrollView(
                key: _scrollViewKey,
                controller: _scrollController,
                physics: _dragSelect.selecting || _pinchTracker.pinching
                    ? const NeverScrollableScrollPhysics()
                    : null,
                slivers: <Widget>[
                  for (final _PhotoGroup group in groups) ...<Widget>[
                    if (showHeader && group.label.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Container(
                          color: Theme.of(context).scaffoldBackgroundColor,
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
                                group.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _groupCountLabel(group.photos),
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              // 多选态下提供「全选」：一键选中该日期组的全部照片。
                              // M3 触控目标：交互元素点击区至少 48x48dp。
                              const Spacer(),
                              // 关键：按钮始终渲染，只用 Visibility 控制可见性，
                              // 靠 maintainSize 让它在「不可见」时仍然占住 48x48。
                              //
                              // 为什么不能用 `if (hasSelection)` 直接插入：未选中时
                              // 这行的高度由旁边 fontSize:15 的日期文字决定（约
                              // 20dp），一旦有选中项，插入的 TextButton 带
                              // minimumSize: Size(48,48)，Row 高度就从 20dp 撑到
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
                                visible: hasSelection,
                                maintainSize: true,
                                maintainAnimation: true,
                                maintainState: true,
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                  ),
                                  onPressed: () => _selectAllGroup(group),
                                  child: const Text('全选'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
                            final Photo p = group.photos[index];
                            final int? pid = p.id;
                            final int idx = pid != null
                                ? (indexById[pid] ?? index)
                                : index;
                            return PhotoGridItem(
                              key: pid != null
                                  ? (_itemKeys.putIfAbsent(
                                      pid, () => GlobalKey()))
                                  : null,
                              photo: p,
                              photoIds: ids,
                              index: idx,
                            );
                          },
                          childCount: group.photos.length,
                          // T4.1/R6：网格项无状态需要保活，关掉 keep-alive
                          // 减少滚动时的元素管理开销（十万级列表受益明显）。
                          addAutomaticKeepAlives: false,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
            return grid;
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('加载失败：$error')),
        ),
        bottomNavigationBar: const MultiSelectBar(),
      ),
    );
  }
}
