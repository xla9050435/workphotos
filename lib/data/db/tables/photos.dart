import 'package:drift/drift.dart';

/// photos 表定义。
///
/// 列说明：
/// - [mediaRefType]：'uri' | 'path'，本期示例数据使用 'uri'。
/// - [usedStatus]：0=未用 / 1=已用，默认 0。
/// - [syncState]：预留云同步状态，默认 0（设计决策 D3）。
/// - [mediaType]：'image' | 'video'（视频支持），默认 'image'；
///   历史数据迁移时由 [AppDatabase] onUpgrade 补默认值。
/// - [durationMs] / [width] / [height]：视频元数据（图片也可存，
///   便于详情页展示），均可空。
/// - [shotAt]：拍摄时间（来自 `AssetEntity.createDateTime`）；老数据为
///   null，读取时一律用 `COALESCE(shot_at, created_at)` 兜底。
///
/// 索引（R6/T4.1）：搜索与列表主排序都按 `COALESCE(shot_at, created_at)`
/// 倒序（拍摄时间优先、缺失回退导入时间），建索引避免十万级数据全表排序
/// （LIKE 子串匹配无法用索引，但 ORDER BY 可以）；同时保留 created_at 索引
/// 供其它按导入时间查询的场景使用。
///
/// 注意：排序真正命中的是**表达式索引** `idx_photos_display_time`
/// （`COALESCE(shot_at, created_at) DESC`）。`@TableIndex` 无法表达表达式
/// 索引，因此它在 [AppDatabase] 的 onCreate 与 onUpgrade(v5) 里以
/// `CREATE INDEX IF NOT EXISTS` 显式创建（两条路径成对存在）。
@TableIndex(name: 'idx_photos_created_at', columns: {#createdAt})
@TableIndex(name: 'idx_photos_shot_at', columns: {#shotAt})
@DataClassName('PhotoRow')
class Photos extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get mediaRefValue => text()();

  TextColumn get mediaRefType => text()();

  TextColumn get title => text().nullable()();

  IntColumn get usedStatus => integer().withDefault(const Constant(0))();

  /// 用户备注（纯文本，可空）。第四轮打磨新增。
  TextColumn get note => text().nullable()();

  TextColumn get sourceAlbum => text().nullable()();

  IntColumn get syncState => integer().withDefault(const Constant(0))();

  /// 媒体类型：'image' | 'video'（视频支持新增，默认 image 兼容历史数据）。
  TextColumn get mediaType => text().withDefault(const Constant('image'))();

  /// 视频时长（毫秒）；图片为 null。由导入时从 AssetEntity 提取。
  IntColumn get durationMs => integer().nullable()();

  /// 媒体宽高（像素）；解析失败为 null。视频详情页展示分辨率用。
  IntColumn get width => integer().nullable()();

  IntColumn get height => integer().nullable()();

  /// 拍摄时间（从 AssetEntity.createDateTime 提取）；未知为 null，
  /// 读取时一律用 COALESCE(shot_at, created_at) 兜底。
  DateTimeColumn get shotAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();
}
