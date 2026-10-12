import 'package:flutter/foundation.dart';

/// 返回拦截注册表（多选态系统返回退出的修复）。
///
/// 背景：`StatefulShellRoute.indexedStack` 的分支页面位于**内嵌
/// Navigator** 中，系统返回键先询问根导航器的 Shell 路由——分支页面
/// 内的 `PopScope` 不会被询问（go_router 已知限制），表现为多选态按
/// 返回直接退出软件。
///
/// 方案：分支页面在 [initState] 注册一个 [BackHandler]（返回 true =
/// 本次返回已被消费，如"清除选中"），Shell（AppScaffold）用 PopScope
/// 统一拦截：有活跃拦截器时消费返回并调栈顶处理器；没有则正常放行
/// （到达根退出软件）。
///
/// 用法（ConsumerState 分支页面）：
/// ```dart
/// late final BackHandler _backHandler = () {
///   if (ref.read(selectionProvider).isNotEmpty) {
///     ref.read(selectionProvider.notifier).state = <int>{};
///     return true;
///   }
///   return false;
/// }();
/// bool _backBlocked = false;
///
/// // build 中按当前条件同步注册/注销（count 驱动 Shell 的 canPop）：
/// _syncBackBlock(hasSelection);
/// void _syncBackBlock(bool block) {
///   if (block && !_backBlocked) { BackBlocker.push(_backHandler); _backBlocked = true; }
///   if (!block && _backBlocked) { BackBlocker.pop(_backHandler); _backBlocked = false; }
/// }
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
