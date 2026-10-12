import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:work_photos/core/theme_mode_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('默认跟随系统', () {
    final ThemeModeNotifier notifier = ThemeModeNotifier();
    expect(notifier.state, ThemeMode.system);
  });

  test('setMode 更新状态并持久化', () async {
    final ThemeModeNotifier notifier = ThemeModeNotifier();
    await notifier.setMode(ThemeMode.dark);
    expect(notifier.state, ThemeMode.dark);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'dark');
  });

  test('setMode(light) 持久化 light', () async {
    final ThemeModeNotifier notifier = ThemeModeNotifier();
    await notifier.setMode(ThemeMode.light);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'light');
  });
}
