import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// 线下性能追踪（T4.2 / R15）。
///
/// 基于 [SchedulerBinding] 的 [FrameTiming] 回调统计帧率与卡顿：
/// - **jank 判定**：帧构建+栅格化总耗时 > 20ms（预算阈值，低于 60fps
///   预算线 16.7ms 但留有余量，避免统计噪声误报）；
/// - **jank 率**：验收口径 jank < 5%（滚动 ≥ 60fps 的等价指标）；
/// - **冷启动**：[markAppStart]（main 中调用）到首帧 [endOfFrame] 的时长，
///   验收口径 < 1.5s。
///
/// 仅线下使用：数据只在 debugPrint / [summary] 中呈现，不做任何上报
/// （与 R17「仅线下度量」一致）。release 包内安装与否均可（开销极低）。
class PerfTracker {
  PerfTracker._();

  static bool _installed = false;
  static final Stopwatch _coldStart = Stopwatch();
  static bool _coldStartReported = false;

  static int _totalFrames = 0;
  static int _jankyFrames = 0;
  static Duration _worstFrame = Duration.zero;

  /// jank 判定阈值（单帧总耗时）。
  static const Duration kJankThreshold = Duration(milliseconds: 20);

  /// 在 main 中尽早调用：开始计时冷启动并安装帧回调。
  static void install() {
    _coldStart.start();
    if (_installed) return;
    _installed = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    // 首帧渲染完成 → 冷启动时长（只报一次）。
    SchedulerBinding.instance.endOfFrame.then((_) {
      if (_coldStartReported) return;
      _coldStartReported = true;
      debugPrint('[Perf] 冷启动（首帧）: '
          '${_coldStart.elapsedMilliseconds}ms（预算 <1500ms）');
    });
  }

  static void _onTimings(List<FrameTiming> timings) {
    for (final FrameTiming t in timings) {
      _totalFrames++;
      final Duration total = t.totalSpan;
      if (total > _worstFrame) _worstFrame = total;
      if (total > kJankThreshold) _jankyFrames++;
    }
  }

  /// jank 率（0~1）。无帧数据时返回 0。
  static double get jankRatio =>
      _totalFrames == 0 ? 0 : _jankyFrames / _totalFrames;

  static int get totalFrames => _totalFrames;
  static int get jankyFrames => _jankyFrames;
  static Duration get worstFrame => _worstFrame;

  /// 预算检查（R15 验收卡点口径）。
  static bool get jankWithinBudget => jankRatio < 0.05;

  /// 汇总报告（调试输出 / 集成测试断言用）。
  static String summary() {
    return '[Perf] frames=$_totalFrames janky=$_jankyFrames '
        'jankRatio=${(jankRatio * 100).toStringAsFixed(2)}% '
        'worst=${_worstFrame.inMilliseconds}ms '
        'coldStart=${_coldStartReported ? '${_coldStart.elapsedMilliseconds}ms' : 'n/a'}';
  }

  /// 重置统计（集成测试分段测量用；不影响冷启动计时）。
  static void resetFrames() {
    _totalFrames = 0;
    _jankyFrames = 0;
    _worstFrame = Duration.zero;
  }
}
