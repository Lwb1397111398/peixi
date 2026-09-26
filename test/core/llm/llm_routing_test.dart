import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/llm/llm_routing.dart';

void main() {
  test('显式绑定命中：返回绑定渠道与模型', () {
    final t = RoutingTable(
      channels: [
        ChannelRoute(id: 1, name: 'A', baseUrl: 'https://a/v1', apiKey: 'k1', enabled: true),
        ChannelRoute(id: 2, name: 'B', baseUrl: 'https://b/v1', apiKey: 'k2', enabled: true),
      ],
      slots: {LlmSlot.analysis: SlotBinding(channelId: 2, model: 'deepseek-v3')},
    );
    final r = t.resolve(LlmSlot.analysis)!;
    expect(r.channel.id, 2);
    expect(r.model, 'deepseek-v3');
  });

  test('未绑定槽位回落首个可用渠道 + 默认模型；embedding 不回落返回 null', () {
    final t = RoutingTable(
      channels: [
        ChannelRoute(id: 1, name: 'A', baseUrl: 'https://a/v1', apiKey: 'k1', enabled: false),
        ChannelRoute(id: 2, name: 'B', baseUrl: 'https://b/v1', apiKey: '', enabled: true),
        ChannelRoute(id: 3, name: 'C', baseUrl: 'https://c/v1', apiKey: 'k3', enabled: true),
      ],
      slots: {},
    );
    expect(t.resolve(LlmSlot.summary)!.channel.id, 3);
    expect(t.resolve(LlmSlot.summary)!.model, 'qwen-flash');
    expect(t.resolve(LlmSlot.analysis)!.model, 'qwen-plus');
    expect(t.resolve(LlmSlot.embedding), isNull);
  });

  test('绑定指向不存在/禁用渠道时按未绑定处理', () {
    final t = RoutingTable(
      channels: [ChannelRoute(id: 9, name: 'X', baseUrl: 'https://x/v1', apiKey: 'k', enabled: false)],
      slots: {LlmSlot.analysis: SlotBinding(channelId: 9, model: 'm')},
    );
    expect(t.resolve(LlmSlot.analysis), isNull);
  });
}
