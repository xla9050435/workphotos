/// 媒体类型（本期新增视频支持）。
///
/// 与数据库 photos.media_type 列对应：'image' | 'video'。
/// 音频不在本期范围内（工作照片场景无音频需求）。
enum MediaType {
  image,
  video;

  /// 持久化到数据库时使用的字符串值。
  String get value => name;

  /// 从数据库读取的字符串还原（脏值兜底为图片）。
  static MediaType fromValue(String value) =>
      value == 'video' ? MediaType.video : MediaType.image;
}
