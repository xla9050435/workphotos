import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:work_photos/routing/app_router.dart';

/// 运行时权限闸门（B2）。
///
/// 使用 [permission_handler] 申请相册权限：
/// - 优先 [Permission.photos]（Android 13+ 映射为 READ_MEDIA_IMAGES，
///   低版本映射为 READ_EXTERNAL_STORAGE）；
/// - 若仍未授权，回退请求 [Permission.storage]（覆盖 Android <13）；
/// - 被永久拒绝时引导用户到系统设置开启。
///
/// 授权成功后展示 go_router 正式路由体系（[RouterApp]）；
/// 未授权展示"需要相册权限"页。
class PermissionGate extends ConsumerStatefulWidget {
  const PermissionGate({super.key});

  @override
  ConsumerState<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends ConsumerState<PermissionGate> {
  bool _checking = true;
  bool _granted = false;

  @override
  void initState() {
    super.initState();
    _evaluate();
  }

  /// 检查当前授权状态。
  Future<void> _evaluate() async {
    final PermissionStatus status = await _targetPermission().status;
    _apply(status);
  }

  /// 请求授权（含旧版回退）。
  Future<void> _request() async {
    PermissionStatus status = await _targetPermission().request();
    // 回退：旧版 Android（<13）使用 storage 权限。
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    _apply(status);
  }

  void _apply(PermissionStatus status) {
    if (mounted) {
      setState(() {
        _granted = status.isGranted;
        _checking = false;
      });
    }
  }

  /// 优先请求 photos（详见类注释的版本映射说明）。
  Permission _targetPermission() => Permission.photos;

  Future<void> _openSettings() async {
    await openAppSettings();
    // 从设置返回后重新评估状态。
    await _evaluate();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    if (_granted) {
      // B6：授权后进入 go_router 正式路由体系（含底部导航四大页）。
      return const RouterApp();
    }
    return Scaffold(
      body: Center(
        child: _checking
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.photo_library,
                        size: 64, color: scheme.primary),
                    const SizedBox(height: 16),
                    const Text('需要相册权限',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                      '本应用仅以"引用"方式读取相册，不会复制或上传您的照片。'
                      '请授予相册访问权限以继续使用。',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _request,
                      icon: const Icon(Icons.lock_open),
                      label: const Text('去授权'),
                    ),
                    TextButton(
                      onPressed: _openSettings,
                      child: const Text('在系统设置中手动开启'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
