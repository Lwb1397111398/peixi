/// 功能槽位：管线各环节使用哪条渠道的哪个模型。
/// summary=轻量整理（地图/摘要/知识卡）analysis=深层分析（批注/解说）
/// vision=视觉理解 embedding=语义向量（仅语义回忆模块）
enum LlmSlot { summary, analysis, vision, embedding }

/// 单条渠道的路由信息（api_key 由调用方从 secure storage 读出注入）。
class ChannelRoute {
  const ChannelRoute({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    required this.enabled,
  });
  final int id;
  final String name;
  final String baseUrl;
  final String apiKey;
  final bool enabled;

  bool get usable => enabled && baseUrl.isNotEmpty && apiKey.isNotEmpty;
}

/// 槽位 → (渠道 id, 模型名)。
class SlotBinding {
  const SlotBinding({required this.channelId, required this.model});
  final int channelId;
  final String model;
}

/// 渠道 + 槽位整体路由表；LlmService 解析请求的唯一依据。
class RoutingTable {
  const RoutingTable({required this.channels, required this.slots});
  final List<ChannelRoute> channels;
  final Map<LlmSlot, SlotBinding> slots;

  static const _fallbackModel = {
    LlmSlot.summary: 'qwen-flash',
    LlmSlot.analysis: 'qwen-plus',
    LlmSlot.vision: 'qwen-vl-plus',
  };

  /// 槽位未绑定时的默认模型名。
  static String fallbackModelFor(LlmSlot slot) => _fallbackModel[slot]!;

  ChannelRoute? _byId(int id) {
    for (final c in channels) {
      if (c.id == id) return c;
    }
    return null;
  }

  ChannelRoute? _firstUsable() {
    for (final c in channels) {
      if (c.usable) return c;
    }
    return null;
  }

  /// 解析槽位 → (渠道, 模型)。显式绑定优先；未绑定时 summary/analysis/vision
  /// 回落到首个可用渠道 + 默认模型；embedding 必须显式绑定（不回落）。
  ({ChannelRoute channel, String model})? resolve(LlmSlot slot) {
    final bind = slots[slot];
    if (bind != null) {
      final c = _byId(bind.channelId);
      if (c != null && c.usable) return (channel: c, model: bind.model);
    }
    if (slot == LlmSlot.embedding) return null;
    final c = _firstUsable();
    if (c == null) return null;
    return (channel: c, model: _fallbackModel[slot]!);
  }
}
