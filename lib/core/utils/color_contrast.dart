import 'package:flutter/material.dart';

/// 返回在给定背景色上可读性最佳的对比前景色（黑或白）。
///
/// 用于动态用户色板（分类色）上的图标 / 勾选标记，
/// 保证在亮色与暗色主题下均清晰可辨，从而无需硬编码 white/black。
Color contrastColorOn(Color background) {
  // 相对亮度（sRGB），阈值 0.5 近似分割明暗。
  return background.computeLuminance() > 0.5
      ? const Color(0xFF000000)
      : const Color(0xFFFFFFFF);
}
