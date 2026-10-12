import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:work_photos/core/app_theme.dart';
import 'package:work_photos/core/theme_mode_controller.dart';
import 'package:work_photos/features/me/settings_provider.dart';
import 'package:work_photos/features/permission/permission_gate.dart';
import 'package:work_photos/l10n/generated/app_localizations.dart';
/// 应用根组件（B2 引入）。
///
/// 以 [PermissionGate] 作为首页：运行时申请相册权限，
/// 授权后再由 [PermissionGate] 切换到 go_router 正式路由体系（[RouterApp]）。
/// 主题与正式路由根共用同一套 [buildAppTheme] 双主题（亮/暗），由
/// [themeModeProvider] 驱动 themeMode；本地化（R12）与语言切换由
/// [settingsProvider].localeMode 驱动，两处 MaterialApp 配置保持一致。
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode mode = ref.watch(themeModeProvider);
    final AppSettings settings = ref.watch(settingsProvider);
    // 主题颜色（设置页点选种子色）：亮/暗两套色板均由同一种子生成。
    final Color seed = themeSeedFromHex(settings.themeSeedHex);
    return MaterialApp(
      title: 'Photo Manager',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(seed),
      darkTheme: buildDarkTheme(seed),
      themeMode: mode,
      // R12：本地化委托（含 Material/Cupertino 全局代理）+ 支持语言 + 用户语言。
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: localeFromMode(settings.localeMode),
      home: const PermissionGate(),
    );
  }
}
