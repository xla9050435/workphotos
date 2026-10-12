import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 本地用户度量日志（T4.5 / R17，HEART 模型，**仅线下**）。
///
/// 设计决策（对齐 PRD §6）：不做线上埋点；事件以 JSONL 追加写入应用
/// 文档目录 `metrics/usage_log.jsonl`（每行一个 JSON 对象），卸载即清。
///
/// 覆盖的 HEART 指标（≥3 个）：
/// - **Happiness（满意度）**：SUS 问卷得分（见 heart_survey_page，
///   事件 `sus_survey_submitted`，params: score）；
/// - **Engagement（参与度）**：周活跃事件量（`app_open` / `search_performed`
///   等事件计数，聚合自本日志）；
/// - **Task success（任务成功）**：搜索转化（`search_performed` 中带
///   `resultCount > 0` 的占比，即「搜到东西并可继续查看」的成功率）。
///
/// 验收口径：每阶段结束后人工导出本文件做可用性结论（SUS ≥ 68 达标）。
class UsageLog {
  UsageLog._();

  static final UsageLog instance = UsageLog._();

  /// 事件类型白名单外的也允许记录（开放事件名），但保留此常量供检索。
  static const String _dirName = 'metrics';
  static const String _fileName = 'usage_log.jsonl';

  Directory? _cacheDir;

  /// 记录一个事件（fire-and-forget：失败静默，绝不影响业务流程）。
  ///
  /// [event]：短横线小写事件名，如 `app_open` / `search_performed`；
  /// [params]：附加参数（可序列化标量）。
  Future<void> log(String event, {Map<String, Object?>? params}) async {
    try {
      final Directory dir = await _ensureDir();
      final File file = File(p.join(dir.path, _fileName));
      final Map<String, Object?> line = <String, Object?>{
        'ts': DateTime.now().toIso8601String(),
        'event': event,
        if (params != null) 'params': params,
      };
      await file.writeAsString('${jsonEncode(line)}\n',
          mode: FileMode.append);
    } catch (_) {
      // 度量绝不干扰业务：吞掉一切异常。
    }
  }

  /// 读取全部事件（阶段末人工分析用；文件大时注意内存）。
  Future<List<Map<String, Object?>>> readAll() async {
    try {
      final Directory dir = await _ensureDir();
      final File file = File(p.join(dir.path, _fileName));
      if (!await file.exists()) return const <Map<String, Object?>>[];
      final List<String> lines = await file.readAsLines();
      return <Map<String, Object?>>[
        for (final String line in lines)
          if (line.trim().isNotEmpty)
            jsonDecode(line) as Map<String, Object?>,
      ];
    } catch (_) {
      return const <Map<String, Object?>>[];
    }
  }

  /// 统计近 [days] 天内某事件的发生次数（Engagement 指标）。
  Future<int> countEvents(String event, {int days = 7}) async {
    final List<Map<String, Object?>> all = await readAll();
    final DateTime since =
        DateTime.now().subtract(Duration(days: days));
    int count = 0;
    for (final Map<String, Object?> e in all) {
      if (e['event'] != event) continue;
      final DateTime? ts = DateTime.tryParse(e['ts'] as String? ?? '');
      if (ts != null && ts.isAfter(since)) count++;
    }
    return count;
  }

  Future<Directory> _ensureDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory dir = Directory(p.join(docs.path, _dirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return _cacheDir = dir;
  }
}
