import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_photos/features/classify/category_style.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseColorHex', () {
    test('带 # 前缀解析为对应色', () {
      expect(parseColorHex('#2E7D32'), const Color(0xFF2E7D32));
    });

    test('无 # 前缀也可解析', () {
      expect(parseColorHex('2E7D32'), const Color(0xFF2E7D32));
    });

    test('非法输入回退灰色', () {
      expect(parseColorHex('not-a-color'), Colors.grey);
    });
  });

  group('categoryIconOf', () {
    test('null 回退文件夹图标', () {
      expect(categoryIconOf(null), Icons.folder);
    });

    test('未知名称回退文件夹图标', () {
      expect(categoryIconOf('unknown_name'), Icons.folder);
    });
  });
}
