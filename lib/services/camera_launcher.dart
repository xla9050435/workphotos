import 'package:flutter/services.dart';

/// 系统相机快捷入口（MethodChannel 封装）。
///
/// 与原生 `MainActivity.kt` 中同名 Channel（`work_photos/camera`）通信：
/// - method：`capturePhoto`
/// - 返回值：`bool` —— `true` 表示拍摄成功且文件已写入相册；`false` 表示
///   用户取消 / 无可用相机 / 失败。
///
/// 为什么用系统相机而不是 App 内自建相机：系统相机成像与兼容性由 ROM 保证，
/// 且无需申请 CAMERA 权限；拍完由相机应用把文件写入我们给定的 Uri 并进入媒体库，
/// 与「引用式导入」（只读相册、不复制字节）的定位一致。
class CameraLauncher {
  CameraLauncher._();

  /// 原生通道名，须与 MainActivity 的 `CHANNEL` 常量一致。
  static const MethodChannel _channel = MethodChannel('work_photos/camera');

  /// 拉起系统相机拍照。
  ///
  /// 返回 `true` 表示已成功拍摄并写入相册；`false` 表示取消 / 失败（含无相机
  /// 应用、通道未注册等异常场景，均降级为 `false`，不向上抛异常）。
  static Future<bool> capturePhoto() async {
    try {
      final bool? ok = await _channel.invokeMethod<bool>('capturePhoto');
      return ok ?? false;
    } on PlatformException {
      // 原生侧以 error 形式回报（busy / io / no_camera 等）→ 视为未成功。
      return false;
    } on MissingPluginException {
      // 通道未注册（例如在非 Android 平台或旧包运行时）→ 安全降级。
      return false;
    }
  }
}
