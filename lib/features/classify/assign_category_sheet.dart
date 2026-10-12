import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:work_photos/data/models/category.dart';
import 'package:work_photos/providers/category_provider.dart';
import 'package:work_photos/providers/photo_provider.dart';

/// 底部弹层：把一张或多张照片归入 / 移出某分类（B3）。
///
/// 通过 [AssignCategorySheet.show] 拉起。内部读取分类列表，
/// 并以首张照片的当前归属初始化勾选态；勾选变化即调用
/// [PhotoRepository.assignCategory] / [unassignCategory]。
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

  Future<void> _toggle(Category cat) async {
    final int? cid = cat.id;
    if (cid == null) return;
    final repo = ref.read(photoRepositoryProvider);
    final bool willAssign = !_assigned.contains(cid);
    for (final int pid in widget.photoIds) {
      if (willAssign) {
        await repo.assignCategory(pid, cid);
      } else {
        await repo.unassignCategory(pid, cid);
      }
    }
    if (mounted) {
      setState(() {
        if (willAssign) {
          _assigned.add(cid);
        } else {
          _assigned.remove(cid);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Category>> catsAsync =
        ref.watch(categoryListProvider);
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
            if (!_loaded)
              const Center(child: CircularProgressIndicator())
            else
              catsAsync.when(
                data: (cats) => cats.isEmpty
                    ? const Text('暂无分类，请先新建分类。')
                    : Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: cats.length,
                          itemBuilder: (ctx, i) {
                            final cat = cats[i];
                            final int cid = cat.id ?? -1;
                            final bool checked = _assigned.contains(cid);
                            return CheckboxListTile(
                              title: Text(cat.name),
                              value: checked,
                              onChanged: (_) => _toggle(cat),
                            );
                          },
                        ),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('加载失败：$e'),
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
