import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_photos/core/utils/color_contrast.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('contrastColorOn', () {
    test('亮背景返回黑', () {
      expect(
        contrastColorOn(const Color(0xFFFFFFFF)),
        const Color(0xFF000000),
      );
    });

    test('暗背景返回白', () {
      expect(
        contrastColorOn(const Color(0xFF000000)),
        const Color(0xFFFFFFFF),
      );
    });

    test('中亮背景（灰）按阈值返回白', () {
      // Colors.grey 相对亮度约 0.35 < 0.5 → 返回白。
      expect(
        contrastColorOn(const Color(0xFF9E9E9E)),
        const Color(0xFFFFFFFF),
      );
    });

    test('品牌绿（暗）返回白', () {
      expect(
        contrastColorOn(const Color(0xFF2E7D32)),
        const Color(0xFFFFFFFF),
      );
    });
  });
}
