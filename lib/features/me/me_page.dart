import 'package:flutter/material.dart';

import 'package:work_photos/features/me/backup_page.dart';
import 'package:work_photos/features/me/heart_survey_page.dart';
import 'package:work_photos/features/me/settings_page.dart';
import 'package:work_photos/features/me/update_flow.dart';
import 'package:work_photos/services/app_native.dart';
import 'package:work_photos/services/update_checker.dart';

/// "我的"页（底部导航第四项 /me）。
///
/// 当前承载：账户/应用概览占位 + 备份/反馈/检查更新/设置入口。
class MePage extends StatefulWidget {
  const MePage({super.key});

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  /// 手动检查更新进行中：禁用重复点击 + 显示进度。
  bool _checkingUpdate = false;

  /// 手动「检查更新」：检查中显示 loading；已最新/失败用 SnackBar，有新版弹窗。
  Future<void> _onCheckUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    try {
      final UpdateInfo? info = await checkForUpdate();
      if (!mounted) return;
      if (info == null) {
        final ({String version, int build}) v = await AppNative.getVersion();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已是最新版本 v${v.version}')),
        );
      } else {
        await showUpdateDialog(context, info);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('检查失败，请检查网络')),
      );
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        children: <Widget>[
          // 顶部概览占位（后续可接入账户/统计）。
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            child: Column(
              children: <Widget>[
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Icon(Icons.person,
                      size: 40,
                      color: Theme.of(context).colorScheme.onPrimary),
                ),
                const SizedBox(height: 12),
                const Text('work_photos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '引用式照片管理',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const Divider(),
          // 备份与恢复（T4.3/R11）：元数据 JSON 本地导出 / 恢复。
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('备份与恢复'),
            subtitle: const Text('导出照片引用与分类结构（不拷贝原图）'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext ctx) => const BackupPage(),
                ),
              );
            },
          ),
          // 体验反馈（T4.5/R17）：SUS 问卷，结果仅存本地。
          ListTile(
            leading: const Icon(Icons.favorite_outline),
            title: const Text('体验反馈'),
            subtitle: const Text('1 分钟问卷，帮我们做得更好'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext ctx) => const HeartSurveyPage(),
                ),
              );
            },
          ),
          // 检查更新：手动触发一次检查（启动时另有自动检查）。
          ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: const Text('检查更新'),
            subtitle: _checkingUpdate ? const Text('正在检查…') : null,
            trailing: _checkingUpdate
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _checkingUpdate ? null : _onCheckUpdate,
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('设置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // 作为普通子页压入当前导航栈，返回即回到"我的"。
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext ctx) => const SettingsPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
