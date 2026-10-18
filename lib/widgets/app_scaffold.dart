import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:work_photos/widgets/back_blocker.dart';

/// 系统返回的统一处理：注册给 [BackButtonListener]。
///
/// 返回 true = 本次返回已被本 App 消费（如「退出多选」）；
/// 返回 false = 交回 go_router / Flutter 的默认行为（关闭上层弹层，或在根
/// 页面时退出应用）。
///
/// [context] 用 [AppScaffold] 自身的 context：`BackButtonListener` 比
/// go_router 的 `popRoute()` 更早拿到返回，所以**必须先让压在上面的路由
/// （确认导入对话框等）优先消费**，否则会出现「对话框开着、按返回却把多选
/// 清空、对话框还在」的怪现象。见下方 `routeAbove` 判断。
Future<bool> _onBackButtonPressed(BuildContext context) async {
  // 上层路由优先：ModalRoute（`showDialog` 默认 `useRootNavigator: true`，
  // 所以落在根 Navigator 上）能 pop 时，本次返回应当关掉它，我们让路。
  // 交给 go_router 走 popRoute() → 根 Navigator.canPop() → maybePop()。
  final bool routeAbove =
      Navigator.maybeOf(context, rootNavigator: true)?.canPop() ?? false;
  if (routeAbove) {
    debugPrint('[BackBlocker] back passed to route above (dialog/sheet)');
    return false;
  }
  final bool consumed = BackBlocker.handleBack();
  // 无条件 debugPrint（release 包同样输出）：真机装包后用
  //   adb logcat | grep BackBlocker
  // 就能确认「按返回时到底有没有拦截器、有没有被消费」，这是排查
  // 「按返回直接退出」最直接的一条证据。
  debugPrint('[BackBlocker] back consumed=$consumed '
      'handlers=${BackBlocker.count.value}');
  return consumed;
}

/// 底部导航 Shell（B6，Material 3 NavigationBar）。
///
/// 由 [StatefulShellRoute.indexedStack] 的 [StatefulNavigationShell] 驱动，
/// 渲染四页（相册 / 分类 / 导入 / 我的）并维护各分支的页面栈与状态。
/// 点击底部导航项时调用 [StatefulNavigationShell.goBranch] 切换分支。
///
/// ## 返回键：为什么用 [BackButtonListener]，而不是 PopScope（别改回去！）
///
/// go_router 13.2.5 的 `GoRouterDelegate.popRoute()`
/// （`go_router/lib/src/delegate.dart:54-78`）逻辑是：
///
/// ```dart
/// NavigatorState? state = navigatorKey.currentState;
/// if (state == null) return false;
/// if (!state.canPop()) state = null;   // 根 Navigator 只有 shell 一个路由 → null
/// RouteMatchBase walker = currentConfiguration.matches.last;
/// while (walker is ShellRouteMatch) {
///   if (walker.navigatorKey.currentState?.canPop() ?? false) {
///     state = walker.navigatorKey.currentState;   // 分支 Navigator 也没有可 pop 的路由
///   }
///   walker = walker.matches.last;
/// }
/// if (state != null) return state.maybePop();
/// final GoRoute lastRoute = currentConfiguration.last.route;
/// if (lastRoute.onExit != null && navigatorKey.currentContext != null) {
///   return !(await lastRoute.onExit!(navigatorKey.currentContext!));
/// }
/// return false;   // ← 单 tab 根页（本 App 的常态）走到这里
/// ```
///
/// 关键在最后：`state == null` 时**直接 `return false`，根本不会调用
/// `maybePop()`**，于是任何 `PopScope`（`canPop: false` /
/// `onPopInvokedWithResult`）**从未被咨询** —— 之前挂在这里的
/// `PopScope(canPop: blockers == 0)` 在 go_router 这条路径上是**死代码**。
/// `popRoute()` 返回 false 后，`WidgetsBinding.handlePopRoute()` 认为没有
/// 任何观察者处理本次返回，于是调用 `SystemNavigator.pop()` —— **退出软件**。
///
/// 正确做法是 [BackButtonListener]：它注册到
/// `Router.of(context).backButtonDispatcher`（这里就是 GoRouter 自己 new 的
/// `RootBackButtonDispatcher`，见 `go_router/lib/src/router.dart:186`），
/// 并 `createChildBackButtonDispatcher()..addCallback(...)..takePriority()`
/// 抢到优先级。`BackButtonDispatcher.invokeCallback()` 会**先问子分发器**
/// （也就是本组件），返回 true 就直接结束，压根不会走到
/// `RouterDelegate.popRoute()`。也就是说它跑在 go_router 的 popRoute 之前，
/// 这正是 `PopScope` 拿不到的位置。
///
/// ## 已知边界：压在 shell 之上的弹层
///
/// 因为拦截器比 `popRoute()` 更早执行，弹层必须先被让路，否则「对话框开着
/// 按返回」会变成「清空多选、对话框还在」。当前实现用
/// `Navigator.maybeOf(context, rootNavigator: true).canPop()` 判断，
/// 覆盖 `showDialog`（默认 `useRootNavigator: true`，落在根 Navigator）。
/// **分支 Navigator 上的弹层（`showModalBottomSheet` 默认
/// `useRootNavigator: false`）不在判断范围内**：那类弹层请显式传
/// `useRootNavigator: true`，让它也落到根 Navigator 上（顺带能盖住底部
/// 导航栏，视觉上也更正确）；否则多选态下打开该弹层按返回，会先清空多选
/// 而不是关闭弹层。
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
    // 注意：这里必须是 MaterialApp.router 的 Router 子树内的位置——
    // BackButtonListener 依赖 `Router.of(context)` 找到祖先 Router，
    // 本组件由 StatefulShellRoute.indexedStack 的 builder 渲染，正处在
    // routerDelegate 构建出的子树里，满足前提（详见类文档）。
    //
    // 回调是 per-build 闭包（而不是顶层函数）：需要 AppScaffold 的 context
    // 去判断「上面是否还有可 pop 的弹层」。代价是切 tab 重建时会走一次
    // BackButtonListener.didUpdateWidget 里的 remove/add/takePriority，
    // 三次轻量调用，可接受。
    return BackButtonListener(
      onBackButtonPressed: () => _onBackButtonPressed(context),
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
