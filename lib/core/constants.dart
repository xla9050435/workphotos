/// 应用级常量集中定义，避免散落的魔法字符串/魔法数字。
///
/// 命名约定：常量以 `k` 前缀 + PascalCase（如 [kDatabaseVersion]）。

/// 数据库 schema 版本（Drift [schemaVersion] 使用）。
const int kDatabaseVersion = 1;

/// 批量处理上限，供 B3+ 批量导入/导出使用。
const int kBatchLimit = 200;

/// 表名常量，便于在测试或日志中引用。
const String kTablePhotos = 'photos';
const String kTableCategories = 'categories';
const String kTablePhotoCategory = 'photo_category';
