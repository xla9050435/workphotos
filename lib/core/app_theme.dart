import 'package:flutter/material.dart';

/// 应用统一主题（Material 3，遵循 Google M3 设计指南）。
///
/// 颜色策略（M3 Color Roles）：
/// - 以用户可选的种子色（默认品牌绿 `#2E7D32`）经 [ColorScheme.fromSeed]
///   生成完整色调调色板（官方推荐做法：从种子生成，不手工逐个挑色）；
/// - 组件一律引用 [ColorScheme] 语义角色（primary / surface /
///   surfaceContainerHighest / outlineVariant / onSurfaceVariant 等），
///   不在组件内硬编码 hex；
/// - 大面积背景使用 surface 系角色（不用 primary 当背景）；
/// - 前景元素使用与背景匹配的 on 色（对比度由色调系统保证）。
///
/// 暗色主题：通过 [brightness] 直接驱动 [ColorScheme.fromSeed] 生成对应
/// 亮/暗色板——同一套语义角色在两种亮度下都保持合规对比度，无需手写两套色值。
/// 配合 [ThemeModeNotifier] 在 MaterialApp 上同时设置 theme / darkTheme /
/// themeMode 即可（见 [App] / [RouterApp]）。
///
/// 主题色（R2 增强）：种子色持久化于 settings（`theme_seed_hex`），
/// 设置页「主题颜色」点选，亮/暗两套色板都由同一种子生成。
ThemeData buildAppTheme([
  Brightness brightness = Brightness.light,
  Color? seedColor,
]) {
  final Color seed = seedColor ?? const Color(0xFF2E7D32); // 品牌绿（默认）
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    // 内容区底 = surface（M3：页面底用 surface 系，与导航/栏位形成层次）。
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0.5,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    ),
  );
}

/// 浅色主题（MaterialApp.theme）。
ThemeData buildLightTheme([Color? seedColor]) =>
    buildAppTheme(Brightness.light, seedColor);

/// 暗色主题（MaterialApp.darkTheme）。
ThemeData buildDarkTheme([Color? seedColor]) =>
    buildAppTheme(Brightness.dark, seedColor);

/// 主题颜色预设（设置页点选，M3 经典基准色）：
/// (hex, 名称)。默认项「品牌绿」与历史主题保持延续。
const List<(String, String)> kThemeSeedOptions = <(String, String)>[
  ('#2E7D32', '品牌绿'),
  ('#1565C0', '海洋蓝'),
  ('#283593', '靛蓝'),
  ('#6A1B9A', '典雅紫'),
  ('#AD1457', '玫红'),
  ('#C62828', '绯红'),
  ('#E65100', '暖橙'),
  ('#00838F', '湖水青'),
  ('#37474F', '石墨灰'),
];

/// 从设置中的 hex 解析种子色；非法值回退品牌绿。
Color themeSeedFromHex(String hex) {
  try {
    final String h = hex.replaceAll('#', '');
    return Color(int.parse('0xFF$h'));
  } catch (_) {
    return const Color(0xFF2E7D32);
  }
}
