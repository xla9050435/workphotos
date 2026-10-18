import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:work_photos/data/models/category.dart';
import 'package:work_photos/features/classify/category_sort.dart';
import 'package:work_photos/providers/category_provider.dart';
import 'package:work_photos/providers/photo_provider.dart';

/// 底部弹层：把一张或多张照片归入 / 移出某分类（B3）。
///
/// 通过 [AssignCategorySheet.show] 拉起。内部读取分类列表并以**树序**
/// （父在前、子缩进，同层按全局排序模式排）展示——与分类管理页口径一致；
/// 以首张照片的当前归属初始化勾选态；勾选变化即调用
/// [PhotoRepository.assignCategory] / [PhotoRepository.unassignCategory]。
///
/// 两个关键行为（详见下方 [_toggle] / [_ancestorIdsOf] 注释）：
/// - 展示顺序：用 [treeOrdered] 而非 `sortedCategoryListProvider`；
/// - 勾选级联：勾子分类时自动补齐全部祖先；取消时只撤自身，不向下级联。
class AssignCategorySheet extends ConsumerStatefulWidget {
  final List<int> photoIds;

  const AssignCategorySheet._({super.key, required this.photoIds});

  /// 拉起底部弹层。
  static Future<void> show(BuildContext context, List<int> photoIds) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => AssignCategorySheet._(photoIds: photoIds),
    );
  }

  @override
  ConsumerState<AssignCategorySheet> createState() =>
      _AssignCategorySheetState();
}

class _AssignCategorySheetState extends ConsumerState<AssignCategorySheet> {
  final Set<int> _assigned = <int>{};
  bool _loaded = false;

  /// 写库进行中守卫：串行写库期间忽略后续点击，防止快速连点触发重复
  /// assign / 并发写（同一分类被重复归入、或父子级联半途被打断）。
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _initAssigned();
  }

  /// 以首张照片的当前分类归属初始化勾选态。
  Future<void> _initAssigned() async {
    if (widget.photoIds.isEmpty) return;
    final repo = ref.read(photoRepositoryProvider);
    final List<int> ids = await repo.categoriesOfPhoto(widget.photoIds.first);
    if (mounted) {
      setState(() {
        _assigned.addAll(ids);
        _loaded = true;
      });
    }
  }

  /// 计算 [categoryId] 的全部祖先 id（不含自身），带环检测，按由近到远返回。
  ///
  /// 为什么需要：分类是树形归属，子分类隐含属于其父。勾选子分类时若只写
  /// 子、不写父，则「按父分类筛选」会漏掉这些照片，层级关系在展示/筛选上
  /// 断裂。故勾子时向上补齐所有祖先。
  ///
  /// 防环：`visited` 从自身 id 起，沿 parentId 上溯时遇到已访问过的 id 立即
  /// 停止，避免脏数据（A→B→A、自环、父缺失）导致死循环。
  List<int> _ancestorIdsOf(int categoryId) {
    final List<Category> flat =
        ref.read(categoryListProvider).valueOrNull ?? const <Category>[];
    final Map<int, Category> byId = <int, Category>{
      for (final Category c in flat)
        if (c.id != null) c.id!: c,
    };
    final List<int> ancestors = <int>[];
    final Set<int> visited = <int>{categoryId};
    int? pid = byId[categoryId]?.parentId;
    while (pid != null && !visited.contains(pid)) {
      visited.add(pid);
      final Category? parent = byId[pid];
      if (parent == null) break; // 父被删 / 数据脏：停止上溯。
      ancestors.add(pid);
      pid = parent.parentId;
    }
    return ancestors;
  }

  /// 切换某分类的勾选态（勾选 / 取消）。
  ///
  /// 为什么取消不向下级联：若取消一个父分类时连带取消其全部子孙，用户在
  /// 「只想撤掉父的归属」时会把一大批子分类归属也一并删掉，破坏数据且难以
  /// 预期（尤其多选批次下影响面更大）。因此取消只撤自身，保持行为可预测；
  /// 勾选才向上补父（见 [_ancestorIdsOf]），方向单一、无歧义。
  Future<void> _toggle(Category cat) async {
    final int? cid = cat.id;
    // _busy 守卫（同步置位）：串行写库期间忽略连点，避免重复写。
    if (cid == null || _busy) return;
    _busy = true;

    final repo = ref.read(photoRepositoryProvider);
    final bool willAssign = !_assigned.contains(cid);

    // 勾选：自身 + 全部祖先一并归入（级联父，见 [_ancestorIdsOf]）；
    // 取消：只撤自身，不向下级联（原因见本方法头注释）。
    final List<int> targets = <int>[cid];
    if (willAssign) {
      targets.addAll(_ancestorIdsOf(cid));
    }

    try {
      // 串行写库：先逐目标、再逐照片，保证父子写入顺序稳定、可预测。
      for (final int target in targets) {
        for (final int pid in widget.photoIds) {
          if (willAssign) {
            await repo.assignCategory(pid, target);
          } else {
            await repo.unassignCategory(pid, target);
          }
        }
      }
    } finally {
      // 必须同步更新 _assigned，否则勾选态不刷新。
      if (mounted) {
        setState(() {
          if (willAssign) {
            _assigned.addAll(targets);
          } else {
            _assigned.remove(cid);
          }
        });
      }
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 原始流：仅用于判断是否仍在加载 / 加载失败。
    final AsyncValue<List<Category>> catsAsync =
        ref.watch(categoryListProvider);
    final String sortMode = ref.watch(categorySortModeProvider);
    final List<Category> flat = catsAsync.valueOrNull ?? const <Category>[];
    // 为什么用 treeOrdered 而不是 sortedCategoryListProvider：
    // 后者只把扁平列表按名称重排，**不含父子层级**——父与子会按名字混在
    // 一起、没有缩进。treeOrdered 按 parentId 做 DFS（父排在子之前），
    // 同层再按排序模式排，缩进展示才成立，与分类管理页口径一致。
    final List<Category> display = treeOrdered(flat, sortMode: sortMode);
    final Map<int, int> depths = categoryDepthMap(flat);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('归入分类（共 ${widget.photoIds.length} 张照片）',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (!_loaded || catsAsync.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (catsAsync.hasError)
              Text('加载失败：${catsAsync.error}')
            else
              display.isEmpty
                  ? const Text('暂无分类，请先新建分类。')
                  : Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: display.length,
                        itemBuilder: (ctx, i) {
                          final Category cat = display[i];
                          final int cid = cat.id ?? -1;
                          final int depth = depths[cat.id] ?? 0;
                          final bool checked = _assigned.contains(cid);
                          return CheckboxListTile(
                            // 按层级缩进（每层 20dp，与分类管理页一致）。
                            contentPadding: EdgeInsets.only(
                                left: 16.0 + depth * 20, right: 16),
                            title: Text(cat.name),
                            value: checked,
                            onChanged: (_) => _toggle(cat),
                          );
                        },
                      ),
                    ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('完成'),
            ),
          ],
        ),
      ),
    );
  }
}
