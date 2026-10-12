import 'package:photo_manager/photo_manager.dart' as pm;

import 'package:work_photos/core/utils/media_ref.dart';
import 'package:work_photos/data/repositories/photo_repository.dart';

/// 导入控制器（B4）。
///
/// 负责将选中的 [pm.AssetEntity] 转换为引用式 [MediaRef]
/// （uri 类型存 AssetEntity.id），并委托 [PhotoRepository] 执行引用式批量导入。
class ImportController {
  final PhotoRepository _repository;

  ImportController(this._repository);

  /// 引用式导入：仅记录 AssetEntity.id，绝不复制字节。
  ///
  /// 返回成功导入的照片记录数。
  Future<int> importAssets(List<pm.AssetEntity> entities,
      {String? album}) async {
    final List<MediaRef> refs = entities.map((pm.AssetEntity e) {
      return MediaRef(value: e.id, type: MediaRefType.uri);
    }).toList();
    return _repository.importFromAlbum(refs, album: album);
  }
}
