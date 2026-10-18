import 'package:flutter/foundation.dart';

/// 返回拦截注册表（多选态系统返回退出的修复）。
///
/// 背景：`StatefulShellRoute.indexedStack` 的分支页面位于**内嵌 Navigator**
/// 中，且整个 Shell 在根 Navigator 里只有一个路由。按系统返回时 go_router
/// 的 `GoRouterDelegate.popRoute()` 会发现「哪一层都没有可 pop 的路由」，
/// **直接 `return false`**（根本不会调用 `maybePop()`），所以分支页面里的
/// `PopScope` 以及 Shell 外层的 `PopScope` 都不会被咨询 —— 表现为多选态
/// 按返回直接退出软件。详见 `AppScaffold` 类文档里的源码引用。
///
/// 方案：分支页面把 [BackHandler] 注册到本注册表；Shell（[AppScaffold]）
/// 用 **`BackButtonListener`**（不是 PopScope！它跑在
/// `RouterDelegate.popRoute()` 之前）统一拦截：有活跃拦截器时由栈顶处理器
/// 消费本次返回（如"清除选中"），没人消费则返回 false 交回 go_router 默认
/// 行为（根页面 → 退出软件）。
///
/// 用法（ConsumerState 分支页面）：注册/注销**不要放在 build 里**
/// （改 [count] 会在 build 期间触发监听者重建，见各页 `_syncBackBlock`
/// 的说明），应在改变选中集的入口处调用：
/// ```dart
/// late final BackHandler _backHandler = () {
///   if (_selected.isNotEmpty) {
///     setState(() => _selected.clear());
///     return true;
///   }
///   return false;
/// }();
/// bool _wantBackBlock = false;   // 期望
/// bool _backBlocked = false;     // 已真正 push
/// void _syncBackBlock(bool block) { /* 记录期望 + 帧后 push/pop */ }
/// // dispose：if (_backBlocked) BackBlocker.pop(_backHandler);
/// ```
typedef BackHandler = bool Function();

class BackBlocker {
  BackBlocker._();

  /// 活跃拦截器栈（后注册的先被询问，对应当前可见页）。
  static final List<BackHandler> _handlers = <BackHandler>[];

  /// 活跃拦截器数量（驱动 Shell 的 PopScope.canPop，需可监听）。
  static final ValueNotifier<int> count = ValueNotifier<int>(0);

  static void push(BackHandler handler) {
    _handlers.add(handler);
    count.value = _handlers.length;
  }

  static void pop(BackHandler handler) {
    _handlers.remove(handler);
    count.value = _handlers.length;
  }

  /// 系统返回被 Shell 拦截后分发：从栈顶询问，返回是否有人消费。
  static bool handleBack() {
    for (int i = _handlers.length - 1; i >= 0; i--) {
      if (_handlers[i]()) return true;
    }
    return false;
  }
}
