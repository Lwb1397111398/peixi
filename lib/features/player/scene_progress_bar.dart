import 'package:flutter/material.dart';

/// 场景刻度进度条（设计稿 8.2）：细刻度=场景边界，橙点=含 L4 提问场景，
/// 点击/拖动跳转。位于播放器自带控制条下方。
class SceneProgressBar extends StatelessWidget {
  const SceneProgressBar({
    super.key,
    required this.positionMs,
    required this.durationMs,
    required this.boundariesMs,
    required this.quizMarkerMs,
    required this.onSeek,
  });

  final int positionMs;
  final int durationMs;
  final List<int> boundariesMs;
  final List<int> quizMarkerMs;
  final void Function(int ms) onSeek;

  double _frac(int ms) =>
      durationMs <= 0 ? 0 : (ms / durationMs).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final posFrac = _frac(positionMs);
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => onSeek((d.localPosition.dx / w * durationMs)
            .clamp(0, durationMs > 0 ? durationMs - 1 : 0)
            .toInt()),
        onHorizontalDragUpdate: (d) => onSeek(
            (d.localPosition.dx / w * durationMs).clamp(0, durationMs).toInt()),
        child: SizedBox(
          height: 22,
          child: Stack(children: [
            // 轨道
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                height: 3,
                margin: EdgeInsets.only(right: w * (1 - posFrac)),
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(height: 3, color: Colors.white24),
            ),
            // 场景边界细刻度
            for (final b in boundariesMs)
              Positioned(
                left: _frac(b) * w - 0.5,
                top: 6,
                child: Container(width: 1, height: 10, color: Colors.white38),
              ),
            // L4 橙点
            for (final q in quizMarkerMs)
              Positioned(
                left: (_frac(q) * w - 4).clamp(0.0, w - 8),
                top: 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Colors.orange, shape: BoxShape.circle),
                ),
              ),
            // 播放头
            Positioned(
              left: (posFrac * w - 5).clamp(0.0, w - 10),
              top: 2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle),
              ),
            ),
          ]),
        ),
      );
    });
  }
}
