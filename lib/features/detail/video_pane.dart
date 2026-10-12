import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import 'package:work_photos/core/utils/duration_format.dart';
import 'package:work_photos/core/utils/video_mime.dart';
import 'package:work_photos/data/models/photo.dart';

/// 视频播放面板（详情页图片区的视频替代）。
///
/// - 经 [Photo.resolveFile] 解析引用得到本地文件，用
///   [VideoPlayerController.file] 播放（ExoPlayer 内核，覆盖
///   mp4 / webm / mkv / ts / 3gp 等常见容器）；
/// - 控制层：中央播放/暂停大按钮 + 底部进度条（可拖拽 seek）+ 时间文本；
/// - 初始化失败（ExoPlayer 不支持的容器，如 avi / flv / rmvb，或文件
///   缺失）时展示「用其他应用打开」——经 [Share.shareXFiles] 带正确
///   MIME 分享到系统播放器（MX Player / VLC / 系统播放器）兜底。
class VideoPane extends StatefulWidget {
  final Photo photo;

  const VideoPane({super.key, required this.photo});

  @override
  State<VideoPane> createState() => _VideoPaneState();
}

class _VideoPaneState extends State<VideoPane> {
  VideoPlayerController? _controller;
  File? _file;
  bool _initializing = true;
  bool _failed = false;

  /// 进度条正在拖拽时的临时值（null = 未拖拽，跟随播放进度）。
  ///
  /// video_player 播放期间每 ~100ms 推送一次 position，若 Slider 只发
  /// seekTo 而不锁值，seek 生效前 listener 会用旧 position 重建，滑块
  /// 在手指下回跳。拖拽期间以 [_dragValue] 为准，松手再 seek 并解锁。
  double? _dragValue;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final File? file = await widget.photo.resolveFile();
    if (!mounted) return;
    if (file == null) {
      setState(() {
        _initializing = false;
        _failed = true;
      });
      return;
    }
    _file = file;
    final VideoPlayerController controller =
        VideoPlayerController.file(file);
    try {
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      controller.addListener(_onUpdate);
      setState(() {
        _controller = controller;
        _initializing = false;
      });
      controller.setLooping(false);
      controller.play();
    } catch (_) {
      controller.dispose();
      if (mounted) {
        setState(() {
          _initializing = false;
          _failed = true;
        });
      }
    }
  }

  /// 控制器变化（播放/暂停/进度）→ 重建控制层。
  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    final VideoPlayerController? c = _controller;
    if (c != null) {
      c.removeListener(_onUpdate);
      c.dispose();
    }
    super.dispose();
  }

  void _togglePlay() {
    final VideoPlayerController? c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      // 播完再点 = 重播。
      if (c.value.position >= c.value.duration) {
        c.seekTo(Duration.zero);
      }
      c.play();
    }
  }

  Future<void> _seek(double ms) async {
    final VideoPlayerController? c = _controller;
    if (c == null || !c.value.isInitialized) return;
    await c.seekTo(Duration(milliseconds: ms.round()));
  }

  /// 兜底：交给系统播放器（share 面板选应用）。
  Future<void> _openExternally() async {
    final File? f = _file;
    if (f == null) return;
    await Share.shareXFiles(
      <XFile>[XFile(f.path, mimeType: videoMimeFromPath(f.path))],
      text: '选择一个应用播放视频',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failed || _controller == null) {
      return _FallbackPane(onOpenExternally: _openExternally);
    }
    final VideoPlayerController c = _controller!;
    if (!c.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    final double aspect =
        c.value.aspectRatio > 0 ? c.value.aspectRatio : 16 / 9;
    final int totalMs = c.value.duration.inMilliseconds;
    final int posMs = c.value.position.inMilliseconds.clamp(0, totalMs);
    final bool playing = c.value.isPlaying;

    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        // 画面：按视频宽高比布局，黑底（详情页背景即黑）。
        Center(
          child: AspectRatio(
            aspectRatio: aspect,
            child: VideoPlayer(c),
          ),
        ),
        // 中央播放/暂停（大触控目标；播放中淡出避让画面）。
        // IgnorePointer：AnimatedOpacity 只改 alpha，RenderProxyBox 的
        // hitTest 不看 paintsChild，透明节点照样命中 → 播放中点画面中央
        // 会误暂停，全屏态还会被 _SwipeLayer 判为轻点而退出全屏。
        Center(
          child: AnimatedOpacity(
            opacity: playing ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: playing,
              child: GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    posMs >= totalMs && totalMs > 0
                        ? Icons.replay
                        : Icons.play_arrow,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
        // 底部控制条：当前时间 / 进度 / 总时长。
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 44,
                  child: Text(
                    formatDuration(Duration(milliseconds: posMs)) ?? '0:00',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: SliderComponentShape.noOverlay,
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white38,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      min: 0,
                      max: totalMs > 0 ? totalMs.toDouble() : 1,
                      value: (_dragValue ?? posMs.toDouble())
                          .clamp(0.0, totalMs > 0 ? totalMs.toDouble() : 1.0),
                      onChangeStart: (_) => _dragValue = posMs.toDouble(),
                      onChanged: (double v) => setState(() => _dragValue = v),
                      // 松手后先锁住本次拖拽值再 seek：若此时解锁，
                      // seek 生效前撞上 video_player 的 position 推送会
                      // 用旧位置重建，出现 1 帧回跳；seek 完成后再解锁。
                      onChangeEnd: (double v) async {
                        setState(() => _dragValue = v);
                        await _seek(v);
                        if (mounted) setState(() => _dragValue = null);
                      },
                    ),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    formatDuration(Duration(milliseconds: totalMs)) ?? '0:00',
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 播放失败 / 文件缺失降级面板。
class _FallbackPane extends StatelessWidget {
  final Future<void> Function() onOpenExternally;

  const _FallbackPane({required this.onOpenExternally});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.videocam_off, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              '此视频无法在内置播放器中打开\n（格式不支持或源文件缺失）',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('用其他应用打开'),
              onPressed: onOpenExternally,
            ),
          ],
        ),
      ),
    );
  }
}
