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
///
/// 索引（R6/T4.1）：搜索与列表主排序都按 created_at 倒序，建索引避免
/// 十万级数据全表排序（LIKE 子串匹配无法用索引，但 ORDER BY 可以）。
@DataClassName('PhotoRow')
@TableIndex(name: 'idx_photos_created_at', columns: {#createdAt})
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

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();
}
