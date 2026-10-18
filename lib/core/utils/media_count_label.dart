/// 媒体分组计数文案工具（统一各页「日期头」右侧的计数口径）。
///
/// 相册页与导入页共用同一函数，保证「同一构成 → 同一文案」，避免出现
/// 「1 个视频被显示成 1 张」这类口径不一致。无外部依赖。
library;

/// 按图片 / 视频构成生成分组计数文案。
///
/// - 全部为图片：`N 张`（沿用旧口径）；
/// - 全部为视频：`N 个视频`；
/// - 图片 / 视频混合：`N 项`（N = 图片数 + 视频数）。
///
/// 传入负值按 0 处理；两者均为 0 时返回 `0张`（正常分组非空，仅为兜底）。
String mediaCountLabel({required int imageCount, required int videoCount}) {
  final int images = imageCount < 0 ? 0 : imageCount;
  final int videos = videoCount < 0 ? 0 : videoCount;
  final int total = images + videos;
  if (videos == 0) return '$total张';
  if (images == 0) return '$videos个视频';
  return '$total项';
}
