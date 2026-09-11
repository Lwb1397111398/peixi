import 'package:flutter/material.dart';
import 'package:peixi/core/theme/tokens.dart';

/// L4 弹幕提问全屏模组（设计稿 8.2）：
/// 阶段1 问题+输入框〔跳过本题〕〔提交回答〕→
/// 阶段2 perspectives 参考视角 + 〔继续播放〕。
/// 遮罩面恒定深色（影院暗场），不随应用主题切换。
class QuizOverlay extends StatefulWidget {
  const QuizOverlay({
    super.key,
    required this.question,
    required this.perspectives,
    required this.onSubmit,
    required this.onSkip,
    required this.onResume,
  });
  final String question;
  final List<String> perspectives;
  final void Function(String answer) onSubmit;
  final VoidCallback onSkip;
  final VoidCallback onResume;

  @override
  State<QuizOverlay> createState() => _QuizOverlayState();
}

class _QuizOverlayState extends State<QuizOverlay> {
  final _controller = TextEditingController();
  bool _answered = false;
  bool _skipped = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {})); // 刷新提交按钮可用态
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
    setState(() => _answered = true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      color: const Color(0xE6141611),
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(Space.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(Space.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: AppRadius.rSm,
                      ),
                      child: Icon(Icons.quiz_outlined,
                          color: cs.onPrimaryContainer, size: 17),
                    ),
                    const SizedBox(width: Space.m),
                    Text('思考时刻', style: tt.titleLarge),
                  ]),
                  const SizedBox(height: Space.l),
                  Text(widget.question,
                      style: tt.titleLarge!.copyWith(height: 1.5)),
                  const SizedBox(height: Space.xl),
                  if (!_answered && !_skipped) ...[
                    TextField(
                      controller: _controller,
                      maxLines: 4,
                      minLines: 2,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: '写下你的想法（代入角色，越具体越好）',
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: Space.l),
                    Row(children: [
                      TextButton(
                        onPressed: () {
                          widget.onSkip();
                          setState(() => _skipped = true);
                        },
                        child: const Text('跳过本题'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _controller.text.trim().isEmpty
                            ? null
                            : _submit,
                        icon: const Icon(Icons.send, size: 15),
                        label: const Text('提交回答'),
                      ),
                    ]),
                  ] else ...[
                    Text(
                        _skipped ? '已跳过。参考视角：' : '你的回答已记录。参考视角：',
                        style: tt.labelLarge!
                            .copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: Space.m),
                    for (final p in widget.perspectives)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.m),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 9),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                    color: cs.primary,
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: Space.m),
                              Expanded(
                                  child: Text(p,
                                      style: tt.bodyLarge!
                                          .copyWith(height: 1.6))),
                            ]),
                      ),
                    const SizedBox(height: Space.s),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: widget.onResume,
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('继续播放'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
