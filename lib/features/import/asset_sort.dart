/// 相册网格排序工具（BugFix：点选后图片位置跳动/洗牌）。
///
/// 本文件刻意不 import photo_manager：排序比较逻辑抽成纯函数，
/// 单测里只用 [DateTime] + `String` 就能覆盖，不需要真机也不需要插件桩。
library;

/// 相册网格排序比较器：主键拍摄时间，次级键资产 id，两个键方向严格一致。
///
/// 入参用「摊平的值」而不是 `pm.AssetEntity`，是为了让本函数可在纯 Dart
/// 单测里调用（photo_manager 依赖 Android/iOS 通道，`flutter test` 下拿不到）。
///
/// ## 为什么必须加 tie-break（三个原因叠加，缺一不可）
///
/// 1. **拍摄时间只有秒级精度**。`AssetEntity.createDateTime` 来自 Android
///    MediaStore 的 `DATE_TAKEN`，精确到秒。工地连拍、批量截图会让大量照片
///    落在同一秒里（实测某天 116 张照片有大量同秒），主键相等是常态而不是
///    边角情况。
/// 2. **Dart 的 [List.sort] 是不稳定排序**。它用内省排序（introsort：快排
///    + 堆排 + 插入排序混合），元素相等时的相对顺序取决于算法内部的分区
///    过程，与输入顺序没有必然关系——所以「同一份数据排两次结果不同」是
///    完全可能的。
/// 3. **排序发生在 build 里**。`ImportPage` 的 `_buildGroups()` 每次 build
///    都会被调用，而「点一下选中」也会触发 `setState` → 重新 build → 重新
///    排序整份 `_assets`。
///
/// 三点叠加，用户看到的就是「点一下某张图选中，列表里图片的位置全变了」。
/// 补上 id 作次级键后，比较器成为**严格全序**（任意两个不同资产一定分出
/// 大小、不会返回 0），排序结果只由数据本身决定，与输入顺序、与具体排序
/// 算法都无关：同一份数据排 100 次结果完全一致。
///
/// ## 为什么次级键方向要和主键一致
///
/// 若「新→旧」时时间降序、id 升序，那么同秒的一组照片内部会是 id 升序，
/// 而下一秒（更早）的那组又是另一套方向，翻页/加载更多合并后视觉上会出现
/// 「同一批连拍被反着放」的错位。让两个键同向（`newToOld` 时整体取反），
/// 整列就等价于「按 (时间, id) 元组做单一方向的字典序」，语义最直白，
/// 也最容易验证：`newToOld = true` 时输出必然是 `newToOld = false` 输出的
/// 逆序（见单测）。
///
/// [aTime]/[bTime] 为拍摄时间，[aId]/[bId] 为资产 id（MediaStore id 字符串，
/// 全局唯一且稳定），[newToOld] 为 true 表示「新→旧」。
///
/// 返回负数表示 a 排在 b 前，正数表示 a 排在 b 后，0 只会在
/// 「同一张资产自己和自己比」时出现。
int compareAssetOrder({
  required DateTime aTime,
  required String aId,
  required DateTime bTime,
  required String bId,
  required bool newToOld,
}) {
  final int byTime = aTime.compareTo(bTime);
  // 主键不相等就用主键；相等时用 id 兜底，保证全序、结果可复现。
  final int cmp = byTime != 0 ? byTime : aId.compareTo(bId);
  return newToOld ? -cmp : cmp;
}
