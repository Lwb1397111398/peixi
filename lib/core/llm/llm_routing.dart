/// 功能槽位：管线各环节使用哪条渠道的哪个模型。
/// summary=轻量模型（地图/摘要/知识卡）analysis=主力模型（批注/解说）
/// vision=视觉模型 embedding=向量模型（仅语义回忆模块）
enum LlmSlot { summary, analysis, vision, embedding }

/// 单条自定义渠道的路由信息（api_key 由调用方从 secure storage 读出注入）。
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
///
/// 没有内置默认渠道与默认模型：每个槽位必须显式绑定到某条自定义渠道的
/// 某个模型（轻量/主力/视觉/向量各配各的），未绑定则 resolve 返回 null，
/// 调用方报「未配置」错误，绝不静默把请求打到任意渠道上。
class RoutingTable {
  const RoutingTable({required this.channels, required this.slots});
  final List<ChannelRoute> channels;
  final Map<LlmSlot, SlotBinding> slots;

  ChannelRoute? _byId(int id) {
    for (final c in channels) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// 解析槽位 → (渠道, 模型)。仅当存在显式绑定且绑定渠道可用时命中；
  /// 否则返回 null（embedding 之外不再回落默认模型）。
  ({ChannelRoute channel, String model})? resolve(LlmSlot slot) {
    final bind = slots[slot];
    if (bind == null) return null;
    final c = _byId(bind.channelId);
    if (c == null || !c.usable) return null;
    return (channel: c, model: bind.model);
  }
}
