import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:work_photos/data/metrics/usage_log.dart';

/// SUS 标准量表 10 题（System Usability Scale，Brooke 1996）。
///
/// 奇数题为正面陈述、偶数题为反面陈述；计分：奇数题 = 得分-1，
/// 偶数题 = 5-得分，总和 ×2.5 → 0~100 分。业界基线 **SUS ≥ 68 合格**
/// （R17 验收口径）。
const List<String> kSusQuestions = <String>[
  '我愿意经常使用这个应用。',
  '这个应用有些地方过于复杂。',
  '这个应用很容易上手。',
  '我需要技术人员的支持才能使用。',
  '这个应用的各项功能整合得很好。',
  '这个应用有不一致的地方（同类操作方式不统一）。',
  '大多数人能很快学会使用这个应用。',
  '这个应用用起来很别扭。',
  '我对这个应用有信心。',
  '开始使用之前，我需要学很多东西。',
];

/// 「体验反馈」（T4.5 / R17）：SUS 问卷 + 历史得分展示。
///
/// 结果仅存本地（SharedPreferences `last_sus_*`），并写入
/// [UsageLog]（事件 `sus_survey_submitted`，params: score），供阶段末
/// 汇总 Happiness（满意度）指标。问卷 5 分制：1=非常不同意 … 5=非常同意。
class HeartSurveyPage extends ConsumerStatefulWidget {
  const HeartSurveyPage({super.key});

  @override
  ConsumerState<HeartSurveyPage> createState() => _HeartSurveyPageState();
}

class _HeartSurveyPageState extends ConsumerState<HeartSurveyPage> {
  /// 每题得分（下标与 [kSusQuestions] 对应），null=未作答。
  final List<int?> _answers = List<int?>.filled(kSusQuestions.length, null);

  int? _lastScore;
  String? _lastSubmittedAt;

  @override
  void initState() {
    super.initState();
    _loadLast();
  }

  Future<void> _loadLast() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? score = prefs.getInt('last_sus_score');
    final String? at = prefs.getString('last_sus_at');
    if (!mounted) return;
    setState(() {
      _lastScore = score;
      _lastSubmittedAt = at;
    });
  }

  bool get _allAnswered => _answers.every((int? v) => v != null);

  /// SUS 标准计分。
  int computeSusScore(List<int?> answers) {
    int sum = 0;
    for (int i = 0; i < answers.length; i++) {
      final int v = (answers[i] ?? 1).clamp(1, 5);
      sum += i.isEven ? (v - 1) : (5 - v);
    }
    return sum * 5 / 2 ~/ 1; // 等价 sum*2.5 取整
  }

  Future<void> _submit() async {
    if (!_allAnswered) return;
    final int score = computeSusScore(_answers);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String at = DateTime.now().toIso8601String();
    await prefs.setInt('last_sus_score', score);
    await prefs.setString('last_sus_at', at);
    await UsageLog.instance.log('sus_survey_submitted',
        params: <String, Object?>{'score': score});
    if (!mounted) return;
    setState(() {
      _lastScore = score;
      _lastSubmittedAt = at;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('感谢反馈！你的 SUS 得分：$score / 100'
          '${score >= 68 ? '（达到业界合格线 68）' : '（暂未达 68，我们会继续改进）'}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('体验反馈')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '这份问卷约需 1 分钟（SUS 标准可用性量表）。'
              '结果只保存在你的手机上，用于改进体验。'
              '1 = 非常不同意，5 = 非常同意。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (_lastScore != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              '上次提交：$_lastScore / 100'
              '${_lastSubmittedAt == null ? '' : ' · $_lastSubmittedAt'}',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          for (int i = 0; i < kSusQuestions.length; i++)
            _QuestionCard(
              index: i,
              question: kSusQuestions[i],
              answer: _answers[i],
              onChanged: (int? v) => setState(() => _answers[i] = v),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _allAnswered ? _submit : null,
            child: Text(_allAnswered ? '提交' : '请完成全部 ${kSusQuestions.length} 题'),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final int index;
  final String question;
  final int? answer;
  final ValueChanged<int?> onChanged;

  const _QuestionCard({
    required this.index,
    required this.question,
    required this.answer,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('${index + 1}. $question'),
            RadioGroup<int>(
              groupValue: answer,
              onChanged: onChanged,
              child: Row(
                children: <Widget>[
                  for (int v = 1; v <= 5; v++)
                    Expanded(
                      child: RadioListTile<int>(
                        value: v,
                        title: Text('$v', textAlign: TextAlign.center),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
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
