import 'dart:convert';
import 'dart:io';

import 'package:work_photos/services/app_native.dart';

/// GitHub「latest release」接口（仓库需为公开；未登录限流 60 次/小时，够用）。
const String _kLatestReleaseUrl =
    'https://api.github.com/repos/xla9050435/workphotos/releases/latest';

/// 检查更新得到的新版本信息。
class UpdateInfo {
  /// 最新语义版本名（三段，如 '1.3.2'）。对话框标题用它。
  final String latestVersion;

  /// 最新 build 号（tag 的 `+N`；缺失时回退为本地 build 号）。
  final int latestBuild;

  /// Release 正文（更新说明），可能为空串。
  final String notes;

  /// APK 资产的下载直链；该 release 无 apk 资产时为空串。
  final String downloadUrl;

  /// Release 页面地址（无 apk 资产时可退回打开它）。
  final String htmlUrl;

  const UpdateInfo({
    required this.latestVersion,
    required this.latestBuild,
    required this.notes,
    required this.downloadUrl,
    required this.htmlUrl,
  });

  @override
  String toString() =>
      'UpdateInfo(version: $latestVersion, build: $latestBuild)';
}

/// 检查是否有更新。
///
/// 返回 null 表示已是最新；抛异常表示检查失败（网络 / HTTP 非 200 / JSON 解析）。
/// 呈现方式由调用方决定：启动检查静默吞异常，手动检查提示「检查失败」。
Future<UpdateInfo?> checkForUpdate() async {
  final ({String version, int build}) local = await AppNative.getVersion();
  // 本地版本：versionName 三段 + PackageManager 给的 build 号。
  final _Ver localVer = _withBuild(_parse(local.version), local.build);

  final Map<String, dynamic> json = await _fetchLatestRelease();
  final String tag = (json['tag_name'] as String?) ?? '';
  final String body = (json['body'] as String?) ?? '';
  final String htmlUrl = (json['html_url'] as String?) ?? '';
  final List<dynamic> assets =
      (json['assets'] as List<dynamic>?) ?? const <dynamic>[];

  // 从 assets 里找第一个 .apk（大小写不敏感），取其下载直链。
  String downloadUrl = '';
  for (final dynamic a in assets) {
    if (a is Map<String, dynamic>) {
      final String name = (a['name'] as String?) ?? '';
      if (name.toLowerCase().endsWith('.apk')) {
        downloadUrl = (a['browser_download_url'] as String?) ?? '';
        if (downloadUrl.isNotEmpty) break;
      }
    }
  }

  final _Ver remote = _parse(tag);
  if (!_remoteIsNewer(localVer, remote)) return null;

  return UpdateInfo(
    latestVersion: '${remote.major}.${remote.minor}.${remote.patch}',
    latestBuild: remote.build ?? local.build,
    notes: body,
    downloadUrl: downloadUrl,
    htmlUrl: htmlUrl,
  );
}

// —— 版本解析与比较 ——

/// 解析后的三段语义版本 + 可选 build 号（内部用）。
class _Ver {
  final int major;
  final int minor;
  final int patch;
  final int? build; // tag 的 `+N`；本地版本由 PackageManager 提供
  const _Ver(this.major, this.minor, this.patch, this.build);
}

/// 解析 tag / versionName：兼容 `v1.3.1+21`、`1.3.1+21`、`v1.3.1`、`1.3.1`。
///
/// 三段版本取前三个数字段（非数字字符忽略，如 `-beta`）；`+N` 解析为 build
/// （缺失为 null）。解析容错、绝不抛异常（脏 tag 也只会得到 0.0.0）。
_Ver _parse(String raw) {
  String s = raw.trim();
  if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
  int? build;
  final int plus = s.indexOf('+');
  if (plus >= 0) {
    build = int.tryParse(s.substring(plus + 1).trim());
    s = s.substring(0, plus);
  }
  final List<String> parts = s.split('.');
  int at(int i) {
    if (i >= parts.length) return 0;
    final String digits = parts[i].replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  return _Ver(at(0), at(1), at(2), build);
}

_Ver _withBuild(_Ver v, int build) => _Ver(v.major, v.minor, v.patch, build);

/// 远端是否比本地新。
///
/// **build 号优先**：发版常出现 versionName 不变、仅 build 递增（如 1.3.1+20 →
/// 1.3.1+21）。若只比语义版本三段，会永远判定「已最新」而漏掉这类更新——这是
/// build 号优先的根本原因。规则：双方 build 都存在且不同 → 由 build 决定；
/// 否则（build 相同或任一方缺失）退回语义版本三段比较。
bool _remoteIsNewer(_Ver local, _Ver remote) {
  if (remote.build != null && local.build != null) {
    if (remote.build! != local.build!) return remote.build! > local.build!;
    // build 相同 → 继续比语义版本（稳健兜底）。
  }
  if (remote.major != local.major) return remote.major > local.major;
  if (remote.minor != local.minor) return remote.minor > local.minor;
  return remote.patch > local.patch;
}

// —— 网络 ——

/// 拉取 latest release JSON。
///
/// 8 秒连接/读取超时；非 200 抛异常（403 多为未登录限流、404 为仓库/Release
/// 不存在）。抛出的任何异常由 [checkForUpdate] 的调用方处理，不让 App 崩。
Future<Map<String, dynamic>> _fetchLatestRelease() async {
  final HttpClient client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8);
  try {
    final HttpClientRequest req =
        await client.getUrl(Uri.parse(_kLatestReleaseUrl));
    req.headers.set(HttpHeaders.userAgentHeader, 'work_photos-updater');
    req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    final HttpClientResponse resp =
        await req.close().timeout(const Duration(seconds: 8));
    final String body = await resp
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) {
      throw HttpException(
        'GitHub API 返回 ${resp.statusCode}',
        uri: Uri.parse(_kLatestReleaseUrl),
      );
    }
    final dynamic decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('GitHub 响应不是 JSON 对象');
  } finally {
    client.close(force: true);
  }
}
