import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:work_photos/data/models/category.dart';
import 'package:work_photos/core/utils/color_contrast.dart';
import 'package:work_photos/features/classify/category_form.dart';
import 'package:work_photos/features/classify/category_style.dart';
import 'package:work_photos/providers/category_provider.dart';

/// 将扁平分类列表整理为树序（父在前、子在后，DFS），用于层级展示。
List<Category> _toTreeOrdered(List<Category> flat) {
  final Map<int?, List<Category>> childrenOf = <int?, List<Category>>{};
  for (final Category c in flat) {
    childrenOf.putIfAbsent(c.parentId, () => <Category>[]).add(c);
  }
  final List<Category> out = <Category>[];
  void dfs(Category c) {
    out.add(c);
    for (final Category child in childrenOf[c.id] ?? <Category>[]) dfs(child);
  }

  for (final Category root in childrenOf[null] ?? <Category>[]) dfs(root);
  // 兜底：若某分类的父指向不存在的节点，补到末尾，避免丢失。
  if (out.length < flat.length) {
    for (final Category c in flat) {
      if (!out.contains(c)) out.add(c);
    }
  }
  return out;
}

/// 计算每个分类在树中的深度（根=0），用于缩进展示。
Map<int, int> _depthMap(List<Category> flat) {
  final Map<int, Category> byId = <int, Category>{
    for (final Category c in flat)
      if (c.id != null) c.id!: c,
  };
  final Map<int, int> depth = <int, int>{};
  int compute(int id) {
    if (depth.containsKey(id)) return depth[id]!;
    final Category? c = byId[id];
    if (c == null || c.parentId == null || !byId.containsKey(c.parentId)) {
      depth[id] = 0;
      return 0;
    }
    final int d = compute(c.parentId!) + 1;
    depth[id] = d;
    return d;
  }

  for (final Category c in flat) {
    if (c.id != null) compute(c.id!);
  }
  return depth;
}

/// 分类管理页（B3 + R8 增强）。
///
/// 通过 [categoryListProvider] 实时观察分类列表；支持增 / 编 / 删 /
/// 拖拽排序（持久化，已有），R8 新增：
/// - 列表内搜索过滤（按名称子串匹配，纯客户端）；
/// - 长按进入多选，批量改色 / 批量移动到父级 / 批量删除（带确认与防环）。
/// 搜索过滤时禁用拖拽排序（子集重排会写出错误的 sortOrder）。
class CategoryPage extends ConsumerStatefulWidget {
  const CategoryPage({super.key});

  @override
  ConsumerState<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends ConsumerState<CategoryPage> {
  final TextEditingController _searchCtrl = TextEditingController();

  /// 列表内搜索关键词（按名称子串匹配）。
  String _search = '';

  /// 多选模式选中的分类 id 集合（非空即处于多选态）。
  Set<int> _selected = <int>{};

  bool get _selecting => _selected.isNotEmpty;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AsyncValue<List<Category>> categoriesAsync =
        ref.watch(categoryListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_selecting ? '已选 ${_selected.length} 项' : '分类管理'),
        actions: <Widget>[
          if (_selecting)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: '退出多选',
              onPressed: () => setState(() => _selected = <int>{}),
            ),
        ],
        // 列表内搜索框（R8）：常驻 appBar 下方；多选态隐藏避免遮挡。
        bottom: _selecting
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (String v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: '搜索分类名称',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: _search.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              tooltip: '清空搜索',
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _search = '');
                              },
                            ),
                    ),
                  ),
                ),
              ),
      ),
      body: categoriesAsync.when(
        data: (List<Category> categories) {
          if (categories.isEmpty) {
            return const Center(
              child: Text('暂无分类，点击右下角 + 新建。'),
            );
          }
          // 搜索过滤（子串匹配，大小写不敏感）。
          final String kw = _search.trim().toLowerCase();
          final List<Category> filtered = kw.isEmpty
              ? categories
              : categories
                  .where((Category c) =>
                      c.name.toLowerCase().contains(kw))
                  .toList();
          if (filtered.isEmpty) {
            return const Center(child: Text('没有匹配的分类。'));
          }
          // 按层级整理为树序，并计算每个节点的深度用于缩进。
          final List<Category> display = _toTreeOrdered(filtered);
          final Map<int, int> depths = _depthMap(filtered);
          final Map<int, String> nameOf = <int, String>{
            for (final Category c in filtered)
              if (c.id != null) c.id!: c.name,
          };
          final bool reorderable = !_selecting && kw.isEmpty;
          final List<Widget> tiles = <Widget>[
            for (int i = 0; i < display.length; i++)
              _CategoryTile(
                key: Key('category-${display[i].id}'),
                index: i,
                category: display[i],
                depth: depths[display[i].id] ?? 0,
                parentName: display[i].parentId == null
                    ? null
                    : nameOf[display[i].parentId],
                inSelectionMode: _selecting,
                isSelected: _selected.contains(display[i].id),
                onLongPress: () => _enterSelection(display[i]),
                onTapInSelectionMode: () => _toggleSelection(display[i]),
              ),
          ];
          if (reorderable) {
            return ReorderableListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              // 关闭默认整行拖拽，仅拖拽手柄可触发排序，避免与编辑/删除按钮冲突。
              buildDefaultDragHandles: false,
              onReorder: (int oldIndex, int newIndex) {
                _onReorder(ref, display, oldIndex, newIndex);
              },
              children: tiles,
            );
          }
          // 多选态 / 搜索过滤态：普通列表（禁用拖拽，避免子集重排写错顺序）。
          return ListView(children: tiles);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载失败：$error')),
      ),
      floatingActionButton: _selecting
          ? null
          : FloatingActionButton(
              tooltip: '新建分类',
              onPressed: () => _showForm(context, ref, null),
              child: const Icon(Icons.add),
            ),
      // 多选操作栏（R8）：批量改色 / 移动 / 删除。
      bottomNavigationBar: _selecting
          ? BottomAppBar(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.palette_outlined),
                      label: const Text('改色'),
                      onPressed: () => _batchChangeColor(context),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.drive_file_move_outline),
                      label: const Text('移动'),
                      onPressed: () => _batchMove(context),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      icon: Icon(Icons.delete_outline, color: scheme.error),
                      label:
                          Text('删除', style: TextStyle(color: scheme.error)),
                      onPressed: () => _batchDelete(context),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  // —— 多选（R8）——

  void _enterSelection(Category c) {
    if (c.id == null) return;
    setState(() => _selected = <int>{c.id!});
  }

  void _toggleSelection(Category c) {
    if (c.id == null) return;
    setState(() {
      final Set<int> next = Set<int>.from(_selected);
      if (!next.remove(c.id!)) next.add(c.id!);
      _selected = next;
    });
  }

  /// 批量改色：色板点选（复用 Google 500 色阶）。
  Future<void> _batchChangeColor(BuildContext context) async {
    final String? hex = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('修改 ${_selected.length} 个分类的颜色'),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: googlePresetColorHexes.map((String h) {
              // 48dp 点击区 + 36dp 视觉圆点（与分类表单色板一致）。
              return SizedBox(
                width: 48,
                height: 48,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(ctx).pop(h),
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: parseColorHex(h),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (hex == null) return;
    await ref
        .read(categoryRepositoryProvider)
        .updateColorForIds(_selected.toList(), hex);
    if (mounted) setState(() => _selected = <int>{});
  }

  /// 批量移动：从现有分类中选新父级（根分类可选）。
  ///
  /// 候选排除所选分类自身及其后代（防父子环）；仓储层另有兜底校验。
  /// 弹窗返回值约定：null=取消，-1=移到根分类，>0=挂到该 id 下。
  Future<void> _batchMove(BuildContext context) async {
    final List<Category> all =
        ref.read(categoryListProvider).valueOrNull ?? const <Category>[];
    final Set<int> forbidden = <int>{..._selected};
    for (final int id in _selected) {
      forbidden.addAll(categoryDescendantIds(all, id));
    }
    final List<Category> candidates = all
        .where((Category c) => c.id == null || !forbidden.contains(c.id))
        .toList();
    final Map<int, int> depths = _depthMap(all);
    const int kRootSentinel = -1;
    final int? result = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('移动 ${_selected.length} 个分类到'),
        content: SizedBox(
          width: 280,
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('根分类'),
                onTap: () => Navigator.of(ctx).pop(kRootSentinel),
              ),
              for (final Category c in candidates)
                ListTile(
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: parseColorHex(c.colorHex),
                    child: Icon(categoryIconOf(c.iconName),
                        size: 16,
                        color: contrastColorOn(parseColorHex(c.colorHex))),
                  ),
                  contentPadding:
                      EdgeInsets.only(left: 16.0 + (depths[c.id] ?? 0) * 20),
                  title: Text(c.name),
                  onTap: () => Navigator.of(ctx).pop(c.id),
                ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (result == null) return; // 取消
    await _doMove(result == kRootSentinel ? null : result);
  }

  Future<void> _doMove(int? parentId) async {
    try {
      await ref
          .read(categoryRepositoryProvider)
          .moveAllTo(_selected.toList(), parentId);
      if (mounted) setState(() => _selected = <int>{});
    } on ArgumentError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message?.toString() ?? '移动失败')),
        );
      }
    }
  }

  /// 批量删除：确认后逐个删除（关联清理 + 子分类提升为根）。
  Future<void> _batchDelete(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('删除分类'),
        content: Text('确定删除所选 ${_selected.length} 个分类？'
            '分类下的照片关联会被移除（照片本身保留）；'
            '它们的子分类会提升为根分类。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(categoryRepositoryProvider).deleteAll(_selected.toList());
    if (mounted) setState(() => _selected = <int>{});
  }

  // —— 原有：单分类增改 / 删除 / 排序 ——

  /// 弹出新增 / 编辑表单，并在关闭后落库。
  Future<void> _showForm(
      BuildContext context, WidgetRef ref, Category? initial) async {
    final Category? result = await showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => CategoryForm(
        allCategories: ref.read(categoryListProvider).valueOrNull ??
            const <Category>[],
        initial: initial,
        onSubmit: (category) => Navigator.of(ctx).pop(category),
      ),
    );
    if (result == null) return;
    final repo = ref.read(categoryRepositoryProvider);
    if (initial == null) {
      await repo.insert(result);
    } else {
      await repo.update(result);
    }
  }

  /// 拖拽排序后持久化新顺序（[ReorderableListView.onReorder] 回调）。
  ///
  /// 按 Flutter 约定（下移时 newIndex 需 -1）在本地列表上重排，再写入数据库，
  /// Riverpod 流会自动刷新列表顺序。
  Future<void> _onReorder(
    WidgetRef ref,
    List<Category> categories,
    int oldIndex,
    int newIndex,
  ) async {
    final List<Category> ordered = List<Category>.from(categories);
    if (oldIndex < newIndex) newIndex -= 1;
    final Category moved = ordered.removeAt(oldIndex);
    ordered.insert(newIndex, moved);
    await ref.read(categoryRepositoryProvider).reorder(ordered);
  }
}

class _CategoryTile extends ConsumerWidget {
  final int index;
  final Category category;
  final int depth;
  final String? parentName;

  /// 多选态（R8）：true 时整行点击=切换选中，trailing 显示勾选状态，
  /// 编辑/删除/拖拽手柄隐藏（批量操作走底部操作栏）。
  final bool inSelectionMode;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onTapInSelectionMode;

  const _CategoryTile({
    super.key,
    required this.index,
    required this.category,
    this.depth = 0,
    this.parentName,
    this.inSelectionMode = false,
    this.isSelected = false,
    this.onLongPress,
    this.onTapInSelectionMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color color = parseColorHex(category.colorHex);
    return ListTile(
      // 按层级缩进（每层 20px）。
      contentPadding:
          EdgeInsets.only(left: 16.0 + depth * 20, right: 8),
      leading: CircleAvatar(
        backgroundColor: color,
        child: Icon(categoryIconOf(category.iconName),
            color: contrastColorOn(color)),
      ),
      title: Text(category.name),
      subtitle: Text(parentName == null
          ? '根分类 · ${category.iconName}'
          : '父级：$parentName · ${category.iconName}'),
      onTap: inSelectionMode ? onTapInSelectionMode : null,
      onLongPress: onLongPress,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (inSelectionMode)
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
            )
          else ...<Widget>[
            // 拖拽手柄：仅此处可触发排序拖拽，避免与编辑/删除按钮冲突。
            ReorderableDragStartListener(
              index: index,
              child: Icon(Icons.drag_handle, color: scheme.onSurfaceVariant),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: '编辑',
              onPressed: () => _showEdit(context, ref),
            ),
            IconButton(
              icon: Icon(Icons.delete, color: scheme.error),
              tooltip: '删除',
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showEdit(BuildContext context, WidgetRef ref) async {
    final Category? result = await showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => CategoryForm(
        allCategories: ref.read(categoryListProvider).valueOrNull ??
            const <Category>[],
        initial: category,
        onSubmit: (c) => Navigator.of(ctx).pop(c),
      ),
    );
    if (result != null) {
      await ref.read(categoryRepositoryProvider).update(result);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除分类'),
        content: Text('确定删除"${category.name}"？该分类下的照片关联会被移除'
            '（照片本身保留）。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true && category.id != null) {
      await ref.read(categoryRepositoryProvider).delete(category.id!);
    }
  }
}
