import 'package:photo_manager/photo_manager.dart' as pm;

import 'package:work_photos/core/utils/media_ref.dart';
import 'package:work_photos/data/models/import_item.dart';
import 'package:work_photos/data/models/media_type.dart';
import 'package:work_photos/data/repositories/photo_repository.dart';

/// 导入控制器（B4 + 视频支持）。
///
/// 负责将选中的 [pm.AssetEntity] 转换为引用式 [MediaRef]
/// （uri 类型存 AssetEntity.id）并附带元数据，委托
/// [PhotoRepository] 执行引用式批量导入。
class ImportController {
  final PhotoRepository _repository;

  ImportController(this._repository);

  /// 引用式导入，**返回成功导入的照片 id 列表**（供导入后立即分配分类）。
  ///
  /// 为什么加这个「返回 ids」的版本，而不是改 [importAssets] 原签名：原方法
  /// 返回条数、被快速导入面板等调用；改签名会波及调用点。新增方法、让原方法
  /// 委托取 length，调用点零改动。
  Future<List<int>> importAssetsReturningIds(List<pm.AssetEntity> entities,
      {String? album}) async {
    final List<ImportItem> items = entities.map(_toItem).toList();
    return _repository.importFromAlbumIds(items, album: album);
  }

  /// 引用式导入：仅记录 AssetEntity.id 与元数据，绝不复制字节。
  ///
  /// 返回成功导入的记录数。委托 [importAssetsReturningIds]，保持原签名不变。
  Future<int> importAssets(List<pm.AssetEntity> entities,
          {String? album}) async =>
      (await importAssetsReturningIds(entities, album: album)).length;

  /// [pm.AssetEntity] → [ImportItem]。
  ///
  /// 视频判定：`type == AssetType.video`；时长取
  /// [pm.AssetEntity.videoDuration]（毫秒精度），图片 duration 恒 0
  /// 不写库；宽高直接取实体字段（MediaStore 元数据）；
  /// [pm.AssetEntity.createDateTime] 即**拍摄时间**，写入 shotAt 供相册页
  /// 排序 / 分组 / 日期筛选用。
  ImportItem _toItem(pm.AssetEntity e) {
    final bool isVideo = e.type == pm.AssetType.video;
    return ImportItem(
      ref: MediaRef(value: e.id, type: MediaRefType.uri),
      mediaType: isVideo ? MediaType.video : MediaType.image,
      durationMs: isVideo ? e.videoDuration.inMilliseconds : null,
      width: e.width,
      height: e.height,
      shotAt: e.createDateTime,
    );
  }
}
