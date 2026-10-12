import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:work_photos/data/db/app_database.dart';
// appDatabaseProvider 定义于 providers/database_provider.dart。
import 'package:work_photos/providers/database_provider.dart';
import 'package:work_photos/data/models/category.dart';
import 'package:work_photos/data/repositories/category_repository.dart';
import 'package:work_photos/features/classify/category_sort.dart';
import 'package:work_photos/features/me/settings_provider.dart';

/// 分类仓储 Provider。
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return CategoryRepository(db);
});

/// 分类列表（流式，实时刷新；数据库顺序 = 手动拖拽的 sortOrder）。
final categoryListProvider = StreamProvider<List<Category>>((ref) {
  final CategoryRepository repo = ref.watch(categoryRepositoryProvider);
  return repo.watchAll();
});

/// 当前分类排序模式（跟随设置，跨会话持久化）。
final categorySortModeProvider = Provider<String>((ref) {
  return ref.watch(settingsProvider).categorySortMode;
});

/// 按当前排序模式排好的分类列表（全局消费方统一用它，保证
/// 相册筛选条 / 分类管理页 / 分类表单 / 分配面板顺序一致）。
///
/// 流式列表每次发射都会按最新模式重排（设置切换即时生效）。
final sortedCategoryListProvider = Provider<List<Category>>((ref) {
  final List<Category> flat =
      ref.watch(categoryListProvider).valueOrNull ?? const <Category>[];
  return sortCategories(flat, ref.watch(categorySortModeProvider));
});
