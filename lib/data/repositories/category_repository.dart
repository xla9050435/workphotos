import 'package:drift/drift.dart';

import 'package:work_photos/data/db/app_database.dart';
import 'package:work_photos/data/db/tables/categories.dart';
import 'package:work_photos/data/models/category.dart';

/// 分类业务仓储层。
///
/// 承接分类的增删改查与流式观察。删除分类前会先清理其多对多关联
/// （设计决策 D1），并严格遵循"仅逻辑归类、不建文件夹"（决策 D2）。
class CategoryRepository {
  final AppDatabase _db;

  CategoryRepository(this._db);

  /// 新增分类，返回自增主键。
  ///
  /// 排序值取「当前最大 [sortOrder] + 1」，避免新分类都挤在 0
  /// （第四轮打磨：分类可拖动排序）。
  Future<int> insert(Category category) async {
    final int maxOrder = await _db.categoryDao.maxSortOrder();
    final int nextOrder = maxOrder + 1;
    return _db.categoryDao.insert(
      CategoriesCompanion.insert(
        name: category.name,
        colorHex: category.colorHex,
        iconName: category.iconName,
        createEntityFolder: Value(category.createEntityFolder),
        parentId: Value(category.parentId),
        sortOrder: Value(nextOrder),
        createdAt: DateTime.now(),
      ),
    );
  }

  /// 更新已有分类（按 [category.id] 定位）。
  Future<void> update(Category category) async {
    if (category.id == null) return;
    await _db.categoryDao.updateCategory(
      CategoriesCompanion(
        id: Value(category.id!),
        name: Value(category.name),
        colorHex: Value(category.colorHex),
        iconName: Value(category.iconName),
        createEntityFolder: Value(category.createEntityFolder),
        parentId: Value(category.parentId),
        sortOrder: Value(category.sortOrder),
      ),
    );
  }

  /// 拖拽排序持久化：按 [ordered] 的列表顺序写入各自的 [sortOrder]。
  ///
  /// 第 i 个分类的 [sortOrder] 置为 i，松手后顺序重启 App 依然保持。
  Future<void> reorder(List<Category> ordered) =>
      _db.categoryDao.reorder(ordered.map((c) => c.id!).toList());

  /// 删除分类：先清照片关联，再把子分类提升为根（避免孤儿节点），最后删自己。
  Future<void> delete(int id) async {
    await _db.photoCategoryDao.deleteByCategory(id);
    await _db.categoryDao.reparentChildren(id, null);
    await _db.categoryDao.deleteById(id);
  }

  /// 批量删除分类（R8 多选）：逐个走 [delete]，保证关联清理与子分类提升。
  Future<void> deleteAll(List<int> ids) async {
    for (final int id in ids) {
      await delete(id);
    }
  }

  /// 批量改色（R8 多选）。
  Future<void> updateColorForIds(List<int> ids, String colorHex) =>
      _db.categoryDao.updateColorForIds(ids, colorHex);

  /// 批量移动到新父级（R8 多选）：[ids] 整组挂到 [parentId]（null=提为根）。
  ///
  /// 防环校验：目标父级不得是所选分类之一，也不得是任一所选分类的后代
  /// （否则会形成父子环）。校验失败抛 [ArgumentError]，UI 侧应先行过滤。
  Future<void> moveAllTo(List<int> ids, int? parentId) async {
    if (ids.isEmpty) return;
    if (parentId == null) {
      await _db.categoryDao.updateParentForIds(ids, null);
      return;
    }
    final List<Category> all =
        await _db.categoryDao.getAll().then((List<CategoryRow> rows) => rows
            .map((CategoryRow row) => Category(
                  id: row.id,
                  name: row.name,
                  colorHex: row.colorHex,
                  iconName: row.iconName,
                  createEntityFolder: row.createEntityFolder,
                  parentId: row.parentId,
                  sortOrder: row.sortOrder,
                ))
            .toList());
    if (ids.contains(parentId)) {
      throw ArgumentError('目标父级在所选分类中，会造成父子环');
    }
    // 从目标父级沿父链向上爬：途中碰到任一所选分类 → 该分类是目标的
    // 祖先 → 目标是其后代，移动会成环。（guard 防脏数据成环死循环。）
    final Map<int, int?> parentOf = <int, int?>{
      for (final Category c in all)
        if (c.id != null) c.id!: c.parentId,
    };
    int? cur = parentId;
    int guard = 0;
    while (cur != null && guard++ <= all.length) {
      if (ids.contains(cur)) {
        throw ArgumentError('目标父级是所选分类的后代，会造成父子环');
      }
      cur = parentOf[cur];
    }
    await _db.categoryDao.updateParentForIds(ids, parentId);
  }

  /// 流式观察全部分类。
  Stream<List<Category>> watchAll() => _db.categoryDao
      .watchAll()
      .map((List<CategoryRow> rows) => rows.map(_toCategory).toList());

  Category _toCategory(CategoryRow row) => Category(
        id: row.id,
        name: row.name,
        colorHex: row.colorHex,
        iconName: row.iconName,
        createEntityFolder: row.createEntityFolder,
        parentId: row.parentId,
        sortOrder: row.sortOrder,
      );
}
