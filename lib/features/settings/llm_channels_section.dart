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
  final Set<int> _testingChannels = {}; // 正在拉模型的渠道 id（在途去重）
  int _concurrency = 2;
  int _minIntervalMs = 0;
  bool _loaded = false;

  static const _slotLabels = {
    LlmSlot.summary: '轻量模型（地图/摘要/知识卡）',
    LlmSlot.analysis: '主力模型（批注/解说）',
    LlmSlot.vision: '视觉模型（关键帧理解）',
    LlmSlot.embedding: '向量模型（前文回忆，可选）',
  };

  @override
  void initState() {
    super.initState();
    _reload();
  }

  /// 统一从路由表提取渠道/槽位到 state（_reload 与 _persistAndRefresh 共用）。
  /// conc/minMs 仅 _reload 需要（_persistAndRefresh 不动并发/频控设置）。
  void _applyState(RoutingTable routing, {int? conc, int? minMs}) {
    _channels = routing.channels;
    for (final s in LlmSlot.values) {
      final b = routing.slots[s];
      _slots[s] = b == null ? null : (channelId: b.channelId, model: b.model);
    }
    if (conc != null) _concurrency = conc;
    if (minMs != null) _minIntervalMs = minMs;
  }

  Future<void> _reload() async {
    final repo = ref.read(settingsRepoProvider);
    final routing = await repo.loadRouting();
    final (conc, minMs) = await repo.loadLlmLimits();
    if (!mounted) return;
    setState(() {
      _applyState(routing, conc: conc, minMs: minMs);
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
    if (!mounted) return;
    await _persistAndRefresh();
    unawaited(_pullModels(id, saved.baseUrl, saved.apiKey));
  }

  /// 落库后统一走这里：一次 loadRouting，注入 LlmService（运行中的管线立即
  /// 生效）并刷新渠道/槽位 state——避免多重读（迁移检查 + N 次安全读）。
  Future<void> _persistAndRefresh() async {
    final routing = await ref.read(settingsRepoProvider).loadRouting();
    if (!mounted) return;
    ref.read(llmServiceProvider).updateRouting(routing);
    setState(() => _applyState(routing));
  }

  Future<void> _saveLimits() async {
    await ref.read(settingsRepoProvider).saveLlmLimits(
        concurrency: _concurrency, minIntervalMs: _minIntervalMs);
    if (!mounted) return;
    ref.read(llmServiceProvider).gate.updateLimits(
        maxConcurrent: _concurrency,
        minInterval: Duration(milliseconds: _minIntervalMs));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('并发与频控已保存')));
  }

  Future<void> _pullModels(int channelId, String baseUrl, String apiKey) async {
    // 在途去重：同渠道重复点击不发起第二次请求
    if (_testingChannels.contains(channelId)) return;
    if (!mounted) return;
    setState(() => _testingChannels.add(channelId));
    try {
      final models = await ref.read(llmServiceProvider).fetchModels(
          ChannelRoute(
              id: channelId,
              name: '',
              baseUrl: baseUrl,
              apiKey: apiKey,
              enabled: true));
      if (!mounted) return;
      setState(() => _testingChannels.remove(channelId));
      // 渠道在途被删除：丢弃结果，不写回也不弹提示
      if (!_channels.any((c) => c.id == channelId)) return;
      setState(() => _models[channelId] = models);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接成功，拉取到 ${models.length} 个模型')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _testingChannels.remove(channelId));
      if (!_channels.any((c) => c.id == channelId)) return;
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
                child: Text(
                    '尚未添加渠道。填写任意 OpenAI 兼容接口（中转站/官方 API 均可）的'
                    ' BASE_URL 与 KEY，即可拉取模型列表。可添加多条渠道，'
                    '下方按角色分别绑定。',
                    style: tt.bodySmall)),
          for (final c in _channels)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c.name),
              subtitle: Text(c.baseUrl,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                TextButton(
                    onPressed: _testingChannels.contains(c.id)
                        ? null
                        : () => _pullModels(c.id, c.baseUrl, c.apiKey),
                    child: Text(_testingChannels.contains(c.id)
                        ? '测试中…'
                        : '测试/拉模型')),
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
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '每个角色单独绑定一条渠道里的一个模型，同一渠道可绑多个角色。'
                '轻量模型未绑定时相关调用自动落到主力模型；'
                '其余角色未绑定则对应功能不运行（没有隐藏的默认模型）。',
                style: tt.bodySmall),
            ),
          ),
          for (final s in LlmSlot.values)
            _SlotRow(
              slotName: s.name,
              label: _slotLabels[s]!,
              channels: _channels,
              binding: _slots[s],
              models: _models,
              onChanged: (channelId, model) async {
                if (model.isEmpty) {
                  // 只切了渠道、还没选模型：不落库，等用户从拉取列表里选模型后一起保存
                  return;
                }
                await ref
                    .read(settingsRepoProvider)
                    .saveSlot(s, channelId: channelId, model: model);
                if (!mounted) return;
                await _persistAndRefresh();
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
    if (!mounted) return;
    await _persistAndRefresh();
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
  String? _nameError;
  String? _baseUrlError;
  String? _apiKeyError;

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final baseUrl = _baseUrl.text.trim();
    final apiKey = _apiKey.text.trim();
    final nameErr = name.isEmpty ? '请填写名称' : null;
    final urlErr = baseUrl.isEmpty
        ? '请填写 BASE_URL'
        : !(baseUrl.startsWith('http://') || baseUrl.startsWith('https://'))
            ? '需以 http:// 或 https:// 开头'
            : null;
    final keyErr = apiKey.isEmpty ? '请填写 API KEY' : null;
    setState(() {
      _nameError = nameErr;
      _baseUrlError = urlErr;
      _apiKeyError = keyErr;
    });
    if (nameErr != null || urlErr != null || keyErr != null) return;
    Navigator.pop(context, (name: name, baseUrl: baseUrl, apiKey: apiKey));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '添加渠道' : '编辑渠道'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
            key: const Key('field-name'),
            controller: _name,
            decoration:
                InputDecoration(labelText: '名称', errorText: _nameError)),
        const SizedBox(height: Space.s),
        TextField(
            key: const Key('field-baseurl'),
            controller: _baseUrl,
            decoration: InputDecoration(
                labelText: 'BASE_URL（OpenAI 兼容，含 /v1）',
                errorText: _baseUrlError)),
        const SizedBox(height: Space.s),
        TextField(
            key: const Key('field-apikey'),
            controller: _apiKey,
            obscureText: true,
            decoration:
                InputDecoration(labelText: 'API KEY', errorText: _apiKeyError)),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }
}

/// 单行槽位：渠道下拉 + 模型弹层两步选择。渠道选择是瞬态 state（不落库），
/// 选模型时才以「当前选中渠道 + 模型」成对保存——修复无绑定时无法创建绑定、
/// 以及切渠道后仍按旧绑定渠道保存两个缺陷。
class _SlotRow extends StatefulWidget {
  const _SlotRow({
    required this.slotName,
    required this.label,
    required this.channels,
    required this.binding,
    required this.models,
    required this.onChanged,
  });
  final String slotName; // 供测试定位
  final String label;
  final List<ChannelRoute> channels;
  final ({int channelId, String model})? binding;
  final Map<int, List<String>> models; // 渠道 id → 已拉取模型列表
  final void Function(int channelId, String model) onChanged;

  @override
  State<_SlotRow> createState() => _SlotRowState();
}

class _SlotRowState extends State<_SlotRow> {
  /// 用户在下拉里临时选中的渠道 id（选模型前不落库）。
  int? _selectedChannelId;

  @override
  void initState() {
    super.initState();
    _alignWithBinding();
  }

  @override
  void didUpdateWidget(_SlotRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final b = widget.binding;
    final ob = oldWidget.binding;
    final bindingChanged =
        ob?.channelId != b?.channelId || ob?.model != b?.model;
    // 选中渠道已被删除（如在途删除渠道）也需回退
    final selectionStale = _selectedChannelId != null &&
        !widget.channels.any((c) => c.id == _selectedChannelId);
    if (!bindingChanged && !selectionStale) return;
    _alignWithBinding();
  }

  /// 向绑定对齐：绑定渠道存在于渠道列表时以其为选中项，否则清空。
  /// 绑定未变且选中项仍有效时保留瞬态选择（用户可能正切渠道选模型到一半）。
  void _alignWithBinding() {
    final b = widget.binding;
    _selectedChannelId =
        (b != null && widget.channels.any((c) => c.id == b.channelId))
            ? b.channelId
            : null;
  }

  List<String>? get _selectedModels =>
      _selectedChannelId == null ? null : widget.models[_selectedChannelId];

  @override
  Widget build(BuildContext context) {
    final binding = widget.binding;
    final channels = widget.channels;
    // 绑定指向的渠道可能已被删除：此时不能把悬空 id 传给 DropdownButton
    // 的 value（断言崩溃），回退为 null 显示占位提示。
    final validValue =
        channels.any((c) => c.id == _selectedChannelId) ? _selectedChannelId : null;
    // 展示已绑模型的前提是绑定仍指向当前选中渠道，否则提示重新选择
    final showBoundModel =
        binding != null && binding.channelId == _selectedChannelId;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(children: [
        SizedBox(
            width: 190,
            child: Text(widget.label, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: Space.s),
        Expanded(
          child: DropdownButton<int>(
            key: Key('slot-channel-${widget.slotName}'),
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
                    setState(() => _selectedChannelId = cid);
                    // 空模型名：父级不落库，等选模型后成对保存
                    widget.onChanged(cid, '');
                  },
          ),
        ),
        const SizedBox(width: Space.s),
        Expanded(
          child: PopupMenuButton<String>(
            key: Key('slot-model-${widget.slotName}'),
            initialValue: showBoundModel ? binding.model : null,
            // 未选中渠道时禁用（embedding 槽位必须显式绑定，无回落）
            enabled: _selectedChannelId != null,
            itemBuilder: (ctx) => [
              if (_selectedModels == null || _selectedModels!.isEmpty)
                const PopupMenuItem(
                    enabled: false, child: Text('先在该渠道「测试/拉模型」')),
              for (final m in _selectedModels ?? const <String>[])
                PopupMenuItem(
                    value: m,
                    child:
                        Text(m, overflow: TextOverflow.ellipsis)),
            ],
            onSelected: (m) {
              final cid = _selectedChannelId;
              if (cid == null) return;
              // 以瞬态选中的渠道为准，而非旧绑定的渠道 id
              widget.onChanged(cid, m);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Space.s, vertical: Space.xs),
              decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(showBoundModel ? binding.model : '模型',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      ]),
    );
  }
}
