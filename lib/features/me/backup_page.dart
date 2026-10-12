import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:work_photos/data/backup/backup_service.dart';
import 'package:work_photos/data/metrics/usage_log.dart';
import 'package:work_photos/providers/database_provider.dart';

/// 备份与恢复页（T4.3 / R11）。
///
/// - 导出：把照片引用 + 分类结构（元数据 JSON）写入本地
///   `work_photos_backups/` 目录，并可经系统 Sharesheet 分享出去留存；
/// - 恢复：从列表中选择备份文件，幂等合并（已有引用/同名分类跳过）；
/// - 云端同步本期不做（设计决策）。
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  late final BackupService _service =
      BackupService(ref.read(appDatabaseProvider));
  List<File>? _backups;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final List<File> files = await _service.listBackups();
    if (!mounted) return;
    setState(() => _backups = files);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final (:File file, :int photos, :int categories, :int links) =
          await _service.export();
      await UsageLog.instance.log('backup_exported', params: <String, Object?>{
        'photos': photos,
        'categories': categories,
      });
      _snack('已导出：$photos 张照片 / $categories 个分类 / $links 条关联\n'
          '${file.path}');
      await _refresh();
    } catch (e) {
      _snack('导出失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share(File file) async {
    try {
      await Share.shareXFiles(
        <XFile>[XFile(file.path)],
        text: 'work_photos 备份（元数据）',
        subject: 'work_photos 备份',
      );
    } catch (_) {
      _snack('分享失败，请重试');
    }
  }

  Future<void> _restore(File file) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('恢复备份'),
        content: Text('将把「${_fileName(file)}」中的照片引用与分类结构合并到当前数据：\n\n'
            '· 已存在的引用 / 同名分类不会被覆盖\n'
            '· 仅补充缺失的记录与关联\n\n确定继续？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      final (:int photosAdded, :int categoriesAdded, :int linksAdded) =
          await _service.restore(file);
      await UsageLog.instance.log('backup_restored',
          params: <String, Object?>{
            'photos': photosAdded,
            'categories': categoriesAdded,
          });
      _snack('恢复完成：新增 $photosAdded 张照片 / '
          '$categoriesAdded 个分类 / $linksAdded 条关联');
    } catch (e) {
      _snack('恢复失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(File file) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('删除备份'),
        content: Text('确定删除「${_fileName(file)}」？此操作不可撤销。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _service.deleteBackup(file);
    _snack('已删除');
    await _refresh();
  }

  static String _fileName(File file) => file.uri.pathSegments.last;

  static String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('备份与恢复')),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                // 说明卡。
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '备份内容为照片引用与分类结构（元数据），不拷贝原图——'
                    '设备相册中的照片保持原样。建议导出后经「分享」留存到'
                    '网盘或电脑；恢复时按引用合并，不会覆盖现有数据。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.backup),
                  label: const Text('导出新备份'),
                  onPressed: _export,
                ),
                const SizedBox(height: 16),
                Text('现有备份', style: Theme.of(context).textTheme.titleSmall),
                if (_backups == null)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_backups!.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('暂无备份，点击上方按钮创建。')),
                  )
                else
                  for (final File file in _backups!)
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(_fileName(file)),
                      subtitle: FutureBuilder<FileStat>(
                        future: file.stat(),
                        builder: (BuildContext context, AsyncSnapshot<FileStat> snap) {
                          final FileStat? stat = snap.data;
                          if (stat == null) return const SizedBox.shrink();
                          final DateTime t = stat.modified;
                          return Text(
                            '${t.year}-${t.month.toString().padLeft(2, '0')}-'
                            '${t.day.toString().padLeft(2, '0')} '
                            '${t.hour.toString().padLeft(2, '0')}:'
                            '${t.minute.toString().padLeft(2, '0')} · '
                            '${_fmtSize(stat.size)}',
                          );
                        },
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            tooltip: '恢复',
                            icon: const Icon(Icons.restore),
                            onPressed: () => _restore(file),
                          ),
                          IconButton(
                            tooltip: '分享',
                            icon: const Icon(Icons.share),
                            onPressed: () => _share(file),
                          ),
                          IconButton(
                            tooltip: '删除',
                            icon: Icon(Icons.delete_outline,
                                color: scheme.error),
                            onPressed: () => _delete(file),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
    );
  }
}
