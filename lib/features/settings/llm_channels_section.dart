import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peixi/core/llm/llm_routing.dart';
import 'package:peixi/core/theme/tokens.dart';
import 'package:peixi/providers.dart';
import 'package:peixi/ui/widgets/section_card.dart';

/// 渠道：OpenAI 兼容中转站（KEY+URL+拉模型）。槽位：功能 → 渠道+模型绑定。
/// 并发/频控：llm.concurrency / llm.min_request_interval_ms。
class LlmChannelsSection extends ConsumerStatefulWidget {
  const LlmChannelsSection({super.key});
  @override
  ConsumerState<LlmChannelsSection> createState() => _LlmChannelsSectionState();
}

class _LlmChannelsSectionState extends ConsumerState<LlmChannelsSection> {
  List<ChannelRoute> _channels = [];
  final Map<LlmSlot, ({int channelId, String model})?> _slots = {};
  final Map<int, List<String>> _models = {}; // 渠道 id → 已拉取模型列表
  int _concurrency = 2;
  int _minIntervalMs = 0;
  bool _loaded = false;

  static const _slotLabels = {
    LlmSlot.summary: '轻量整理（地图/摘要/知识卡）',
    LlmSlot.analysis: '深层分析（批注/解说）',
    LlmSlot.vision: '视觉理解（关键帧）',
    LlmSlot.embedding: '语义向量（可选，前文回忆）',
  };

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final repo = ref.read(settingsRepoProvider);
    final routing = await repo.loadRouting();
    final (conc, minMs) = await repo.loadLlmLimits();
    if (!mounted) return;
    setState(() {
      _channels = routing.channels;
      for (final s in LlmSlot.values) {
        _slots[s] = routing.slots[s] == null
            ? null
            : (
                channelId: routing.slots[s]!.channelId,
                model: routing.slots[s]!.model
              );
      }
      _concurrency = conc;
      _minIntervalMs = minMs;
      _loaded = true;
    });
  }

  Future<void> _openChannelDialog([ChannelRoute? existing]) async {
    // 控制器归对话框 State 所有：showDialog 的 Future 在 pop 时即完成，
    // 而退场动画期间 TextField 仍在树上——由调用方 dispose 会触发
    // "used after being disposed"。
    final saved = await showDialog<({String name, String baseUrl, String apiKey})>(
      context: context,
      builder: (ctx) => _ChannelDialog(existing: existing),
    );
    if (saved == null || !mounted) return;
    final repo = ref.read(settingsRepoProvider);
    final int id;
    if (existing == null) {
      id = await repo.addChannel(
          name: saved.name, baseUrl: saved.baseUrl, apiKey: saved.apiKey);
    } else {
      id = existing.id;
      await repo.updateChannel(existing.id,
          name: saved.name,
          baseUrl: saved.baseUrl,
          apiKey: saved.apiKey,
          enabled: existing.enabled);
    }
    await _applyRouting();
    await _reload(); // 刷新渠道列表 UI（_applyRouting 只注入服务，不落 state）
    unawaited(_pullModels(id, saved.baseUrl, saved.apiKey));
  }

  /// 保存后重读路由表并注入 LlmService——运行中的管线立即生效。
  Future<void> _applyRouting() async {
    final routing = await ref.read(settingsRepoProvider).loadRouting();
    ref.read(llmServiceProvider).updateRouting(routing);
  }

  Future<void> _saveLimits() async {
    await ref.read(settingsRepoProvider).saveLlmLimits(
        concurrency: _concurrency, minIntervalMs: _minIntervalMs);
    ref.read(llmServiceProvider).gate.updateLimits(
        maxConcurrent: _concurrency,
        minInterval: Duration(milliseconds: _minIntervalMs));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('并发与频控已保存')));
  }

  Future<void> _pullModels(int channelId, String baseUrl, String apiKey) async {
    try {
      final models = await ref.read(llmServiceProvider).fetchModels(
          ChannelRoute(
              id: channelId,
              name: '',
              baseUrl: baseUrl,
              apiKey: apiKey,
              enabled: true));
      if (!mounted) return;
      setState(() => _models[channelId] = models);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接成功，拉取到 ${models.length} 个模型')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('拉取失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    // stretch：设置页 ListView 与独立使用时卡片都撑满可用宽度
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
      SectionCard(
        title: '模型渠道',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_channels.isEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.m),
                child: Text('尚未添加渠道。填写中转站的 BASE_URL 与 KEY，即可拉取模型列表。',
                    style: tt.bodySmall)),
          for (final c in _channels)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c.name),
              subtitle: Text(c.baseUrl,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                TextButton(
                    onPressed: () => _pullModels(c.id, c.baseUrl, c.apiKey),
                    child: const Text('测试/拉模型')),
                IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => _openChannelDialog(c)),
                // 删除渠道：deleteChannel 级联清 KEY 与槽位绑定
                IconButton(
                    key: Key('del-channel-${c.id}'),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => _confirmDelete(c)),
              ]),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
                onPressed: () => _openChannelDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('添加渠道')),
          ),
        ]),
      ),
      const SizedBox(height: Space.l),
      SectionCard(
        title: '功能槽位',
        child: Column(children: [
          for (final s in LlmSlot.values)
            _SlotRow(
              label: _slotLabels[s]!,
              channels: _channels,
              binding: _slots[s],
              models: _slots[s] == null ? null : _models[_slots[s]!.channelId],
              onChanged: (channelId, model) async {
                if (model.isEmpty) {
                  // 只切了渠道、还没选模型：不落库，等用户从拉取列表里选模型后一起保存
                  return;
                }
                await ref
                    .read(settingsRepoProvider)
                    .saveSlot(s, channelId: channelId, model: model);
                await _applyRouting();
                await _reload();
              },
            ),
        ]),
      ),
      const SizedBox(height: Space.l),
      SectionCard(
        title: '并发与频控',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('并发数'),
            Expanded(
              child: Slider(
                value: _concurrency.toDouble(),
                min: 1,
                max: 8,
                divisions: 7,
                label: '$_concurrency',
                onChanged: (v) => setState(() => _concurrency = v.round()),
              ),
            ),
            Text('$_concurrency 路'),
          ]),
          Row(children: [
            const Text('请求最小间隔'),
            Expanded(
              child: Slider(
                value: _minIntervalMs.toDouble(),
                min: 0,
                max: 2000,
                divisions: 20,
                label: '${_minIntervalMs}ms',
                onChanged: (v) => setState(() => _minIntervalMs = v.round()),
              ),
            ),
            Text('${_minIntervalMs}ms'),
          ]),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
                onPressed: _saveLimits, child: const Text('保存')),
          ),
        ]),
      ),
    ]);
  }

  Future<void> _confirmDelete(ChannelRoute c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除渠道'),
        content: Text('删除渠道「${c.name}」？其槽位绑定将一并清除。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(settingsRepoProvider).deleteChannel(c.id);
    await _applyRouting();
    await _reload();
  }
}

class _ChannelDialog extends StatefulWidget {
  const _ChannelDialog({this.existing});
  final ChannelRoute? existing;
  @override
  State<_ChannelDialog> createState() => _ChannelDialogState();
}

class _ChannelDialogState extends State<_ChannelDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _baseUrl =
      TextEditingController(text: widget.existing?.baseUrl ?? '');
  late final _apiKey =
      TextEditingController(text: widget.existing?.apiKey ?? '');

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, (
        name: _name.text.trim(),
        baseUrl: _baseUrl.text.trim(),
        apiKey: _apiKey.text.trim(),
      ));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '添加渠道' : '编辑渠道'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
            key: const Key('field-name'),
            controller: _name,
            decoration: const InputDecoration(labelText: '名称')),
        const SizedBox(height: Space.s),
        TextField(
            key: const Key('field-baseurl'),
            controller: _baseUrl,
            decoration: const InputDecoration(
                labelText: 'BASE_URL（OpenAI 兼容，含 /v1）')),
        const SizedBox(height: Space.s),
        TextField(
            key: const Key('field-apikey'),
            controller: _apiKey,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'API KEY')),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.label,
    required this.channels,
    required this.binding,
    required this.models,
    required this.onChanged,
  });
  final String label;
  final List<ChannelRoute> channels;
  final ({int channelId, String model})? binding;
  final List<String>? models;
  final void Function(int channelId, String model) onChanged;

  @override
  Widget build(BuildContext context) {
    // 绑定指向的渠道可能已被删除：此时不能把悬空 id 传给 DropdownButton
    // 的 value（断言崩溃），回退为 null 显示占位提示。
    final validValue = channels.any((c) => c.id == binding?.channelId)
        ? binding?.channelId
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(children: [
        SizedBox(
            width: 190,
            child: Text(label, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: Space.s),
        Expanded(
          child: DropdownButton<int>(
            isExpanded: true,
            hint: const Text('渠道'),
            value: validValue,
            items: [
              for (final c in channels)
                DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
            onChanged: channels.isEmpty
                ? null
                : (cid) {
                    if (cid == null) return;
                    onChanged(cid, binding?.model ?? '');
                  },
          ),
        ),
        const SizedBox(width: Space.s),
        Expanded(
          child: PopupMenuButton<String>(
            initialValue: binding?.model,
            enabled: binding != null,
            itemBuilder: (ctx) => [
              if (models == null || models!.isEmpty)
                const PopupMenuItem(
                    enabled: false, child: Text('先在该渠道「测试/拉模型」')),
              for (final m in models ?? const <String>[])
                PopupMenuItem(
                    value: m,
                    child:
                        Text(m, overflow: TextOverflow.ellipsis)),
            ],
            onSelected: (m) => onChanged(binding!.channelId, m),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Space.s, vertical: Space.xs),
              decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(binding?.model ?? '模型',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      ]),
    );
  }
}
