import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:work_photos/data/models/photo.dart';
import 'package:work_photos/providers/database_provider.dart';
import 'package:work_photos/providers/photo_provider.dart';

/// 一次搜索的条件（R9）：关键词 + 分类 + 日期范围。
///
/// 作为 [searchResultsProvider] 的 family 键，需实现相等性；
/// 日期取「天」粒度比较（忽略时分秒，与 [PhotoFilter] 同规则）。
class SearchQuery {
  final String keyword;
  final int? categoryId;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const SearchQuery({
    this.keyword = '',
    this.categoryId,
    this.dateFrom,
    this.dateTo,
  });

  /// 是否有任何生效条件：无条件的查询不发起数据库访问（显示初始引导态）。
  bool get isActive =>
      keyword.trim().isNotEmpty ||
      categoryId != null ||
      dateFrom != null ||
      dateTo != null;

  /// 日期的「天」粒度键（忽略时分秒）。
  static int? _dayKey(DateTime? d) =>
      d == null ? null : d.year * 10000 + d.month * 100 + d.day;

  SearchQuery copyWith({
    String? keyword,
    int? categoryId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) =>
      SearchQuery(
        keyword: keyword ?? this.keyword,
        categoryId: categoryId ?? this.categoryId,
        dateFrom: dateFrom ?? this.dateFrom,
        dateTo: dateTo ?? this.dateTo,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchQuery &&
          keyword == other.keyword &&
          categoryId == other.categoryId &&
          _dayKey(dateFrom) == _dayKey(other.dateFrom) &&
          _dayKey(dateTo) == _dayKey(other.dateTo);

  @override
  int get hashCode =>
      keyword.hashCode ^
      categoryId.hashCode ^
      _dayKey(dateFrom).hashCode ^
      _dayKey(dateTo).hashCode;
}

/// 搜索页当前条件（UI 输入写入，防抖后更新触发结果刷新）。
final searchQueryProvider = StateProvider<SearchQuery>(
    (ref) => const SearchQuery());

/// 搜索结果（一次性查询，条件变化时重新执行）。
///
/// 无条件时直接返回空列表（UI 显示初始引导），不发 SQL；
/// 有条件时走 [PhotoRepository.search]（关键词含分类名匹配）。
final searchResultsProvider =
    FutureProvider.autoDispose.family<List<Photo>, SearchQuery>((ref, q) {
  if (!q.isActive) return Future<List<Photo>>.value(const <Photo>[]);
  final repo = ref.watch(photoRepositoryProvider);
  return repo.search(
    keyword: q.keyword.trim().isEmpty ? null : q.keyword.trim(),
    categoryId: q.categoryId,
    dateFrom: q.dateFrom,
    dateTo: q.dateTo,
  );
});
