import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:work_photos/data/models/photo.dart';

/// PDF 打包器（B5 + 视频支持）。
///
/// 使用 [pdf] 包：逐张照片经 [MediaRef.resolveFile] 解析后读取字节，
/// 构造 [pw.MemoryImage] → [pw.Image]，逐张加页；最后 [pw.Document.save]
/// 写入临时目录的 .pdf 文件并返回 [File]。失效引用（resolveFile 返回 null）
/// 直接跳过。
///
/// 视频不支持渲染进 PDF（pdf 包仅接受图片字节），自动跳过；
/// 调用方（分享面板 / 导出）会另行提示被跳过的视频数量。
class PdfPacker {
  const PdfPacker._();

  /// 把 [photos] 中的**图片**逐张渲染为单页 PDF，返回写入临时目录的文件。
  ///
  /// 一页都没渲染出来（全是视频 / 全是失效引用）时抛 [StateError]，
  /// 避免写出 0 页的无效 PDF。
  static Future<File> build(List<Photo> photos, Directory tmpDir) async {
    final pw.Document doc = pw.Document();
    // 已成功渲染的页数（视频不进 PDF、失效引用被跳过都会让它保持 0）。
    int pages = 0;
    for (final Photo photo in photos) {
      if (photo.isVideo) continue; // 视频不进 PDF
      final File? file = await photo.resolveFile();
      if (file == null) continue; // 失效引用降级跳过
      final Uint8List bytes = await file.readAsBytes();
      final pw.MemoryImage image = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Center(child: pw.Image(image)),
        ),
      );
      pages++;
    }
    // 0 页兜底：pdf 包的 save() 不校验页数，空文档会写出一个打不开的
    // 0 页 PDF，故在此抛出，由 UI 层（分享面板前置拦截 / 导出的
    // StateError 捕获）提示用户。
    if (pages == 0) {
      throw StateError('所选内容没有可用图片，无法生成 PDF');
    }
    final String fileName =
        'photos_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final File output = File(p.join(tmpDir.path, fileName));
    final Uint8List data = await doc.save();
    await output.writeAsBytes(data);
    return output;
  }
}
