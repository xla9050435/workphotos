import 'package:flutter/material.dart';

import 'package:work_photos/services/app_native.dart';
import 'package:work_photos/services/update_checker.dart';

/// 是否已执行过本次启动的自动检查更新（模块级：保证「一次启动只检查/弹窗一次」）。
bool _startupChecked = false;

/// 启动自动检查更新：首帧后延迟 3 秒，有新版弹窗；失败/已最新静默。
///
/// 为什么要延迟 + 静默：
/// - 延迟 3 秒：让冷启动首屏、权限页先渲染完成，检查不阻塞启动；
/// - 失败静默：启动阶段网络差是常态，弹「检查失败」会拖累启动体验，启动优先。
///
/// [navKey] 为 MaterialApp 的根 Navigator key：用它拿到根上下文弹对话框。
Future<void> runStartupUpdateCheck(GlobalKey<NavigatorState> navKey) async {
  if (_startupChecked) return;
  _startupChecked = true;
  await Future<void>.delayed(const Duration(seconds: 3));
  final BuildContext? ctx = navKey.currentContext;
  if (ctx == null || !ctx.mounted) return;
  try {
    final UpdateInfo? info = await checkForUpdate();
    if (info != null && ctx.mounted) {
      await showUpdateDialog(ctx, info);
    }
  } catch (_) {
    // 启动检查失败静默：不打扰用户（网络差时启动不弹错误）。
  }
}

/// 弹出「发现新版本」对话框；点「去更新」用系统浏览器打开下载页。
Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) async {
  final ColorScheme scheme = Theme.of(context).colorScheme;
  final bool? go = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext ctx) {
      return AlertDialog(
        title: Text('发现新版本 ${info.latestVersion}'),
        content: ConstrainedBox(
          // release notes 可长可短：限高 + 可滚动，避免撑破弹窗。
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '最新版本：${info.latestVersion}（build ${info.latestBuild}）',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Text(
                  info.notes.trim().isEmpty
                      ? '（本次更新暂无说明）'
                      : _truncate(info.notes.trim(), 1200),
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('去更新'),
          ),
        ],
      );
    },
  );
  if (go == true) {
    // 优先下载 APK 直链；没有 apk 资产时退回打开 release 页面。
    final String url =
        info.downloadUrl.isNotEmpty ? info.downloadUrl : info.htmlUrl;
    if (url.isNotEmpty) {
      await AppNative.openUrl(url);
    }
  }
}

/// 更新说明过长时截断（避免超长文本撑爆弹窗）。
String _truncate(String s, int max) =>
    s.length <= max ? s : '${s.substring(0, max)}…';
