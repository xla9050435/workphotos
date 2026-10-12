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
      expect(asc(cat(1, 'a'), cat(2, 'a')), 0);
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
