/// 照片使用状态：未被归类使用 / 已被归类使用。
enum UsedStatus {
  unused,
  used,
}

/// [UsedStatus] 与数据库 int 字段的互转扩展。
extension UsedStatusX on UsedStatus {
  /// 持久化到数据库时使用的整数值（0=未用, 1=已用）。
  int get value {
    switch (this) {
      case UsedStatus.unused:
        return 0;
      case UsedStatus.used:
        return 1;
    }
  }

  /// 从数据库读取的整数值还原为枚举。
  static UsedStatus fromValue(int value) {
    switch (value) {
      case 0:
        return UsedStatus.unused;
      case 1:
        return UsedStatus.used;
      default:
        throw ArgumentError('Unknown UsedStatus value: $value');
    }
  }
}
