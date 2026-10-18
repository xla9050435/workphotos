import 'package:flutter/services.dart';

/// 原生「应用信息 / 外部跳转」MethodChannel 封装。
///
/// 与 MainActivity 中 `work_photos/app` 通道通信：
/// - `getVersion` → Map{ 'version': String, 'build': int }（PackageManager 读取当前 APK 版本）
/// - `openUrl`（参数 {'url': String}）→ bool（是否成功拉起浏览器）
///
/// 为什么用 MethodChannel 读版本、而不用 package_info_plus / url_launcher：
/// 本仓库当前构建环境无法在改动后可靠执行 `flutter pub get`（沙箱内 Dart 工具受限），
/// 新增任何 pub 依赖都可能出现「依赖未解析 → 构建失败」。而 versionName/versionCode
/// 是 PackageManager 就有的原生信息、打开链接是系统 Intent，都是**纯原生能力**，
/// 用 MethodChannel 零新依赖即可拿到，最稳、对构建零风险。
class AppNative {
  AppNative._();

  /// 原生通道名，须与 MainActivity 的 `APP_CHANNEL` 常量一致。
  static const MethodChannel _channel = MethodChannel('work_photos/app');

  /// 读取当前应用版本（versionName + build 号）。
  ///
  /// 通道不可用（如测试环境 / 非 Android 平台）时降级为 ('0.0.0', 0)，不抛异常。
  static Future<({String version, int build})> getVersion() async {
    try {
      final Map<String, dynamic>? map =
          await _channel.invokeMapMethod<String, dynamic>('getVersion');
      final String version = (map?['version'] as String?) ?? '0.0.0';
      final int build = (map?['build'] as num?)?.toInt() ?? 0;
      return (version: version, build: build);
    } on PlatformException {
      return (version: '0.0.0', build: 0);
    } on MissingPluginException {
      return (version: '0.0.0', build: 0);
    }
  }

  /// 用系统浏览器打开 [url]；返回是否成功拉起（异常一律降级为 false）。
  static Future<bool> openUrl(String url) async {
    if (url.isEmpty) return false;
    try {
      final bool? ok = await _channel.invokeMethod<bool>(
        'openUrl',
        <String, dynamic>{'url': url},
      );
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
