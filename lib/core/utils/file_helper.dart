import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 临时文件辅助（B5）。
///
/// 集中封装分享/打包过程中临时文件的目录获取与清理，
/// 避免各打包器各自调用 [path_provider]。
class FileHelper {
  const FileHelper._();

  /// 获取应用临时目录（[path_provider.getTemporaryDirectory]）。
  ///
  /// 打包产生的 PDF / ZIP 写入此目录，分享后由其所在系统应用消费。
  static Future<Directory> getTempDir() => getTemporaryDirectory();

  /// 获取「导出到本机」的降级目录（T4.4）：
  /// 应用文档目录 `exports/` 子目录（不存在则创建）。
  ///
  /// 公共下载目录不可写时（部分 ROM 分区存储限制）使用此目录兜底。
  static Future<Directory> getDocumentsDirForExport() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory dir = Directory(
        p.join(docs.path, 'exports'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 清理分享产生的临时文件。
  ///
  /// B5：本期保留临时文件不立即删除——系统分享面板在后台仍可能引用该文件，
  /// 提前删除会导致分享失败或二次分享失败。如需主动清理，可取消注释下方逻辑：
  static Future<void> cleanup(File file) async {
    // try {
    //   if (await file.exists()) await file.delete();
    // } catch (_) {
    //   // 忽略清理失败。
    // }
  }
}
