/// 媒体时长格式化工具（视频支持）。
library;

/// 毫秒时长 → 「m:ss」或 「h:mm:ss」（超过 1 小时）。
///
/// 非正数（0 / 负 / null 语义由调用方保证传正数）返回 null。
String? formatDurationMs(int? ms) {
  if (ms == null || ms <= 0) return null;
  final int totalSec = (ms / 1000).round();
  final int h = totalSec ~/ 3600;
  final int m = (totalSec % 3600) ~/ 60;
  final int s = totalSec % 60;
  final String ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}

/// [Duration] → 「m:ss」/「h:mm:ss」（薄封装）。
String? formatDuration(Duration? d) =>
    d == null ? null : formatDurationMs(d.inMilliseconds);
