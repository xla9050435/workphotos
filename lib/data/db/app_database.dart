import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/photos.dart';
import 'tables/categories.dart';
import 'tables/photo_category.dart';
import 'daos/photo_dao.dart';
import 'daos/category_dao.dart';
import 'daos/photo_category_dao.dart';

part 'app_database.g.dart';

/// 应用数据库（Drift 类型安全 SQLite）。
///
/// B2 起将三个 DAO（[PhotoDao] / [CategoryDao] / [PhotoCategoryDao]）注册进
/// [DriftDatabase] 注解，由 Drift 生成对应的 `photoDao` / `categoryDao` /
/// `photoCategoryDao` getter（见 `_$AppDatabase`）。
@DriftDatabase(
  tables: [Photos, Categories, PhotoCategory],
  daos: [PhotoDao, CategoryDao, PhotoCategoryDao],
)
class AppDatabase extends _$AppDatabase {
  /// 直接打开应用文档目录下的 SQLite 文件。
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          // createAll 会一并创建 @TableIndex 声明的索引（含新装的 v3）。
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // v1 → v2：新增 photos.note 备注列。
          if (from < 2) {
            await m.addColumn(photos, photos.note);
          }
          // v2 → v3（R6/T4.1）：photos.created_at 排序索引。
          // CREATE INDEX IF NOT EXISTS 保证重复执行幂等。
          if (from < 3) {
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_photos_created_at '
              'ON photos (created_at);',
            );
          }
          // v3 → v4（视频支持）：photos 新增 media_type / duration_ms /
          // width / height 四列。media_type 带默认值 'image'，
          // 历史数据自动按图片处理；其余三列可空。
          if (from < 4) {
            await m.addColumn(photos, photos.mediaType);
            await m.addColumn(photos, photos.durationMs);
            await m.addColumn(photos, photos.width);
            await m.addColumn(photos, photos.height);
          }
        },
      );

  // ===== 调试 / 特殊场景便捷访问器 =====
  // 常规查询请走 DAO；以下保留给 DebugHome 等场景。

  /// 插入一条照片记录，返回自增主键。
  Future<int> insertPhoto(PhotosCompanion companion) =>
      into(photos).insert(companion);

  /// 获取全部照片。
  Future<List<PhotoRow>> getAllPhotos() => select(photos).get();

  /// 照片总数。
  Future<int> countPhotos() =>
      select(photos).get().then((list) => list.length);

  /// 插入一条分类记录，返回自增主键。
  Future<int> insertCategory(CategoriesCompanion companion) =>
      into(categories).insert(companion);

  /// 获取全部分类。
  Future<List<CategoryRow>> getAllCategories() => select(categories).get();

  /// 分类总数。
  Future<int> countCategories() =>
      select(categories).get().then((list) => list.length);

  // photoDao / categoryDao / photoCategoryDao getter 由 Drift 生成的
  // `_$AppDatabase` 自动提供，无需手写。
}

/// 在应用文档目录中创建（后台线程）SQLite 连接。
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'photo_manager.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
