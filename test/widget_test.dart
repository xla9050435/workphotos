// 应用主题构建的冒烟测试（替换原 Flutter 计数器模板）。
//
// 验证 buildAppTheme 能基于同一品牌种子生成亮 / 暗两套符合 M3 的双主题，
// 这是 R2 暗色主题与 R1 语义色治理的基础。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_photos/core/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('buildAppTheme 生成亮/暗双主题', () {
    final ThemeData light = buildLightTheme();
    final ThemeData dark = buildDarkTheme();

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    // 同一品牌种子 → 主色一致，仅亮度不同。
    expect(light.colorScheme.primary, dark.colorScheme.primary);
    expect(light.useMaterial3, isTrue);
  });
}
