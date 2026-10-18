import 'package:drift/drift.dart';

import 'package:work_photos/data/db/app_database.dart';
import 'package:work_photos/data/db/tables/photos.dart';
import 'package:work_photos/data/db/tables/photo_category.dart';

part 'photo_dao.g.dart';

/// 排序 / 日期筛选取用的「展示时间」表达式：优先拍摄时间（shot_at），
/// 缺失时回退导入时间（created_at）。
///
/// 必须用 COALESCE 而不是直接按 shot_at 排：老数据 shot_at 为 null，
/// 直接排序会让它们全部沉到列表末尾（NULL 在倒序里排最后），
/// 与领域模型 Photo.displayTime 的语义也不一致。
Expression<DateTime> _shotOrCreated(Photos t) =>
    coalesce<DateTime>(<Expression<DateTime>>[t.shotAt, t.createdAt]);

/// 照片数据访问对象（DAO）。
///
/// 负责照片表的复杂查询（按分类 / 已用状态 / 组合过滤）与写操作。
/// 多对多关联通过 join [PhotoCategory] 实现（设计决策 D1）。
@DriftAccessor(tables: [Photos, PhotoCategory])
class PhotoDao extends DatabaseAccessor<AppDatabase>
    with _$PhotoDaoMixin {
  /// 构造时绑定所属数据库。
  PhotoDao(super.db);

  /// 「未归入任何分类」条件：`photos.id NOT IN (SELECT photo_id FROM ...)`。
  ///
  /// 为什么用 NOT IN 子查询，而不是 `LEFT JOIN photo_category + IS NULL`：
  /// - 分类路径（`categoryId != null`）本身已经 `innerJoin` 了 photo_category，
  ///   一张照片属于 N 个分类就产生 N 行；再 LEFT JOIN 一次会把行数乘成 N×M，
  ///   必须 `DISTINCT`/去重才能还原，而 drift 的 joined 查询是
  ///   `row.readTable(photos)` 逐行映射——**重复行会直接变成重复的网格项**
  ///   （用户看到同一张照片出现多次），后续还要在 DAO 外层去重，容易漏；
  /// - 子查询不改变外层结果集的行数（每张照片仍是一行），因此不影响既有的
  ///   `ORDER BY COALESCE(shot_at, created_at) DESC` 与 `limit`，也不需要
  ///   在任何调用点做去重；
  /// - 性能上 NOT IN 与 LEFT JOIN + IS NULL 在本数据量级等价（两表都只有
  ///   索引列参与），但前者语义更直白。
  ///
  /// 流式刷新：子查询是写进**同一个** [GenerationContext] 的
  /// （`_InSelectExpression._writeValues` → `_select.writeInto(context)`，
  /// 而 `writeResultSet` 会把子查询的 FROM 表加进 `context.watchedTables`），
  /// 所以 photo_category 一变，网格流会自动重算——不需要手动 invalidate。
  Expression<bool> _uncategorized() => photos.id.isNotInQuery(
        selectOnly(photoCategory)
          ..addColumns(<Expression<Object>>[photoCategory.photoId]),
      );

  /// 插入一条照片记录，返回自增主键。
  Future<int> insert(PhotosCompanion companion) =>
      into(photos).insert(companion);

  /// 查询全部照片。
  Future<List<PhotoRow>> all() => select(photos).get();

  /// 按主键取一条照片记录（不存在返回 null）。供详情页 [PhotoRepository.futureById] 使用。
  Future<PhotoRow?> byId(int id) =>
      (select(photos)..where((p) => p.id.equals(id))).getSingleOrNull();

  /// 按分类查询（多对多 join [PhotoCategory]）。
  Future<List<PhotoRow>> byCategory(int categoryId) {
    final query = select(photos).join([
      innerJoin(
        photoCategory,
        photoCategory.photoId.equalsExp(photos.id),
      ),
    ]);
    query.where(photoCategory.categoryId.equals(categoryId));
    return query.map((row) => row.readTable(photos)).get();
  }

  /// 按已用状态查询。
  Future<List<PhotoRow>> byUsedStatus(int usedStatus) =>
      (select(photos)..where((p) => p.usedStatus.equals(usedStatus))).get();

  /// 组合过滤：可选分类 + 可选已用状态。
  Future<List<PhotoRow>> byFilter({int? categoryId, int? usedStatus}) {
    if (categoryId != null) {
      final query = select(photos).join([
        innerJoin(
          photoCategory,
          photoCategory.photoId.equalsExp(photos.id),
        ),
      ]);
      Expression<bool> filter = photoCategory.categoryId.equals(categoryId);
      if (usedStatus != null) {
        filter = filter & photos.usedStatus.equals(usedStatus);
      }
      query.where(filter);
      return query.map((row) => row.readTable(photos)).get();
    }
    final query = select(photos);
    if (usedStatus != null) {
      query.where((p) => p.usedStatus.equals(usedStatus));
    }
    return query.get();
  }

  /// [byFilter] 的流式版本，供 Repository 实时刷新（相册网格的唯一数据源）。
  ///
  /// 排序：`COALESCE(shot_at, created_at)` 倒序（最新拍摄在前），同一秒
  /// 连拍 / 同批导入再按 id 倒序兜底，保证顺序稳定不抖动。
  ///
  /// [onlyUncategorized]：仅「未归入任何分类」的照片（筛选条「未分类」）。
  /// 与 [categoryId] 语义互斥；若调用方同时传了两者，结果是空集
  /// （显式与运算，而不是悄悄忽略其中一个条件）。
  Stream<List<PhotoRow>> watchByFilter({
    int? categoryId,
    int? usedStatus,
    bool onlyUncategorized = false,
  }) {
    if (categoryId != null) {
      final query = select(photos).join([
        innerJoin(
          photoCategory,
          photoCategory.photoId.equalsExp(photos.id),
        ),
      ]);
      Expression<bool> filter = photoCategory.categoryId.equals(categoryId);
      if (usedStatus != null) {
        filter = filter & photos.usedStatus.equals(usedStatus);
      }
      if (onlyUncategorized) {
        filter = filter & _uncategorized();
      }
      query.where(filter);
      query.orderBy(<OrderingTerm>[
        OrderingTerm(
            expression: _shotOrCreated(photos), mode: OrderingMode.desc),
        OrderingTerm(expression: photos.id, mode: OrderingMode.desc),
      ]);
      return query.map((row) => row.readTable(photos)).watch();
    }
    final query = select(photos);
    Expression<bool>? cond;
    if (usedStatus != null) {
      cond = photos.usedStatus.equals(usedStatus);
    }
    if (onlyUncategorized) {
      // 简单分支同样要加：否则「未分类 + 已用/未用」这一类不带 categoryId
      // 的组合会静默退化成不过滤（两条路径必须口径一致）。
      final Expression<bool> un = _uncategorized();
      cond = cond == null ? un : (cond & un);
    }
    if (cond != null) query.where(cond);
    query.orderBy(<OrderingTerm Function(Photos)>[
      (Photos p) =>
          OrderingTerm(expression: _shotOrCreated(p), mode: OrderingMode.desc),
      (Photos p) => OrderingTerm(expression: p.id, mode: OrderingMode.desc),
    ]);
    return query.watch();
  }

  /// 全局搜索（R9）：关键词（标题/备注/来源相册）+ 命中分类名的分类 + 日期范围。
  ///
  /// - [keyword]：子串匹配（SQLite LIKE，ASCII 大小写不敏感；通配符 %/_/\
  ///   已转义，避免用户输入被当模式解析）；
  /// - [nameMatchedCategoryIds]：名称命中关键词的分类 id 列表（由仓储层用
  ///   分类全表算出，分类表不在本 DAO 注册；与关键词之间为 OR 关系——
  ///   关键词命中照片任一文本字段 **或** 命中其任一所属分类名）；
  /// - [categoryId]：显式分类过滤（UI 下拉选择，与其它条件取交集）；
  /// - [dateFrom] / [dateTo]：拍摄日期闭区间（dateTo 含当天）。
  /// - [limit]：结果上限（防极端关键词全表返回拖垮 UI）。
  ///
  /// 实现要点：LEFT JOIN photo_category 保证无分类照片也能被关键词命中；
  /// 一张照片可属多分类会重复出现，按 id 去重（保持
  /// `COALESCE(shot_at, created_at)` 倒序）。
  Future<List<PhotoRow>> search({
    String? keyword,
    List<int> nameMatchedCategoryIds = const <int>[],
    int? categoryId,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 300,
  }) {
    final query = select(photos).join(<Join>[
      leftOuterJoin(
        photoCategory,
        photoCategory.photoId.equalsExp(photos.id),
      ),
    ]);

    Expression<bool>? cond;
    if (keyword != null && keyword.isNotEmpty) {
      final String esc = keyword
          .replaceAll('\\', '\\\\')
          .replaceAll('%', '\\%')
          .replaceAll('_', '\\_');
      Expression<bool> kw = photos.title.like('%$esc%', escapeChar: r'\') |
          photos.note.like('%$esc%', escapeChar: r'\') |
          photos.sourceAlbum.like('%$esc%', escapeChar: r'\');
      if (nameMatchedCategoryIds.isNotEmpty) {
        kw = kw | photoCategory.categoryId.isIn(nameMatchedCategoryIds);
      }
      cond = kw;
    } else if (nameMatchedCategoryIds.isNotEmpty) {
      cond = photoCategory.categoryId.isIn(nameMatchedCategoryIds);
    }
    if (categoryId != null) {
      final Expression<bool> cat = photoCategory.categoryId.equals(categoryId);
      cond = cond == null ? cat : (cond & cat);
    }
    if (dateFrom != null) {
      final DateTime from =
          DateTime(dateFrom.year, dateFrom.month, dateFrom.day);
      final Expression<bool> fromCond =
          _shotOrCreated(photos).isBiggerOrEqualValue(from);
      cond = cond == null ? fromCond : (cond & fromCond);
    }
    if (dateTo != null) {
      final DateTime toExclusive = DateTime(dateTo.year, dateTo.month,
              dateTo.day)
          .add(const Duration(days: 1));
      final Expression<bool> toCond =
          _shotOrCreated(photos).isSmallerThanValue(toExclusive);
      cond = cond == null ? toCond : (cond & toCond);
    }
    if (cond != null) query.where(cond);
    query.orderBy(<OrderingTerm>[
      OrderingTerm(
          expression: _shotOrCreated(photos), mode: OrderingMode.desc),
      OrderingTerm(expression: photos.id, mode: OrderingMode.desc),
    ]);
    query.limit(limit);
    return query.get().then((List<TypedResult> rows) {
      final Set<int> seen = <int>{};
      final List<PhotoRow> out = <PhotoRow>[];
      for (final TypedResult row in rows) {
        final PhotoRow p = row.readTable(photos);
        if (seen.add(p.id)) out.add(p);
      }
      return out;
    });
  }

  /// 标记照片为已用 / 未用，并刷新 [updatedAt]。
  Future<void> markUsed(int photoId, bool used) =>
      (update(photos)..where((p) => p.id.equals(photoId))).write(
        PhotosCompanion(
          usedStatus: Value(used ? 1 : 0),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// 更新照片备注（纯文本，可空），并刷新 [updatedAt]。
  Future<void> updateNote(int photoId, String? note) =>
      (update(photos)..where((p) => p.id.equals(photoId))).write(
        PhotosCompanion(
          note: Value(note),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// 按主键批量删除照片，并清理其多对多关联（事务内）。
  ///
  /// 用于「相册」多选删除：同时移除照片记录与 [photoCategory] 关联，
  /// 保证两张表的一致性。
  Future<void> deleteByIds(List<int> ids) {
    if (ids.isEmpty) return Future.value();
    return transaction(() async {
      await (delete(photoCategory)..where((pc) => pc.photoId.isIn(ids))).go();
      await (delete(photos)..where((p) => p.id.isIn(ids))).go();
    });
  }

  /// 删除不在 [keepIds] 中的照片，并清理其多对多关联。
  ///
  /// 在事务中执行，保证照片与关联表的一致性。
  Future<void> deleteMissingExcept(Set<int> keepIds) {
    return transaction(() async {
      if (keepIds.isEmpty) {
        await delete(photos).go();
        await delete(photoCategory).go();
        return;
      }
      await (delete(photos)..where((p) => p.id.isNotIn(keepIds))).go();
      await (delete(photoCategory)
            ..where((pc) => pc.photoId.isNotIn(keepIds)))
          .go();
    });
  }
}
