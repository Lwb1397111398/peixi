import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peixi/core/asr/asr_model_controller.dart';
import 'package:peixi/core/settings/app_prefs.dart';
import 'package:peixi/core/theme/tokens.dart';
import 'package:peixi/core/theme/theme_controller.dart';
import 'package:peixi/features/settings/llm_channels_section.dart';
import 'package:peixi/features/settings/update_section.dart';
import 'package:peixi/ui/widgets/loading_view.dart';
import 'package:peixi/ui/widgets/page_header.dart';
import 'package:peixi/ui/widgets/section_card.dart';
import 'package:peixi/providers.dart';

/// 设置页（设计稿 8.6 的 M1 子集）：外观（主题模式）、模型渠道/功能槽位/
/// 并发频控、用量与预算、ASR 本地模型、播放偏好，按 SectionCard 分组；
/// 播放偏好开关即时落库。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _budget = TextEditingController();
  int _totalTokens = 0;
  int _monthTokens = 0;
  bool _loaded = false;
  PlayPrefs _playPrefs = const PlayPrefs();
  final _listScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _totalTokens =
        (await ref
                .read(databaseProvider)
                .customSelect(
                  'SELECT COALESCE(SUM(prompt_tokens+completion_tokens),0) AS t FROM llm_logs',
                )
                .getSingle())
            .read<int>('t');
    _monthTokens = await ref.read(llmServiceProvider).monthUsedTokens();
    final budget = await ref.read(settingsRepoProvider).loadLlmBudgetTokens();
    if (budget > 0) _budget.text = '$budget';
    _playPrefs = await ref.read(settingsRepoProvider).loadPlayPrefs();
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _savePlayPrefs(PlayPrefs p) async {
    setState(() => _playPrefs = p);
    await ref.read(settingsRepoProvider).savePlayPrefs(p);
  }

  /// ASR 本地模型状态行 + 应用内下载入口（手机端跑不了下载脚本）
  Widget _buildLocalModelStatus(BuildContext context) {
    final st = ref.watch(asrModelStateProvider);
    final sem = context.semanticColors;
    final textTheme = Theme.of(context).textTheme;

    final (IconData icon, Color color, String label) = switch (st.phase) {
      AsrModelPhase.ready => (
          Icons.check_circle_outline,
          sem.success,
          '本地模型已就绪'
        ),
      AsrModelPhase.downloading => (
          Icons.downloading,
          sem.info,
          '正在下载本地模型…'
        ),
      AsrModelPhase.failed => (
          Icons.error_outline,
          sem.error,
          '本地模型下载失败'
        ),
      AsrModelPhase.missing => (
          Icons.error_outline,
          sem.warning,
          '本地模型未下载'
        ),
      AsrModelPhase.resolving => (
          Icons.help_outline,
          sem.info,
          '正在检查本地模型…'
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: Space.s),
          // Expanded：窄屏上标签可收缩省略，右侧按钮不被挤出屏幕
          Expanded(
            child: Text(label,
                style: textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          if (st.phase == AsrModelPhase.downloading)
            TextButton.icon(
              onPressed: () =>
                  ref.read(asrModelStateProvider.notifier).cancel(),
              icon: const Icon(Icons.close, size: 15),
              label: const Text('取消'),
            )
          else ...[
            if (st.phase == AsrModelPhase.missing ||
                st.phase == AsrModelPhase.failed)
              FilledButton.tonalIcon(
                onPressed: () => unawaited(
                    ref.read(asrModelStateProvider.notifier).download()),
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('下载模型'),
              ),
            const SizedBox(width: Space.s),
            TextButton.icon(
              onPressed: () => ref.invalidate(asrModelStateProvider),
              icon: const Icon(Icons.refresh, size: 15),
              label: const Text('刷新状态'),
            ),
          ],
        ]),
        if (st.modelDir.isNotEmpty)
          Text('模型目录：${st.modelDir}', style: textTheme.bodySmall),
        if (st.phase == AsrModelPhase.downloading) ...[
          const SizedBox(height: Space.s),
          LinearProgressIndicator(
              value: st.ratio,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2)),
          const SizedBox(height: Space.xs),
          Text(_downloadDetail(st), style: textTheme.bodySmall),
        ],
        if (st.phase == AsrModelPhase.failed && st.error != null) ...[
          const SizedBox(height: Space.xs),
          Text('失败原因：${st.error}',
              style: textTheme.bodySmall!.copyWith(color: sem.error)),
        ],
        if (st.phase == AsrModelPhase.missing ||
            st.phase == AsrModelPhase.failed) ...[
          const SizedBox(height: Space.xs),
          Text(
            '点击"下载模型"即可在应用内完成（约 200–300 MB，国内优先走 hf-mirror 镜像，'
            '建议 Wi-Fi 下进行）；桌面端也可手动运行 tool/download-sherpa-model.sh。'
            '本地模式无说话人分离，角色映射将全部归为一个说话人。',
            style: textTheme.bodySmall!.copyWith(color: sem.warning),
          ),
        ],
      ],
    );
  }

  String _downloadDetail(AsrModelState st) {
    String mb(int b) => (b / 1048576).toStringAsFixed(1);
    final totalPart = st.total > 0 ? ' / ${mb(st.total)} MB' : '';
    final pct =
        st.ratio != null ? '（${(st.ratio! * 100).toStringAsFixed(0)}%）' : '';
    return '已下载 ${mb(st.received)} MB$totalPart$pct';
  }

  Widget _prefSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    required ValueChanged<double> onChanged,
  }) =>
      Row(children: [
        SizedBox(width: 150, child: Text(label)),
        Expanded(
          child: Slider(
            min: min,
            max: max,
            divisions: divisions,
            label: display,
            value: value.clamp(min, max),
            onChanged: onChanged,
          ),
        ),
      ]);

  @override
  void dispose() {
    _listScroll.dispose();
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(title: '设置', subtitle: '服务连接与学习偏好，全部即时生效'),
          Expanded(
            child: !_loaded
                ? const LoadingView()
                : Scrollbar(
                    controller: _listScroll,
                    child: ListView(
                      controller: _listScroll,
                      padding: const EdgeInsets.fromLTRB(
                          Space.xl, 0, Space.xl, Space.xxl),
                    children: [
                      SectionCard(
                        leading: Icons.brightness_6_outlined,
                        title: '外观',
                        subtitle: '浅色为默认书房；深色适合夜间观影与阅读',
                        child: SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(
                                value: ThemeMode.system,
                                label: Text('跟随系统'),
                                icon: Icon(Icons.settings_suggest_outlined,
                                    size: 16)),
                            ButtonSegment(
                                value: ThemeMode.light,
                                label: Text('浅色'),
                                icon: Icon(Icons.light_mode_outlined,
                                    size: 16)),
                            ButtonSegment(
                                value: ThemeMode.dark,
                                label: Text('深色'),
                                icon: Icon(Icons.dark_mode_outlined,
                                    size: 16)),
                          ],
                          selected: {themeMode},
                          onSelectionChanged: (s) => ref
                              .read(themeModeProvider.notifier)
                              .set(s.first),
                        ),
                      ),
                      const SizedBox(height: Space.l),
                      const LlmChannelsSection(),
                      const SizedBox(height: Space.l),
                      SectionCard(
                        leading: Icons.savings_outlined,
                        title: '用量与预算',
                        subtitle: '统计与月度预算对全部渠道生效',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _budget,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: '月度 token 预算',
                                hintText: '留空表示不限；达到上限后管线暂停并提示',
                              ),
                            ),
                            const SizedBox(height: Space.l),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _clearLlmStats,
                                icon: const Icon(
                                    Icons.delete_sweep_outlined,
                                    size: 16),
                                label: const Text('清空统计与缓存'),
                              ),
                            ),
                            const SizedBox(height: Space.m),
                            Text(
                                '累计 LLM 消耗：$_totalTokens tokens'
                                '（本月 $_monthTokens）',
                                style:
                                    Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                      const SizedBox(height: Space.l),
                      SectionCard(
                        leading: Icons.graphic_eq_outlined,
                        title: '语音识别（本地离线）',
                        subtitle: 'sherpa-onnx 离线转写，无需联网与 API KEY',
                        child: _buildLocalModelStatus(context),
                      ),
                      const SizedBox(height: Space.l),
                      SectionCard(
                        leading: Icons.play_circle_outline,
                        title: '播放偏好',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('弹幕提问打断（L4）'),
                              subtitle:
                                  const Text('播放到关键场景自动暂停提问'),
                              value: _playPrefs.quizEnabled,
                              onChanged: (v) => _savePlayPrefs(
                                  _playPrefs.copyWith(quizEnabled: v)),
                            ),
                            _prefSlider(
                              label: '每集最多提问',
                              value: _playPrefs.maxPerEpisode.toDouble(),
                              min: 1,
                              max: 10,
                              divisions: 9,
                              display: '${_playPrefs.maxPerEpisode} 次',
                              onChanged: (v) => _savePlayPrefs(_playPrefs
                                  .copyWith(maxPerEpisode: v.round())),
                            ),
                            _prefSlider(
                              label: '两次提问最小间隔',
                              value:
                                  _playPrefs.minGapMinutes.toDouble(),
                              min: 1,
                              max: 15,
                              divisions: 14,
                              display:
                                  '${_playPrefs.minGapMinutes} 分钟',
                              onChanged: (v) => _savePlayPrefs(_playPrefs
                                  .copyWith(minGapMinutes: v.round())),
                            ),
                            _prefSlider(
                              label: '触发位置（场景进度比例）',
                              value: _playPrefs.triggerRatio,
                              min: 0.1,
                              max: 0.6,
                              divisions: 10,
                              display:
                                  '${(_playPrefs.triggerRatio * 100).round()}%',
                              onChanged: (v) => _savePlayPrefs(
                                  _playPrefs.copyWith(triggerRatio: v)),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('保留临时音频'),
                              subtitle:
                                  const Text('关闭可节省磁盘（重跑需重新抽取）'),
                              value: _playPrefs.keepTempAudio,
                              onChanged: (v) => _savePlayPrefs(
                                  _playPrefs.copyWith(keepTempAudio: v)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Space.l),
                      const UpdateSection(),
                      const SizedBox(height: Space.xl),
                      Center(
                        child: FilledButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.save_outlined, size: 17),
                          label: const Text('保存全部'),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }

  /// 清空 llm_logs + llm_cache（token 统计归零；缓存删除后重复请求会重新计费）。
  Future<void> _clearLlmStats() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空调用统计与响应缓存？'),
        content: const Text('token 用量统计将归零；已缓存的 LLM 响应删除后，'
            '相同请求会重新调用并计费。管线数据不受影响。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('清空')),
        ],
      ),
    );
    if (confirmed != true) return;
    final db = ref.read(databaseProvider);
    await db.delete(db.llmLogs).go();
    await db.delete(db.llmCache).go();
    if (!mounted) return;
    setState(() {
      _totalTokens = 0;
      _monthTokens = 0;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已清空')));
  }

  Future<void> _save() async {
    await ref
        .read(settingsRepoProvider)
        .saveLlmBudgetTokens(int.tryParse(_budget.text.trim()) ?? 0);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存')));
    }
  }
}
