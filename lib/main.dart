import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:work_photos/app.dart';
import 'package:work_photos/core/utils/perf_tracker.dart';
import 'package:work_photos/data/db/app_database.dart';
import 'package:work_photos/data/metrics/usage_log.dart';
import 'package:work_photos/providers/database_provider.dart';

// 兼容 B1：保留对 main 库的再导出，便于既有
// `import 'package:work_photos/main.dart'` 仍能取到 appDatabaseProvider。
export 'package:work_photos/providers/database_provider.dart'
    show appDatabaseProvider;

void main() {
  // 初始化 Flutter 绑定（数据库 / 插件在 runApp 前需确保已初始化）。
  WidgetsFlutterBinding.ensureInitialized();

  // T4.2/R15：性能追踪（冷启动计时 + 帧率统计，仅线下输出）。
  PerfTracker.install();
  // T4.5/R17：线下度量（参与度指标：启动事件；失败静默不影响启动）。
  UsageLog.instance.log('app_open');

  final AppDatabase db = AppDatabase();

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: const App(),
    ),
  );
}
