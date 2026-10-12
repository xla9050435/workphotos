import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';

import 'package:work_photos/data/db/app_database.dart';
// appDatabaseProvider 定义于 providers/database_provider.dart。
import 'package:work_photos/providers/database_provider.dart';

/// B1 验收用调试主页。
///
/// 职责（仅在为空时执行一次，避免重复插入）：
/// 1. 初始化数据库（通过 [appDatabaseProvider] 获取 [AppDatabase]）；
/// 2. 若分类表为空，插入一条示例分类；
/// 3. 若照片表为空，插入一条示例照片；
/// 4. 读取照片总数 / 分类总数 / 示例照片已用状态并展示。
class DebugHome extends ConsumerStatefulWidget {
  const DebugHome({super.key});

  @override
  ConsumerState<DebugHome> createState() => _DebugHomeState();
}

class _DebugHomeState extends ConsumerState<DebugHome> {
  bool _dbReady = false;
  int _photoCount = 0;
  int _categoryCount = 0;
  String _sampleUsedStatus = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _initDemoData();
  }

  Future<void> _initDemoData() async {
    try {
      final AppDatabase db = ref.read(appDatabaseProvider);

      // 仅当分类表为空时插入示例分类。
      final catCount = await db.countCategories();
      if (catCount == 0) {
        await db.insertCategory(
          CategoriesCompanion.insert(
          name: '示例分类',
          colorHex: '#4CAF50',
          iconName: 'folder',
          createdAt: DateTime.now(),
          ),
        );
      }

      // 仅当照片表为空时插入示例照片。
      final photoCount = await db.countPhotos();
      if (photoCount == 0) {
        await db.insertPhoto(
          PhotosCompanion.insert(
            mediaRefValue: 'content://example',
            mediaRefType: 'uri',
            usedStatus: const Value(0),
            sourceAlbum: const Value('demo'),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }

      // 读取统计信息用于展示。
      _photoCount = await db.countPhotos();
      _categoryCount = await db.countCategories();

      final photos = await db.getAllPhotos();
      if (photos.isNotEmpty) {
        _sampleUsedStatus = photos.first.usedStatus == 0 ? '未用' : '已用';
      }

      if (mounted) {
        setState(() {
          _dbReady = true;
        });
      }
    } catch (e, stack) {
      debugPrint('DebugHome init error: $e\n$stack');
      if (mounted) {
        setState(() {
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Photo Manager · B1')),
      body: Center(
        child: _error != null
            ? Text('❌ 初始化失败：$_error',
                style: TextStyle(color: scheme.error))
            : !_dbReady
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('✅ 数据库初始化成功',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Text('照片总数：$_photoCount'),
                      Text('分类总数：$_categoryCount'),
                      Text('示例照片已用状态：$_sampleUsedStatus'),
                    ],
                  ),
      ),
    );
  }
}
