import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:work_photos/data/models/category.dart';
import 'package:work_photos/data/models/used_status.dart';
import 'package:work_photos/providers/category_provider.dart';
import 'package:work_photos/providers/photo_provider.dart';

/// 网格筛选条（B6）。
///
/// 选择"分类（含全部）"、"已用 / 未用 / 全部"状态、"按日期"与"星期几"，
/// 写入 [gridFilterProvider]；[PhotoGridPage] 据此作为 [photoListProvider] 的
/// family 参数过滤网格。各筛选条件相互独立、可叠加（取交集）。
class FilterBar extends ConsumerWidget {
  const FilterBar({super.key});

  /// 星期几标签（周一至周日），索引 i 对应 [DateTime.weekday] = i+1。
  static const List<String> _weekdayLabels = <String>[
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '日',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PhotoFilter filter = ref.watch(gridFilterProvider);
    // 分类按全局排序模式（默认名称升序）展示。
    final List<Category> cats = ref.watch(sortedCategoryListProvider);
    // 原始流：仅用于 loading / error 判定——sortedCategoryListProvider 把
    // 二者都压成空列表，直接用它判空会在冷启动/出错时误渲染成「无分类」。
    final AsyncValue<List<Category>> catsAsync =
        ref.watch(categoryListProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: <Widget>[
          // 三个分类芯片互斥，唯一真相是 (categoryId, onlyUncategorized) 的组合：
          // - 全部分类：categoryId == null && !onlyUncategorized
          // - 某个分类：categoryId == id   && !onlyUncategorized
          // - 未分类  ：categoryId == null &&  onlyUncategorized
          // 判据里必须同时看两个字段，否则「未分类」选中时「全部分类」也会
          // 一起高亮（两者 categoryId 都是 null）。
          _chip(
            '全部分类',
            filter.categoryId == null && !filter.onlyUncategorized,
            () => _setCategory(ref, null),
          ),
          _chip(
            '未分类',
            filter.categoryId == null && filter.onlyUncategorized,
            () => _setCategory(ref, null, onlyUncategorized: true),
          ),
          // 加载中 / 加载失败：不渲染分类芯片（避免闪「无分类」或空白）。
          if (catsAsync.isLoading || catsAsync.hasError)
            const SizedBox.shrink()
          else
            for (final Category c in cats)
              _chip(
                c.name,
                // 具体分类要求 onlyUncategorized == false：切到某个分类时
                // 必须同时清掉「未分类」，两者不会同时高亮。
                filter.categoryId == c.id && !filter.onlyUncategorized,
                () => _setCategory(ref, c.id),
              ),
          const VerticalDivider(width: 16),
          _chip('全部状态', filter.status == null,
              () => _setStatus(ref, null)),
          _chip('已用', filter.status == UsedStatus.used,
              () => _setStatus(ref, UsedStatus.used)),
          _chip('未用', filter.status == UsedStatus.unused,
              () => _setStatus(ref, UsedStatus.unused)),
          const VerticalDivider(width: 16),
          _dateChip(context, ref, filter),
          for (int i = 0; i < _weekdayLabels.length; i++)
            _weekdayChip(ref, filter, i + 1, _weekdayLabels[i]),
        ],
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => onTap(),
      ),
    );
  }

  /// 日期筛选芯片：未选时显示"按日期"，选中后显示 M/D 并再次点击清除。
  Widget _dateChip(BuildContext context, WidgetRef ref, PhotoFilter filter) {
    final String label =
        filter.date == null ? '按日期' : '${filter.date!.month}/${filter.date!.day}';
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: filter.date != null,
        onSelected: (_) async {
          if (filter.date != null) {
            _setDate(ref, null);
            return;
          }
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime.now(),
          );
          if (picked != null) _setDate(ref, picked);
        },
      ),
    );
  }

  Widget _weekdayChip(
      WidgetRef ref, PhotoFilter filter, int weekday, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: filter.weekday == weekday,
        onSelected: (_) =>
            _setWeekday(ref, filter.weekday == weekday ? null : weekday),
      ),
    );
  }

  // —— 以下各 setter 在更新单一字段时保留其它筛选条件 ——

  /// 设置分类维度：「全部分类」/「未分类」/「某个分类」三态互斥。
  ///
  /// 统一在这里落「未分类」开关，避免每个调用点各写一遍导致状态组合非法
  /// （例如 categoryId=null 但 onlyUncategorized 没被清掉）。
  /// - `categoryId == null && !onlyUncategorized` → 全部分类
  /// - `categoryId == null && onlyUncategorized` → 未分类
  /// - `categoryId != null` → 某个分类（onlyUncategorized 恒为 false）
  void _setCategory(WidgetRef ref, int? categoryId,
      {bool onlyUncategorized = false}) {
    final PhotoFilter f = ref.read(gridFilterProvider);
    ref.read(gridFilterProvider.notifier).state = PhotoFilter(
      categoryId: categoryId,
      status: f.status,
      date: f.date,
      weekday: f.weekday,
      onlyUncategorized: onlyUncategorized,
    );
  }

  void _setStatus(WidgetRef ref, UsedStatus? status) {
    final PhotoFilter f = ref.read(gridFilterProvider);
    ref.read(gridFilterProvider.notifier).state = PhotoFilter(
      categoryId: f.categoryId,
      status: status,
      date: f.date,
      weekday: f.weekday,
      onlyUncategorized: f.onlyUncategorized,
    );
  }

  void _setDate(WidgetRef ref, DateTime? date) {
    final PhotoFilter f = ref.read(gridFilterProvider);
    ref.read(gridFilterProvider.notifier).state = PhotoFilter(
      categoryId: f.categoryId,
      status: f.status,
      date: date,
      weekday: f.weekday,
      onlyUncategorized: f.onlyUncategorized,
    );
  }

  void _setWeekday(WidgetRef ref, int? weekday) {
    final PhotoFilter f = ref.read(gridFilterProvider);
    ref.read(gridFilterProvider.notifier).state = PhotoFilter(
      categoryId: f.categoryId,
      status: f.status,
      date: f.date,
      weekday: weekday,
      onlyUncategorized: f.onlyUncategorized,
    );
  }
}
