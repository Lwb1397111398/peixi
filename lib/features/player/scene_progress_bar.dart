import 'package:flutter/material.dart';
import 'package:peixi/core/theme/tokens.dart';

/// 场景刻度进度条（设计稿 8.2）：细刻度=场景边界，暖色点=含 L4 提问场景，
/// 点击/拖动跳转。位于视频区正下方（恒定深色面，白系轨道保证对比度）。
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
    final cs = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
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
            // 轨道（未播放段：暗面上的低透明白）
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                  height: 3,
                  color: Colors.white.withValues(alpha: 0.16)),
            ),
            // 已播放段
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                height: 3,
                margin: EdgeInsets.only(right: w * (1 - posFrac)),
                color: cs.primary,
              ),
            ),
            // 场景边界细刻度
            for (final b in boundariesMs)
              Positioned(
                left: _frac(b) * w - 0.5,
                top: 6,
                child: Container(
                    width: 1,
                    height: 10,
                    color: Colors.white.withValues(alpha: 0.32)),
              ),
            // L4 提问标记点
            for (final q in quizMarkerMs)
              Positioned(
                left: (_frac(q) * w - 4).clamp(0.0, w - 8),
                top: 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: semantic.warning, shape: BoxShape.circle),
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
                  color: cs.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xCCFFFFFF), width: 1.5),
                ),
              ),
            ),
          ]),
        ),
      );
    });
  }
}
