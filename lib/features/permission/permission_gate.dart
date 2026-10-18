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

  /// 检查当前授权状态（冷启动 / 从系统设置返回时调用）。
  Future<void> _evaluate() async {
    _apply(await _resolveStatus(request: false));
  }

  /// 请求授权（点击「去授权」时调用）。
  Future<void> _request() async {
    _apply(await _resolveStatus(request: true));
  }

  /// 统一的相册可用状态判定（评估与请求共用，避免两处逻辑再次分叉）。
  ///
  /// - [request] 为 true 时发起授权请求，否则仅查询当前状态；
  /// - 优先 [Permission.photos]；未授权时回退 [Permission.storage]。
  ///
  /// 回退必要性：Android <13 上 [Permission.photos] 映射的
  /// READ_MEDIA_IMAGES 不被系统识别，permission_handler 查到空权限列表
  /// 会恒返回 denied；此时真正的相册权限是 READ_EXTERNAL_STORAGE
  /// （即 [Permission.storage]）。若评估阶段不做同样的回退，就会出现
  /// 「已授权却每次冷启动都停在权限页」的问题。
  Future<PermissionStatus> _resolveStatus({required bool request}) async {
    final Permission photos = _targetPermission();
    PermissionStatus status =
        request ? await photos.request() : await photos.status;
    if (!status.isGranted) {
      status = request
          ? await Permission.storage.request()
          : await Permission.storage.status;
    }
    return status;
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
