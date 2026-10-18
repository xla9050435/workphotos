import 'package:flutter_test/flutter_test.dart';
import 'package:work_photos/data/models/category.dart';
import 'package:work_photos/features/classify/category_sort.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 构造仅含层级相关字段的分类（id / parentId）；其余字段给固定值。
  Category cat(int id, {int? parentId}) => Category(
        id: id,
        name: 'c$id',
        parentId: parentId,
        colorHex: '#000000',
        iconName: 'folder',
      );

  group('categoryDepthMap', () {
    test('单层：根深度为 0，其直接子节点为 1', () {
      final List<Category> flat = <Category>[
        cat(1),
        cat(2, parentId: 1),
        cat(3, parentId: 1),
      ];
      final Map<int, int> d = categoryDepthMap(flat);
      expect(d[1], 0);
      expect(d[2], 1);
      expect(d[3], 1);
    });

    test('多层链：逐级 +1', () {
      final List<Category> flat = <Category>[
        cat(1),
        cat(2, parentId: 1),
        cat(3, parentId: 2),
        cat(4, parentId: 3),
      ];
      final Map<int, int> d = categoryDepthMap(flat);
      expect(d[1], 0);
      expect(d[2], 1);
      expect(d[3], 2);
      expect(d[4], 3);
    });

    test('输入顺序无关：打乱后深度仍按父子链正确计算', () {
      final List<Category> flat = <Category>[
        cat(4, parentId: 3),
        cat(2, parentId: 1),
        cat(3, parentId: 2),
        cat(1),
      ];
      final Map<int, int> d = categoryDepthMap(flat);
      expect(d[1], 0);
      expect(d[2], 1);
      expect(d[3], 2);
      expect(d[4], 3);
    });

    test('父节点不存在：兜底为根（深度 0），不抛异常', () {
      final List<Category> flat = <Category>[
        cat(1),
        cat(2, parentId: 999), // 父被删 / 指向不存在的 id
      ];
      final Map<int, int> d = categoryDepthMap(flat);
      expect(d[1], 0);
      expect(d[2], 0);
    });

    test('id 为 null 的草稿分类不进入深度图', () {
      final List<Category> flat = <Category>[
        cat(1),
        const Category(
          id: null,
          name: 'draft',
          colorHex: '#000000',
          iconName: 'folder',
        ),
      ];
      final Map<int, int> d = categoryDepthMap(flat);
      expect(d.containsKey(1), isTrue);
      expect(d.length, 1); // 只统计有 id 的分类
    });

    test('空列表返回空图', () {
      expect(categoryDepthMap(<Category>[]), isEmpty);
    });

    test('自环（A.parent = A）不死循环，返回有限深度', () {
      final List<Category> flat = <Category>[cat(1, parentId: 1)];
      // 若实现无环检测，此处会无限递归 → 栈溢出使用例失败。
      final Map<int, int> d = categoryDepthMap(flat);
      expect(d.containsKey(1), isTrue);
      expect(d[1], isNotNull);
      expect(d[1]!, lessThan(100));
    });

    test('二元环（A→B→A）不死循环，两节点均得到有限深度', () {
      final List<Category> flat = <Category>[
        cat(1, parentId: 2),
        cat(2, parentId: 1),
      ];
      final Map<int, int> d = categoryDepthMap(flat);
      expect(d.containsKey(1), isTrue);
      expect(d.containsKey(2), isTrue);
      expect(d[1]!, lessThan(100));
      expect(d[2]!, lessThan(100));
    });

    test('环与正常链混合：环外正常节点深度仍正确', () {
      // 环：1→2→1；另一条正常链 3（根）→4（子）。
      final List<Category> flat = <Category>[
        cat(1, parentId: 2),
        cat(2, parentId: 1),
        cat(3),
        cat(4, parentId: 3),
      ];
      final Map<int, int> d = categoryDepthMap(flat);
      expect(d[3], 0);
      expect(d[4], 1);
      expect(d[1]!, lessThan(100));
      expect(d[2]!, lessThan(100));
    });
  });
}
