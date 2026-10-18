import 'package:flutter_test/flutter_test.dart';
import 'package:work_photos/data/models/category.dart';
import 'package:work_photos/features/classify/category_sort.dart';
import 'package:work_photos/features/me/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Category cat(int id, String name, {int? parentId}) => Category(
        id: id,
        name: name,
        parentId: parentId,
        colorHex: '#000000',
        iconName: 'folder',
      );

  /// 混合数字 / 英文大小写 / 中文的名称集合，顺序刻意打乱。
  final List<Category> flat = <Category>[
    cat(1, '香蕉'),
    cat(2, 'Apple'),
    cat(3, 'banana'),
    cat(4, '苹果'),
    cat(5, '1号线'),
  ];

  List<String> namesOf(List<Category> list) =>
      list.map((Category c) => c.name).toList();

  group('categoryNameComparator', () {
    test('manual 模式返回 null（表示保持原序）', () {
      expect(categoryNameComparator(kCategorySortManual), isNull);
    });

    test('非法 / 未知模式返回 null（兜底为手动）', () {
      expect(categoryNameComparator(''), isNull);
      expect(categoryNameComparator('bogus'), isNull);
      expect(categoryNameComparator('name_asc'), isNull);
    });

    test('nameAsc / nameDesc 返回可用比较器', () {
      final int Function(Category, Category)? asc =
          categoryNameComparator(kCategorySortNameAsc);
      final int Function(Category, Category)? desc =
          categoryNameComparator(kCategorySortNameDesc);
      expect(asc, isNotNull);
      expect(desc, isNotNull);
      expect(asc!(cat(1, 'a'), cat(2, 'b')), lessThan(0));
      expect(desc!(cat(1, 'a'), cat(2, 'b')), greaterThan(0));
      // 同名不再返回 0：次级键 id 参与比较（id 小者在前，desc 时整体取反）。
      expect(asc(cat(1, 'a'), cat(2, 'a')), lessThan(0));
      expect(desc(cat(1, 'a'), cat(2, 'a')), greaterThan(0));
      // 同一对象与自身比较才为 0。
      expect(asc(cat(1, 'a'), cat(1, 'a')), 0);
    });
  });

  group('categoryNameComparator — 同名 tie-break（不稳定排序回归）', () {
    /// 同名分类：只比 name 时 List.sort 每次结果都可能不同。
    List<Category> namesakes() => <Category>[
          cat(3, '材料'),
          cat(1, '材料'),
          cat(5, '材料'),
          cat(2, '材料'),
          cat(4, '材料'),
        ];

    List<int?> idsOf(List<Category> list) =>
        list.map((Category c) => c.id).toList();

    test('nameAsc：同名按 id 升序', () {
      final int Function(Category, Category) cmp =
          categoryNameComparator(kCategorySortNameAsc)!;
      final List<Category> out = namesakes()..sort(cmp);
      expect(idsOf(out), <int?>[1, 2, 3, 4, 5]);
    });

    test('nameDesc：同名按 id 降序（次级键方向与主键一致）', () {
      final int Function(Category, Category) cmp =
          categoryNameComparator(kCategorySortNameDesc)!;
      final List<Category> out = namesakes()..sort(cmp);
      expect(idsOf(out), <int?>[5, 4, 3, 2, 1]);
    });

    test('id 为 null 视作 0，排在同名组最前', () {
      final List<Category> list = <Category>[
        cat(2, '同名'),
        const Category(
          id: null,
          name: '同名',
          colorHex: '#000000',
          iconName: 'folder',
        ),
        cat(1, '同名'),
      ];
      final int Function(Category, Category) cmp =
          categoryNameComparator(kCategorySortNameAsc)!;
      final List<Category> out = list..sort(cmp);
      expect(idsOf(out), <int?>[null, 1, 2]);
    });

    test('同一份数据重复排序 100 次结果不变', () {
      final int Function(Category, Category) cmp =
          categoryNameComparator(kCategorySortNameAsc)!;
      final List<int?> first = idsOf(namesakes()..sort(cmp));
      for (int i = 0; i < 100; i++) {
        expect(idsOf(namesakes()..sort(cmp)), first);
      }
    });

    test('降序结果严格等于升序结果的逆序', () {
      final List<Category> asc = namesakes()
        ..sort(categoryNameComparator(kCategorySortNameAsc)!);
      final List<Category> desc = namesakes()
        ..sort(categoryNameComparator(kCategorySortNameDesc)!);
      expect(idsOf(desc), idsOf(asc).reversed.toList());
    });
  });

  group('sortCategories', () {
    test('manual 模式原样保序（数据库 sortOrder 顺序）', () {
      final List<Category> out = sortCategories(flat, kCategorySortManual);
      expect(namesOf(out), <String>['香蕉', 'Apple', 'banana', '苹果', '1号线']);
    });

    test('manual 模式返回副本，不改动入参', () {
      final List<Category> out = sortCategories(flat, kCategorySortManual);
      expect(identical(out, flat), isFalse);
      expect(out.length, flat.length);
      // 元素仍为同一实例（仅重排，不拷贝对象）。
      expect(identical(out.first, flat.first), isTrue);
    });

    test('nameAsc 按 Unicode 码位升序（数字 < 大写 < 小写 < 中文）', () {
      final List<Category> out = sortCategories(flat, kCategorySortNameAsc);
      expect(
        namesOf(out),
        <String>['1号线', 'Apple', 'banana', '苹果', '香蕉'],
      );
    });

    test('nameDesc 为升序的逆序', () {
      final List<Category> asc = sortCategories(flat, kCategorySortNameAsc);
      final List<Category> desc = sortCategories(flat, kCategorySortNameDesc);
      expect(namesOf(desc), namesOf(asc).reversed.toList());
    });

    test('非法模式回退为手动（原序）', () {
      final List<Category> out = sortCategories(flat, 'NOPE');
      expect(namesOf(out), <String>['香蕉', 'Apple', 'banana', '苹果', '1号线']);
    });

    test('空列表不报错', () {
      expect(sortCategories(<Category>[], kCategorySortNameAsc), isEmpty);
      expect(sortCategories(<Category>[], kCategorySortManual), isEmpty);
    });

    test('单元素列表保持该元素', () {
      final List<Category> one = <Category>[cat(9, '唯一')];
      expect(namesOf(sortCategories(one, kCategorySortNameDesc)),
          <String>['唯一']);
    });
  });
}
