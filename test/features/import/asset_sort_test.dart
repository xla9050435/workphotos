import 'package:flutter_test/flutter_test.dart';
import 'package:work_photos/features/import/asset_sort.dart';

/// 测试用最小资产：只保留比较器需要的两个字段（拍摄时间 + 资产 id）。
///
/// 不用 `pm.AssetEntity` 是刻意的：它依赖 Android/iOS 插件通道，在
/// `flutter test` 里构造不出来；把比较逻辑抽成纯函数后才能这样测。
class _TestAsset {
  const _TestAsset(this.time, this.id);

  final DateTime time;
  final String id;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 真机上大量照片共用的那一秒（MediaStore 的 DATE_TAKEN 只到秒）。
  final DateTime sameSecond = DateTime(2024, 10, 18, 9, 30, 15);

  List<String> idsOf(List<_TestAsset> list) =>
      list.map((_TestAsset a) => a.id).toList();

  /// 用被测比较器排一份副本（不改入参）。
  List<_TestAsset> sortedCopy(List<_TestAsset> input,
      {required bool newToOld}) {
    final List<_TestAsset> out = List<_TestAsset>.of(input);
    out.sort((_TestAsset a, _TestAsset b) => compareAssetOrder(
          aTime: a.time,
          aId: a.id,
          bTime: b.time,
          bId: b.id,
          newToOld: newToOld,
        ));
    return out;
  }

  /// 24 个「同一秒、不同 id」的资产，按 id 升序生成。
  final List<_TestAsset> sameSecondBatch = List<_TestAsset>.generate(
    24,
    (int i) => _TestAsset(
      sameSecond,
      'p${(i + 1).toString().padLeft(2, '0')}',
    ),
    growable: false,
  );

  /// 固定乱序（0..23 的一个置换），模拟 MediaStore 返回的任意顺序。
  const List<int> permutation = <int>[
    11, 3, 22, 0, 17, 8, 23, 5, 14, 1, //
    19, 10, 2, 21, 7, 16, 4, 13, 9, 20, //
    6, 15, 12, 18,
  ];
  final List<_TestAsset> shuffled = permutation
      .map((int index) => sameSecondBatch[index])
      .toList(growable: false);

  /// 期望值：id 升序 p01..p24。
  final List<String> expectedAsc = List<String>.generate(
    24,
    (int i) => 'p${(i + 1).toString().padLeft(2, '0')}',
  );

  group('compareAssetOrder — tie-break 存在性', () {
    test('时间相同时按 id 区分，不再返回 0（这是本 bug 的根因）', () {
      // 新→旧：id 降序，所以 p02 应排在 p01 前面。
      expect(
        compareAssetOrder(
          aTime: sameSecond,
          aId: 'p01',
          bTime: sameSecond,
          bId: 'p02',
          newToOld: true,
        ),
        greaterThan(0),
      );
      // 旧→新：id 升序。
      expect(
        compareAssetOrder(
          aTime: sameSecond,
          aId: 'p01',
          bTime: sameSecond,
          bId: 'p02',
          newToOld: false,
        ),
        lessThan(0),
      );
    });

    test('时间不同时只看时间，id 不参与比较', () {
      final DateTime older = DateTime(2024, 10, 18, 9, 30, 14);
      // id 故意取反方向，若被 id 影响结论会变号。
      expect(
        compareAssetOrder(
          aTime: older,
          aId: 'zzz',
          bTime: sameSecond,
          bId: 'aaa',
          newToOld: false,
        ),
        lessThan(0),
      );
      expect(
        compareAssetOrder(
          aTime: older,
          aId: 'zzz',
          bTime: sameSecond,
          bId: 'aaa',
          newToOld: true,
        ),
        greaterThan(0),
      );
    });

    test('任意两个不同资产都不会比出 0（严格全序）', () {
      for (final _TestAsset a in sameSecondBatch) {
        for (final _TestAsset b in sameSecondBatch) {
          if (identical(a, b)) continue;
          for (final bool newToOld in <bool>[true, false]) {
            expect(
              compareAssetOrder(
                aTime: a.time,
                aId: a.id,
                bTime: b.time,
                bId: b.id,
                newToOld: newToOld,
              ),
              isNot(0),
              reason: '${a.id} vs ${b.id}（newToOld=$newToOld）',
            );
          }
        }
      }
    });

    test('同一张资产与自己比较返回 0', () {
      expect(
        compareAssetOrder(
          aTime: sameSecond,
          aId: 'p01',
          bTime: sameSecond,
          bId: 'p01',
          newToOld: true,
        ),
        0,
      );
    });

    test('反对称：compare(a,b) == -compare(b,a)', () {
      for (final _TestAsset a in sameSecondBatch) {
        for (final _TestAsset b in sameSecondBatch) {
          final int ab = compareAssetOrder(
            aTime: a.time,
            aId: a.id,
            bTime: b.time,
            bId: b.id,
            newToOld: false,
          );
          final int ba = compareAssetOrder(
            aTime: b.time,
            aId: b.id,
            bTime: a.time,
            bId: a.id,
            newToOld: false,
          );
          expect(ab, -ba, reason: '${a.id} / ${b.id}');
        }
      }
    });
  });

  group('同秒 24 张：排序结果完全确定', () {
    test('新→旧：id 降序（p24 … p01）', () {
      expect(
        idsOf(sortedCopy(shuffled, newToOld: true)),
        expectedAsc.reversed.toList(),
      );
    });

    test('旧→新：id 升序（p01 … p24）', () {
      expect(idsOf(sortedCopy(shuffled, newToOld: false)), expectedAsc);
    });

    test('降序结果严格等于升序结果的逆序（次级键方向与主键一致）', () {
      final List<String> asc = idsOf(sortedCopy(shuffled, newToOld: false));
      final List<String> desc = idsOf(sortedCopy(shuffled, newToOld: true));
      expect(desc, asc.reversed.toList());
    });

    test('同一份乱序输入重复排序 100 次，结果完全不变', () {
      final List<String> firstAsc =
          idsOf(sortedCopy(shuffled, newToOld: false));
      final List<String> firstDesc =
          idsOf(sortedCopy(shuffled, newToOld: true));
      for (int i = 0; i < 100; i++) {
        expect(
          idsOf(sortedCopy(shuffled, newToOld: false)),
          firstAsc,
          reason: '旧→新 第 ${i + 1} 次重排与首次不一致（不稳定排序回归）',
        );
        expect(
          idsOf(sortedCopy(shuffled, newToOld: true)),
          firstDesc,
          reason: '新→旧 第 ${i + 1} 次重排与首次不一致（不稳定排序回归）',
        );
      }
    });

    test('入参列表不被就地修改', () {
      final List<String> before = idsOf(shuffled);
      sortedCopy(shuffled, newToOld: true);
      expect(idsOf(shuffled), before);
    });

    test('列表 length 不变、元素不丢失（重复 id 除外无遗漏）', () {
      final List<_TestAsset> out = sortedCopy(shuffled, newToOld: true);
      expect(out.length, sameSecondBatch.length);
      expect(out.toSet().length, sameSecondBatch.length);
    });
  });

  group('不同时间戳 + 同秒混排', () {
    final DateTime t1 = DateTime(2024, 10, 18, 9, 30, 10);
    final DateTime t2 = DateTime(2024, 10, 18, 9, 30, 11);
    final DateTime t3 = DateTime(2024, 10, 18, 9, 30, 12);

    final List<_TestAsset> mixed = <_TestAsset>[
      _TestAsset(t2, 'b2'),
      _TestAsset(t1, 'a3'),
      _TestAsset(t3, 'c1'),
      _TestAsset(t1, 'a1'),
      _TestAsset(t3, 'c3'),
      _TestAsset(t2, 'b1'),
      _TestAsset(t1, 'a2'),
      _TestAsset(t3, 'c2'),
      _TestAsset(t2, 'b3'),
    ];

    const List<String> expectedMixedAsc = <String>[
      'a1', 'a2', 'a3', 'b1', 'b2', 'b3', 'c1', 'c2', 'c3', //
    ];

    test('旧→新：先按时间，同秒内按 id 升序', () {
      expect(idsOf(sortedCopy(mixed, newToOld: false)), expectedMixedAsc);
    });

    test('新→旧：时间倒序，同秒内按 id 降序', () {
      expect(
        idsOf(sortedCopy(mixed, newToOld: true)),
        expectedMixedAsc.reversed.toList(),
      );
    });

    test('100 次重排结果不变（含同秒与跨秒两种键）', () {
      final List<String> first = idsOf(sortedCopy(mixed, newToOld: true));
      for (int i = 0; i < 100; i++) {
        expect(idsOf(sortedCopy(mixed, newToOld: true)), first);
      }
    });
  });

  group('真机量级：同一天 116 张同秒连拍', () {
    // 用户相册 10 月 18 日共 116 张，工地连拍+批量截图导致大量同秒。
    final List<_TestAsset> burst = List<_TestAsset>.generate(
      116,
      (int i) => _TestAsset(sameSecond, 'img-$i'),
      growable: false,
    );
    final List<_TestAsset> reversedInput =
        burst.reversed.toList(growable: false);

    test('逆序输入与正序输入排出完全相同的序列', () {
      expect(
        idsOf(sortedCopy(burst, newToOld: true)),
        idsOf(sortedCopy(reversedInput, newToOld: true)),
      );
      expect(
        idsOf(sortedCopy(burst, newToOld: false)),
        idsOf(sortedCopy(reversedInput, newToOld: false)),
      );
    });

    test('100 次重排结果不变', () {
      final List<String> first =
          idsOf(sortedCopy(reversedInput, newToOld: true));
      for (int i = 0; i < 100; i++) {
        expect(idsOf(sortedCopy(reversedInput, newToOld: true)), first);
      }
    });
  });

  group('边界', () {
    test('空列表不报错', () {
      expect(sortedCopy(<_TestAsset>[], newToOld: true), isEmpty);
      expect(sortedCopy(<_TestAsset>[], newToOld: false), isEmpty);
    });

    test('单元素列表保持该元素', () {
      final List<_TestAsset> one = <_TestAsset>[
        _TestAsset(sameSecond, 'only'),
      ];
      expect(idsOf(sortedCopy(one, newToOld: true)), <String>['only']);
      expect(idsOf(sortedCopy(one, newToOld: false)), <String>['only']);
    });

    test('同一秒的单张资产在两个方向上都可用', () {
      final List<_TestAsset> pair = <_TestAsset>[
        _TestAsset(sameSecond, 'a'),
        _TestAsset(sameSecond, 'b'),
      ];
      expect(idsOf(sortedCopy(pair, newToOld: false)), <String>['a', 'b']);
      expect(idsOf(sortedCopy(pair, newToOld: true)), <String>['b', 'a']);
    });
  });
}
