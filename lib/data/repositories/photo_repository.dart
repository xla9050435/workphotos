import 'package:drift/drift.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

import 'package:work_photos/core/utils/media_ref.dart';
import 'package:work_photos/data/db/app_database.dart';
import 'package:work_photos/data/db/tables/photos.dart';
import 'package:work_photos/data/models/import_item.dart';
import 'package:work_photos/data/models/media_type.dart';
import 'package:work_photos/data/models/photo.dart';
import 'package:work_photos/data/models/used_status.dart';

/// 照片业务仓储层。
///
/// 承接 UI 与数据库之间的编排：引用式导入、分类关联、已用状态标记，
/// 以及对照片数据的流式观察。
class PhotoRepository {
  final AppDatabase _db;

  /// 构造时注入 [AppDatabase]（来自 [appDatabaseProvider]）。
  PhotoRepository(this._db);

  /// 引用式批量导入：逐条插入媒体（绝不拷贝任何字节）。
  ///
  /// - [items]：待导入的媒体项（引用 + 类型 / 时长 / 尺寸元数据）。
  /// - [album]：来源相册名（可选）。
  /// 返回成功插入的记录数。
  Future<int> importFromAlbum(List<ImportItem> items, {String? album}) async {
    int inserted = 0;
    final DateTime now = DateTime.now();
    for (final ImportItem item in items) {
      final MediaRef ref = item.ref;
      final int id = await _db.photoDao.insert(
        PhotosCompanion.insert(
          mediaRefValue: ref.value,
          mediaRefType: ref.type.value,
          usedStatus: const Value(0),
          sourceAlbum: Value(album),
          mediaType: Value(item.mediaType.value),
          durationMs: Value(item.durationMs),
          width: Value(item.width),
          height: Value(item.height),
          // 拍摄时间（AssetEntity.createDateTime）；null 时查询走
          // COALESCE(shot_at, created_at) 兜底。
          shotAt: Value(item.shotAt),
          createdAt: now,
          updatedAt: now,
        ),
      );
      if (id > 0) inserted++;
    }
    return inserted;
  }

  /// 将照片归入某分类（重复忽略）。
  Future<void> assignCategory(int photoId, int categoryId) =>
      _db.photoCategoryDao.assign(photoId, categoryId);

  /// 将照片移出某分类。
  Future<void> unassignCategory(int photoId, int categoryId) =>
      _db.photoCategoryDao.unassign(photoId, categoryId);

  /// 标记照片为已用 / 未用。
  Future<void> markUsed(int photoId, bool used) =>
      _db.photoDao.markUsed(photoId, used);

  /// 更新照片备注（纯文本，可空）。
  Future<void> updateNote(int photoId, String? note) =>
      _db.photoDao.updateNote(photoId, note);

  /// 删除已导入的照片（「相册」多选删除入口）。
  ///
  /// - [photos]：待删除的照片领域模型（携带各自的 [MediaRef]）。
  /// - [deleteFiles]：true 时同时删除设备相册中的原始文件
  ///   （仅对 uri 类型引用生效，调用 [pm.PhotoManager.editor.deleteWithIds]）；
  ///   false 时仅删除本应用的引用数据，设备原图保留。
  /// 返回删除结果统计：引用数据删除数 / 设备文件删除成功数 / 失败数。
  Future<({int dbDeleted, int deviceDeleted, int deviceFailed})> deletePhotos(
    List<Photo> photos, {
    required bool deleteFiles,
  }) async {
    final List<int> ids =
        photos.where((p) => p.id != null).map((p) => p.id!).toList();
    int deviceDeleted = 0;
    int deviceFailed = 0;
    if (deleteFiles) {
      // uri 类型引用的 value 即 AssetEntity.id，可直接交给 photo_manager 删除。
      final List<String> deviceIds = <String>[
        for (final Photo p in photos)
          if (p.mediaRef.isUri) p.mediaRef.value,
      ];
      if (deviceIds.isNotEmpty) {
        final List<String> ok =
            await pm.PhotoManager.editor.deleteWithIds(deviceIds);
        deviceDeleted = ok.length;
        deviceFailed = deviceIds.length - ok.length;
      }
    }
    if (ids.isNotEmpty) {
      await _db.photoDao.deleteByIds(ids);
    }
    return (
      dbDeleted: ids.length,
      deviceDeleted: deviceDeleted,
      deviceFailed: deviceFailed,
    );
  }

  /// 查询某照片当前归属的分类 id 列表。
  Future<List<int>> categoriesOfPhoto(int photoId) =>
      _db.photoCategoryDao.byPhoto(photoId);

  /// 按 id 取单张照片（不存在返回 null）。供详情页 [PhotoDetailPage] 使用。
  Future<Photo?> futureById(int id) async {
    final PhotoRow? row = await _db.photoDao.byId(id);
    return row == null ? null : _toPhoto(row);
  }

  /// 流式观察照片列表，支持按分类 / 已用状态 / 日期 / 星期几过滤。
  ///
  /// 排序与日期语义均以「展示时间」为准（拍摄时间优先，缺失回退导入
  /// 时间，即 [Photo.displayTime] 与 SQL 侧 COALESCE 同义）：
  /// - [date]：取 [Photo.displayTime] 的同天（忽略时分秒）；
  /// - [weekday]：取 [Photo.displayTime.weekday]（1=周一 … 7=周日）相等。
  Stream<List<Photo>> watchByFilter({
    int? categoryId,
    UsedStatus? status,
    DateTime? date,
    int? weekday,
  }) {
    final int? usedValue = status?.value;
    return _db.photoDao
        .watchByFilter(categoryId: categoryId, usedStatus: usedValue)
        .map((List<PhotoRow> rows) {
      List<Photo> list = rows.map(_toPhoto).toList();
      if (date != null) {
        list = list
            .where((Photo p) => _isSameDay(p.displayTime, date))
            .toList();
      }
      if (weekday != null) {
        list = list
            .where((Photo p) => p.displayTime.weekday == weekday)
            .toList();
      }
      return list;
    });
  }

  /// 全局搜索（R9）：关键词（名称/备注/来源相册/分类名）+ 分类 + 日期范围。
  ///
  /// 关键词除匹配照片自身文本字段外，还匹配**分类名**（命中分类的照片
  /// 全部纳入结果）；分类名匹配在 Dart 侧完成（分类总量小，无需 SQL），
  /// 照片文本匹配与日期过滤由 DAO 在 SQL 侧完成。
  Future<List<Photo>> search({
    String? keyword,
    int? categoryId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final String? kw = (keyword == null || keyword.trim().isEmpty)
        ? null
        : keyword.trim();
    List<int> nameMatched = const <int>[];
    if (kw != null) {
      final List<CategoryRow> cats = await _db.categoryDao.getAll();
      final String lower = kw.toLowerCase();
      nameMatched = <int>[
        for (final CategoryRow c in cats)
          if (c.name.toLowerCase().contains(lower)) c.id,
      ];
    }
    final List<PhotoRow> rows = await _db.photoDao.search(
      keyword: kw,
      nameMatchedCategoryIds: nameMatched,
      categoryId: categoryId,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
    return rows.map(_toPhoto).toList();
  }

  /// 两个时间戳是否同年月日（忽略时分秒）。
  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 数据库行 → 领域模型。
  Photo _toPhoto(PhotoRow row) {
    return Photo(
      id: row.id,
      mediaRef: MediaRef.from(row.mediaRefValue, row.mediaRefType),
      title: row.title,
      usedStatus: UsedStatusX.fromValue(row.usedStatus),
      sourceAlbum: row.sourceAlbum,
      note: row.note,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      mediaType: MediaType.fromValue(row.mediaType),
      durationMs: row.durationMs,
      width: row.width,
      height: row.height,
      shotAt: row.shotAt,
    );
  }
}
