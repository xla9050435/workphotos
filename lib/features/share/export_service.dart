import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:work_photos/core/utils/file_helper.dart';
import 'package:work_photos/data/models/photo.dart';
import 'package:work_photos/features/share/packer/pdf_packer.dart';
import 'package:work_photos/features/share/packer/zip_packer.dart';

/// 导出到本机（T4.4 / R16）。
///
/// 与分享面板共用 PDF / ZIP 打包器；产物写入公共下载目录
/// `/storage/emulated/0/Download`，失败（个别 ROM 的分区存储限制）
/// 降级到应用文档目录 `exports/`，并在返回值中注明实际落盘位置。
enum ExportFormat { pdf, zip }

class ExportService {
  ExportService._();

  /// 导出到本机，返回实际写入的文件与是否成功落入公共下载目录。
  ///
  /// [onSkip]：失效引用（源文件缺失）被跳过的张数回调。
  static Future<({File file, bool inPublicDownload, int skipped})> export(
    List<Photo> photos,
    ExportFormat format, {
    void Function(int skipped)? onSkip,
  }) async {
    // 1) 打包到临时目录（复用既有打包器）。
    final (_, int skipped) = await _resolveFiles(photos);
    onSkip?.call(skipped);
    final Directory tmp = await FileHelper.getTempDir();
    final File packed = format == ExportFormat.pdf
        ? await PdfPacker.build(photos, tmp)
        : await ZipPacker.build(photos, tmp);

    // 2) 尝试落到公共下载目录（用户在文件管理器里最容易找到）。
    final Directory download = Directory('/storage/emulated/0/Download');
    if (await _canWrite(download)) {
      final File target = File(p.join(
          download.path, p.basename(packed.path)));
      try {
        await packed.copy(target.path);
        return (file: target, inPublicDownload: true, skipped: skipped);
      } catch (_) {
        // 复制失败继续走降级。
      }
    }

    // 3) 降级：应用文档目录 exports/（应用私有，但可用系统分享转存）。
    final Directory docs = await FileHelper.getDocumentsDirForExport();
    final File target =
        File(p.join(docs.path, p.basename(packed.path)));
    await packed.copy(target.path);
    return (file: target, inPublicDownload: false, skipped: skipped);
  }

  static Future<bool> _canWrite(Directory dir) async {
    try {
      if (!await dir.exists()) return false;
      final File probe = File(p.join(dir.path,
          '.work_photos_probe_${DateTime.now().millisecondsSinceEpoch}'));
      await probe.writeAsString('');
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 解析全部照片文件并统计失效张数（与 SharePanel 同规则）。
  static Future<(List<File>, int)> _resolveFiles(List<Photo> photos) async {
    final List<File> files = <File>[];
    int skipped = 0;
    for (final Photo photo in photos) {
      final File? f = await photo.resolveFile();
      if (f == null) {
        skipped++;
      } else {
        files.add(f);
      }
    }
    return (files, skipped);
  }
}
