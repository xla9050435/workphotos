/// 分类领域模型（本期仅逻辑归类，[isLogicalOnly] 恒为 true）。
class Category {
  final int? id;
  final String name;
  final String colorHex;
  final String iconName;
  final bool createEntityFolder;
  final int? parentId;
  final int sortOrder;

  const Category({
    this.id,
    required this.name,
    required this.colorHex,
    required this.iconName,
    this.createEntityFolder = false,
    this.parentId,
    this.sortOrder = 0,
  });

  /// 是否仅逻辑归类（不创建实体磁盘文件夹）。
  ///
  /// 设计决策 D2：本期只做逻辑归类，绝不建真实磁盘文件夹，
  /// 因此 [createEntityFolder] 恒为 false，[isLogicalOnly] 恒为 true。
  bool get isLogicalOnly => !createEntityFolder;

  @override
  String toString() {
    return 'Category(id: $id, name: $name, isLogicalOnly: $isLogicalOnly)';
  }
}
