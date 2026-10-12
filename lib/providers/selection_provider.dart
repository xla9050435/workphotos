import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 多选状态：当前已选中的照片 id 集合。
final selectionProvider = StateProvider<Set<int>>((ref) => <int>{});
