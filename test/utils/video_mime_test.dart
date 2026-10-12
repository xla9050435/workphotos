import 'package:flutter_test/flutter_test.dart';
import 'package:work_photos/core/utils/video_mime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('videoMimeFromPath', () {
    test('常见容器映射到标准 MIME', () {
      expect(videoMimeFromPath('/sdcard/DCIM/a.mp4'), 'video/mp4');
      expect(videoMimeFromPath('/sdcard/DCIM/a.m4v'), 'video/mp4');
      expect(videoMimeFromPath('/sdcard/DCIM/a.webm'), 'video/webm');
      expect(videoMimeFromPath('/sdcard/DCIM/a.mkv'), 'video/x-matroska');
      expect(videoMimeFromPath('/sdcard/DCIM/a.mov'), 'video/quicktime');
      expect(videoMimeFromPath('/sdcard/DCIM/a.3gp'), 'video/3gpp');
      expect(videoMimeFromPath('/sdcard/DCIM/a.3g2'), 'video/3gpp2');
      expect(videoMimeFromPath('/sdcard/DCIM/a.avi'), 'video/x-msvideo');
      expect(videoMimeFromPath('/sdcard/DCIM/a.flv'), 'video/x-flv');
      expect(videoMimeFromPath('/sdcard/DCIM/a.wmv'), 'video/x-ms-wmv');
      expect(videoMimeFromPath('/sdcard/DCIM/a.rmvb'), 'video/vnd.rn-realvideo');
      expect(videoMimeFromPath('/sdcard/DCIM/a.rm'), 'video/vnd.rn-realvideo');
      expect(videoMimeFromPath('/sdcard/DCIM/a.mpg'), 'video/mpeg');
      expect(videoMimeFromPath('/sdcard/DCIM/a.mpeg'), 'video/mpeg');
    });

    test('TS 系列 → video/mp2t', () {
      expect(videoMimeFromPath('a.ts'), 'video/mp2t');
      expect(videoMimeFromPath('a.mts'), 'video/mp2t');
      expect(videoMimeFromPath('a.m2ts'), 'video/mp2t');
    });

    test('大写扩展名同样识别（先 toLowerCase）', () {
      expect(videoMimeFromPath('/sdcard/DCIM/A.MP4'), 'video/mp4');
      expect(videoMimeFromPath('/sdcard/DCIM/A.MKV'), 'video/x-matroska');
      expect(videoMimeFromPath('/sdcard/DCIM/A.MOV'), 'video/quicktime');
    });

    test('未知扩展名 / 无扩展名回退 video/*', () {
      expect(videoMimeFromPath('/sdcard/DCIM/a.xyz'), 'video/*');
      expect(videoMimeFromPath('/sdcard/DCIM/VID_20240101_120000'), 'video/*');
      // 以点结尾：不构成扩展名。
      expect(videoMimeFromPath('/sdcard/DCIM/a.'), 'video/*');
      // 目录名含点时按最后一个点切分，得到的不是真实扩展名 → 回退。
      expect(videoMimeFromPath('/sdcard/my.dir/clip'), 'video/*');
    });

    test('空路径不会越界', () {
      expect(videoMimeFromPath(''), 'video/*');
    });
  });

  group('imageMimeFromPath', () {
    test('常见图片格式映射', () {
      expect(imageMimeFromPath('a.jpg'), 'image/jpeg');
      expect(imageMimeFromPath('a.jpeg'), 'image/jpeg');
      expect(imageMimeFromPath('a.png'), 'image/png');
      expect(imageMimeFromPath('a.webp'), 'image/webp');
      expect(imageMimeFromPath('a.gif'), 'image/gif');
      expect(imageMimeFromPath('a.heic'), 'image/heic');
      expect(imageMimeFromPath('a.heif'), 'image/heic');
      expect(imageMimeFromPath('a.bmp'), 'image/bmp');
    });

    test('大写扩展名同样识别', () {
      expect(imageMimeFromPath('A.JPG'), 'image/jpeg');
      expect(imageMimeFromPath('A.HEIC'), 'image/heic');
    });

    test('未知扩展名 / 无扩展名回退 image/*', () {
      expect(imageMimeFromPath('a.tiff'), 'image/*');
      expect(imageMimeFromPath('IMG_0001'), 'image/*');
      expect(imageMimeFromPath(''), 'image/*');
    });
  });
}
