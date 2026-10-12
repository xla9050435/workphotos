import 'package:flutter/material.dart';

import 'package:work_photos/data/models/category.dart';
import 'package:work_photos/core/utils/color_contrast.dart';
import 'package:work_photos/features/classify/category_style.dart';

/// 给定分类的所有后代 id（含直接/间接子分类），用于防止把分类挂到自己子孙下成环。
List<int> categoryDescendantIds(List<Category> all, int rootId) {
  final Map<int, List<Category>> byParent = <int, List<Category>>{};
  for (final Category c in all) {
    if (c.parentId != null) {
      byParent.putIfAbsent(c.parentId!, () => <Category>[]).add(c);
    }
  }
  final List<int> result = <int>[];
  final List<int> stack = <int>[rootId];
  while (stack.isNotEmpty) {
    final int cur = stack.removeLast();
    for (final Category child in byParent[cur] ?? <Category>[]) {
      result.add(child.id!);
      stack.add(child.id!);
    }
  }
  return result;
}

/// 分类增改表单（B3）。
///
/// 仅收集 name / colorHex / iconName，以及可选的 [parentId]（层级归类）。
/// 设计决策 D2：本期为"仅逻辑归类"，[createEntityFolder] 恒为 false，
/// UI 展示禁用开关并说明不建文件夹。
class CategoryForm extends StatefulWidget {
  /// 现有全部分类，用于父级下拉候选（需排除自身与后代以防成环）。
  final List<Category> allCategories;
  final Category? initial;
  final ValueChanged<Category> onSubmit;

  const CategoryForm({
    super.key,
    this.allCategories = const <Category>[],
    this.initial,
    required this.onSubmit,
  });

  @override
  State<CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<CategoryForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  String _colorHex;
  String _iconName;
  int? _parentId;

  _CategoryFormState()
      : _colorHex = '#4CAF50',
        _iconName = 'folder';

  @override
  void initState() {
    super.initState();
    final Category? c = widget.initial;
    _nameCtrl.text = c?.name ?? '';
    _colorHex = c?.colorHex ?? '#4CAF50';
    _iconName = c?.iconName ?? 'folder';
    _parentId = c?.parentId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  /// 可被选作父级的分类：排除自身与自身的全部后代（防止成环）。
  List<Category> get _parentCandidates {
    final int? selfId = widget.initial?.id;
    if (selfId == null) return List<Category>.from(widget.allCategories);
    final Set<int> forbidden = <int>{
      selfId,
      ...categoryDescendantIds(widget.allCategories, selfId),
    };
    return widget.allCategories
        .where((Category c) => c.id == null || !forbidden.contains(c.id))
        .toList();
  }

  List<DropdownMenuItem<int?>> _buildParentItems() {
    final List<DropdownMenuItem<int?>> items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(
        value: null,
        child: Text('无（作为根分类）'),
      ),
      for (final Category c in _parentCandidates)
        DropdownMenuItem<int?>(
          value: c.id,
          child: Text(c.name),
        ),
    ];
    // 兜底：当前 parentId 指向已失效（被删）的分类时，补一个占位项，
    // 避免 value 不在 items 中触发 DropdownButton 断言。
    if (_parentId != null &&
        !_parentCandidates.any((Category c) => c.id == _parentId)) {
      items.add(
        DropdownMenuItem<int?>(
          value: _parentId,
          child: Text('(失效父级 #$_parentId)'),
        ),
      );
    }
    return items;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final Category category = Category(
      id: widget.initial?.id,
      name: _nameCtrl.text.trim(),
      colorHex: _colorHex,
      iconName: _iconName,
      createEntityFolder: false, // D2：仅逻辑归类
      parentId: _parentId,
      sortOrder: widget.initial?.sortOrder ?? 0,
    );
    widget.onSubmit(category);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        // 内容（色板 + 图标网格 + 表单项）可能超过一屏，必须可滚动，
        // 否则底部「保存」按钮会被挤出屏幕外且无法滚到（用户看不到确定键）。
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
            Text(widget.initial == null ? '新建分类' : '编辑分类',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '名称',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '请输入名称' : null,
            ),
            const SizedBox(height: 12),
            Text('颜色', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: googlePresetColorHexes.map((String hex) {
                final bool selected =
                    _colorHex.toLowerCase() == hex.toLowerCase();
                // M3 触控目标：视觉 36dp 圆点 + 48x48dp 点击区（透明补边）。
                return SizedBox(
                  width: 48,
                  height: 48,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _colorHex = hex),
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: parseColorHex(hex),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: selected
                          ? Icon(Icons.check,
                              color: contrastColorOn(parseColorHex(hex)),
                              size: 20)
                            : null,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('图标', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presetCategoryIcons.entries.map((e) {
                final bool selected = _iconName == e.key;
                return InkWell(
                  onTap: () => setState(() => _iconName = e.key),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      e.value,
                      color: selected
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            // 层级：选择父级分类（根分类可选"无"）。
            DropdownButtonFormField<int?>(
              value: _parentId,
              decoration: const InputDecoration(
                labelText: '父级分类（层级）',
                border: OutlineInputBorder(),
              ),
              hint: const Text('无（作为根分类）'),
              items: _buildParentItems(),
              onChanged: (int? v) => setState(() => _parentId = v),
            ),
            const SizedBox(height: 12),
            // D2：仅逻辑归类，禁用开关并说明。
            const SwitchListTile(
              value: false,
              onChanged: null,
              title: Text('创建实体文件夹'),
              subtitle: Text('仅逻辑归类（不建文件夹）'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _submit,
              child: const Text('保存'),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
