import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'package:work_photos/core/utils/file_helper.dart';
import 'package:work_photos/core/utils/video_mime.dart';
import 'package:work_photos/data/models/photo.dart';
import 'package:work_photos/features/share/export_service.dart';
import 'package:work_photos/features/share/packer/pdf_packer.dart';
import 'package:work_photos/features/share/packer/zip_packer.dart';

/// 分享面板（B5 + 视频支持）。
///
/// 接收一组 [Photo]（来自多选或详情页单张，可含视频），提供：
/// 1. 直接分享：逐张经 [MediaRef.resolveFile] 解析为 [File] → [XFile]，
///    按类型携带 MIME（image/* 或 video/*，混合时为 */*），经系统
///    Sharesheet [Share.shareXFiles] 调起（自动列出微信/QQ 等）；
/// 2. 打包 PDF 后分享（**视频自动跳过**——PDF 仅承载图片）；
/// 3. 打包 ZIP 后分享（视频原样进包，保留真实扩展名）。
/// 失效引用（resolveFile 返回 null）降级跳过，并提示被跳过的数量。
class SharePanel extends StatelessWidget {
  final List<Photo> photos;

  const SharePanel({super.key, required this.photos});

  /// 拉起底部弹层。
  static Future<void> show(BuildContext context, List<Photo> photos) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SharePanel(photos: photos),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('分享（共 ${photos.length} 项）',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('直接分享（系统 Sharesheet）'),
              onPressed: () => _shareDirect(context),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('打包为 PDF 后分享'),
              onPressed: () => _sharePdf(context),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.archive),
              label: const Text('打包为 ZIP 后分享'),
              onPressed: () => _shareZip(context),
            ),
            const SizedBox(height: 8),
            // 导出到本机（R16/T4.4）：不经 Sharesheet，直接落盘
            // 公共下载目录（不可写时降级应用目录并提示路径）。
            OutlinedButton.icon(
              icon: const Icon(Icons.save_alt),
              label: const Text('导出 PDF 到本机（下载目录）'),
              onPressed: () => _exportLocal(context, ExportFormat.pdf),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.save_alt),
              label: const Text('导出 ZIP 到本机（下载目录）'),
              onPressed: () => _exportLocal(context, ExportFormat.zip),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    );
  }

  /// 解析所有媒体文件，返回可读文件列表与被跳过的失效数量。
  Future<(List<File>, int)> _resolveFiles() async {
    final List<File> files = <File>[];
    int skipped = 0;
    for (final Photo p in photos) {
      final File? f = await p.resolveFile();
      if (f == null) {
        skipped++;
      } else {
        files.add(f);
      }
    }
    return (files, skipped);
  }

  /// 当前选中集合中的视频数量（PDF 打包会跳过，用于提示）。
  int get _videoCount => photos.where((Photo p) => p.isVideo).length;

  void _notifySkip(BuildContext context, int skipped) {
    if (skipped > 0 && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$skipped 项已失效（源文件缺失）被跳过')),
      );
    }
  }

  /// 直接分享：解析为 XFile 列表（按类型带 MIME）后调起系统 Sharesheet。
  ///
  /// Android Sharesheet 的 intent 只有一个 type 字段：全图片 → image/*，
  /// 全视频 → video/*，混合 → */*（系统面板列出全部可接收应用）。
  Future<void> _shareDirect(BuildContext context) async {
    final (files, skipped) = await _resolveFiles();
    if (files.isEmpty) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有可分享的媒体（源文件均缺失）')),
        );
      }
      return;
    }
    final List<XFile> xfiles = files.map((File f) {
      final String v = videoMimeFromPath(f.path);
      if (v != 'video/*') return XFile(f.path, mimeType: v);
      final String i = imageMimeFromPath(f.path);
      if (i != 'image/*') return XFile(f.path, mimeType: i);
      return XFile(f.path, mimeType: '*/*');
    }).toList();
    await Share.shareXFiles(xfiles, text: '来自 Photo Manager');
    if (context.mounted) {
      Navigator.of(context).pop();
      _notifySkip(context, skipped);
    }
  }

  /// 打包 PDF 后分享：视频自动跳过（提示数量），先统计跳过张数，
  /// 再生成并分享。
  ///
  /// 前置校验：PDF 只承载图片，所选内容全是视频时会产出 0 页的
  /// 无效 PDF（pdf 包的 save() 不做 0 页校验），故提前拦截并提示。
  Future<void> _sharePdf(BuildContext context) async {
    final int imageCount = photos.where((Photo p) => !p.isVideo).length;
    if (imageCount == 0) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('所选内容没有图片，无法生成 PDF')),
        );
      }
      return;
    }
    final (_, skipped) = await _resolveFiles();
    final int videos = _videoCount;
    final Directory tmp = await FileHelper.getTempDir();
    final File pdf = await PdfPacker.build(photos, tmp);
    await Share.shareXFiles([XFile(pdf.path)], text: '照片合集（PDF）');
    if (context.mounted) {
      Navigator.of(context).pop();
      _notifySkip(context, skipped);
      if (videos > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF 仅包含图片，$videos 个视频已跳过')),
        );
      }
    }
  }

  /// 打包 ZIP 后分享：先统计跳过张数，再生成并分享。
  Future<void> _shareZip(BuildContext context) async {
    final (_, skipped) = await _resolveFiles();
    final Directory tmp = await FileHelper.getTempDir();
    final File zip = await ZipPacker.build(photos, tmp);
    await Share.shareXFiles([XFile(zip.path)], text: '照片合集（ZIP）');
    if (context.mounted) {
      Navigator.of(context).pop();
      _notifySkip(context, skipped);
    }
  }

  /// 导出到本机（R16/T4.4）：经 [ExportService] 落盘后提示实际路径。
  ///
  /// [ExportService.export] 可能对无效组合抛 [StateError]（如全视频导出
  /// PDF）；这里统一捕获并提示，避免静默失败或崩溃。
  Future<void> _exportLocal(BuildContext context, ExportFormat format) async {
    ({File file, bool inPublicDownload, int skipped}) result;
    try {
      result = await ExportService.export(photos, format);
    } on StateError catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
      return;
    }
    final File file = result.file;
    final bool inPublicDownload = result.inPublicDownload;
    final int skipped = result.skipped;
    if (!context.mounted) return;
    Navigator.of(context).pop();
    _notifySkip(context, skipped);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(inPublicDownload
            ? '已导出到下载目录：${file.path}'
            : '下载目录不可写，已导出到应用目录：${file.path}'),
        duration: const Duration(seconds: 5),
      ),
    );
  }
}
