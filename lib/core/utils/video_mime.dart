/// 视频 MIME 推断（按扩展名）。
///
/// 用途：
/// - 详情页「用其他应用打开」经 share_plus 分享时带上正确 MIME，
///   Android 分享面板才能列出真正的播放器应用；
/// - ExoPlayer（video_player）不支持的容器（avi / flv / rmvb 等）
///   经系统播放器兜底播放。
///
/// 覆盖常见容器；未知扩展名回退 'video/*'（系统面板仍会列出
/// 声明支持任意视频的应用）。
String videoMimeFromPath(String path) {
  final String lower = path.toLowerCase();
  String ext;
  final int dot = lower.lastIndexOf('.');
  if (dot >= 0 && dot < lower.length - 1) {
    ext = lower.substring(dot + 1);
  } else {
    ext = '';
  }
  switch (ext) {
    case 'mp4':
    case 'm4v':
      return 'video/mp4';
    case 'webm':
      return 'video/webm';
    case 'mkv':
      return 'video/x-matroska';
    case 'mov':
      return 'video/quicktime';
    case '3gp':
      return 'video/3gpp';
    case '3g2':
      return 'video/3gpp2';
    case 'ts':
    case 'mts':
    case 'm2ts':
      return 'video/mp2t';
    case 'avi':
      return 'video/x-msvideo';
    case 'flv':
      return 'video/x-flv';
    case 'wmv':
      return 'video/x-ms-wmv';
    case 'rmvb':
    case 'rm':
      return 'video/vnd.rn-realvideo';
    case 'mpg':
    case 'mpeg':
      return 'video/mpeg';
    default:
      return 'video/*';
  }
}

/// 图片 MIME 推断（按扩展名）。分享面板直接分享时用；
/// 未知扩展名回退 'image/*'。
String imageMimeFromPath(String path) {
  final String lower = path.toLowerCase();
  final int dot = lower.lastIndexOf('.');
  final String ext = (dot >= 0 && dot < lower.length - 1)
      ? lower.substring(dot + 1)
      : '';
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    case 'heic':
    case 'heif':
      return 'image/heic';
    case 'bmp':
      return 'image/bmp';
    default:
      return 'image/*';
  }
}
