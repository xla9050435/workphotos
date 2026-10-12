import 'package:work_photos/core/utils/media_ref.dart';
import 'package:work_photos/data/models/media_type.dart';

/// 一条待导入的媒体项（引用式，不拷贝字节）。
///
/// 携带从 photo_manager [pm.AssetEntity] 提取的类型 / 时长 / 尺寸元数据，
/// 供入库持久化（视频支持）。定义在数据层，便于仓储与导入控制器共用。
class ImportItem {
  final MediaRef ref;

  /// 媒体类型（图片 / 视频）。
  final MediaType mediaType;

  /// 视频时长（毫秒）；图片为 null。
  final int? durationMs;

  /// 宽高（像素）。
  final int? width;
  final int? height;

  const ImportItem({
    required this.ref,
    required this.mediaType,
    this.durationMs,
    this.width,
    this.height,
  });
}
