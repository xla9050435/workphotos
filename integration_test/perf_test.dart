// 性能预算集成测试（T4.2 / R15）。
//
// 需真机 / 模拟器运行（agent 无法自验，用户侧执行）：
//   flutter test integration_test/perf_test.dart -d <device>
//
// 预算口径（R6/R15 验收）：
//   - 滚动 jank 率 < 5%（jank = 单帧总耗时 > 20ms）；
//   - 无未捕获异常 / 无 OOM。
// 不达预算时测试失败并打印 PerfTracker.summary()，便于定位。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:work_photos/core/utils/perf_tracker.dart';
import 'package:work_photos/main.dart' as app;

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('网格滚动帧率满足预算（jank < 5%）', (WidgetTester tester) async {
    // 用 main() 真实入口启动（含数据库注入与 PerfTracker.install）。
    app.main();

    // 等待权限闸门 / 首屏稳定：权限在真机上已授权过才会直接进入网格；
    // 未授权时本测试无法继续，按前提「测试设备已授权」处理。
    await tester.pumpAndSettle(const Duration(seconds: 3));

    PerfTracker.resetFrames();

    // 模拟 15 次快速滑动（上下交替，覆盖大列表滚动场景）。
    for (int i = 0; i < 15; i++) {
      await tester.fling(
        tester.getCenter(find.byType(Scrollable).first),
        Offset(0, i.isEven ? -1200 : 1200),
        3000,
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
    }

    // ignore: avoid_print
    print(PerfTracker.summary());

    expect(
      PerfTracker.jankWithinBudget,
      isTrue,
      reason: 'jank 率 ${(PerfTracker.jankRatio * 100).toStringAsFixed(2)}% '
          '超出预算 5%（janky=${PerfTracker.jankyFrames}/'
          '${PerfTracker.totalFrames}）\n${PerfTracker.summary()}',
    );
  });
}
