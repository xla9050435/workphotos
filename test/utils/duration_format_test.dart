import 'package:flutter_test/flutter_test.dart';
import 'package:work_photos/core/utils/duration_format.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('formatDurationMs', () {
    test('null / 0 / 负数一律返回 null（UI 据此不渲染时长）', () {
      expect(formatDurationMs(null), isNull);
      expect(formatDurationMs(0), isNull);
      expect(formatDurationMs(-1), isNull);
      expect(formatDurationMs(-1000), isNull);
    });

    test('不足 1 分钟 → m:ss', () {
      expect(formatDurationMs(59 * 1000), '0:59');
      expect(formatDurationMs(9 * 1000), '0:09');
      expect(formatDurationMs(1000), '0:01');
    });

    test('超过 1 分钟 → m:ss（秒补零）', () {
      expect(formatDurationMs(65 * 1000), '1:05');
      expect(formatDurationMs(60 * 1000), '1:00');
      expect(formatDurationMs(600 * 1000), '10:00');
    });

    test('超过 1 小时 → h:mm:ss', () {
      expect(formatDurationMs(3725000), '1:02:05');
      expect(formatDurationMs(3600 * 1000), '1:00:00');
      expect(formatDurationMs((3600 * 2 + 60 * 3 + 4) * 1000), '2:03:04');
    });

    test('毫秒按四舍五入折算为秒（999ms → 0:01）', () {
      // 实现为 (ms / 1000).round()：不足半秒向下、半秒及以上向上。
      // 这是既有行为，断言用于锁定回归（后续若改为 floor 需同步更新）。
      expect(formatDurationMs(999), '0:01');
      expect(formatDurationMs(400), '0:00'); // 0.4 秒 → 向下取 0 秒
      expect(formatDurationMs(1500), '0:02'); // 1.5 秒 → 向上取 2 秒
    });
  });

  group('formatDuration', () {
    test('null → null', () {
      expect(formatDuration(null), isNull);
    });

    test('Duration → m:ss / h:mm:ss', () {
      expect(formatDuration(const Duration(seconds: 65)), '1:05');
      expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 5)),
          '1:02:05');
    });

    test('Duration.zero → null（与 0 毫秒一致）', () {
      expect(formatDuration(Duration.zero), isNull);
    });
  });
}
