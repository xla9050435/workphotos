import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

import 'package:work_photos/core/utils/media_ref.dart';
import 'package:work_photos/data/models/photo.dart';

/// 缩略图内存缓存（T4.1 / R6）。
///
/// 全应用共享的简单 LRU（LinkedHashMap 插入序实现：get 触碰重插，
/// put 后裁剪最旧）。跨页命中——相册网格 / 搜索结果 / 重新进入页面
/// 时不重复向 photo_manager 请求缩略图字节，提升滚动流畅度与
/// 缓存命中率（验收目标 ≥90%）。
class ThumbnailMemoryCache {
  ThumbnailMemoryCache._();

  /// 容量（条）。缩略图 200px 见方 ≈ 200*200*4 bytes ≈ 160KB，
  /// 400 条 ≈ 64MB 上限，主流中端机可接受。
  static const int _kCapacity = 400;

  static final Map<String, Uint8List> _map = <String, Uint8List>{};

  static Uint8List? get(String key) {
    final Uint8List? value = _map.remove(key);
    if (value != null) _map[key] = value; // 触碰：移到最新端
    return value;
  }

  static void put(String key, Uint8List bytes) {
    _map.remove(key);
    _map[key] = bytes;
    while (_map.length > _kCapacity) {
      _map.remove(_map.keys.first); // 淘汰最旧
    }
  }
}

/// 缩略图占位控件（引用失效 / 加载失败时展示）。
class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '图片加载失败',
      child: Container(
        color: scheme.surfaceContainerHighest,
        child: Center(
          child: Icon(Icons.broken_image, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// 缩略图成功态（memory 字节 / 本地文件两分支共用样式）。
class _ThumbnailImage extends StatelessWidget {
  final Uint8List? bytes;
  final File? file;
  final double size;

  const _ThumbnailImage({this.bytes, this.file, required this.size});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '照片缩略图',
      image: true,
      child: bytes != null
          ? Image.memory(bytes!, fit: BoxFit.cover)
          : Image.file(file!, fit: BoxFit.cover,
              // 解码降采样：解码宽度不超过展示尺寸，避免整图进内存。
              cacheWidth: (size * 2).toInt()),
    );
  }
}

/// 基于 [pm.AssetEntity] 的缩略图组件（用于导入页相册浏览）。
///
/// 设计：[initState] 仅发起一次缩略图加载，结果经 [ThumbnailMemoryCache]
/// 共享（命中直接渲染，不再请求 photo_manager）；加载中显示浅灰底色块。
class Thumbnail extends StatefulWidget {
  final pm.AssetEntity entity;
  final double size;

  const Thumbnail({super.key, required this.entity, this.size = 200});

  @override
  State<Thumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<Thumbnail> {
  Uint8List? _bytes;
  bool _failed = false;

  String get _cacheKey => 'a:${widget.entity.id}:${widget.size.toInt()}';

  @override
  void initState() {
    super.initState();
    final Uint8List? cached = ThumbnailMemoryCache.get(_cacheKey);
    if (cached != null) {
      _bytes = cached; // 缓存命中：同步渲染，零请求
      return;
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final Uint8List? bytes = await widget.entity.thumbnailDataWithSize(
        pm.ThumbnailSize(widget.size.toInt(), widget.size.toInt()),
        quality: 80,
      );
      if (!mounted) return;
      setState(() {
        if (bytes == null) {
          _failed = true;
        } else {
          _bytes = bytes;
          ThumbnailMemoryCache.put(_cacheKey, bytes);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    if (_failed) {
      return Semantics(
        label: '图片加载失败',
        child: Container(
          color: scheme.surfaceContainerHighest,
          child: Center(
            child: Icon(Icons.broken_image, color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }
    if (_bytes == null) {
      // 加载中：浅灰底色块，避免转圈。
      return Container(color: scheme.surfaceContainer);
    }
    return _ThumbnailImage(bytes: _bytes, size: widget.size);
  }
}

/// 基于领域模型 [Photo] 的缩略图组件（用于照片网格 / 搜索结果）。
///
/// 设计决策 D2 / B4：uri 类型引用存储的是 [pm.AssetEntity.id]，
/// 通过 [pm.AssetEntity.fromId] 解析实体再取缩略图（结果进
/// [ThumbnailMemoryCache] 跨页共享）；
/// path 类型直接以 [Image.file] 展示并降采样解码（T4.1 补齐，
/// 原先该类型恒为占位图）；解析失败展示占位图，不影响角标逻辑。
class PhotoThumbnail extends StatefulWidget {
  final Photo photo;
  final double size;

  const PhotoThumbnail({super.key, required this.photo, this.size = 200});

  @override
  State<PhotoThumbnail> createState() => _PhotoThumbnailState();
}

class _PhotoThumbnailState extends State<PhotoThumbnail> {
  Uint8List? _bytes;
  File? _file;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final MediaRef ref = widget.photo.mediaRef;
      if (ref.isUri) {
        final String cacheKey = 'u:${ref.value}:${widget.size.toInt()}';
        final Uint8List? cached = ThumbnailMemoryCache.get(cacheKey);
        if (cached != null) {
          if (mounted) setState(() => _bytes = cached);
          return;
        }
        final pm.AssetEntity? entity = await pm.AssetEntity.fromId(ref.value);
        if (entity == null) {
          if (mounted) setState(() => _failed = true);
          return;
        }
        final Uint8List? bytes = await entity.thumbnailDataWithSize(
          pm.ThumbnailSize(widget.size.toInt(), widget.size.toInt()),
          quality: 80,
        );
        if (mounted) {
          setState(() => _bytes = bytes);
          if (bytes != null) ThumbnailMemoryCache.put(cacheKey, bytes);
        }
        return;
      }
      // path 类型（B5 补齐 / T4.1 降采样）：直接展示本地文件。
      final File? f = await widget.photo.resolveFile();
      if (mounted) {
        if (f == null || !await f.exists()) {
          setState(() => _failed = true);
        } else {
          setState(() => _file = f);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const _Placeholder();
    }
    if (_bytes == null && _file == null) {
      final ColorScheme scheme = Theme.of(context).colorScheme;
      return Container(color: scheme.surfaceContainer);
    }
    return _ThumbnailImage(bytes: _bytes, file: _file, size: widget.size);
  }
}
