import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/features/pipeline/scene_segmenter.dart';

typedef Seg = ({int startMs, int endMs});
Seg s(int start, int end) => (startMs: start, endMs: end);

void main() {
  test('常规：>3s 间隔切开', () {
    final r = segmentScenes([
      s(0, 10000), s(12000, 20000), // 场景1（20s）
      s(60000, 80000), // 间隔 40s → 场景2（20s）
    ]);
    expect(r.length, 2);
    expect(r[0].startMs, 0);
    expect(r[0].endMs, 20000);
    expect(r[1].startMs, 60000);
  });

  test('大间隔（>3s）自然切开两个场景', () {
    final segs = <Seg>[
      s(0, 60000),
      s(130000, 190000), // 与前句间隔 70s（最大间隔）
    ];
    final r = segmentScenes(segs);
    expect(r.length, 2, reason: '总长 190s > 120s，应在 70s 间隔处切');
    expect(r[0].endMs, 60000);
    expect(r[1].startMs, 130000);
  });

  test('超 120s 且无间隔：硬切', () {
    final segs = <Seg>[
      for (var i = 0; i < 30; i++) s(i * 10000, i * 10000 + 9000), // 300s 连续
    ];
    final r = segmentScenes(segs);
    expect(r.length, greaterThanOrEqualTo(3));
    for (final sc in r) {
      expect(sc.endMs - sc.startMs, lessThanOrEqualTo(135000),
          reason: '硬切后每景不应远超 120s');
    }
  });

  test('不足 15s 并入前景', () {
    final r = segmentScenes([
      s(0, 20000), // 20s 正常
      s(30000, 35000), // 5s 短景（间隔 10s 触发切分后过短）
      s(60000, 100000), // 40s 正常
    ]);
    expect(r.length, 2);
    expect(r[0].endMs, 35000, reason: '短景并入前景');
    expect(r[1].startMs, 60000);
  });

  test('首个短景并入后景', () {
    final r = segmentScenes([
      s(0, 10000), // 10s 短景且是第一景
      s(30000, 80000),
    ]);
    expect(r.length, 1, reason: '无前景可并，并入后景');
    expect(r[0].startMs, 0);
    expect(r[0].endMs, 80000);
  });

  test('单场景与空输入', () {
    expect(segmentScenes([]), isEmpty);
    final r = segmentScenes([s(1000, 9000)]);
    expect(r.length, 1);
    expect(r[0].firstSegIdx, 0);
    expect(r[0].lastSegIdx, 0);
  });
}
