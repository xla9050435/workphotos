import 'dart:async';

import 'package:flutter/widgets.dart';

/// 一次网格命中：命中的网格项与其在屏幕上的矩形。
///
/// 矩形供纵列连选判定使用（起点格的横向范围决定纵列通道），也便于宿主
/// 扩展自定义判定；[item] 的相等性语义由宿主类型决定（int 用 `==`，
/// photo_manager 的 AssetEntity 重写了基于 id 的 `==`）。
class GridHit<T> {
  final T item;
  final Rect rect;

  const GridHit({required this.item, required this.rect});
}

/// 连选拖动的轴向意图（判定一次后锁定，避免拖动中反复横跳）。
enum DragSelectAxis {
  /// 横向主导：橡皮筋式滑动多选。
  horizontal,

  /// 纵向主导且起点命中**已选中**的网格项：纵列连选（沿一列纵向滑过连选，R4）。
  /// 起点未选中（或未命中）的纵向拖动一律视为滚动意图，见 [scroll]。
  verticalColumn,

  /// 纵向主导且起点未命中网格项、或起点的格子尚未选中：滚动意图，交给列表滚动。
  ///
  /// 多选态下「未选中格子起手纵滑」也走这里——否则网格铺满全屏时用户无处
  /// 起手滚动。想纵列连选请先点中一张作为锚点再从那格起手。
  scroll,
}

/// 网格拖动连选共享状态机（T2.2）：相册页与导入页共用同一套连选语义。
///
/// 宿主通过回调注入差异点（命中测试、选中集读写、滚动控制器），控制器
/// 内部收敛全部公共逻辑：最小拖动位移、轴向判定（横滑连选 / 纵列连选 /
/// 滚动三值，R4）、插值采样防跳格、加减模式（Google 相册语义）、边缘
/// 自动滚动（滚动由定时器驱动，指针不动也持续命中，并做滚动坐标补偿）。
///
/// 用法：Listener 四转发 [onPointerDown] / [onPointerMove] / [end]（up 与
/// cancel 同），宿主布局 physics 在 [selecting] 为 true 时禁滚；dispose
/// 前调用 [dispose] 取消定时器。
class GridDragSelectController<T> {
  GridDragSelectController({
    required this.hasSelection,
    required this.hitTest,
    required this.isSelected,
    required this.onAdd,
    required this.onRemove,
    required this.scrollController,
    required this.viewportKey,
    this.onStateChanged,
    this.decideAxis,
  });

  /// 当前是否处于选择态：仅选择态才允许连选（与相册页语义一致）。
  final bool Function() hasSelection;

  /// 命中测试：指针（屏幕坐标）下的网格项，无则 null。
  final GridHit<T>? Function(Offset global) hitTest;

  /// [item] 当前是否已被选中（用于决定加/减模式）。
  final bool Function(T item) isSelected;

  /// 连选「加模式」命中：把 [item] 加入选择集（宿主负责去重与刷新）。
  final void Function(T item) onAdd;

  /// 连选「减模式」命中：把 [item] 移出选择集。
  final void Function(T item) onRemove;

  /// 网格滚动控制器：边缘自动滚动使用。
  final ScrollController scrollController;

  /// 网格滚动视口的 key：用于取视口屏幕矩形，判定上/下边缘触发区。
  final GlobalKey viewportKey;

  /// 连选状态变化通知（进入/退出连选）：宿主据此 setState 刷新 physics。
  final VoidCallback? onStateChanged;

  /// 自定义轴向判定扩展点：返回 null 则走默认判定（横滑 / 纵列 / 滚动）。
  final DragSelectAxis? Function(
      Offset delta, Offset global, GridHit<T>? downHit)? decideAxis;

  /// 最小拖动位移（逻辑像素）：低于该值的移动视为点按，不进入连选。
  /// 对齐 Flutter 触摸 slop（kTouchSlop=18）：低于它的移动 tap 手势本就
  /// 不会提交，避免连选置位与点按切换在临界位移上双重触发。
  static const double kDragStartThreshold = 18;

  /// 插值采样步长（逻辑像素）：小于平均格子尺寸的一半，保证不跳格。
  static const double kSampleStep = 20;

  /// 距视口上/下边缘小于该值时触发自动滚动。
  static const double kAutoScrollEdge = 80;

  /// 单次 tick（16ms）的最大滚动量：12px/tick ≈ 720px/s；越贴近边缘越快。
  static const double kAutoScrollMaxSpeed = 12;

  // —— 拖动中状态 ——
  /// 连选中（期间宿主应禁用网格滚动，松手恢复）。
  bool _selecting = false;
  /// 轴向是否已判定：判定一次后锁定。已判定且非连选 → 滚动意图，
  /// 本次拖动不再进入连选（否则多选态下页面将永远无法滚动）。
  bool _axisDecided = false;
  /// 指针按下位置：最小拖动位移的基准。
  Offset? _downPos;
  /// 按下时命中的网格项（含矩形）：纵列连选的通道判定与连选起点。
  GridHit<T>? _downHit;
  /// 本次拖动第一个命中的网格项：起点只记录不动作，连选从第二个命中开始。
  T? _firstHit;
  /// 连选模式：false=途经即选中 / true=途经即取消。由第一个非起点命中的
  /// 选中状态决定（已选 → 减模式，未选 → 加模式）。
  bool _remove = false;
  bool _modeDecided = false;

  // —— 边缘自动滚动 ——
  Timer? _autoScrollTimer;
  /// 最近一次指针位置：滚动由定时器驱动，指针不动也需要它做命中测试。
  Offset? _lastPointerPos;
  /// 上次连选采样点：插值采样起点（修快速滑动漏选），松手清空。
  Offset? _lastSamplePos;

  /// 是否连选中（宿主 physics 据此禁滚）。
  bool get selecting => _selecting;

  /// 指针按下：记录基准位置、按下命中与**采样起点**。
  ///
  /// 采样起点必须从按下位置开始：若置空等待首次 move 才开始采样，
  /// 快速滑动时首个 move 事件可能已越过 1-2 个格子，该段路径不参与
  /// 命中——表现为「有时有格子不会被选中」（漏选 bug 根因之一）。
  void onPointerDown(Offset global) {
    _downPos = global;
    _downHit = hitTest(global);
    _lastSamplePos = global;
  }

  /// 指针移动：按需进入连选，并处理途经网格项的选中/取消。
  ///
  /// 触发条件：处于选择态 且 指针位移超过 [kDragStartThreshold]。
  /// 「长按选中后不松手继续滑动」同样会进入连选（长按回调已把起点网格项
  /// 加入选择集，随后的 move 事件满足条件；Listener 不参与手势竞技）。
  void onPointerMove(Offset global) {
    if (!hasSelection()) return;
    final Offset? down = _downPos;
    if (down == null) return; // 无按下基准：不处理（防多点触控脏状态）
    if (_axisDecided && !_selecting) return; // 已判定为滚动：交给列表
    final Offset delta = global - down;
    if (delta.distance < kDragStartThreshold) {
      return; // 位移过小：视为点按/未拖动
    }
    if (!_axisDecided) {
      final DragSelectAxis axis =
          decideAxis?.call(delta, global, _downHit) ??
              _defaultDecideAxis(delta, global, _downHit);
      _axisDecided = true; // 判定一次后锁定
      if (axis == DragSelectAxis.scroll) return;
      _selecting = true;
      // Google 相册语义：起点格随拖动**立即生效**——按住未选中的格子
      // 开始滑动，该格即刻入选（修复「滑动后第一张没有被选中」）。
      // 起点已选中的（减模式锚点）保持选中，由后续途经项决定加减。
      // （局部变量承接 _downHit：非 final 字段无法做空提升。）
      final GridHit<T>? down = _downHit;
      if (down != null) {
        _firstHit = down.item;
        if (!isSelected(down.item)) onAdd(down.item);
      }
      onStateChanged?.call();
    }
    _processHit(global);
    _handleAutoScroll(global);
  }

  /// 默认轴向判定：横向主导 → 连选；纵向主导时**起点命中且该格已被选中**
  /// 且指针仍在其横向范围内 → 纵列连选（R4），否则视为滚动意图。
  ///
  /// 为什么纵列连选要求「起点格已选中」：网格通常铺满整屏，多选态下用户
  /// 几乎找不到「空白起手」的位置。若任何格子起手纵滑都判成纵列连选，
  /// 结果就是既误选了沿途照片、又把列表锁成不可滚动
  /// （`physics: NeverScrollableScrollPhysics`）——多选态下根本滚不动。
  /// 现在的语义：
  /// - 纵向滑动默认 = 滚动（多选态下也能正常浏览）；
  /// - 想纵列连选：先点中一张作为锚点，再从**那张**起手纵向拖；
  /// - 横向滑动保持原有橡皮筋连选，不受影响。
  DragSelectAxis _defaultDecideAxis(
      Offset delta, Offset global, GridHit<T>? downHit) {
    if (delta.dy.abs() < delta.dx.abs()) return DragSelectAxis.horizontal;
    if (downHit != null &&
        // 仅「已选中」的格子可作为纵列连选锚点：未选中格子起手纵滑 →
        // 滚动，避免「一滑就误选 + 页面滚不动」。
        isSelected(downHit.item) &&
        global.dx >= downHit.rect.left &&
        global.dx <= downHit.rect.right) {
      return DragSelectAxis.verticalColumn;
    }
    return DragSelectAxis.scroll;
  }

  /// 连选命中处理（带插值采样）：从上次采样点到当前指针位置之间按步长
  /// 补采样后再逐点命中。
  ///
  /// 修复「快速滑动有时选不中」：move 事件约每帧一个，快速拖动时两次
  /// 事件间会跳过整行网格项，直接只命中终点会漏掉中间的格子——按
  /// [kSampleStep] 插值后逐点命中，途经项全部处理。命中本身幂等
  /// （加模式重复加无变化/减模式重复减无变化），重复采样无副作用。
  void _processHit(Offset global) {
    final Offset? last = _lastSamplePos;
    _lastSamplePos = global;
    if (last == null || (global - last).distance <= kSampleStep) {
      _hitAt(global);
      return;
    }
    final Offset delta = global - last;
    final int steps = (delta.distance / kSampleStep).ceil();
    for (int i = 1; i <= steps; i++) {
      _hitAt(Offset.lerp(last, global, i / steps)!);
    }
  }

  /// 单点命中：指针（屏幕坐标）下的网格项按当前模式加入/移出选择集。
  ///
  /// 由 [_processHit] 与自动滚动 tick 共用——自动滚动时指针不动，
  /// 但视口滚动使指针下的网格项持续变化，需要逐帧重新命中。
  void _hitAt(Offset global) {
    final GridHit<T>? hit = hitTest(global);
    if (hit == null) return;
    if (_firstHit == null) {
      _firstHit = hit.item; // 起点：只记录不动作
      return;
    }
    if (!_modeDecided) {
      // 仍在起点格内（插值采样会重复命中起点）：不据此决定加减模式——
      // 起点已由长按加入选择集，按它判定会错把「加」定成「减」。
      if (hit.item == _firstHit) return;
      _remove = isSelected(hit.item);
      _modeDecided = true;
    }
    if (_remove) {
      onRemove(hit.item);
    } else {
      onAdd(hit.item);
    }
  }

  /// 指针相对视口上/下边缘触发区的自动滚动速度（px/tick）。
  ///
  /// 上边缘为负（向上滚）、下边缘为正（向下滚）、不在触发区为 0；
  /// 越贴近视口边界越快（线性）。
  double _edgeSpeed(Offset global) {
    final RenderBox? box =
        viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return 0;
    final Rect rect = box.localToGlobal(Offset.zero) & box.size;
    if (global.dy < rect.top + kAutoScrollEdge) {
      final double depth = (rect.top + kAutoScrollEdge - global.dy)
          .clamp(0.0, kAutoScrollEdge)
          .toDouble();
      return -kAutoScrollMaxSpeed * depth / kAutoScrollEdge;
    }
    if (global.dy > rect.bottom - kAutoScrollEdge) {
      final double depth = (global.dy - (rect.bottom - kAutoScrollEdge))
          .clamp(0.0, kAutoScrollEdge)
          .toDouble();
      return kAutoScrollMaxSpeed * depth / kAutoScrollEdge;
    }
    return 0;
  }

  /// 进入/离开边缘触发区时启动或维持自动滚动（连选中才生效）。
  void _handleAutoScroll(Offset global) {
    _lastPointerPos = global;
    if (!_selecting) return;
    if (_autoScrollTimer != null) return; // 已在滚动
    if (_edgeSpeed(global) == 0) return; // 不在触发区
    _autoScrollTimer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _autoScrollTick(),
    );
  }

  /// 自动滚动 tick：滚动一帧后按当前指针位置重新命中，继续连选。
  void _autoScrollTick() {
    final Offset? p = _lastPointerPos;
    if (p == null || !_selecting) {
      _stopAutoScroll();
      return;
    }
    final double speed = _edgeSpeed(p);
    if (speed == 0) {
      _stopAutoScroll(); // 指针已离开触发区（等待下次 move 重启）
      return;
    }
    final ScrollPosition pos = scrollController.position;
    final double before = pos.pixels;
    final double target = (pos.pixels + speed)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent)
        .toDouble();
    if (target == before) {
      _stopAutoScroll(); // 已滚到头
      return;
    }
    pos.jumpTo(target);
    // 布局尚未按新偏移更新，直接用当前指针位置命中会拿到滚动前的网格项。
    // 坐标补偿：新偏移下指针下的内容 = 旧布局中 (p.y + Δoffset) 处的内容。
    _processHit(p.translate(0, target - before));
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  /// 松手 / 取消 / 进入捏合：无条件复位全部拖动状态。
  ///
  /// 滚动意图的拖动没有置位 [_selecting]，但 down 基准与方向判定同样需要
  /// 在松手时清理，供下次拖动使用。
  void end() {
    final bool wasSelecting = _selecting;
    _stopAutoScroll();
    _selecting = false;
    _axisDecided = false;
    _downPos = null;
    _downHit = null;
    _firstHit = null;
    _remove = false;
    _modeDecided = false;
    _lastPointerPos = null;
    _lastSamplePos = null;
    if (wasSelecting) onStateChanged?.call();
  }

  /// 宿主 dispose 前调用：取消自动滚动定时器。
  void dispose() {
    _stopAutoScroll();
  }
}
