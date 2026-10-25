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

  test('未绑定槽位返回 null，无默认渠道/默认模型回落', () {
    final t = RoutingTable(
      channels: [
        ChannelRoute(id: 1, name: 'A', baseUrl: 'https://a/v1', apiKey: 'k1', enabled: false),
        ChannelRoute(id: 2, name: 'B', baseUrl: 'https://b/v1', apiKey: '', enabled: true),
        ChannelRoute(id: 3, name: 'C', baseUrl: 'https://c/v1', apiKey: 'k3', enabled: true),
      ],
      slots: {},
    );
    expect(t.resolve(LlmSlot.summary), isNull);
    expect(t.resolve(LlmSlot.analysis), isNull);
    expect(t.resolve(LlmSlot.vision), isNull);
    expect(t.resolve(LlmSlot.embedding), isNull);
  });

  test('绑定指向不存在/禁用渠道时按未绑定处理', () {
    final t = RoutingTable(
      channels: [ChannelRoute(id: 9, name: 'X', baseUrl: 'https://x/v1', apiKey: 'k', enabled: false)],
      slots: {LlmSlot.analysis: SlotBinding(channelId: 9, model: 'm')},
    );
    expect(t.resolve(LlmSlot.analysis), isNull);
  });

  test('同一条渠道可同时绑定多个角色，各自模型互不影响', () {
    final t = RoutingTable(
      channels: [
        ChannelRoute(id: 1, name: 'A', baseUrl: 'https://a/v1', apiKey: 'k1', enabled: true),
      ],
      slots: {
        LlmSlot.summary: SlotBinding(channelId: 1, model: 'lite-x'),
        LlmSlot.analysis: SlotBinding(channelId: 1, model: 'pro-y'),
        LlmSlot.vision: SlotBinding(channelId: 1, model: 'vl-z'),
      },
    );
    expect(t.resolve(LlmSlot.summary)!.model, 'lite-x');
    expect(t.resolve(LlmSlot.analysis)!.model, 'pro-y');
    expect(t.resolve(LlmSlot.vision)!.model, 'vl-z');
  });
}
