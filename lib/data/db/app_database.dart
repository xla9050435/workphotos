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
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          // createAll 会一并创建 @TableIndex 声明的索引（含新装的 v3）。
          await m.createAll();
          // 表达式索引（新装路径）：显示时间 = COALESCE(shot_at, created_at)。
          // 相册 / 搜索的 ORDER BY 用的就是这个表达式，SQLite 只有**表达式
          // 索引**才能命中（单列 idx_photos_shot_at 命不中）。
          // 与下面 onUpgrade 的 v5 分支必须成对存在，否则会出现
          // 「新装快、老库升级后慢」的诡异差异。
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_photos_display_time '
            'ON photos (COALESCE(shot_at, created_at) DESC);',
          );
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
          // v4 → v5（拍摄时间）：photos 新增 shot_at 列（可空，来源
          // AssetEntity.createDateTime）+ 两个索引（shot_at 单列、
          // COALESCE(shot_at, created_at) 表达式）。老数据 shot_at 为 null，
          // 所有查询用 COALESCE(shot_at, created_at) 兜底，表现与升级前一致。
          // 注意：@TableIndex 只在 onCreate 建索引，升级路径不会自动补建，
          // 必须在这里显式 createIndex（IF NOT EXISTS 保证重复执行幂等）。
          if (from < 5) {
            await m.addColumn(photos, photos.shotAt);
            await m.createIndex(Index(
              'idx_photos_shot_at',
              'CREATE INDEX IF NOT EXISTS idx_photos_shot_at '
                  'ON photos (shot_at);',
            ));
            // 排序实际用的是 COALESCE(shot_at, created_at)，SQLite 必须
            // 表达式索引才命中；与 onCreate 中的同名语句保持一致。
            await m.createIndex(Index(
              'idx_photos_display_time',
              'CREATE INDEX IF NOT EXISTS idx_photos_display_time '
                  'ON photos (COALESCE(shot_at, created_at) DESC);',
            ));
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
