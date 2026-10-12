import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// 连续列数网格代理（R10 捏合连续缩放）。
///
/// [SliverGridDelegateWithFixedCrossAxisCount] 的列数是整数（阶跃），
/// [SliverGridDelegateWithMaxCrossAxisExtent] 内部同样按 `ceil` 取整，
/// 都做不出「列宽随手指连续过渡」。本代理以连续列数值 [columnsF] 驱动：
///
/// - **瓦片宽度** `tile = (视口宽 - (columnsF - 1) * spacing) / columnsF`，
///   随 [columnsF] 严格连续变化（再分箱瞬间也无尺寸跳变）；
/// - **结构列数** `n = floor(columnsF)`，决定每行个数与滚动几何。由
///   `tile + spacing = (视口宽 + spacing) / columnsF` 可得
///   `n * (tile + spacing) - spacing <= 视口宽`，即**行永不溢出**；
///   跨过整数阈值时新列在行尾出现，已有瓦片位置几乎不动（平滑再分箱）；
/// - **静止态**（columnsF 恰为整数）：与 `FixedCrossAxisCount` 的布局
///   逐像素一致，无任何回归。
class ContinuousColumnsGridDelegate extends SliverGridDelegate {
  const ContinuousColumnsGridDelegate({
    required this.columnsF,
    this.spacing = 2,
  }) : assert(columnsF > 0);

  /// 连续（未取整）列数值，来自捏合 / 收敛动画。
  final double columnsF;

  /// 瓦片间距（横纵同距，与页面原有 spacing 语义一致）。
  final double spacing;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final double extent = constraints.crossAxisExtent;
    final double f = columnsF.clamp(1.0, 100.0);
    // 结构列数取 floor（+极小 epsilon 抵消浮点误差，避免 f 恰为整数时
    // 因 2.9999... 被取到少一列）；由此保证行宽不溢出（见类注释）。
    final int n = math.max(1, (f + 0.0001).floor());
    // 连续瓦片宽度：f 越大瓦片越小；f 为整数时恰等于整列布局的槽位宽。
    final double tile =
        math.max(0.0, (extent - (f - 1) * spacing) / f);
    return SliverGridRegularTileLayout(
      crossAxisCount: n,
      mainAxisStride: tile + spacing,
      crossAxisStride: tile + spacing,
      childMainAxisExtent: tile,
      childCrossAxisExtent: tile,
      reverseCrossAxis:
          axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(ContinuousColumnsGridDelegate oldDelegate) {
    return oldDelegate.columnsF != columnsF ||
        oldDelegate.spacing != spacing;
  }
}
