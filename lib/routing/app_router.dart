import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:work_photos/core/app_theme.dart';
import 'package:work_photos/core/theme_mode_controller.dart';
import 'package:work_photos/features/classify/category_page.dart';
import 'package:work_photos/features/detail/photo_detail_page.dart';
import 'package:work_photos/features/import/import_page.dart';
import 'package:work_photos/features/library/photo_grid_page.dart';
import 'package:work_photos/features/me/me_page.dart';
import 'package:work_photos/features/me/settings_provider.dart';
import 'package:work_photos/features/search/search_page.dart';
import 'package:work_photos/l10n/generated/app_localizations.dart';
import 'package:work_photos/widgets/app_scaffold.dart';

/// 构建应用路由树（go_router，B6）。
///
/// 结构：
/// - [StatefulShellRoute.indexedStack] 承载底部导航三页（相册 / 分类 / 导入），
///   由 [AppScaffold] 渲染底部导航栏并维持各分支页面状态；
/// - `/photo/:id` 为独立详情页（位于 Shell 之外，因此无底部导航栏）。
///
/// 各页面内部通过 Riverpod `ref.watch` 自行取数，故路由构建本身无需 [ref]。
GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/grid',
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) =>
            AppScaffold(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          // 分支 0：相册（/grid）——App 开屏默认页。
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/grid',
                builder: (BuildContext context, GoRouterState state) =>
                    const PhotoGridPage(),
              ),
            ],
          ),
          // 分支 1：分类（/category）。
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/category',
                builder: (BuildContext context, GoRouterState state) =>
                    const CategoryPage(),
              ),
            ],
          ),
          // 分支 2：导入（/import）。
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/import',
                builder: (BuildContext context, GoRouterState state) =>
                    const ImportPage(),
              ),
            ],
          ),
          // 分支 3：我的（/me）。
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/me',
                builder: (BuildContext context, GoRouterState state) =>
                    const MePage(),
              ),
            ],
          ),
        ],
      ),
      // 全局搜索（R9）：独立页，无底部导航栏；经相册页 AppBar 搜索图标进入。
      GoRoute(
        path: '/search',
        builder: (BuildContext context, GoRouterState state) =>
            const SearchPage(),
      ),
      GoRoute(
        path: '/photo/:id',
        builder: (BuildContext context, GoRouterState state) {
          final String idStr = state.pathParameters['id'] ?? '';
          final int id = int.tryParse(idStr) ?? 0;
          // 从 extra 读取同一筛选上下文的照片 id 列表与当前下标，
          // 用于详情页左右滑动切换；缺省则退化为单张模式。
          final Object? extra = state.extra;
          List<int>? ids;
          int? index;
          if (extra is Map<String, dynamic>) {
            if (extra['ids'] is List) {
              ids = List<int>.from(extra['ids'] as List);
            }
            if (extra['index'] is int) {
              index = extra['index'] as int;
            }
          }
          return PhotoDetailPage(
            photoId: id,
            photoIds: ids,
            initialIndex: index,
          );
        },
      ),
    ],
  );
}

/// 全局路由 Provider。
///
/// 供 [RouterApp] 读取；后续若需在路由中注入依赖，可改为
/// `Provider<GoRouter>((ref) => buildRouter(ref))` 并由页面经 [ref] 取数。
final appRouterProvider = Provider<GoRouter>((ref) => buildRouter());

/// 路由承载根组件：以 [appRouterProvider] 驱动 [MaterialApp.router]。
///
/// B6：授权后由 [PermissionGate] 经 [Navigator.pushReplacement] 进入本组件，
/// 从而在不破坏 B4 权限闸门的前提下切换到正式 go_router 路由体系。
class RouterApp extends ConsumerWidget {
  const RouterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(appRouterProvider);
    final AppSettings settings = ref.watch(settingsProvider);
    // 主题颜色（设置页点选种子色）：与权限壳的 App 保持同一来源。
    final Color seed = themeSeedFromHex(settings.themeSeedHex);
    return MaterialApp.router(
      title: 'Photo Manager',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(seed),
      darkTheme: buildDarkTheme(seed),
      themeMode: ref.watch(themeModeProvider),
      // R12：本地化（与 App 权限壳的 MaterialApp 保持同一套配置）。
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: localeFromMode(settings.localeMode),
      routerConfig: router,
    );
  }
}
