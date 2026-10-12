import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:work_photos/data/db/app_database.dart';
import 'package:work_photos/data/db/tables/categories.dart';

/// 本地备份 / 恢复服务（T4.3 / R11）。
///
/// 设计决策（对齐 PRD §6）：**云端同步本期不做**（syncState 列预留不实现），
/// 仅本地备份。
///
/// 备份内容 = **元数据 JSON**（引用式架构：原图不拷贝任何字节，只备份
/// 引用关系 + 分类结构）。文件写入应用文档目录 `work_photos_backups/`
/// 子目录（应用私有存储，卸载才会清除）；分享出去由用户自行妥善保存。
///
/// 恢复语义（幂等合并）：
/// - 照片按 (mediaRefType, mediaRefValue) 自然键判重，已存在则跳过，
///   否则插入并映射新旧 id；
/// - 分类按名称判重（同名单分类取首个已存在的），两遍插入先建全部
///   分类再按名称映射父级，保证层级结构与备份一致；
/// - 关联按新 id 对重建（insertOrIgnore 幂等）。
class BackupService {
  final AppDatabase _db;

  BackupService(this._db);

  /// 备份文件存放目录（不存在则创建）。
  Future<Directory> backupDir() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory dir = Directory(p.join(docs.path, 'work_photos_backups'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 列出现有备份文件（按修改时间倒序）。
  Future<List<File>> listBackups() async {
    final Directory dir = await backupDir();
    final List<FileSystemEntity> entities = await dir.list().toList();
    final List<(File, DateTime)> pairs = <(File, DateTime)>[];
    for (final FileSystemEntity e in entities) {
      if (e is File && e.path.endsWith('.json')) {
        try {
          pairs.add((e, await e.lastModified()));
        } catch (_) {
          // 读不到修改时间的文件跳过（如正被占用）。
        }
      }
    }
    pairs.sort(((File, DateTime) a, (File, DateTime) b) =>
        b.$2.compareTo(a.$2));
    return <File>[for (final (File, DateTime) item in pairs) item.$1];
  }

  /// 导出一份新备份，返回备份文件与统计。
  Future<({File file, int photos, int categories, int links})> export() async {
    final List<PhotoRow> photos = await _db.photoDao.all();
    final List<CategoryRow> categories = await _db.categoryDao.getAll();
    final List<PhotoCategoryRow> links = await _db.photoCategoryDao.all();

    final Map<int, String> refKeyById = <int, String>{
      for (final PhotoRow row in photos)
        row.id: '${row.mediaRefType}:${row.mediaRefValue}',
    };
    final Map<int, String> nameById = <int, String>{
      for (final CategoryRow row in categories) row.id: row.name,
    };

    final Map<String, Object?> data = <String, Object?>{
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'photos': <Object?>[
        for (final PhotoRow row in photos)
          <String, Object?>{
            'refType': row.mediaRefType,
            'refValue': row.mediaRefValue,
            'title': row.title,
            'usedStatus': row.usedStatus,
            'note': row.note,
            'sourceAlbum': row.sourceAlbum,
            'createdAt': row.createdAt.toIso8601String(),
            'updatedAt': row.updatedAt.toIso8601String(),
          },
      ],
      'categories': <Object?>[
        for (final CategoryRow row in categories)
          <String, Object?>{
            'name': row.name,
            'colorHex': row.colorHex,
            'iconName': row.iconName,
            'parentName': row.parentId == null ? null : nameById[row.parentId],
            'sortOrder': row.sortOrder,
          },
      ],
      'links': <Object?>[
        for (final PhotoCategoryRow link in links)
          <String?>[
            refKeyById[link.photoId],
            nameById[link.categoryId],
          ],
      ],
    };

    final String stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .substring(0, 19);
    final File file = File(p.join(
        (await backupDir()).path, 'backup_$stamp.json'));
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    return (
      file: file,
      photos: photos.length,
      categories: categories.length,
      links: links.length,
    );
  }

  /// 从备份文件恢复（幂等合并），返回统计。
  Future<({int photosAdded, int categoriesAdded, int linksAdded})> restore(
      File file) async {
    final String raw = await file.readAsString();
    final Map<String, Object?> data =
        jsonDecode(raw) as Map<String, Object?>;

    final List<Object?> photos =
        (data['photos'] as List<Object?>? ?? <Object?>[]);
    final List<Object?> categories =
        (data['categories'] as List<Object?>? ?? <Object?>[]);
    final List<Object?> links =
        (data['links'] as List<Object?>? ?? <Object?>[]);

    int photosAdded = 0;
    int categoriesAdded = 0;
    int linksAdded = 0;

    await _db.transaction(() async {
      // 1) 照片：按 (type, value) 自然键判重。
      final Map<String, int> existingPhotoByRef = <String, int>{
        for (final PhotoRow row in await _db.photoDao.all())
          '${row.mediaRefType}:${row.mediaRefValue}': row.id,
      };
      final Map<String, int> refToId = <String, int>{
        ...existingPhotoByRef,
      };
      for (final Object? item in photos) {
        final Map<String, Object?> m = item! as Map<String, Object?>;
        final String key = '${m['refType']}:${m['refValue']}';
        if (refToId.containsKey(key)) continue;
        final int newId = await _db.photoDao.insert(PhotosCompanion.insert(
          mediaRefValue: m['refValue']! as String,
          mediaRefType: m['refType']! as String,
          title: Value(m['title'] as String?),
          usedStatus: Value((m['usedStatus'] as int? ?? 0)),
          note: Value(m['note'] as String?),
          sourceAlbum: Value(m['sourceAlbum'] as String?),
          createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ??
              DateTime.now(),
          updatedAt: DateTime.tryParse(m['updatedAt'] as String? ?? '') ??
              DateTime.now(),
        ));
        refToId[key] = newId;
        photosAdded++;
      }

      // 2) 分类：第一遍按名称判重插入（父级暂空），第二遍按名称映射父级。
      final Map<String, int> existingCategoryByName = <String, int>{
        for (final CategoryRow row in await _db.categoryDao.getAll())
          row.name: row.id,
      };
      final List<Map<String, Object?>> catItems = <Map<String, Object?>>[
        for (final Object? item in categories)
          item! as Map<String, Object?>,
      ];
      final Map<String, int> nameToId = <String, int>{
        ...existingCategoryByName,
      };
      for (final Map<String, Object?> m in catItems) {
        final String name = m['name']! as String;
        if (nameToId.containsKey(name)) continue;
        final int newId = await _db.categoryDao.insert(
          CategoriesCompanion.insert(
            name: name,
            colorHex: m['colorHex'] as String? ?? '#4CAF50',
            iconName: m['iconName'] as String? ?? 'folder',
            createEntityFolder: Value(false),
            sortOrder: Value(m['sortOrder'] as int? ?? 0),
            createdAt: DateTime.now(),
          ),
        );
        nameToId[name] = newId;
        categoriesAdded++;
      }
      for (final Map<String, Object?> m in catItems) {
        final String? parentName = m['parentName'] as String?;
        final int? parentId = parentName == null ? null : nameToId[parentName];
        final int selfId = nameToId[m['name']! as String]!;
        // 幂等写入父级（值相同则无实际变更）。
        await (_db.update(_db.categories)
              ..where((Categories c) => c.id.equals(selfId)))
            .write(CategoriesCompanion(parentId: Value(parentId)));
      }

      // 3) 关联：按新 id 对重建（insertOrIgnore 幂等）。
      for (final Object? item in links) {
        final List<Object?> pair = item! as List<Object?>;
        final String? refKey = pair[0] as String?;
        final String? catName = pair[1] as String?;
        if (refKey == null || catName == null) continue;
        final int? photoId = refToId[refKey];
        final int? categoryId = nameToId[catName];
        if (photoId == null || categoryId == null) continue;
        await _db.photoCategoryDao.assign(photoId, categoryId);
        linksAdded++;
      }
    });

    return (
      photosAdded: photosAdded,
      categoriesAdded: categoriesAdded,
      linksAdded: linksAdded,
    );
  }

  /// 删除一份备份文件。
  Future<void> deleteBackup(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}
