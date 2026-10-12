import 'package:flutter/material.dart';

/// 分类预设样式资源：颜色色板 + 图标库。
///
/// 设计意图：让用户免手填十六进制颜色代码 / 图标名，改为从预设里点选。
///
/// - 颜色取自 Google Material Design 经典 500 色阶，存储为 hex 字符串
///   （与既有 categories 表的 `colorHex` 列格式一致，无需改表）。
/// - 图标为常用 Material Icons，以「名称 -> IconData」映射；`iconName`
///   作为稳定字符串持久化在 categories 表的 `iconName` 列，运行时再映射回图标。
///   详见 category_form / category_page 的使用，及对话中"图标名用途"的讲解。

/// Google Material 500 色阶（部分取舍，覆盖常用语义色）。
const List<String> googlePresetColorHexes = <String>[
  '#F44336', // Red
  '#E91E63', // Pink
  '#9C27B0', // Purple
  '#673AB7', // Deep Purple
  '#3F51B5', // Indigo
  '#2196F3', // Blue
  '#03A9F4', // Light Blue
  '#00BCD4', // Cyan
  '#009688', // Teal
  '#4CAF50', // Green
  '#8BC34A', // Light Green
  '#CDDC39', // Lime
  '#FFEB3B', // Yellow
  '#FFC107', // Amber
  '#FF9800', // Orange
  '#FF5722', // Deep Orange
  '#795548', // Brown
  '#9E9E9E', // Grey
  '#607D8B', // Blue Grey
  '#000000', // Black
];

/// 预设图标库：稳定名称 -> Material 图标（精选 20 个常用图标）。
///
/// 注意：若某分类的 iconName 不在此映射中（如历史数据使用了已移除的图标名），
/// [categoryIconOf] 会回退到 folder，不会报错。
const Map<String, IconData> presetCategoryIcons = <String, IconData>{
  'folder': Icons.folder,
  'star': Icons.star,
  'favorite': Icons.favorite,
  'bookmark': Icons.bookmark,
  'label': Icons.label,
  'photo': Icons.photo,
  'camera_alt': Icons.camera_alt,
  'movie': Icons.movie,
  'music_note': Icons.music_note,
  'palette': Icons.palette,
  'school': Icons.school,
  'work': Icons.work,
  'shopping_cart': Icons.shopping_cart,
  'restaurant': Icons.restaurant,
  'home': Icons.home,
  'place': Icons.place,
  'directions_car': Icons.directions_car,
  'fitness_center': Icons.fitness_center,
  'pets': Icons.pets,
  'cake': Icons.cake,
};

/// 按名称取图标；未知/空名称回退到 folder。
IconData categoryIconOf(String? name) {
  if (name == null) return Icons.folder;
  return presetCategoryIcons[name] ?? Icons.folder;
}

/// 解析 hex 颜色（兼容 '#' 前缀与非法输入回退灰色）。
Color parseColorHex(String hex) {
  try {
    final String h = hex.replaceAll('#', '');
    return Color(int.parse('0xFF$h'));
  } catch (_) {
    return Colors.grey;
  }
}
