import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:work_photos/widgets/back_blocker.dart';

/// 底部导航 Shell（B6，Material 3 NavigationBar）。
///
/// 由 [StatefulShellRoute.indexedStack] 的 [StatefulNavigationShell] 驱动，
/// 渲染四页（相册 / 分类 / 导入 / 我的）并维护各分支的页面栈与状态。
/// 点击底部导航项时调用 [StatefulNavigationShell.goBranch] 切换分支。
///
/// 返回键：分支页面在内嵌 Navigator 中，页面内的 PopScope 拦不到系统
/// 返回（go_router 限制）——由本 Shell 统一拦截并分发给
/// [BackBlocker]（多选态"返回=退出多选"的实现处）。
///
/// M3 规范（material.io/foundations）：
/// - NavigationBar 适用于 3~5 个顶级目的地（当前 4 个）；
/// - 标签常显（不允许纯图标导航）；
/// - 选中态用填充图标 / 未选中用轮廓图标区分；
/// - 活动指示器（pill）默认 secondaryContainer，不覆盖。
class AppScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: BackBlocker.count,
      builder: (BuildContext context, int blockers, Widget? child) {
        return PopScope(
          // 有页面要求拦截（如多选态）时挡下返回并分发；否则正常放行
          //（根路由 pop = 退出软件，与原生行为一致）。
          canPop: blockers == 0,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (!didPop) {
              BackBlocker.handleBack();
            }
          },
          child: child!,
        );
      },
      child: Scaffold(
        // navigationShell 即当前激活分支的页面（StatefulShellRoute 已用
        // IndexedStack 维持各分支状态）。
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (int index) =>
              navigationShell.goBranch(index),
          destinations: const <Widget>[
            // index 0 → /grid 相册（开屏默认页）。
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view),
              label: '相册',
            ),
            // index 1 → /category 分类。
            NavigationDestination(
              icon: Icon(Icons.category_outlined),
              selectedIcon: Icon(Icons.category),
              label: '分类',
            ),
            // index 2 → /import 导入。
            NavigationDestination(
              icon: Icon(Icons.download_outlined),
              selectedIcon: Icon(Icons.download),
              label: '导入',
            ),
            // index 3 → /me 我的。
            NavigationDestination(
              icon: Icon(Icons.person_outlined),
              selectedIcon: Icon(Icons.person),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }
}
