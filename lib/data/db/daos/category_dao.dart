import 'package:drift/drift.dart';

import 'package:work_photos/data/db/app_database.dart';
import 'package:work_photos/data/db/tables/categories.dart';

part 'category_dao.g.dart';

/// 分类数据访问对象（DAO）。
@DriftAccessor(tables: [Categories])
class CategoryDao extends DatabaseAccessor<AppDatabase>
    with _$CategoryDaoMixin {
  /// 构造时绑定所属数据库。
  CategoryDao(super.db);

  /// 插入分类，返回自增主键。
  Future<int> insert(CategoriesCompanion companion) =>
      into(categories).insert(companion);

  /// 查询全部分类，按 [Categories.sortOrder] 升序排列。
  Future<List<CategoryRow>> getAll() =>
      (select(categories)
            ..orderBy([
              (Categories c) => OrderingTerm(
                    expression: c.sortOrder,
                    mode: OrderingMode.asc,
                  )
            ]))
          .get();

  /// 流式观察全部分类，按 [Categories.sortOrder] 升序排列。
  Stream<List<CategoryRow>> watchAll() =>
      (select(categories)
            ..orderBy([
              (Categories c) => OrderingTerm(
                    expression: c.sortOrder,
                    mode: OrderingMode.asc,
                  )
            ]))
          .watch();

  /// 更新分类（仅写入传入的字段）。
  Future<int> updateCategory(CategoriesCompanion companion) =>
      (update(categories)..where((c) => c.id.equals(companion.id.value)))
          .write(companion);

  /// 将某父分类下的子分类改挂到新父（或根：newParentId=null）。
  ///
  /// 用于删除分类时把孤儿子分类提升为根，维持树结构一致性。
  Future<void> reparentChildren(int oldParentId, int? newParentId) =>
      (update(categories)..where((c) => c.parentId.equals(oldParentId)))
          .write(CategoriesCompanion(parentId: Value(newParentId)));

  /// 按主键删除分类，返回受影响行数。
  ///
  /// 注意：方法名不可为 `delete`。Drift 的 [DatabaseConnectionUser] 基类已声明
  /// `DeleteStatement<T, D> delete<T extends Table, D>(TableInfo<T, D> table)`，
  /// 同名方法会因签名不匹配（返回类型 / 参数类型 / 类型变量）而编译失败（D10）。
  /// 改名为 [deleteById] 后，方法体内的 `delete(categories)` 会正确解析到基类方法。
  Future<int> deleteById(int id) =>
      (delete(categories)..where((c) => c.id.equals(id))).go();

  /// 拖拽排序持久化：在一个事务里按 [idsInOrder] 的列表下标写入各自 [sortOrder]。
  ///
  /// 第 i 个 id 的 [sortOrder] 置为 i，保证松手后的顺序重启后依然保持。
  Future<void> reorder(List<int> idsInOrder) {
    return transaction(() async {
      for (int i = 0; i < idsInOrder.length; i++) {
        await (update(categories)..where((c) => c.id.equals(idsInOrder[i])))
            .write(CategoriesCompanion(sortOrder: Value(i)));
      }
    });
  }

  /// 当前最大 [sortOrder]（无记录返回 -1），用于新分类递增分配排序值。
  Future<int> maxSortOrder() async {
    final List<CategoryRow> rows =
        await (select(categories)
              ..orderBy([
                (Categories c) => OrderingTerm(
                      expression: c.sortOrder,
                      mode: OrderingMode.desc,
                    )
              ]))
            .get();
    if (rows.isEmpty) return -1;
    return rows.first.sortOrder;
  }

  /// 批量把 [ids] 的分类改为 [colorHex]（R8 多选批量改色）。
  Future<void> updateColorForIds(List<int> ids, String colorHex) {
    if (ids.isEmpty) return Future<void>.value();
    return (update(categories)..where((Categories c) => c.id.isIn(ids)))
        .write(CategoriesCompanion(colorHex: Value(colorHex)));
  }

  /// 批量把 [ids] 的分类挂到新父级 [parentId]（null=提升为根，R8 批量移动）。
  ///
  /// 防环校验（父级不得是自身后代）由仓储层在调用前完成，DAO 不重复校验。
  Future<void> updateParentForIds(List<int> ids, int? parentId) {
    if (ids.isEmpty) return Future<void>.value();
    return (update(categories)..where((Categories c) => c.id.isIn(ids)))
        .write(CategoriesCompanion(parentId: Value(parentId)));
  }
}
