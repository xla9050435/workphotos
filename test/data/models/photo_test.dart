import 'package:flutter_test/flutter_test.dart';
import 'package:work_photos/core/utils/media_ref.dart';
import 'package:work_photos/data/models/media_type.dart';
import 'package:work_photos/data/models/photo.dart';
import 'package:work_photos/data/models/used_status.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final DateTime now = DateTime(2024, 1, 1);

  /// 构造仅含必填字段的 Photo（其余待测字段按需覆盖）。
  Photo photo({
    MediaType mediaType = MediaType.image,
    int? durationMs,
    int? width,
    int? height,
  }) =>
      Photo(
        id: 1,
        mediaRef: const MediaRef(value: '1000001', type: MediaRefType.uri),
        usedStatus: UsedStatus.unused,
        createdAt: now,
        updatedAt: now,
        mediaType: mediaType,
        durationMs: durationMs,
        width: width,
        height: height,
      );

  group('MediaType', () {
    test('value 与数据库取值一致', () {
      expect(MediaType.image.value, 'image');
      expect(MediaType.video.value, 'video');
    });

    test('fromValue 还原已知值', () {
      expect(MediaType.fromValue('image'), MediaType.image);
      expect(MediaType.fromValue('video'), MediaType.video);
    });

    test('fromValue 脏值兜底为 image（老数据 / 未知来源）', () {
      expect(MediaType.fromValue(''), MediaType.image);
      expect(MediaType.fromValue('VIDEO'), MediaType.image);
      expect(MediaType.fromValue('whatever'), MediaType.image);
    });
  });

  group('Photo.isVideo', () {
    test('默认构造为图片', () {
      expect(photo().mediaType, MediaType.image);
      expect(photo().isVideo, isFalse);
    });

    test('video 类型才是视频', () {
      expect(photo(mediaType: MediaType.video).isVideo, isTrue);
    });

    test('图片即使带时长也不算视频', () {
      final Photo p = photo(durationMs: 65000);
      expect(p.isVideo, isFalse);
      expect(p.durationLabel, isNull);
    });
  });

  group('Photo.durationLabel', () {
    test('视频 + 正数时长 → m:ss', () {
      expect(
        photo(mediaType: MediaType.video, durationMs: 65000).durationLabel,
        '1:05',
      );
      expect(
        photo(mediaType: MediaType.video, durationMs: 59000).durationLabel,
        '0:59',
      );
    });

    test('视频 + 超过 1 小时 → 仍为 mm:ss（不补小时位）', () {
      // 详情页「时长」行实现固定两位分 + 两位秒（见 Photo.durationLabel）；
      // 与 duration_format.formatDurationMs 的 h:mm:ss 口径不同，此处锁定现状。
      expect(
        photo(mediaType: MediaType.video, durationMs: 3725000).durationLabel,
        '62:05',
      );
    });

    test('视频 + 时长为 null / 0 / 负 → null（不渲染角标）', () {
      expect(photo(mediaType: MediaType.video).durationLabel, isNull);
      expect(photo(mediaType: MediaType.video, durationMs: 0).durationLabel,
          isNull);
      expect(photo(mediaType: MediaType.video, durationMs: -1).durationLabel,
          isNull);
    });

    test('时长不足 1 秒 → 补零为 0:0s', () {
      expect(
        photo(mediaType: MediaType.video, durationMs: 500).durationLabel,
        '0:01',
      );
      expect(
        photo(mediaType: MediaType.video, durationMs: 9000).durationLabel,
        '0:09',
      );
    });
  });

  group('Photo 其它', () {
    test('宽高默认 null，可显式携带', () {
      expect(photo().width, isNull);
      expect(photo().height, isNull);
      expect(photo(width: 1920, height: 1080).width, 1920);
      expect(photo(width: 1920, height: 1080).height, 1080);
    });

    test('isUsed 与 mediaType 互不影响', () {
      final Photo p = Photo(
        id: 2,
        mediaRef: const MediaRef(value: '1000002', type: MediaRefType.uri),
        usedStatus: UsedStatus.used,
        createdAt: now,
        updatedAt: now,
        mediaType: MediaType.video,
        durationMs: 10000,
      );
      expect(p.isUsed, isTrue);
      expect(p.isVideo, isTrue);
      expect(p.durationLabel, '0:10');
    });
  });
}
