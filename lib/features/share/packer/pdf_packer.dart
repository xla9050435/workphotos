import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:work_photos/data/models/photo.dart';

/// PDF 打包器（B5）。
///
/// 使用 [pdf] 包：逐张照片经 [MediaRef.resolveFile] 解析后读取字节，
/// 构造 [pw.MemoryImage] → [pw.Image]，逐张加页；最后 [pw.Document.save]
/// 写入临时目录的 .pdf 文件并返回 [File]。失效引用（resolveFile 返回 null）
/// 直接跳过。
class PdfPacker {
  const PdfPacker._();

  /// 把 [photos] 逐张渲染为单页 PDF，返回写入临时目录的文件。
  static Future<File> build(List<Photo> photos, Directory tmpDir) async {
    final pw.Document doc = pw.Document();
    for (final Photo photo in photos) {
      final File? file = await photo.resolveFile();
      if (file == null) continue; // 失效引用降级跳过
      final Uint8List bytes = await file.readAsBytes();
      final pw.MemoryImage image = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Center(child: pw.Image(image)),
        ),
      );
    }
    final String fileName =
        'photos_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final File output = File(p.join(tmpDir.path, fileName));
    final Uint8List data = await doc.save();
    await output.writeAsBytes(data);
    return output;
  }
}
