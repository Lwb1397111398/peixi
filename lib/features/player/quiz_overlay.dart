import 'package:flutter/material.dart';

/// L4 弹幕提问全屏模组（设计稿 8.2）：
/// 阶段1 问题+输入框〔跳过本题〕〔提交回答〕→
/// 阶段2 perspectives 参考视角 + 〔继续播放〕。
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
    return Container(
      color: Colors.black87,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.quiz_outlined, color: cs.primary, size: 20),
                    const SizedBox(width: 8),
                    Text('思考时刻',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 16),
                  Text(widget.question,
                      style: const TextStyle(
                          fontSize: 17, height: 1.6,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 20),
                  if (!_answered && !_skipped) ...[
                    TextField(
                      controller: _controller,
                      maxLines: 4,
                      minLines: 2,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: '写下你的想法（代入角色，越具体越好）',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 16),
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
                        icon: const Icon(Icons.send, size: 16),
                        label: const Text('提交回答'),
                      ),
                    ]),
                  ] else ...[
                    Text(_skipped ? '已跳过。参考视角：' : '你的回答已记录。参考视角：',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 10),
                    for (final p in widget.perspectives)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ',
                                  style: TextStyle(fontSize: 14)),
                              Expanded(
                                  child: Text(p,
                                      style: const TextStyle(
                                          fontSize: 14, height: 1.6))),
                            ]),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: widget.onResume,
                        icon: const Icon(Icons.play_arrow),
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
