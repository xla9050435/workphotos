import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:work_photos/data/db/app_database.dart';
// appDatabaseProvider 定义于 providers/database_provider.dart。
import 'package:work_photos/providers/database_provider.dart';
import 'package:work_photos/data/models/category.dart';
import 'package:work_photos/data/repositories/category_repository.dart';

/// 分类仓储 Provider。
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return CategoryRepository(db);
});

/// 分类列表（流式，实时刷新）。
final categoryListProvider = StreamProvider<List<Category>>((ref) {
  final CategoryRepository repo = ref.watch(categoryRepositoryProvider);
  return repo.watchAll();
});
