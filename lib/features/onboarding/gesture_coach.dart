import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 手势引导（R13）：3 步 walkthrough，教会长按多选、拖动连选与捏合调列。
///
/// - 首次进入相册页自动弹出（[maybeShowOnce]，SharedPreferences 标记，
///   跳过也算已读）；
/// - 设置页「手势引导」入口可随时重看（[showGestureCoach]）。
class GestureCoach {
  GestureCoach._();

  static const String _seenKey = 'gesture_coach_seen';

  /// 首次使用检查：未看过引导则弹出（含「跳过」，任何关闭方式都写标记）。
  static Future<void> maybeShowOnce(BuildContext context) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_seenKey) ?? false) return;
    if (!context.mounted) return;
    await showGestureCoach(context);
  }

  /// 弹出 3 步手势引导；关闭后写入已读标记。
  static Future<void> showGestureCoach(BuildContext context) async {
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.5),
        builder: (BuildContext context) => const _GestureCoachDialog(),
      );
    } finally {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_seenKey, true);
    }
  }
}

class _GestureCoachDialog extends StatefulWidget {
  const _GestureCoachDialog();

  @override
  State<_GestureCoachDialog> createState() => _GestureCoachDialogState();
}

class _GestureCoachDialogState extends State<_GestureCoachDialog> {
  final PageController _pageController = PageController();
  int _page = 0;

  static const List<({IconData icon, String title, String message})> _steps =
      <({IconData icon, String title, String message})>[
    (
      icon: Icons.touch_app_outlined,
      title: '长按照片，进入多选',
      message: '在相册网格中长按任意一张照片即可进入多选模式，'
          '右上角圆形按钮也可以逐张勾选。',
    ),
    (
      icon: Icons.swipe,
      title: '按住拖动，连选照片',
      message: '多选状态下按住不松手：横向滑动连选整行照片；'
          '对准一列纵向滑动可连选整列；拖到屏幕上/下边缘会自动滚动继续选。',
    ),
    (
      icon: Icons.pinch,
      title: '双指捏合，调整列数',
      message: '双指捏合可放大缩小网格列数（2-6 列），松手后自动记住，'
          '下次打开保持你的排版。设置页随时可以重置。',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isLast => _page == _steps.length - 1;

  void _next() {
    if (_isLast) {
      Navigator.of(context).pop();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Dialog(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: 320,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _steps.length,
                onPageChanged: (int i) => setState(() => _page = i),
                itemBuilder: (BuildContext context, int index) {
                  final (:IconData icon, :String title, :String message) =
                      _steps[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(icon, size: 72, color: scheme.primary),
                        const SizedBox(height: 24),
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          message,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.5,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // 进度点：当前步高亮（primary），其余 onSurfaceVariant 淡显。
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (int i = 0; i < _steps.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: i == _page ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? scheme.primary
                          : scheme.onSurfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('跳过'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    child: Text(_isLast ? '开始使用' : '下一步'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
