import 'package:drift/drift.dart';

import 'package:work_photos/data/db/app_database.dart';
import 'package:work_photos/data/db/tables/photo_category.dart';

part 'photo_category_dao.g.dart';

/// 照片-分类多对多关联数据访问对象（DAO）。
///
/// 设计决策 D1：一张照片可归属多个分类。
@DriftAccessor(tables: [PhotoCategory])
class PhotoCategoryDao extends DatabaseAccessor<AppDatabase>
    with _$PhotoCategoryDaoMixin {
  /// 构造时绑定所属数据库。
  PhotoCategoryDao(super.db);

  /// 全量关联（T4.3 备份导出用）。
  Future<List<PhotoCategoryRow>> all() => select(photoCategory).get();

  /// 建立关联（重复忽略）。
  ///
  /// 使用 [InsertMode.insertOrIgnore]，当 (photoId, categoryId) 命中联合主键
  /// 冲突时静默忽略，实现"重复忽略"。
  Future<void> assign(int photoId, int categoryId) async {
    await into(photoCategory).insert(
      PhotoCategoryCompanion.insert(
        photoId: photoId,
        categoryId: categoryId,
        assignedAt: DateTime.now(),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// 解除一条关联。
  Future<void> unassign(int photoId, int categoryId) =>
      (delete(photoCategory)
            ..where((pc) =>
                pc.photoId.equals(photoId) &
                pc.categoryId.equals(categoryId)))
          .go();

  /// 按照片查询其所属分类 id 列表。
  Future<List<int>> byPhoto(int photoId) =>
      (select(photoCategory)..where((pc) => pc.photoId.equals(photoId)))
          .map((row) => row.categoryId)
          .get();

  /// 按分类查询其下照片 id 列表。
  Future<List<int>> byCategory(int categoryId) =>
      (select(photoCategory)..where((pc) => pc.categoryId.equals(categoryId)))
          .map((row) => row.photoId)
          .get();

  /// 删除某分类的全部关联（删除分类前调用）。
  Future<int> deleteByCategory(int categoryId) =>
      (delete(photoCategory)..where((pc) => pc.categoryId.equals(categoryId)))
          .go();

  /// 删除某照片的全部关联（删除照片前调用）。
  Future<int> deleteByPhoto(int photoId) =>
      (delete(photoCategory)..where((pc) => pc.photoId.equals(photoId))).go();
}
