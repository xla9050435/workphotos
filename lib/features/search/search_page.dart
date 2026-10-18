import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:work_photos/data/metrics/usage_log.dart';
import 'package:work_photos/data/models/category.dart';
import 'package:work_photos/data/models/photo.dart';
import 'package:work_photos/features/search/search_provider.dart';
import 'package:work_photos/providers/category_provider.dart';
import 'package:work_photos/providers/photo_provider.dart';
import 'package:work_photos/widgets/status_views.dart';
import 'package:work_photos/widgets/thumbnail.dart';

/// 全局搜索页（R9）。
///
/// 关键词（照片标题 / 备注 / 来源相册 / 分类名）+ 分类下拉 + 日期范围
/// 组合检索；关键词输入 300ms 防抖后触发查询。结果按拍摄日期倒序，
/// 点击进入详情页（可左右滑动浏览全部结果）。
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _kwCtrl = TextEditingController();
  Timer? _debounce;

  /// 已记录过结果的查询键（T4.5 度量：每次查询只记一次，供
  /// Task success 指标 = resultCount>0 占比）。
  final Set<String> _loggedQueries = <String>{};

  @override
  void initState() {
    super.initState();
    // 回到本页时恢复上次关键词（provider 是全局状态）。
    _kwCtrl.text = ref.read(searchQueryProvider).keyword;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _kwCtrl.dispose();
    super.dispose();
  }

  /// 关键词输入：300ms 防抖后写入 [searchQueryProvider] 触发检索，
  /// 避免每个字符都打一次数据库。
  void _onKeywordChanged(String value) {
    setState(() {}); // 刷新清空按钮显隐
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final SearchQuery q = ref.read(searchQueryProvider);
      ref.read(searchQueryProvider.notifier).state =
          SearchQuery(keyword: value, categoryId: q.categoryId,
              dateFrom: q.dateFrom, dateTo: q.dateTo);
    });
  }

  SearchQuery _withCategory(SearchQuery q, int? categoryId) => SearchQuery(
        keyword: q.keyword,
        categoryId: categoryId,
        dateFrom: q.dateFrom,
        dateTo: q.dateTo,
      );

  Future<void> _pickDate({required bool isFrom}) async {
    final SearchQuery q = ref.read(searchQueryProvider);
    final DateTime initial = (isFrom ? q.dateFrom : q.dateTo) ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    ref.read(searchQueryProvider.notifier).state = SearchQuery(
      keyword: q.keyword,
      categoryId: q.categoryId,
      dateFrom: isFrom ? picked : q.dateFrom,
      dateTo: isFrom ? q.dateTo : picked,
    );
  }

  /// 结果行日期：yyyy-MM-dd HH:mm。
  static String _fmtDate(DateTime d) {
    final String mm = d.month.toString().padLeft(2, '0');
    final String dd = d.day.toString().padLeft(2, '0');
    final String hh = d.hour.toString().padLeft(2, '0');
    final String mi = d.minute.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd $hh:$mi';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final SearchQuery query = ref.watch(searchQueryProvider);
    // 原始流：仅用于判断是否仍在加载 / 加载失败。
    final AsyncValue<List<Category>> catsAsync =
        ref.watch(categoryListProvider);
    // 下拉候选：跟随全局分类排序模式（与筛选条 / 分类管理页一致）。
    final List<Category> cats = ref.watch(sortedCategoryListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: Column(
        children: <Widget>[
          // 关键词输入框。
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _kwCtrl,
              onChanged: _onKeywordChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '搜索标题、备注、来源相册或分类名',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _kwCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: '清空关键词',
                        onPressed: () {
                          _kwCtrl.clear();
                          _onKeywordChanged('');
                        },
                      ),
              ),
            ),
          ),
          // 筛选行：分类 + 日期范围 + 清除筛选。
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: query.categoryId,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: '分类',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: <DropdownMenuItem<int?>>[
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('全部分类'),
                      ),
                      // 加载中 / 出错时不渲染任何分类项，避免列表短暂为空
                      // 被读成「没有分类」；正常加载后按排序后的顺序渲染。
                      if (!catsAsync.isLoading && !catsAsync.hasError)
                        for (final Category c in cats)
                          DropdownMenuItem<int?>(
                              value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (int? v) {
                      ref.read(searchQueryProvider.notifier).state =
                          _withCategory(query, v);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // 起始 / 截止日期：选中后显示 M/D，长按或再次点击清除。
                OutlinedButton(
                  onPressed: () => _pickDate(isFrom: true),
                  onLongPress: () {
                    final SearchQuery q = ref.read(searchQueryProvider);
                    ref.read(searchQueryProvider.notifier).state = SearchQuery(
                      keyword: q.keyword,
                      categoryId: q.categoryId,
                      dateFrom: null,
                      dateTo: q.dateTo,
                    );
                  },
                  child: Text(query.dateFrom == null
                      ? '起始日期'
                      : '${query.dateFrom!.month}/${query.dateFrom!.day}'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _pickDate(isFrom: false),
                  onLongPress: () {
                    final SearchQuery q = ref.read(searchQueryProvider);
                    ref.read(searchQueryProvider.notifier).state = SearchQuery(
                      keyword: q.keyword,
                      categoryId: q.categoryId,
                      dateFrom: q.dateFrom,
                      dateTo: null,
                    );
                  },
                  child: Text(query.dateTo == null
                      ? '截止日期'
                      : '${query.dateTo!.month}/${query.dateTo!.day}'),
                ),
              ],
            ),
          ),
          // 结果区。
          Expanded(
            child: !query.isActive
                ? const AppEmptyState(
                    icon: Icons.search,
                    title: '搜索照片',
                    message: '输入关键词，或选择分类 / 日期范围开始检索',
                  )
                : ref
                    .watch(searchResultsProvider(query))
                    .when(
                      data: (List<Photo> results) {
                        // T4.5/R17：本地度量（每次查询只记一次）。
                        final String qKey = query.hashCode.toString();
                        if (!_loggedQueries.contains(qKey)) {
                          _loggedQueries.add(qKey);
                          UsageLog.instance.log('search_performed',
                              params: <String, Object?>{
                                'resultCount': results.length,
                                'hasCategory': query.categoryId != null,
                                'hasDateRange': query.dateFrom != null ||
                                    query.dateTo != null,
                              });
                        }
                        if (results.isEmpty) {
                          return const AppEmptyState(
                            icon: Icons.search_off,
                            title: '没有找到匹配的照片',
                            message: '试试更换关键词，或减少筛选条件',
                          );
                        }
                        final List<int> ids = <int>[
                          for (final Photo p in results)
                            if (p.id != null) p.id!,
                        ];
                        return Column(
                          children: <Widget>[
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '找到 ${results.length} 张照片',
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: ListView.separated(
                                itemCount: results.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (BuildContext context, int i) {
                                  final Photo p = results[i];
                                  return _SearchResultTile(
                                    photo: p,
                                    // 展示时间与结果排序键一致（拍摄时间优先），
                                    // 否则列表看起来像乱序。
                                    dateLabel: _fmtDate(p.displayTime),
                                    photoIds: ids,
                                    index: ids.indexOf(p.id ?? -1),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (Object e, _) => AppErrorState(
                        message: '搜索失败：$e',
                        retryLabel: '重试',
                        onRetry: () => ref
                            .invalidate(searchResultsProvider(query)),
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

/// 搜索结果行：缩略图 + 主标题（备注 / 来源相册）+ 副标题（日期 · 已用状态）。
class _SearchResultTile extends StatelessWidget {
  final Photo photo;
  final String dateLabel;
  final List<int> photoIds;
  final int index;

  const _SearchResultTile({
    required this.photo,
    required this.dateLabel,
    required this.photoIds,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String title = (photo.note != null && photo.note!.trim().isNotEmpty)
        ? photo.note!.trim()
        : (photo.sourceAlbum ?? '未命名照片');
    return ListTile(
      leading: SizedBox(
        width: 56,
        height: 56,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              PhotoThumbnail(photo: photo, size: 200),
              // 视频标识：右下角播放小三角（搜索结果混排时区分类型）。
              if (photo.isVideo)
                const Positioned(
                  right: 3,
                  bottom: 3,
                  child: Icon(Icons.play_circle_filled,
                      size: 16, color: Colors.white),
                ),
            ],
          ),
        ),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '$dateLabel${photo.isVideo && photo.durationLabel != null ? ' · 视频 ${photo.durationLabel}' : ''}'
        ' · ${photo.isUsed ? '已用' : '未用'}'
        '${photo.sourceAlbum != null && title != photo.sourceAlbum ? ' · ${photo.sourceAlbum}' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
      ),
      trailing: photo.isUsed
          ? Icon(Icons.check_circle,
              color: scheme.primary, size: 20, semanticLabel: '已使用')
          : null,
      onTap: () {
        if (photo.id == null) return;
        context.push(
          '/photo/${photo.id}',
          extra: <String, dynamic>{'ids': photoIds, 'index': index},
        );
      },
    );
  }
}
