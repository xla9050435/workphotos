import 'package:flutter/material.dart';

/// 统一状态展示组件（R14）。
///
/// 集中实现「空 / 加载 / 错误 / 离线」四类常见界面状态，保证全应用视觉与
/// 交互一致，并内置无障碍支持：
/// - 文案使用主题文本样式，随系统字号缩放；
/// - 主操作按钮最小触控区 48dp；
/// - 关键状态由主题语义色驱动，暗色主题自动适配。
///
/// 用法示例：
/// ```dart
/// body: _error != null
///     ? AppErrorState(message: _error!, onRetry: _reload)
///     : _items.isEmpty
///         ? const AppEmptyState(title: '还没有照片')
///         : const AppLoadingState();
/// ```

/// 加载中状态：居中转圈，可选文案。
class AppLoadingState extends StatelessWidget {
  final String? message;

  const AppLoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          if (message != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(message!, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

/// 空状态：图标 + 标题 + 可选说明 + 可选操作按钮。
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const AppEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(title,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center),
            if (message != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                message!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...<Widget>[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 错误状态：错误图标 + 文案 + 可选「重试」按钮。
class AppErrorState extends StatelessWidget {
  final String message;
  final String? retryLabel;
  final VoidCallback? onRetry;

  const AppErrorState({
    super.key,
    required this.message,
    this.retryLabel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(message,
                style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryLabel ?? '重试'),
                // FilledButton 默认触控区满足 48dp 无障碍目标。
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 轻量离线 / 网络异常条幅，用于页面顶部非阻塞提示，不替代内容区。
class AppNetworkBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AppNetworkBanner({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: <Widget>[
            Icon(Icons.cloud_off, color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer)),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text('重试',
                    style:
                        TextStyle(color: theme.colorScheme.onErrorContainer)),
              ),
          ],
        ),
      ),
    );
  }
}
