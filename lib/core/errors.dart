/// 媒体引用已失效（引用文件不存在或无法访问）时抛出的异常。
///
/// 本期（B1）仅占位，B4 媒体解析真正接入、[MediaRef.resolveFile] 判定
/// 引用无效时使用。
class BrokenRefException implements Exception {
  final String message;

  const BrokenRefException(this.message);

  @override
  String toString() => 'BrokenRefException: $message';
}
