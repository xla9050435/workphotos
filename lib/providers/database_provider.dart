import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:work_photos/data/db/app_database.dart';

/// 全局数据库 Provider。
///
/// 真实实例在 `main` 中通过 [ProviderScope] 的 `overrideWithValue` 注入，
/// 避免在 Provider 构造期直接创建数据库（此处默认抛 [UnimplementedError]）。
///
/// B2 起从 `main.dart` 抽到独立模块，以便仓储层 / 各 Provider 复用，
/// 并消除 `main` ↔ `providers` 之间的导入环。
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError(
    'appDatabaseProvider 必须在 main 中通过 overrideWithValue 注入真实实例',
  );
});
