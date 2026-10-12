import 'package:drift/drift.dart';

/// categories 表定义。
///
/// 列说明：
/// - [createEntityFolder]：是否创建实体文件夹，本期恒为 false（设计决策 D2）。
/// - [parentId]：支持层级分类的父节点，根分类为 NULL。
@DataClassName('CategoryRow')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get colorHex => text()();

  TextColumn get iconName => text()();

  BoolColumn get createEntityFolder =>
      boolean().withDefault(const Constant(false))();

  IntColumn get parentId => integer().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime()();
}
