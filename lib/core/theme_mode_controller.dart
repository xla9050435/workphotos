import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题模式（亮 / 暗 / 跟随系统）的持久化状态管理。
///
/// 配合 [buildAppTheme] 的双主题（ColorScheme.fromSeed 按 brightness 生成
/// light/dark 两套），在 MaterialApp 上同时设置 theme / darkTheme / themeMode
/// 即可获得系统级暗色体验，无需为暗色手写一套色板。
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  static const String _kThemeMode = 'theme_mode';

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_kThemeMode);
    if (raw == null || !mounted) return;
    state = switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_kThemeMode, value);
  }
}

/// 全局主题模式 Provider（设置页写入、App/RouterApp 读取驱动 themeMode）。
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);
