import 'package:flutter/material.dart';

/// 统一的"已用 / 未用"角标组件（网格项与详情页复用）。
///
/// 配色与全局「绿 = 已用」约定保持一致：已用使用主题绿
/// [Color(0xFF2E7D32)]（与网格已用边框、底部导航选中色一致），未用使用红色，
/// 形成清晰对比。
class StatusBadge extends StatelessWidget {
  final bool isUsed;
  final VoidCallback? onTap;

  const StatusBadge({super.key, required this.isUsed, this.onTap});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color background = isUsed ? scheme.primary : scheme.error;
    final String label = isUsed ? '已用' : '未用';
    final Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [BoxShadow(color: scheme.shadow, blurRadius: 2)],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: scheme.onPrimary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    if (onTap == null) return badge;
    return GestureDetector(onTap: onTap, child: badge);
  }
}
