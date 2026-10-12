import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:work_photos/data/db/app_database.dart';
// appDatabaseProvider 定义于 providers/database_provider.dart。
import 'package:work_photos/providers/database_provider.dart';
import 'package:work_photos/data/models/photo.dart';
import 'package:work_photos/data/models/used_status.dart';
import 'package:work_photos/data/repositories/photo_repository.dart';

/// 照片仓储 Provider。
final photoRepositoryProvider = Provider<PhotoRepository>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return PhotoRepository(db);
});

/// 照片列表过滤条件。
///
/// 作为 [photoListProvider] 的 family 键，需实现相等性。
///
/// - [categoryId] / [status]：分类与已用状态（仓储层 SQL 过滤）；
/// - [date] / [weekday]：按拍摄日期（同天）或星期几过滤（仓储层 Dart 过滤，
///   因数据库无星期列，且 [date] 需忽略时分秒比较，统一在映射后处理）。
class PhotoFilter {
  final int? categoryId;
  final UsedStatus? status;
  final DateTime? date;
  final int? weekday;

  const PhotoFilter({
    this.categoryId,
    this.status,
    this.date,
    this.weekday,
  });

  /// 日期的「天」粒度键（忽略时分秒），用于在 [==] / [hashCode] 中比较。
  static int? _dayKey(DateTime? d) =>
      d == null ? null : d.year * 10000 + d.month * 100 + d.day;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoFilter &&
          categoryId == other.categoryId &&
          status == other.status &&
          _dayKey(date) == _dayKey(other.date) &&
          weekday == other.weekday;

  @override
  int get hashCode =>
      categoryId.hashCode ^
      status.hashCode ^
      _dayKey(date).hashCode ^
      weekday.hashCode;
}

/// 照片列表（流式），按 [filter] 过滤。
final photoListProvider =
    StreamProvider.family<List<Photo>, PhotoFilter>((ref, filter) {
  final PhotoRepository repo = ref.watch(photoRepositoryProvider);
  return repo.watchByFilter(
    categoryId: filter.categoryId,
    status: filter.status,
    date: filter.date,
    weekday: filter.weekday,
  );
});

/// 网格页当前过滤条件（UI 可切换 全部 / 已用 / 未用）。
final gridFilterProvider =
    StateProvider<PhotoFilter>((ref) => const PhotoFilter());

/// 单张照片详情（按 id）。供 [PhotoDetailPage] 使用；标记已用后
/// 由页面 [ref.invalidate] 触发刷新。
final photoDetailProvider =
    FutureProvider.family<Photo?, int>((ref, int id) {
  final PhotoRepository repo = ref.watch(photoRepositoryProvider);
  return repo.futureById(id);
});
