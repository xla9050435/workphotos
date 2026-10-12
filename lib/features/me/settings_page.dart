import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:work_photos/core/app_theme.dart';
import 'package:work_photos/core/theme_mode_controller.dart';
import 'package:work_photos/core/utils/color_contrast.dart';
import 'package:work_photos/features/classify/category_style.dart';
import 'package:work_photos/features/me/settings_provider.dart';
import 'package:work_photos/features/onboarding/gesture_coach.dart';

/// 设置页。
///
/// 提供可持久化的应用设置：相册按天分组显示日期、已用照片边框颜色等。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: <Widget>[
          SwitchListTile(
            title: const Text('相册按天分组显示日期'),
            subtitle: const Text('开启后，相册页会按拍摄/导入日期分组并显示日期头'),
            value: settings.groupByDay,
            onChanged: (bool v) =>
                ref.read(settingsProvider.notifier).setGroupByDay(v),
          ),
          const Divider(),
          // 外观 / 主题模式：跟随系统 / 浅色 / 深色（M3 SegmentedButton）。
          // 写入 [themeModeProvider] 后由 App / RouterApp 的 themeMode 驱动双主题。
          ListTile(
            title: const Text('外观'),
            subtitle: const Text('选择浅色、深色或跟随系统'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<ThemeMode>(
              selected: <ThemeMode>{ref.watch(themeModeProvider)},
              onSelectionChanged: (Set<ThemeMode> sel) =>
                  ref.read(themeModeProvider.notifier).setMode(sel.first),
              segments: const <ButtonSegment<ThemeMode>>[
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('跟随系统'),
                  icon: Icon(Icons.brightness_auto),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('浅色'),
                  icon: Icon(Icons.brightness_5),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('深色'),
                  icon: Icon(Icons.brightness_4),
                ),
              ],
            ),
          ),
          // 主题颜色（M3 种子色）：点选即全局换肤（亮/暗两套同步生成）。
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('主题颜色',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: kThemeSeedOptions.map(((String, String) option) {
                final String hex = option.$1;
                final bool selected =
                    settings.themeSeedHex.toLowerCase() == hex.toLowerCase();
                // M3 触控目标：视觉 36dp 圆点 + 48x48dp 点击区（透明补边）。
                return SizedBox(
                  width: 48,
                  height: 48,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => ref
                        .read(settingsProvider.notifier)
                        .setThemeSeedHex(hex),
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: parseColorHex(hex),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: selected
                            ? Icon(Icons.check,
                                color: contrastColorOn(parseColorHex(hex)),
                                size: 20)
                            : null,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // 网格列数（R3）：相册/导入页双指捏合调节，跨会话保留；此处一键重置。
          ListTile(
            title: const Text('网格列数'),
            subtitle:
                Text('当前 ${settings.gridColumns} 列 · 在相册/导入页双指捏合调节'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: OutlinedButton(
              onPressed: settings.gridColumns == kDefaultGridColumns
                  ? null
                  : () => ref
                      .read(settingsProvider.notifier)
                      .setGridColumns(kDefaultGridColumns),
              child: const Text('重置为默认 3 列'),
            ),
          ),
          // 界面语言（R12）：跟随系统 / 中文 / English。
          ListTile(
            title: const Text('语言'),
            subtitle: const Text('选择界面显示语言（跟随系统 / 中文 / English）'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SegmentedButton<String>(
              selected: <String>{settings.localeMode},
              onSelectionChanged: (Set<String> sel) => ref
                  .read(settingsProvider.notifier)
                  .setLocaleMode(sel.first),
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(
                  value: kLocaleModeSystem,
                  label: Text('跟随系统'),
                ),
                ButtonSegment<String>(
                  value: kLocaleModeZh,
                  label: Text('中文'),
                ),
                ButtonSegment<String>(
                  value: kLocaleModeEn,
                  label: Text('English'),
                ),
              ],
            ),
          ),
          // 手势引导（R13）：首次进入相册页自动弹出，此处可重看。
          ListTile(
            leading: const Icon(Icons.touch_app_outlined),
            title: const Text('手势引导'),
            subtitle: const Text('重看长按多选、拖动连选与捏合调列的教学'),
            onTap: () => GestureCoach.showGestureCoach(context),
          ),
          // 已用照片边框颜色：Google 推荐色板点选（未用照片始终无边框）。
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('已用照片边框颜色',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text('相册网格中「已用」照片的彩色边框；「未用」照片无边框',
                style: Theme.of(context).textTheme.bodySmall),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: googlePresetColorHexes.map((String hex) {
                final bool selected =
                    settings.usedBorderHex.toLowerCase() == hex.toLowerCase();
                // M3 触控目标：视觉 36dp 圆点 + 48x48dp 点击区（透明补边）。
                return SizedBox(
                  width: 48,
                  height: 48,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => ref
                        .read(settingsProvider.notifier)
                        .setUsedBorderHex(hex),
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: parseColorHex(hex),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: selected
                            ? Icon(Icons.check,
                                color: contrastColorOn(parseColorHex(hex)),
                                size: 20)
                            : null,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('显示"部分照片访问"提示横幅'),
            subtitle: const Text('关闭后导入页不再显示该横幅；注意：未授权的照片仍不会显示'),
            value: settings.showLimitedBanner,
            onChanged: (bool v) =>
                ref.read(settingsProvider.notifier).setShowLimitedBanner(v),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于'),
            subtitle: const Text('work_photos · 引用式照片管理 · v1.2.1'),
          ),
        ],
      ),
    );
  }
}
