import 'dart:io';

import 'package:work_photos/core/utils/media_ref.dart';
import 'package:work_photos/data/models/used_status.dart';

/// 照片领域模型（与数据库行 [PhotoRow] 解耦，供 UI / 业务层使用）。
class Photo {
  final int? id;
  final MediaRef mediaRef;
  final String? title;
  final UsedStatus usedStatus;
  final String? sourceAlbum;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Photo({
    this.id,
    required this.mediaRef,
    this.title,
    required this.usedStatus,
    this.sourceAlbum,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 是否已被归类使用。
  bool get isUsed => usedStatus == UsedStatus.used;

  /// 解析为本地文件（委托给 [MediaRef.resolveFile]）。
  Future<File?> resolveFile() => mediaRef.resolveFile();

  @override
  String toString() {
    return 'Photo(id: $id, title: $title, usedStatus: $usedStatus, '
        'sourceAlbum: $sourceAlbum, note: $note)';
  }
}
