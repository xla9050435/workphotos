import 'dart:io';

import 'package:work_photos/core/utils/media_ref.dart';
import 'package:work_photos/data/models/media_type.dart';
import 'package:work_photos/data/models/used_status.dart';

/// 照片领域模型（与数据库行 [PhotoRow] 解耦，供 UI / 业务层使用）。
///
/// 视频支持后本模型同时承载图片与视频：[mediaType] 区分类型，
/// [durationMs] / [width] / [height] 携带视频元数据（图片也可有）。
class Photo {
  final int? id;
  final MediaRef mediaRef;
  final String? title;
  final UsedStatus usedStatus;
  final String? sourceAlbum;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 媒体类型（'image' | 'video'），历史数据默认图片。
  final MediaType mediaType;

  /// 视频时长（毫秒）；图片为 null。
  final int? durationMs;

  /// 媒体宽高（像素）；未知为 null。
  final int? width;
  final int? height;

  /// 拍摄时间（来源 `AssetEntity.createDateTime`）；老数据/未知为 null，
  /// 统一用 [displayTime] 取「展示用时间」。
  final DateTime? shotAt;

  const Photo({
    this.id,
    required this.mediaRef,
    this.title,
    required this.usedStatus,
    this.sourceAlbum,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.mediaType = MediaType.image,
    this.durationMs,
    this.width,
    this.height,
    this.shotAt,
  });

  /// 展示用时间：优先拍摄时间，缺失时回退到导入时间。
  ///
  /// 相册页排序 / 日期分组 / 日期筛选与详情页元信息都应取这个值，
  /// 与 SQL 侧 `COALESCE(shot_at, created_at)` 保持同一语义。
  DateTime get displayTime => shotAt ?? createdAt;

  /// 是否已被归类使用。
  bool get isUsed => usedStatus == UsedStatus.used;

  /// 是否为视频（UI 据此切换播放器 / 角标）。
  bool get isVideo => mediaType == MediaType.video;

  /// 时长「mm:ss」文本（视频专用；null 或非视频返回 null）。
  String? get durationLabel {
    if (!isVideo) return null;
    final int? ms = durationMs;
    if (ms == null || ms <= 0) return null;
    final int totalSec = (ms / 1000).round();
    final int m = totalSec ~/ 60;
    final int s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// 解析为本地文件（委托给 [MediaRef.resolveFile]）。
  Future<File?> resolveFile() => mediaRef.resolveFile();

  @override
  String toString() {
    return 'Photo(id: $id, title: $title, usedStatus: $usedStatus, '
        'mediaType: $mediaType, sourceAlbum: $sourceAlbum, note: $note)';
  }
}
