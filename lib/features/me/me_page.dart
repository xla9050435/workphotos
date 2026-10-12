import 'package:flutter/material.dart';

import 'package:work_photos/features/me/backup_page.dart';
import 'package:work_photos/features/me/heart_survey_page.dart';
import 'package:work_photos/features/me/settings_page.dart';

/// "我的"页（底部导航第四项 /me）。
///
/// 当前承载：账户/应用概览占位 + "设置"入口。
class MePage extends StatelessWidget {
  const MePage({super.key});

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
                SizedBox(height: 12),
                Text('work_photos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
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
