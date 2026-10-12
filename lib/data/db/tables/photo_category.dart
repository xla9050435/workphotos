import 'package:drift/drift.dart';

/// photo_category 多对多关联表。
///
/// 设计决策 D1：一张照片可归属多个分类，故采用关联表实现多对多。
/// 联合主键 (photoId, categoryId) 保证同一 (照片, 分类) 组合不会重复。
@DataClassName('PhotoCategoryRow')
@TableIndex(name: 'idx_pc_category', columns: {#categoryId})
@TableIndex(name: 'idx_pc_photo', columns: {#photoId})
class PhotoCategory extends Table {
  IntColumn get photoId => integer()();

  IntColumn get categoryId => integer()();

  DateTimeColumn get assignedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {photoId, categoryId};
}
