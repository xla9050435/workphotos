import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_photos/data/models/category.dart';
import 'package:work_photos/features/classify/category_form.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<Category> tree = <Category>[
    Category(id: 1, name: 'root', colorHex: '#000000', iconName: 'folder'),
    Category(
      id: 2,
      name: 'child',
      parentId: 1,
      colorHex: '#000000',
      iconName: 'folder',
    ),
    Category(
      id: 3,
      name: 'grandchild',
      parentId: 2,
      colorHex: '#000000',
      iconName: 'folder',
    ),
    Category(id: 4, name: 'other', colorHex: '#000000', iconName: 'folder'),
  ];

  group('categoryDescendantIds', () {
    test('返回直接+间接子节点，不含自身与无关节点', () {
      final List<int> ids = categoryDescendantIds(tree, 1);
      expect(ids, containsAll(<int>[2, 3]));
      expect(ids, isNot(contains(1)));
      expect(ids, isNot(contains(4)));
    });

    test('叶子节点返回空', () {
      expect(categoryDescendantIds(tree, 3), isEmpty);
    });

    test('无子节点返回空', () {
      expect(categoryDescendantIds(tree, 4), isEmpty);
    });
  });
}
