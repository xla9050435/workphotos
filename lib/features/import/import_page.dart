import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

import 'package:work_photos/data/repositories/photo_repository.dart';
import 'package:work_photos/features/import/album_browser.dart';
import 'package:work_photos/features/import/asset_sort.dart';
import 'package:work_photos/features/import/asset_viewer.dart';
import 'package:work_photos/features/import/import_controller.dart';
import 'package:work_photos/features/import/quick_import_sheet.dart';
import 'package:work_photos/features/me/settings_provider.dart';
import 'package:work_photos/providers/photo_provider.dart';
import 'package:work_photos/services/camera_launcher.dart';
import 'package:work_photos/widgets/back_blocker.dart';
import 'package:work_photos/widgets/status_views.dart';
import 'package:work_photos/widgets/thumbnail.dart';

/// 引用式导入页（B4）。
///
/// 使用 photo_manager 只读枚举相册与资产；选中后点击"引用导入"，
/// 仅将 AssetEntity.id 写入数据库，不拷贝任何字节。
///
/// 本页负责：
/// - 相册加载与并行预取各相册数量（仅用于下拉项展示，避免每个 item 各起请求）；
/// - 相册内资产分页累积（每页 100 张，滚动到底自动加载更多，支持大相册）；
/// - 客户端排序（按拍摄时间 新→旧 / 旧→新）与按天分组；UI 由 [AlbumBrowser] 承载。
class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage>
    with WidgetsBindingObserver {
  List<pm.AssetPathEntity> _albums = <pm.AssetPathEntity>[];
  pm.AssetPathEntity? _currentAlbum;
  // 累积的完整资产列表（跨分页），排序与分组均基于此列表，而非单页结果。
  List<pm.AssetEntity> _assets = <pm.AssetEntity>[];
  final Set<pm.AssetEntity> _selected = <pm.AssetEntity>{};
  final Map<String, int> _albumCounts = <String, int>{};
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  bool _sortNewToOld = true;
  String? _error;
  // 是否仅获得「部分访问」权限（Android 13+ 用户选了部分照片）。
  bool _isLimited = false;
  // 按日期筛选（同天，忽略时分秒）。null 表示不过滤。
  DateTime? _filterDate;
  // 按星期几筛选（1=周一 … 7=周日）。null 表示不过滤。
  int? _filterWeekday;

  // —— 系统返回拦截（分支页内 PopScope 拦不到，见 BackBlocker 说明）——
  /// 多选态下：返回 = 清空选中（消费本次返回）；非多选态不拦截。
  late final BackHandler _backHandler = () {
    if (_selected.isNotEmpty) {
      setState(() => _selected.clear());
      _syncBackBlock(false); // 选中已清空 → 期望解除拦截
      return true;
    }
    return false;
  };

  /// 期望状态：当前**应该**是否拦截系统返回（选中集非空即为 true）。
  bool _wantBackBlock = false;
  /// 实际状态：是否**已经真正** push 到 [BackBlocker]。
  ///
  /// 与 [_wantBackBlock] 分离，是为了让「已注册」这一事实有唯一真相，
  /// 既不会重复 push，也不会 pop 一个还没 push 的 handler（见 dispose）。
  bool _backBlocked = false;
  /// 是否已排入帧后回调：合并同一帧内的多次切换，只落定一次。
  bool _backSyncScheduled = false;

  /// 请求把返回拦截同步为 [block] —— **必须在 build 之外调用**。
  ///
  /// 两条独立的理由，别混淆：
  ///
  /// 1. **为什么返回拦截改用 BackButtonListener**：go_router 13.2.5 的
  ///    `popRoute()` 在「根 Navigator 只有 shell、分支也没有可 pop 路由」时
  ///    直接 `return false`，根本不调用 `maybePop()`，所以挂在 Shell 上的
  ///    `PopScope(canPop: false)` 从未被咨询（详见 `AppScaffold` 类文档）。
  ///    现在的 `BackButtonListener` 直接读 [BackBlocker] 注册表消费返回。
  ///
  /// 2. **为什么 push/pop 仍要排到帧后**：build 期间修改全局状态
  ///    （[BackBlocker] 的注册表）会被 Flutter 判定为「构建中改状态」，
  ///    抛出 `setState() or markNeedsBuild() called during build`，中断本次
  ///    build。与返回能否生效无关，但会引发别的构建问题。
  ///
  /// 实现：改选中态时只登记「期望」，真正的 push/pop 排到帧后执行；
  /// `_wantBackBlock`（期望）与 `_backBlocked`（真实注册状态）分开维护，
  /// 保证 dispose 时不会 pop 一个从未 push 过的 handler。
  void _syncBackBlock(bool block) {
    if (block == _wantBackBlock) return; // 期望没变：无需排队
    _wantBackBlock = block;
    if (_backSyncScheduled) return; // 已有帧后回调，届时按最新期望落定
    _backSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _backSyncScheduled = false;
      // 页面已销毁：注册/注销交给 dispose 处理（此处不能再碰 BackBlocker，
      // 否则可能为一个已卸载页面留下拦截器）。
      if (!mounted) return;
      if (_wantBackBlock == _backBlocked) return; // 已与期望一致
      if (_wantBackBlock) {
        BackBlocker.push(_backHandler);
      } else {
        BackBlocker.pop(_backHandler);
      }
      _backBlocked = _wantBackBlock;
    });
  }

  /// 星期几标签（周一至周日），索引 i 对应 [DateTime.weekday] = i+1。
  static const List<String> _weekdayLabels = <String>[
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '日',
  ];

  /// 每页资产数量。300 张可显著减少"按天分组显示不全需多次触底"的感知
  /// （第 0 页即覆盖更长时间段；触底仍会继续加载）。
  static const int _pageSize = 300;

  /// 分页查询过滤器：显式按拍摄时间「从新到旧」排序。
  ///
  /// 关键修复：[pm.FilterOptionGroup] 默认 orders 为空，原生层（Android
  /// MediaStore）无排序时按添加顺序（旧→新）返回，第 0 页只会拿到最老的
  /// 100 张，界面上看就像「读不到最新照片」。显式指定 DESC 后，
  /// 第 0 页即最新的 100 张，配合客户端排序顶部直接就是今天。
  static pm.FilterOptionGroup _newestFirstFilter() => pm.FilterOptionGroup(
        orders: <pm.OrderOption>[
          const pm.OrderOption(
            type: pm.OrderOptionType.createDate,
            asc: false,
          ),
        ],
      );

  @override
  void initState() {
    super.initState();
    // 监听应用生命周期：从系统设置返回后重载（部分访问 → 完整访问）。
    WidgetsBinding.instance.addObserver(this);
    _loadAlbums();
  }

  @override
  void dispose() {
    // 只有**确实 push 过**（_backBlocked）才需要 pop。若 push 还躺在帧后
    // 回调队列里没执行：回调里的 `if (!mounted) return` 会跳过它（等于从未
    // 注册），此时 _backBlocked 仍为 false，这里也就不 pop —— 状态自洽。
    // 反过来若已注册，则必须 pop，否则拦截器会随页面卸载残留在全局栈里，
    // 让 Shell 的 canPop 永远为 false（返回键彻底失效）。
    if (_backBlocked) {
      _backBlocked = false;
      BackBlocker.pop(_backHandler);
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 从系统设置页返回时，重新请求权限并刷新相册。
      _loadAlbums();
    }
  }

  /// 请求 photo_manager 权限并加载相册列表。
  ///
  /// 修复「很多照片读不到 / 最近拍摄的读不到」：
  /// A) 显式选取「全部照片」相册（[pm.AssetPathEntity.isAll]），找不到再退回首个；
  /// B) 若处于「部分访问」（Android 13+ 选了部分照片，[pm.PermissionState.isLimited]），
  ///    不报错，仅置标志位由 UI 引导用户去设置开启完整权限。
  Future<void> _loadAlbums() async {
    // 并发保护：避免生命周期 resumed 与 presentLimited 回调同时触发两次查询互相干扰。
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pm.PermissionState ps =
          await pm.PhotoManager.requestPermissionExtend();
      // 判定是否仅获得「部分访问」（limited）。
      final bool isLimited = ps.isLimited;
      if (mounted) setState(() => _isLimited = isLimited);
      if (!ps.hasAccess) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = '未获得相册访问权限';
          });
        }
        return;
      }
      final List<pm.AssetPathEntity> albums =
          await pm.PhotoManager.getAssetPathList(
        type: pm.RequestType.common,
        // 相册会携带该过滤器用于后续 getAssetListPaged 分页（见
        // AssetPathEntity.getAssetListPaged 的 optionGroup: filterOption）。
        filterOption: _newestFirstFilter(),
      );
      if (mounted) {
        setState(() {
          _albums = albums;
          _loading = false;
        });
      }
      // 并行预取各相册数量，写入 [_albumCounts]（id -> count）。
      _prefetchCounts(albums);
      if (albums.isNotEmpty) {
        // 显式选取「全部照片」相册；找不到 isAll 再退回到 albums.first。
        final pm.AssetPathEntity defaultAlbum = albums.firstWhere(
          (pm.AssetPathEntity a) => a.isAll,
          orElse: () => albums.first,
        );
        await _selectAlbum(defaultAlbum);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  /// 并行预取各相册资产数量，写入 [_albumCounts]（id -> count）。
  Future<void> _prefetchCounts(List<pm.AssetPathEntity> albums) async {
    final List<Future<void>> tasks = albums.map((pm.AssetPathEntity a) async {
      final int count = await a.assetCountAsync;
      _albumCounts[a.id] = count;
    }).toList();
    await Future.wait(tasks);
    if (mounted) setState(() {});
  }

  /// 切换相册：重置分页并加载第 0 页。
  Future<void> _selectAlbum(pm.AssetPathEntity album) async {
    setState(() {
      _currentAlbum = album;
      _loading = true;
      _assets = <pm.AssetEntity>[];
      _page = 0;
      _hasMore = true;
    });
    try {
      final List<pm.AssetEntity> assets =
          await album.getAssetListPaged(page: 0, size: _pageSize);
      if (mounted) {
        setState(() {
          _assets = assets;
          _loading = false;
          // 只有页满才认为还有下一页：恰好整除时 `>=` 会多发一次空请求。
          _hasMore = assets.length == _pageSize;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  /// 滚动到底自动加载更多（第 page+1 页），追加到 [_assets]。
  ///
  /// 以 [_loadingMore] / [_hasMore] / [_loading] 多重守卫，避免重复与越界请求。
  Future<void> _loadMore() async {
    if (_loadingMore || _loading || !_hasMore || _currentAlbum == null) return;
    setState(() => _loadingMore = true);
    try {
      final int next = _page + 1;
      final List<pm.AssetEntity> more =
          await _currentAlbum!.getAssetListPaged(page: next, size: _pageSize);
      if (mounted) {
        setState(() {
          // 去重兜底：`getAssetListPaged` 是 offset 分页，而相册在用户浏览
          // 期间可能被系统写入新照片（实测总数 12287→12288）。头部插入会让
          // 后续所有项后移一位，于是第 N 页会与已加载内容重叠，出现同一张图
          // 两次。重复 id 除了视觉重复，还会让 [AlbumBrowser] 的
          // `_itemKeys.putIfAbsent(asset.id, ...)` 给两个格子返回同一个
          // GlobalKey，直接抛 duplicate GlobalKey。故按 id 过滤后再追加。
          final Set<String> known =
              _assets.map((pm.AssetEntity a) => a.id).toSet();
          final List<pm.AssetEntity> fresh = more
              .where((pm.AssetEntity a) => !known.contains(a.id))
              .toList();
          _assets = <pm.AssetEntity>[..._assets, ...fresh];
          _page = next;
          // 用原始页长度判断，不能用去重后的长度：整页都是重复项时
          // 去重结果为 0 条，但下一页其实还有数据，误判会让分页提前中断。
          _hasMore = more.length == _pageSize;
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingMore = false;
          _error = '$e';
        });
      }
    }
  }

  /// 切换排序方式（新→旧 / 旧→新）。
  ///
  /// 仅改变标志位；实际排序在 [_buildGroups] 中基于完整 [_assets] 进行，
  /// 不会因只排当前页而错乱。
  void _onSelectSort(bool newToOld) {
    if (_sortNewToOld == newToOld) return;
    setState(() => _sortNewToOld = newToOld);
  }

  void _toggleAsset(pm.AssetEntity asset) {
    setState(() {
      if (_selected.contains(asset)) {
        _selected.remove(asset);
      } else {
        _selected.add(asset);
      }
    });
    // 选中集变化后同步返回拦截（首张入选 → 注册；清空 → 注销）。
    // 必须在 build 之外调用，见 [_syncBackBlock] 的说明。
    _syncBackBlock(_selected.isNotEmpty);
  }

  /// 滑动连选「加模式」：仅添加选中（不切换）。
  void _selectAsset(pm.AssetEntity asset) {
    if (!_selected.contains(asset)) {
      setState(() => _selected.add(asset));
      _syncBackBlock(true); // 必然非空，无需再算 isNotEmpty
    }
  }

  /// 滑动连选「减模式」：仅移除选中（不切换）。
  void _deselectAsset(pm.AssetEntity asset) {
    if (_selected.remove(asset)) {
      setState(() {});
      _syncBackBlock(_selected.isNotEmpty); // 可能减到 0 张 → 解除拦截
    }
  }

  /// 日期头「全选」：把该组全部资产加入选择集。
  void _selectGroup(List<pm.AssetEntity> assets) {
    setState(() => _selected.addAll(assets));
    _syncBackBlock(true); // 全选后必然非空
  }

  /// 筛选条用的统一芯片样式（与 [FilterBar] 视觉一致）。
  Widget _filterChip(String label, bool active, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => onTap(),
      ),
    );
  }

  /// 客户端排序 + 按天分组（保序 [LinkedHashMap]）。
  ///
  /// 排序后依次应用日期 / 星期几筛选（均为可选），再按
  /// [pm.AssetEntity.createDateTime] 的年月日分组，键即日期头文本
  /// （格式 yyyy年M月d日）。分组基于完整 [_assets]，而非单页结果。
  ///
  /// 排序键见 [compareAssetOrder]：拍摄时间为主键、资产 id 为次级键，且两个
  /// 键方向一致。**次级键不可省**——MediaStore 的拍摄时间只到秒，同秒照片
  /// 是常态；而 [List.sort] 不稳定、本方法又每次 build 都重跑，缺 tie-break
  /// 时同秒照片的相对顺序每次都可能不同，表现为「点一下选中，格子就换位」。
  LinkedHashMap<String, List<pm.AssetEntity>> _buildGroups() {
    final List<pm.AssetEntity> sorted = List<pm.AssetEntity>.from(_assets);
    sorted.sort((pm.AssetEntity a, pm.AssetEntity b) => compareAssetOrder(
          aTime: a.createDateTime,
          aId: a.id,
          bTime: b.createDateTime,
          bId: b.id,
          newToOld: _sortNewToOld,
        ));
    // 日期筛选：同天（忽略时分秒）。
    List<pm.AssetEntity> filtered = sorted;
    if (_filterDate != null) {
      filtered = filtered.where((pm.AssetEntity a) {
        final DateTime d = a.createDateTime;
        return d.year == _filterDate!.year &&
            d.month == _filterDate!.month &&
            d.day == _filterDate!.day;
      }).toList();
    }
    // 星期几筛选：createDateTime.weekday 相等。
    if (_filterWeekday != null) {
      filtered = filtered
          .where((pm.AssetEntity a) => a.createDateTime.weekday == _filterWeekday)
          .toList();
    }
    final LinkedHashMap<String, List<pm.AssetEntity>> groups =
        LinkedHashMap<String, List<pm.AssetEntity>>();
    for (final pm.AssetEntity asset in filtered) {
      final DateTime dt = asset.createDateTime;
      final String key = '${dt.year}年${dt.month}月${dt.day}日';
      groups.putIfAbsent(key, () => <pm.AssetEntity>[]).add(asset);
    }
    return groups;
  }

  /// 引用导入前的二次确认：以网格预览即将导入的照片，确认后才真正写入。
  Future<void> _confirmImport() async {
    if (_selected.isEmpty) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('确认导入 ${_selected.length} 项媒体'),
        content: SizedBox(
          width: double.maxFinite,
          height: 380,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('即将以"引用"方式导入以下媒体（仅记录引用，不复制文件）：'),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: _selected.length,
                  itemBuilder: (c, i) =>
                      Thumbnail(entity: _selected.elementAt(i), size: 150),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认导入'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _doImport();
  }

  Future<void> _doImport() async {
    if (_selected.isEmpty) return;
    final PhotoRepository repo = ref.read(photoRepositoryProvider);
    final ImportController controller = ImportController(repo);
    final int n = await controller.importAssets(
      _selected.toList(),
      album: _currentAlbum == null ? null : albumDisplayName(_currentAlbum!),
    );
    if (mounted) {
      setState(() => _selected.clear());
      _syncBackBlock(false); // 导入完成清空选中 → 解除返回拦截
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已引用导入 $n 项媒体（仅记录引用，未复制文件）')),
      );
    }
  }

  /// 相机快捷入口：拉起系统相机 → 拍完刷新 → 按时间戳筛选本次新增 → 快速导入弹窗。
  ///
  /// 为什么用「时间戳筛选」而不是「总数差」判断新增：
  /// 相册随时可能被其它应用并发写入（别的 App 也在拍照），「相册总数前后差」
  /// 会把别人的新增也算成本次拍摄，导致误判导入范围；而本次拍摄的
  /// `createDateTime` 必然晚于拍摄前记录的基线，逐项按时间戳筛选更精确、
  /// 可解释，也不受并发写入干扰。基线前置 2 秒容差，用于吸收设备时钟精度与
  /// 文件写入/入库的延迟。
  Future<void> _openCameraAndQuickImport() async {
    // 保障写入公共 DCIM 所需的存储权限（不阻断流程）：
    // - Android 9 及以下（API<=28）必须 WRITE_EXTERNAL_STORAGE 才能创建输出文件；
    // - 它与 READ 同属 STORAGE 组，若 READ 已授予，本次请求会静默自动授予（无弹窗）；
    // - 新系统上 Permission.storage 已废弃，请求直接返回 denied，无副作用。
    // 用户拒绝时拍照会失败并被静默忽略，不影响其余功能。
    await Permission.storage.request();
    if (!mounted) return;

    // 拍摄前记录时间基线（2 秒容差：防设备时钟与写入延迟）。
    final DateTime since =
        DateTime.now().subtract(const Duration(seconds: 2));

    final bool captured = await CameraLauncher.capturePhoto();
    if (!mounted) return;
    if (!captured) return; // 用户取消 / 无相机 / 失败：静默返回。

    // 刷新相册列表与当前相册第 0 页（相机已把文件写入 MediaStore）。
    await _loadAlbums();
    if (!mounted) return;

    final pm.AssetPathEntity? album = _currentAlbum;
    if (album == null) return;

    // 重新取第 0 页（最新 size 项），筛出拍摄时间晚于基线的项。
    final List<pm.AssetEntity> page0 =
        await album.getAssetListPaged(page: 0, size: 50);
    final List<pm.AssetEntity> fresh = page0
        .where((pm.AssetEntity a) => a.createDateTime.isAfter(since))
        .toList();
    if (!mounted) return;

    if (fresh.isEmpty) {
      // 可能是媒体库尚未索引完成：提示用户稍后刷新重试。
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('未识别到本次新增的媒体（可能仍在写入相册，稍后点右上刷新重试）'),
        ),
      );
      return;
    }

    final int? imported = await showQuickImportSheet(
      context,
      assets: fresh,
      albumLabel: albumDisplayName(album),
    );
    if (!mounted) return;
    if (imported != null && imported > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已快速导入 $imported 项媒体（仅记录引用，未复制文件）')),
      );
      // 再刷一次，确保导入后列表状态最新。
      await _loadAlbums();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    // 注意：返回拦截的注册/注销**不在 build 里做**（旧实现就是这么踩坑的）：
    // 在 build 中改 BackBlocker.count 会触发 Shell 的 setState during build，
    // 详见 [_syncBackBlock]。现在改为在每个改变选中集的入口处调用它。
    return PopScope(
      // 选中态下：返回应"退出选中界面"而非退出软件；非选中态则正常返回
      //（到达根则退出）。注：分支内 PopScope 拦不到系统返回（go_router
      // 限制），系统返回由 Shell 的 BackBlocker 处理；此 PopScope 保留
      // 给根 Navigator maybePop 路径（如 AppBar 返回箭头）兜底。
      canPop: _selected.isEmpty,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          setState(() => _selected.clear());
          _syncBackBlock(false); // 与上面清空选中保持一致
        }
      },
      child: Scaffold(
        appBar: AppBar(
        title: const Text('引用式导入'),
        actions: <Widget>[
          // 相机快捷入口：拍完自动识别新增 → 弹「快速导入」确认后引用入库。
          IconButton(
            icon: const Icon(Icons.photo_camera_outlined),
            tooltip: '拍照快速导入',
            onPressed: _loading ? null : _openCameraAndQuickImport,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新相册',
            // 部分 ROM 在系统选择面板关闭后可能返回缓存，手动刷新可强制重新枚举。
            onPressed: _loading ? null : _loadAlbums,
          ),
        ],
        // 按日期 / 星期几 筛选条（与「相册」页保持一致的视觉与交互）。
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Theme.of(context).appBarTheme.backgroundColor ??
                scheme.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: <Widget>[
                  _filterChip(
                    _filterDate == null
                        ? '按日期'
                        : '${_filterDate!.month}/${_filterDate!.day}',
                    _filterDate != null,
                    () async {
                      if (_filterDate != null) {
                        setState(() => _filterDate = null);
                        return;
                      }
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null && mounted) {
                        setState(() => _filterDate = picked);
                      }
                    },
                  ),
                  for (int i = 0; i < _weekdayLabels.length; i++)
                    _filterChip(
                      _weekdayLabels[i],
                      _filterWeekday == i + 1,
                      () => setState(() => _filterWeekday =
                          _filterWeekday == i + 1 ? null : i + 1),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _error != null
          ? AppErrorState(message: _error!, onRetry: _loadAlbums)
          : _loading && _assets.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: <Widget>[
                    // 部分访问权限引导条（可在设置中关闭显示）。
                    if (_isLimited &&
                        ref.watch(settingsProvider).showLimitedBanner)
                      _LimitedPermissionBanner(
                        // 拉起系统「选择照片」面板（Android 14+），可选"全部"。
                        onPickMore: () async {
                          await pm.PhotoManager.presentLimited(
                              type: pm.RequestType.common);
                          _loadAlbums();
                        },
                        onGrant: () async {
                          // 前往系统设置开启完整访问权限。
                          await pm.PhotoManager.openSetting();
                          // 延迟 1s 后重载兜底（同时有 resume 监听刷新）。
                          Future<void>.delayed(const Duration(seconds: 1), () {
                            if (mounted) _loadAlbums();
                          });
                        },
                      ),
                    // 已加载进度提示：按天分组只显示「已加载」的照片，
                    // 未滚到底的照片不会出现——明确告知分页机制避免误解为丢失。
                    if (_currentAlbum != null &&
                        _assets.length <
                            (_albumCounts[_currentAlbum!.id] ?? 0))
                      Container(
                        width: double.infinity,
                        // M3：信息条用 surfaceContainerHighest 底 +
                        // onSurfaceVariant 文字（弱强调层级）。
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Text(
                          '已加载 ${_assets.length} / 共 ${_albumCounts[_currentAlbum!.id] ?? 0} 项，下滑到底自动加载更多',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ),
                    Expanded(
                      child: AlbumBrowser(
                        albums: _albums,
                        albumCounts: _albumCounts,
                        currentAlbum: _currentAlbum,
                        grouped: _buildGroups(),
                        sortNewToOld: _sortNewToOld,
                        selected: _selected,
                        loadingMore: _loadingMore,
                        onSelectAlbum: _selectAlbum,
                        onSelectSort: _onSelectSort,
                        onToggleAsset: _toggleAsset,
                        onSelectAsset: _selectAsset,
                        onRemoveAsset: _deselectAsset,
                        onSelectGroup: _selectGroup,
                        onViewAsset: (assets, index) =>
                            showAssetViewer(context, assets, index),
                        onLoadMore: _loadMore,
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: _selected.isEmpty
          ? null
          : BottomAppBar(
              child: Row(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('已选 ${_selected.length}'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('引用导入'),
                    onPressed: _confirmImport,
                  ),
                ],
              ),
            ),
      ),
    );
  }
}

/// 部分访问权限引导条。
///
/// 当用户仅授权了「部分照片」（Android 13+ 选了部分照片，photo_manager 处于
/// limited 状态）时显示，提供两条恢复路径：
/// - 「选照片」：[pm.PhotoManager.presentLimited] 拉起系统照片选择面板
///   （Android 14+），用户可"全部选择"后立即读到最新照片；
/// - 「去设置」：跳系统应用设置授予完整权限。
/// 不报错，避免「很多照片读不到」时直接阻断导入流程。
class _LimitedPermissionBanner extends StatelessWidget {
  final VoidCallback onPickMore;
  final VoidCallback onGrant;

  const _LimitedPermissionBanner({
    required this.onPickMore,
    required this.onGrant,
  });

  @override
  Widget build(BuildContext context) {
    // M3：提示/警示类信息用 tertiaryContainer 底 + onTertiaryContainer 内容
    // （色调系统保证对比度，不再硬编码琥珀色 hex）。
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: <Widget>[
          Icon(Icons.info_outline, color: scheme.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '仅授权了部分照片，未授权的照片不会显示。点「选照片」在系统面板右上角选「全部」，或「去设置」改为允许访问所有照片，完成后回本页点右上刷新',
              style: TextStyle(color: scheme.onTertiaryContainer),
            ),
          ),
          TextButton(
            onPressed: onPickMore,
            child: const Text('选照片'),
          ),
          TextButton(
            onPressed: onGrant,
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }
}
