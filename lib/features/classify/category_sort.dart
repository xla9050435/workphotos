/// 分类排序工具（新功能：相册中按项目名排序分类）。
library;

import 'package:work_photos/data/models/category.dart';
import 'package:work_photos/features/me/settings_provider.dart';

/// 按排序模式返回名称比较器（null = 手动，保持原序）。
///
/// 中文按 Unicode 码位 deterministic 排序（同字典序行为）；
/// 数字/英文/中文混排时数字 < 英文 < 中文。
///
/// 次级键为 [Category.id]：分类重名是允许的（同一父下建两个「材料」不会被
/// 拦），而 [List.sort] 是不稳定排序，只比 name 时同名分类的相对顺序在每次
/// 重排后都可能变——列表每次 build 都重排，用户看到的就是同名分类自己来回
/// 跳动。补 id 后比较器成为严格全序，顺序只由数据决定。
int Function(Category a, Category b)? categoryNameComparator(String mode) {
  switch (mode) {
    case kCategorySortNameAsc:
      return (Category a, Category b) =>
          _compareByNameThenId(a, b, descending: false);
    case kCategorySortNameDesc:
      return (Category a, Category b) =>
          _compareByNameThenId(a, b, descending: true);
    default:
      return null; // manual
  }
}

/// 名称主键 + id 次级键；[descending] 时**整体**取反。
///
/// 整体取反而不是只反转名称比较，是为了让次级键方向与主键一致：
/// 降序时 id 也降序，升序列表的逆序才严格等于降序列表（单测按此断言）。
/// id 可能为 null（尚未入库的新分类，如 `Category` 的临时草稿），
/// 统一按 0 参与比较，避免空指针且排在同名组最前。
int _compareByNameThenId(
  Category a,
  Category b, {
  required bool descending,
}) {
  final int byName = a.name.compareTo(b.name);
  final int cmp = byName != 0 ? byName : (a.id ?? 0).compareTo(b.id ?? 0);
  return descending ? -cmp : cmp;
}

/// 对扁平分类列表按模式排序（手动模式原样返回副本）。
List<Category> sortCategories(List<Category> flat, String mode) {
  final int Function(Category, Category)? cmp = categoryNameComparator(mode);
  if (cmp == null) return List<Category>.of(flat);
  final List<Category> list = List<Category>.of(flat)..sort(cmp);
  return list;
}

/// 将扁平分类列表整理为树序（父在前、子在后，DFS），用于层级展示。
///
/// 语义约定：
/// - DFS 保证父节点一定排在其子节点之前，缩进展示才成立；
/// - [sortMode] 非 manual 时，**根层与每层子节点**都按
///   [categoryNameComparator] 排序；manual（比较器为 null）保持
///   数据库里的手动拖拽顺序不变；
/// - 兜底：若某分类的父指向不存在的节点（父被删），补到末尾，避免丢失。
List<Category> treeOrdered(
  List<Category> flat, {
  String sortMode = kCategorySortManual,
}) {
  final int Function(Category a, Category b)? cmp =
      categoryNameComparator(sortMode);
  final Map<int?, List<Category>> childrenOf = <int?, List<Category>>{};
  for (final Category c in flat) {
    childrenOf.putIfAbsent(c.parentId, () => <Category>[]).add(c);
  }
  final List<Category> out = <Category>[];
  void dfs(Category c) {
    out.add(c);
    final List<Category> children =
        List<Category>.of(childrenOf[c.id] ?? <Category>[]);
    if (cmp != null) children.sort(cmp);
    for (final Category child in children) dfs(child);
  }

  final List<Category> roots =
      List<Category>.of(childrenOf[null] ?? <Category>[]);
  if (cmp != null) roots.sort(cmp);
  for (final Category root in roots) dfs(root);
  // 兜底：若某分类的父指向不存在的节点，补到末尾，避免丢失。
  if (out.length < flat.length) {
    for (final Category c in flat) {
      if (!out.contains(c)) out.add(c);
    }
  }
  return out;
}

/// 计算每个分类在树中的深度（根 = 0），用于层级缩进展示。
///
/// 语义与「分类管理页」「归入分类面板」共用同一口径，三处调用此函数，
/// 避免各自维护一份实现导致缩进/层级漂移。
///
/// 兜底与健壮性：
/// - 父节点不在 [flat] 中（父被删 / 数据脏）：该分类按根处理，深度 0；
/// - [Category.id] 为 null 的分类（尚未入库的草稿）不进入深度图；
/// - **环检测**：沿 [Category.parentId] 向上传递一个 `visiting` 访问集合，
///   若某节点在本条递归链上重复出现（如 A→B→A 或自环），直接按根（0）
///   终止递归，避免无限递归 / 栈溢出。环上各节点仍会得到有限深度。
Map<int, int> categoryDepthMap(List<Category> flat) {
  final Map<int, Category> byId = <int, Category>{
    for (final Category c in flat)
      if (c.id != null) c.id!: c,
  };
  final Map<int, int> depth = <int, int>{};

  int compute(int id, Set<int> visiting) {
    final int? memo = depth[id];
    if (memo != null) return memo;
    // 环检测：id 已在本条递归链上 → 成环，按根（0）兜底，终止递归。
    if (!visiting.add(id)) return 0;
    final Category? c = byId[id];
    final int result;
    if (c == null || c.parentId == null || !byId.containsKey(c.parentId)) {
      result = 0; // 到达根，或父节点缺失。
    } else {
      result = compute(c.parentId!, visiting) + 1;
    }
    visiting.remove(id);
    depth[id] = result;
    return result;
  }

  for (final Category c in flat) {
    if (c.id != null) compute(c.id!, <int>{});
  }
  return depth;
}
