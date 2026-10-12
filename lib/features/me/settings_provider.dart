import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局应用设置（持久化）。
///
/// 当前设置项：
/// - [groupByDay]：相册页是否按天分组显示日期（默认开启）。
/// - [usedBorderHex]：已用照片在相册网格中的彩色边框颜色（hex 字符串，
///   默认绿色 #2E7D32；在设置页从 Google 推荐色板中点选）。
/// - [showLimitedBanner]：导入页是否显示"部分照片访问"权限提示横幅
///   （默认开启；关闭后不再打扰，但未授权照片仍不会显示）。
/// - [gridColumns]：相册 / 导入页网格列数（捏合调节，跨会话保留）。
/// - [localeMode]：界面语言（R12）：'system' 跟随系统 / 'zh' 中文 /
///   'en' English（经 [localeFromMode] 映射为 MaterialApp.locale）。
///
/// 持久化使用 [SharedPreferences]；初始化时以默认值先行渲染，
/// 异步回读后按需更新，保证首帧不阻塞。
/// 网格列数默认值 / 捏合调节上下限（R3 列数持久化 / R10 连续缩放）。
const int kDefaultGridColumns = 3;
const int kMinGridColumns = 2;
const int kMaxGridColumns = 6;

/// 界面语言模式取值。
const String kLocaleModeSystem = 'system';
const String kLocaleModeZh = 'zh';
const String kLocaleModeEn = 'en';

/// [AppSettings.localeMode] → [Locale]（null = 跟随系统，交给框架解析）。
Locale? localeFromMode(String mode) {
  switch (mode) {
    case kLocaleModeZh:
      return const Locale('zh');
    case kLocaleModeEn:
      return const Locale('en');
    default:
      return null;
  }
}

class AppSettings {
  final bool groupByDay;
  final String usedBorderHex;
  final bool showLimitedBanner;

  /// 相册 / 导入页网格列数（双指捏合调节，跨会话保留；R3）。
  final int gridColumns;

  /// 界面语言模式（R12）：'system' / 'zh' / 'en'。
  final String localeMode;

  /// 主题种子色（hex，如 '#2E7D32'）：亮/暗色板均由它经
  /// ColorScheme.fromSeed 生成；设置页「主题颜色」点选。
  final String themeSeedHex;

  const AppSettings({
    this.groupByDay = true,
    this.usedBorderHex = '#2E7D32',
    this.showLimitedBanner = true,
    this.gridColumns = kDefaultGridColumns,
    this.localeMode = kLocaleModeSystem,
    this.themeSeedHex = '#2E7D32',
  });

  AppSettings copyWith({
    bool? groupByDay,
    String? usedBorderHex,
    bool? showLimitedBanner,
    int? gridColumns,
    String? localeMode,
    String? themeSeedHex,
  }) =>
      AppSettings(
        groupByDay: groupByDay ?? this.groupByDay,
        usedBorderHex: usedBorderHex ?? this.usedBorderHex,
        showLimitedBanner: showLimitedBanner ?? this.showLimitedBanner,
        gridColumns: gridColumns ?? this.gridColumns,
        localeMode: localeMode ?? this.localeMode,
        themeSeedHex: themeSeedHex ?? this.themeSeedHex,
      );
}

/// 设置状态管理：读/写 [SharedPreferences] 并维护 [AppSettings]。
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  static const String _kGroupByDay = 'album_group_by_day';
  static const String _kUsedBorderHex = 'used_border_hex';
  static const String _kShowLimitedBanner = 'show_limited_banner';
  static const String _kGridColumns = 'grid_columns';
  static const String _kLocaleMode = 'locale_mode';
  static const String _kThemeSeedHex = 'theme_seed_hex';

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool? v = prefs.getBool(_kGroupByDay);
    if (v != null && mounted) state = state.copyWith(groupByDay: v);
    final String? hex = prefs.getString(_kUsedBorderHex);
    if (hex != null && hex.isNotEmpty && mounted) {
      state = state.copyWith(usedBorderHex: hex);
    }
    final bool? banner = prefs.getBool(_kShowLimitedBanner);
    if (banner != null && mounted) {
      state = state.copyWith(showLimitedBanner: banner);
    }
    final int? cols = prefs.getInt(_kGridColumns);
    if (cols != null && mounted) {
      state = state.copyWith(
        gridColumns: cols.clamp(kMinGridColumns, kMaxGridColumns).toInt(),
      );
    }
    final String? locale = prefs.getString(_kLocaleMode);
    if (locale != null && mounted) {
      // 脏值兜底：非法存储值回退跟随系统。
      const List<String> valid = <String>[
        kLocaleModeSystem,
        kLocaleModeZh,
        kLocaleModeEn,
      ];
      if (valid.contains(locale)) {
        state = state.copyWith(localeMode: locale);
      }
    }
    final String? seed = prefs.getString(_kThemeSeedHex);
    if (seed != null && seed.isNotEmpty && mounted) {
      state = state.copyWith(themeSeedHex: seed);
    }
  }

  Future<void> setGroupByDay(bool value) async {
    state = state.copyWith(groupByDay: value);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kGroupByDay, value);
  }

  /// 设置已用照片边框颜色（hex 字符串，如 '#2E7D32'）。
  Future<void> setUsedBorderHex(String hex) async {
    state = state.copyWith(usedBorderHex: hex);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUsedBorderHex, hex);
  }

  /// 是否在导入页显示"部分照片访问"横幅。
  Future<void> setShowLimitedBanner(bool value) async {
    state = state.copyWith(showLimitedBanner: value);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowLimitedBanner, value);
  }

  /// 设置网格列数（双指捏合收敛后 / 设置页重置时调用，R3）。
  Future<void> setGridColumns(int value) async {
    state = state.copyWith(
      gridColumns: value.clamp(kMinGridColumns, kMaxGridColumns).toInt(),
    );
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kGridColumns, state.gridColumns);
  }

  /// 设置界面语言（R12：'system' / 'zh' / 'en'）。
  Future<void> setLocaleMode(String mode) async {
    state = state.copyWith(localeMode: mode);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleMode, mode);
  }

  /// 设置主题种子色（hex，如 '#2E7D32'；设置页「主题颜色」点选）。
  Future<void> setThemeSeedHex(String hex) async {
    state = state.copyWith(themeSeedHex: hex);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeSeedHex, hex);
  }
}

/// 全局设置 Provider。
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) => SettingsNotifier());
