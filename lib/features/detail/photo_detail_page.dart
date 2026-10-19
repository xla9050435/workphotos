import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import 'package:photo_view/photo_view.dart';

import 'package:work_photos/data/models/photo.dart';
import 'package:work_photos/features/classify/assign_category_sheet.dart';
import 'package:work_photos/features/detail/video_pane.dart';
import 'package:work_photos/features/share/share_panel.dart';
import 'package:work_photos/providers/photo_provider.dart';
import 'package:work_photos/widgets/status_badge.dart';
import 'package:work_photos/widgets/thumbnail.dart';

/// 照片详情页（B5）。
///
/// 大图查看：优先经 [MediaRef.resolveFile] 取原图，用 [PhotoView] 支持缩放。
/// 支持：
/// - **左右滑动切换**：通过 [photoIds] + [initialIndex] 以 [PageView] 在
///   同一筛选上下文的照片间横向浏览（默认单张模式退化为长度为 1 的列表）。
/// - **下滑全屏**：在全屏态隐藏 AppBar 与元信息栏，仅显示图片；点按或下滑退出。
/// 顶部展示当前序号「i / n」。
class PhotoDetailPage extends ConsumerStatefulWidget {
  final int photoId;
  final List<int>? photoIds;
  final int? initialIndex;

  const PhotoDetailPage({
    super.key,
    required this.photoId,
    this.photoIds,
    this.initialIndex,
  });

  @override
  ConsumerState<PhotoDetailPage> createState() => _PhotoDetailPageState();
}

class _PhotoDetailPageState extends ConsumerState<PhotoDetailPage> {
  late List<int> _ids;
  late int _currentIndex;
  late PageController _pageController;
  bool _fullscreen = false;

  @override
  void initState() {
    super.initState();
    _ids = widget.photoIds ?? <int>[widget.photoId];
    _currentIndex = widget.initialIndex ??
        (_ids.contains(widget.photoId)
            ? _ids.indexOf(widget.photoId)
            : 0);
    _currentIndex = _currentIndex.clamp(0, _ids.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleFullscreen() => setState(() => _fullscreen = !_fullscreen);

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Photo?> currentAsync =
        ref.watch(photoDetailProvider(_ids[_currentIndex]));

    return PopScope(
      // 详情页始终经 context.push 进入，是可出栈的，返回应回到上一层级（相册列表）。
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) context.pop();
      },
      child: Scaffold(
        appBar: _fullscreen
            ? null
            : AppBar(
                // 显式返回按钮：保证点按返回回到相册列表，而非退出软件。
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: '返回',
                  onPressed: () => context.pop(),
                ),
                title: Text('${_currentIndex + 1} / ${_ids.length}'),
                actions: <Widget>[
                IconButton(
                  icon: const Icon(Icons.fullscreen),
                  tooltip: '全屏',
                  onPressed: _toggleFullscreen,
                ),
                currentAsync.maybeWhen(
                  data: (Photo? p) => p == null
                      ? const SizedBox.shrink()
                      : IconButton(
                          icon: const Icon(Icons.share),
                          tooltip: '分享',
                          onPressed: () =>
                              SharePanel.show(context, <Photo>[p]),
                        ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: _ids.length,
        onPageChanged: (int i) => setState(() => _currentIndex = i),
        itemBuilder: (BuildContext ctx, int i) => _PhotoPage(
          photoId: _ids[i],
          fullscreen: _fullscreen,
          onToggleFullscreen: _toggleFullscreen,
        ),
      ),
      ),
    );
  }
}

/// 单张照片页（PageView 的一项）。
class _PhotoPage extends ConsumerStatefulWidget {
  final int photoId;
  final bool fullscreen;
  final VoidCallback onToggleFullscreen;

  const _PhotoPage({
    required this.photoId,
    required this.fullscreen,
    required this.onToggleFullscreen,
  });

  @override
  ConsumerState<_PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends ConsumerState<_PhotoPage> {
  /// PhotoView 缩放状态控制器（外置以保证全屏切换时缩放状态不丢），
  /// 同时供全屏手势层区分「看大图的缩放/平移」与「下滑/上滑手势」，
  /// 避免放大态下拖图误触全屏切换。
  final PhotoViewScaleStateController _scaleStateController =
      PhotoViewScaleStateController();

  @override
  void dispose() {
    _scaleStateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Photo?> photoAsync =
        ref.watch(photoDetailProvider(widget.photoId));
    return photoAsync.when(
      data: (Photo? photo) {
        if (photo == null) {
          return const Center(child: Text('照片不存在或已失效'));
        }
        return _Body(
          photo: photo,
          fullscreen: widget.fullscreen,
          onToggleFullscreen: widget.onToggleFullscreen,
          scaleStateController: _scaleStateController,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败：$e')),
    );
  }
}

/// 详情页主体：大图 + 元数据栏。
class _Body extends ConsumerWidget {
  final Photo photo;
  final bool fullscreen;
  final VoidCallback onToggleFullscreen;
  final PhotoViewScaleStateController scaleStateController;

  const _Body({
    required this.photo,
    required this.fullscreen,
    required this.onToggleFullscreen,
    required this.scaleStateController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        Expanded(
          child: Stack(
            children: <Widget>[
              // 视频：不经 PhotoView，直接进播放面板。
              //
              // 两个要点：
              // 1) 视频分支必须放在 FutureBuilder **外层**——VideoPane 内部
              //    自己会 resolveFile，套在 FutureBuilder 里会让每次 rebuild
              //    都多发起一次文件解析（IO 往返）；
              // 2) 视频不走 PhotoView，因此 scaleStateController 的
              //    scaleState 恒为 initial（或 null），_SwipeLayer 的
              //    「放大态不触发全屏手势」判定不会被误命中，手势照常生效。
              if (photo.isVideo)
                _SwipeLayer(
                  fullscreen: fullscreen,
                  onToggleFullscreen: onToggleFullscreen,
                  scaleStateController: scaleStateController,
                  // 视频：全屏下的轻点交给 VideoPane（切播放/暂停），
                  // 不再退出全屏；退出全屏仍可上滑。
                  tapExitsFullscreen: false,
                  child: VideoPane(photo: photo),
                )
              else
                FutureBuilder<File?>(
                  future: photo.resolveFile(),
                  builder: (BuildContext ctx, AsyncSnapshot<File?> snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final File? file = snap.data;
                    final Widget img = file == null
                        // 失效引用降级：展示缩略图占位。
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                // 注意：photo 是运行时传入的值，不是编译期常量，故不能用 const。
                                PhotoThumbnail(photo: photo, size: 400),
                                const SizedBox(height: 8),
                                Text('源文件缺失，已降级显示缩略图占位',
                                    style: TextStyle(color: scheme.onSurfaceVariant)),
                              ],
                            ),
                          )
                        : PhotoView(
                            imageProvider: FileImage(file),
                            scaleStateController: scaleStateController,
                          );
                    // 全屏手势层：下拉跟手进全屏、上滑退出、全屏态轻点退出。
                    // 必须用 Listener（原始指针）而非 GestureDetector：
                    // PhotoView 的缩放/平移手势识别器会在手势竞技场中胜出并
                    // 消费垂直拖动，导致外层 onVerticalDrag* 几乎无法触发；
                    // Listener 不参与手势竞技，指针事件必然送达。
                    return _SwipeLayer(
                      fullscreen: fullscreen,
                      onToggleFullscreen: onToggleFullscreen,
                      scaleStateController: scaleStateController,
                      child: img,
                    );
                  },
                ),
              if (fullscreen)
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: Icon(Icons.fullscreen_exit, color: scheme.onSurface),
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.surface.withValues(alpha: 0.6),
                    ),
                    tooltip: '退出全屏',
                    onPressed: onToggleFullscreen,
                  ),
                ),
            ],
          ),
        ),
        // 元数据栏显隐动画：进入全屏时收起（尺寸过渡），退出时展开。
        AnimatedSize(
          duration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: fullscreen
              ? const SizedBox(width: double.infinity)
              : _MetaBar(photo: photo),
        ),
      ],
    );
  }
}

/// 元数据栏：已用状态角标 + id/来源相册 + 状态切换按钮 + 备注区块。
class _MetaBar extends ConsumerWidget {
  final Photo photo;

  const _MetaBar({required this.photo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              StatusBadge(isUsed: photo.isUsed),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('ID: ${photo.id}'),
                    Text('来源相册: ${photo.sourceAlbum ?? '—'}'),
                  ],
                ),
              ),
              FilledButton.icon(
                icon: Icon(photo.isUsed ? Icons.remove_circle : Icons.check_circle),
                label: Text(photo.isUsed ? '标为未用' : '标为已用'),
                onPressed: () async {
                  if (photo.id == null) return;
                  await ref
                      .read(photoRepositoryProvider)
                      .markUsed(photo.id!, !photo.isUsed);
                  if (context.mounted) {
                    // 标记后刷新详情页数据。
                    ref.invalidate(photoDetailProvider(photo.id!));
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 所属分类：展示或编辑照片所属分类。
          _CategoryBar(photo: photo),
          const SizedBox(height: 12),
          // 详细信息：拍摄时间 / 尺寸 / 文件大小 / 类型 / 路径（解析 AssetEntity 与原文件）。
          _MetaInfo(photo: photo),
          const SizedBox(height: 12),
          // 备注区块：展示或编辑照片备注（层级浅，单条纯文本）。
          _NoteBlock(
            photo: photo,
            onChanged: (String? text) async {
              if (photo.id == null) return;
              await ref
                  .read(photoRepositoryProvider)
                  .updateNote(photo.id!, text);
              if (context.mounted) {
                ref.invalidate(photoDetailProvider(photo.id!));
              }
            },
          ),
        ],
      ),
    );
  }
}

/// 字节数格式化为可读字符串（B / KB / MB / GB）。
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final double kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final double mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  return '${(mb / 1024).toStringAsFixed(2)} GB';
}

/// 解析出的照片元数据（部分字段可能为 null）。
class _MetaDetail {
  final String? date;
  final String? dimension;
  final String? size;
  final String? mime;
  final String? path;
  const _MetaDetail({this.date, this.dimension, this.size, this.mime, this.path});
}

/// 详细信息区块：解析 [AssetEntity] 与原文件，展示拍摄时间 / 尺寸 / 大小 / 类型 / 路径。
class _MetaInfo extends StatelessWidget {
  final Photo photo;

  const _MetaInfo({required this.photo});

  Future<_MetaDetail?> _resolve() async {
    String? date, dim, size, mime, path;
    try {
      final pm.AssetEntity? entity = photo.mediaRef.isUri
          ? await pm.AssetEntity.fromId(photo.mediaRef.value)
          : null;
      if (entity != null) {
        mime = entity.mimeType;
        final DateTime dt = entity.createDateTime;
        String p2(int n) => n.toString().padLeft(2, '0');
        date =
            '${dt.year}-${p2(dt.month)}-${p2(dt.day)} ${p2(dt.hour)}:${p2(dt.minute)}';
        dim = '${entity.width} × ${entity.height}';
      }
      final File? file = await photo.resolveFile();
      if (file != null) {
        path = file.path;
        size = _formatBytes(await file.length());
      }
    } catch (_) {
      // 解析失败静默降级，信息区块不显示即可。
    }
    return _MetaDetail(date: date, dimension: dim, size: size, mime: mime, path: path);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return FutureBuilder<_MetaDetail?>(
      future: _resolve(),
      builder: (BuildContext ctx, AsyncSnapshot<_MetaDetail?> snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final _MetaDetail? d = snap.data;
        final List<List<String>> rows = <List<String>>[
          if (d?.date != null) <String>['拍摄时间', d!.date!],
          // 视频时长（导入时入库，无需解析实体）。
          if (photo.isVideo && photo.durationLabel != null)
            <String>['时长', photo.durationLabel!],
          if (d?.dimension != null) <String>['尺寸', d!.dimension!],
          if (d?.size != null) <String>['文件大小', d!.size!],
          if (d?.mime != null) <String>['类型', d!.mime!],
          if (d?.path != null) <String>['路径', d!.path!],
        ];
        if (rows.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
                SizedBox(width: 6),
                Text('详细信息', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            for (final List<String> r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: 72,
                      child: Text(r[0], style: TextStyle(color: scheme.onSurfaceVariant)),
                    ),
                    Expanded(child: Text(r[1])),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 全屏手势层（原始指针方案，不参与手势竞技场）。
///
/// - 非全屏：**下拉跟手**（图片随手指阻尼下移），松手时位移达阈值 → 进入
///   全屏，否则回弹；也支持快速下滑轻扫（位移超阈值、垂直为主、时长短）。
/// - 全屏：**上拉跟手**，松手位移达阈值 → 退出全屏；轻点也退出全屏。
///
/// 为什么不用 [GestureDetector]：内层 PhotoView 的缩放/平移手势识别器会在
/// 手势竞技场中胜出，垂直拖动被其消费，外层 onVerticalDragEnd 基本无法
/// 触发。[Listener] 直接接收原始指针事件，与 PhotoView 缩放互不干扰。
/// 「快速轻扫」判据（时长 + 位移方向）避免缩放态慢速拖图误触发。
class _SwipeLayer extends StatefulWidget {
  final bool fullscreen;
  final VoidCallback onToggleFullscreen;
  final Widget child;
  /// PhotoView 缩放状态：放大态下拖图属于查看平移，跳过全屏手势判定。
  final PhotoViewScaleStateController? scaleStateController;
  /// 全屏态「轻点」是否退出全屏（默认 true，保持照片既有行为）。
  ///
  /// 视频传 false：全屏下把轻点交给 [VideoPane] 自行处理（切换播放/暂停），
  /// 避免「点画面想暂停却被判为退出全屏」。无论取值如何，全屏「上滑」退出
  /// 路径始终保留。
  final bool tapExitsFullscreen;

  const _SwipeLayer({
    required this.fullscreen,
    required this.onToggleFullscreen,
    required this.child,
    this.scaleStateController,
    this.tapExitsFullscreen = true,
  });

  @override
  State<_SwipeLayer> createState() => _SwipeLayerState();
}

class _SwipeLayerState extends State<_SwipeLayer> {
  /// 快速轻扫判定：最小垂直位移（逻辑像素）。
  static const double _swipeThreshold = 80;

  /// 跟手拖拽提交阈值：跟手位移达到该值，松手即切换全屏态。
  static const double _dragCommitOffset = 140;

  /// 「轻扫」的最大时长：超过则视为拖拽/缩放操作，不按轻扫判定。
  static const Duration _swipeMaxDuration = Duration(milliseconds: 600);

  /// 进入跟手的判定：纵向位移超过该值且纵向分量明显大于横向。
  static const double _dragStartThreshold = 12;

  Offset? _downPos;
  DateTime? _downAt;
  // 跟手位移（逻辑像素，正=下拉 / 负=上拉），已带 0.5 阻尼。
  double _dragDy = 0;
  bool _dragging = false;
  // 本次手势期间图片曾处于放大态：平移查看，松手不触发全屏切换。
  bool _zoomedDuringGesture = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (PointerDownEvent e) {
        _downPos = e.position;
        _downAt = DateTime.now();
        _dragging = false;
        _dragDy = 0;
        _zoomedDuringGesture = false;
      },
      onPointerMove: (PointerMoveEvent e) {
        final Offset? down = _downPos;
        if (down == null) return;
        // 放大态（用户已缩放图片）：拖动属于查看平移，不做全屏手势判定。
        final PhotoViewScaleState? ss =
            widget.scaleStateController?.scaleState;
        if (ss != null && ss != PhotoViewScaleState.initial) {
          _zoomedDuringGesture = true;
          if (_dragging) {
            // 已在跟手中突然进入放大态（如双指缩放）：复位跟手位移。
            setState(() {
              _dragging = false;
              _dragDy = 0;
            });
          }
          return;
        }
        final double dy = e.position.dy - down.dy;
        final double dx = e.position.dx - down.dx;
        // 仅纵向意图明显时进入跟手，避免干扰横向翻页与缩放。
        if (!_dragging && dy.abs() > _dragStartThreshold && dy.abs() > dx.abs() * 1.5) {
          _dragging = true;
        }
        if (!_dragging) return;
        setState(() => _dragDy = dy * 0.5);
      },
      onPointerUp: (PointerUpEvent e) => _handleUp(e.position),
      onPointerCancel: (PointerCancelEvent e) => _reset(),
      // 跟手时无动画实时跟随；松手后 220ms 缓动回弹（或保持切换后的位置）。
      child: AnimatedContainer(
        duration: _dragging
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _dragDy, 0),
        child: widget.child,
      ),
    );
  }

  void _reset() {
    _downPos = null;
    _downAt = null;
    _zoomedDuringGesture = false;
    if (_dragging || _dragDy != 0) {
      setState(() {
        _dragging = false;
        _dragDy = 0;
      });
    }
  }

  void _handleUp(Offset pos) {
    final Offset? down = _downPos;
    final DateTime? downAt = _downAt;
    final bool wasDragging = _dragging;
    final double committedDy = _dragDy;
    final bool wasZoomed = _zoomedDuringGesture;
    _reset();
    if (down == null || downAt == null) return;

    final Offset delta = pos - down;
    final bool isTap = delta.distance < 12;
    final bool quick = DateTime.now().difference(downAt) < _swipeMaxDuration;

    if (widget.fullscreen) {
      if (isTap) {
        // 视频（tapExitsFullscreen=false）在全屏下的轻点由播放器自行处理：
        // 此处直接返回，既不退出全屏，也不进入下面的上滑判定。
        if (widget.tapExitsFullscreen) widget.onToggleFullscreen();
        return;
      }
      if (wasZoomed) {
        return; // 放大态平移查看，不触发全屏切换
      }
      // 全屏态：上滑退出（跟手位移达阈值，或快速上滑轻扫）。
      final bool isSwipeUp = -delta.dy > _swipeThreshold &&
          delta.dy < 0 &&
          delta.dy.abs() > 2 * delta.dx.abs() &&
          quick;
      if ((wasDragging && -committedDy > _dragCommitOffset) || isSwipeUp) {
        widget.onToggleFullscreen();
      }
      return;
    }

    if (wasZoomed) {
      return; // 放大态平移查看，不触发全屏切换
    }
    // 非全屏：下滑进入全屏（跟手位移达阈值，或快速下滑轻扫）。
    final bool isSwipeDown = delta.dy > _swipeThreshold &&
        delta.dy > 2 * delta.dx.abs() &&
        quick;
    if ((wasDragging && committedDy > _dragCommitOffset) || isSwipeDown) {
      widget.onToggleFullscreen();
    }
  }
}

/// 所属分类区块：展示照片当前归属的分类，并提供编辑入口。
///
/// 点击可拉起 [AssignCategorySheet] 修改归属；归属变化后自动刷新本详情页。
class _CategoryBar extends ConsumerStatefulWidget {
  final Photo photo;

  const _CategoryBar({required this.photo});

  @override
  ConsumerState<_CategoryBar> createState() => _CategoryBarState();
}

class _CategoryBarState extends ConsumerState<_CategoryBar> {
  /// 当前所属分类列表（id + 名称）。
  List<({int id, String name})> _categories = const <({int id, String name})>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    if (widget.photo.id == null) return;
    final list = await ref
        .read(photoRepositoryProvider)
        .categoriesOfPhotoWithNames(widget.photo.id!);
    if (mounted) {
      setState(() {
        _categories = list;
        _loading = false;
      });
    }
  }

  /// 分类变更后刷新本区块（由 [AssignCategorySheet] 完成写库后触发）。
  void _onChanged() {
    if (widget.photo.id != null && mounted) {
      _loadCategories();
      // 同时让详情页整体刷新（标记已用等状态联动）。
      ref.invalidate(photoDetailProvider(widget.photo.id!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.folder, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            const Text('所属分类', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('编辑分类'),
              onPressed: () => _showAssign(context),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // 分类加载态 / 空态 / 有分类态：整体作为单个列表项，避免 collection-for
        // 与 if/else 表达式链在列表上下文里的解析歧义。
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_categories.isEmpty)
          Text('未归入任何分类',
              style: TextStyle(color: scheme.onSurfaceVariant))
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final ({int id, String name}) cat in _categories)
                _CategoryChip(
                  name: cat.name,
                  onRemove: () async {
                    if (widget.photo.id == null) return;
                    await ref
                        .read(photoRepositoryProvider)
                        .unassignCategory(widget.photo.id!, cat.id);
                    _onChanged();
                  },
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _showAssign(BuildContext context) async {
    if (widget.photo.id == null) return;
    await AssignCategorySheet.show(context, <int>[widget.photo.id!]);
    _onChanged();
  }
}

/// 单个分类标签（带移除按钮）。
class _CategoryChip extends StatelessWidget {
  final String name;
  final VoidCallback onRemove;

  const _CategoryChip({required this.name, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Chip(
      label: Text(name),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onRemove,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: scheme.outlineVariant),
    );
  }
}

/// 照片备注区块：展示已有备注（浅色卡片），并提供编辑入口。
///
/// 层级浅：仅一个文本框，不做多级标签树（第四轮打磨需求）。
class _NoteBlock extends StatelessWidget {
  final Photo photo;
  final ValueChanged<String?> onChanged;

  const _NoteBlock({required this.photo, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.note, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            const Text('备注', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('编辑备注'),
              onPressed: () => _showEdit(context),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (photo.note != null && photo.note!.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(photo.note!),
          )
        else
          Text('暂无备注', style: TextStyle(color: scheme.onSurfaceVariant)),
      ],
    );
  }

  Future<void> _showEdit(BuildContext context) async {
    final TextEditingController controller =
        TextEditingController(text: photo.note ?? '');
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('编辑备注'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入照片备注（纯文本）',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result != null) {
      onChanged(result.isEmpty ? null : result);
    }
  }
}
