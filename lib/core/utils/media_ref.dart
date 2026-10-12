import 'dart:io';

import 'package:photo_manager/photo_manager.dart' as pm;

/// 媒体引用类型：uri（存 AssetEntity.id）或 path（本地绝对路径）。
enum MediaRefType {
  uri,
  path,
}

/// [MediaRefType] 与字符串/枚举的互转扩展。
extension MediaRefTypeX on MediaRefType {
  /// 持久化到数据库时使用的字符串值。
  String get value {
    switch (this) {
      case MediaRefType.uri:
        return 'uri';
      case MediaRefType.path:
        return 'path';
    }
  }

  /// 从数据库读取的字符串值还原为枚举。
  static MediaRefType fromValue(String value) {
    switch (value) {
      case 'uri':
        return MediaRefType.uri;
      case 'path':
        return MediaRefType.path;
      default:
        throw ArgumentError('Unknown MediaRefType value: $value');
    }
  }
}

/// 媒体引用值对象（引用式导入，绝不拷贝文件）。
///
/// 设计决策 D2 / B4：本期只做逻辑归类，照片以"引用"方式记录来源。
///
/// 引用约定（B4 增强）：
/// - [MediaRefType.uri]：[value] 存储的是 photo_manager 的
///   [pm.AssetEntity.id]（字符串）。通过 [pm.AssetEntity.fromId] 取回实体，
///   再解析其原始文件（供 B5 打包真实字节使用）。
/// - [MediaRefType.path]：[value] 存储本地绝对路径。
///
/// B1 的示例数据 `content://example` 并非合法 AssetEntity.id，
/// 因此 [resolveFile] 会返回 null，UI 以占位图降级展示。
class MediaRef {
  final String value;
  final MediaRefType type;

  const MediaRef({
    required this.value,
    required this.type,
  });

  /// 通过字符串类型构造（从数据库读取时使用）。
  factory MediaRef.from(String value, String typeStr) {
    return MediaRef(
      value: value,
      type: MediaRefTypeX.fromValue(typeStr),
    );
  }

  /// 是否为 uri 形式（value 为 AssetEntity.id）。
  bool get isUri => type == MediaRefType.uri;

  /// 解析为可读的本地 [File]。
  ///
  /// - path 类型：校验文件存在，不存在返回 null；
  /// - uri 类型：以 [value] 作为 [pm.AssetEntity.id] 取回实体，
  ///   优先取 [pm.AssetEntity.originFile]（原图文件），回退 [.file]；
  ///   任何解析异常（无权限 / 实体不存在 / id 非法）均被吞掉并返回 null，
  ///   便于上层降级展示。
  Future<File?> resolveFile() async {
    try {
      if (type == MediaRefType.path) {
        final File file = File(value);
        if (!await file.exists()) return null;
        return file;
      }
      // uri 类型：value 即 AssetEntity.id。
      final pm.AssetEntity? entity = await pm.AssetEntity.fromId(value);
      if (entity == null) return null;
      final File? original = await entity.originFile;
      if (original != null) return original;
      return await entity.file;
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaRef &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          type == other.type;

  @override
  int get hashCode => value.hashCode ^ type.hashCode;

  @override
  String toString() => 'MediaRef(value: $value, type: ${type.value})';
}
