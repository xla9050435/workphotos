import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'package:work_photos/data/models/photo.dart';

/// ZIP 打包器（B5 + 视频支持）。
///
/// 使用 [archive] 包：逐张媒体字节写入 [ArchiveFile]，再以 [ZipEncoder]
/// 编码为临时目录的 .zip 文件返回 [File]。文件名采用
/// `photo_<id>_<i><原扩展名>`（视频保留 mp4/mkv 等真实扩展名，
/// 解压后才能被识别播放）。失效引用直接跳过。
class ZipPacker {
  const ZipPacker._();

  /// 把 [photos] 打包为 ZIP，返回写入临时目录的文件。
  static Future<File> build(List<Photo> photos, Directory tmpDir) async {
    final Archive archive = Archive();
    int index = 0;
    for (final Photo photo in photos) {
      final File? file = await photo.resolveFile();
      if (file == null) continue; // 失效引用降级跳过
      final Uint8List bytes = await file.readAsBytes();
      // 真实扩展名；无扩展名时按类型兜底（视频 .mp4 / 图片 .jpg），
      // 否则解压后系统无法识别视频。
      String ext = p.extension(file.path);
      if (ext.isEmpty) ext = photo.isVideo ? '.mp4' : '.jpg';
      final String name = 'photo_${photo.id ?? index}_$index$ext';
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
      index++;
    }
    final ZipEncoder encoder = ZipEncoder();
    // 注意：archive 3.x 的 ZipEncoder.encode 返回 List<int>?（编码异常时为 null），
    // 不是 Uint8List?，因此这里按 List<int>? 接收；
    // File.writeAsBytes 接受 List<int>，无需额外转换。
    final List<int>? zipBytes = encoder.encode(archive);
    if (zipBytes == null) {
      throw StateError('ZIP 编码失败');
    }
    final String fileName =
        'photos_${DateTime.now().millisecondsSinceEpoch}.zip';
    final File output = File(p.join(tmpDir.path, fileName));
    await output.writeAsBytes(zipBytes);
    return output;
  }
}
