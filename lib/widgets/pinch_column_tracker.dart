import 'package:flutter/material.dart';

/// 双指捏合调节网格列数的手势跟踪器（学系统相册：捏合图片变小排版变密，
/// 张开图片变大排版变疏）。
///
/// 在原始指针事件层（Listener）工作，而非 GestureDetector 手势竞技场：
/// - 单指时完全透明，不与滚动 / 连选（长按拖动）/ 点击竞争；
/// - 检测到第二根手指按下即进入捏合模式，由宿主禁用滚动并终止连选。
///
/// 用法：宿主 State 持有一个实例，把 Listener 的 down/move/up/cancel 原样
/// 转发给对应 handler；通过 [columns] 读取当前列数驱动网格 delegate，
/// [onColumnsChanged] / [onPinchStateChanged] 回调里做 setState。
class PinchColumnTracker {
  PinchColumnTracker({
    this.minColumns = 2,
    this.maxColumns = 6,
    this.initialColumns = 3,
    required this.onColumnsChanged,
    this.onColumnsContinuous,
    required this.onPinchStateChanged,
  }) : _columns = initialColumns,
       _columnsF = initialColumns.toDouble();

  /// 最小列数（图片最大）。
  final int minColumns;

  /// 最大列数（图片最小、排版最密）。
  final int maxColumns;

  /// 初始列数。
  final int initialColumns;

  /// 列数变化回调（已去重：仅列数真正变化时触发）。
  final void Function(int columns) onColumnsChanged;

  /// 捏合模式进入/退出回调（宿主据此禁用/恢复滚动并终止连选）。
  final void Function(bool pinching) onPinchStateChanged;

  /// 连续列数回调（R10）：捏合过程中每帧上报未取整的列数值，
  /// 宿主用它驱动「列宽随手指连续过渡」的逐帧布局插值。
  final void Function(double columnsF)? onColumnsContinuous;

  final Map<int, Offset> _pointers = <int, Offset>{};
  double _columnsF;
  double? _lastSpan;
  bool _pinching = false;
  int _columns;
  // 上次连续回调已上报的值：去重，避免同一值重复触发宿主 setState。
  double _lastReportedF = 0;

  /// 是否正处于双指捏合模式。
  bool get pinching => _pinching;

  /// 当前列数。
  int get columns => _columns;

  /// 当前的连续（未取整）列数值：捏合过程中在 [minColumns] 与 [maxColumns]
  /// 之间连续变化；静止时等于取整后的 [columns]。
  double get columnsF => _columnsF;

  /// 指针按下：登记；第二根手指按下时进入捏合模式。
  void handleDown(int pointer, Offset position) {
    _pointers[pointer] = position;
    if (_pointers.length == 2 && !_pinching) {
      _pinching = true;
      _lastSpan = _span();
      // 以当前列数为缩放基准重新累积，避免上次捏合的残差跳变。
      _columnsF = _columns.toDouble();
      _lastReportedF = _columnsF;
      onPinchStateChanged(true);
    }
  }

  /// 指针移动：更新位置；捏合中按两指间距比例连续调整列数。
  void handleMove(int pointer, Offset position) {
    if (!_pointers.containsKey(pointer)) return;
    _pointers[pointer] = position;
    if (!_pinching || _pointers.length < 2) return;
    final double span = _span();
    final double? last = _lastSpan;
    if (last != null && last > 0 && span > 0) {
      // 两指张开（span 增大）→ 图片变大 → 列数减少；反之列数增加。
      _columnsF = (_columnsF * last / span)
          .clamp(minColumns.toDouble(), maxColumns.toDouble());
      // 连续上报（R10）：宿主据此做逐帧布局插值（列宽随手指连续过渡）。
      if (onColumnsContinuous != null &&
          (_columnsF - _lastReportedF).abs() > 0.0005) {
        _lastReportedF = _columnsF;
        onColumnsContinuous!(_columnsF);
      }
      final int c = _columnsF.round();
      if (c != _columns) {
        _columns = c;
        onColumnsChanged(c);
      }
    }
    _lastSpan = span;
  }

  /// 指针抬起/取消：注销；不足两指时退出捏合模式。
  void handleUp(int pointer) {
    _pointers.remove(pointer);
    if (_pinching && _pointers.length < 2) {
      _pinching = false;
      _lastSpan = null;
      onPinchStateChanged(false);
    }
  }

  /// 外部同步列数（R3：设置异步加载完成 / 设置页重置后回读）。
  /// 重置整数列与连续基准，使下一次捏合从该值起算。
  void applyColumns(int columns) {
    _columns = columns.clamp(minColumns, maxColumns).toInt();
    _columnsF = _columns.toDouble();
    _lastReportedF = _columnsF;
  }

  /// 当前两指间距。
  double _span() {
    final Iterator<MapEntry<int, Offset>> it = _pointers.entries.iterator;
    it.moveNext();
    final Offset a = it.current.value;
    it.moveNext();
    final Offset b = it.current.value;
    return (a - b).distance;
  }
}
