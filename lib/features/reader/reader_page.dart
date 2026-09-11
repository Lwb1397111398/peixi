import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/settings/api_config.dart';
import 'package:peixi/core/theme/tokens.dart';
import 'package:peixi/features/reader/reader.dart';
import 'package:peixi/ui/widgets/app_badge.dart';
import 'package:peixi/ui/widgets/empty_state.dart';
import 'package:peixi/ui/widgets/loading_view.dart';
import 'package:peixi/ui/widgets/sheet_scaffold.dart';
import 'package:peixi/providers.dart';

/// 小说阅读器（设计稿 8.4）：
/// 正文纵向滚动（字号/行距/背景可调含夜间）；段落尾部 L1-L4 彩色气泡角标，
/// 点击弹底部卡片；L4 为段间展开卡片（作答/跳过写 qa_records）；
/// 顶部章节抽屉；右上本书人物列表（点击看人设）。
/// 书页三主题（paper/sepia/night）是用户可配置项，色值为既有持久化数据，
/// 不随全局主题变化；页头与抽屉随书页色调适配（"暗壳亮页"反之亦然）。
class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({super.key, required this.projectId});
  final int projectId;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late ReaderRepository _repo;

  ReaderPrefs _prefs = const ReaderPrefs();
  List<Chapter> _chapters = [];
  List<Character> _cast = [];
  int _chapterIdx = 0;
  List<Paragraph> _paragraphs = [];
  Map<int, List<Annotation>> _anns = {};
  bool _loading = true;

  // 阅读进度记忆：恢复目标偏移（一次性）+ 抽屉"上次读到"标记
  final _scroll = ScrollController();
  double? _pendingScrollOffset;
  int _lastReadingChapterIdx = -1;

  // L4 段间卡片状态（paraId 键）
  final _l4Controllers = <int, TextEditingController>{};
  final _l4Answered = <int, String?>{}; // null=未作答，''=跳过

  // 书页三主题（既有持久化语义，色值与旧版一致）
  static const _bgColors = {
    ReaderTheme.paper: Color(0xFFFAFAF5),
    ReaderTheme.sepia: Color(0xFFF5EDDC),
    ReaderTheme.night: Color(0xFF141414),
  };
  static const _textColors = {
    ReaderTheme.paper: Color(0xFF262626),
    ReaderTheme.sepia: Color(0xFF4A3F33),
    ReaderTheme.night: Color(0xFFC9C9C9),
  };

  @override
  void initState() {
    super.initState();
    _repo = ReaderRepository(ref.read(databaseProvider));
    _init();
  }

  Future<void> _init() async {
    _prefs = await ref.read(settingsRepoProvider).loadReaderPrefs();
    _chapters = await _repo.chapters(widget.projectId);
    _cast = await _repo.cast(widget.projectId);
    final saved = await _repo.readingProgress(widget.projectId);
    if (saved != null &&
        saved.chapterIdx >= 0 &&
        saved.chapterIdx < _chapters.length) {
      _lastReadingChapterIdx = saved.chapterIdx;
      _pendingScrollOffset = saved.scrollOffset;
    }
    if (!mounted) return;
    setState(() {});
    if (_chapters.isNotEmpty) {
      await _openChapter(
          _lastReadingChapterIdx >= 0 ? _lastReadingChapterIdx : 0,
          restoreOffset: _pendingScrollOffset);
    }
  }

  Future<void> _openChapter(int idx, {double? restoreOffset}) async {
    setState(() => _loading = true);
    _chapterIdx = idx;
    _paragraphs = await _repo.paragraphs(_chapters[idx].id);
    _anns =
        await _repo.annotationsByParaId([for (final p in _paragraphs) p.id]);
    if (!mounted) return;
    setState(() => _loading = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (restoreOffset != null) {
        _scroll.jumpTo(
            restoreOffset.clamp(0.0, _scroll.position.maxScrollExtent));
      } else if (_scroll.offset > 0) {
        _scroll.jumpTo(0);
      }
      _persistProgress();
    });
  }

  void _persistProgress() {
    if (!_scroll.hasClients) return;
    unawaited(_repo.saveReadingProgress(widget.projectId,
        chapterIdx: _chapterIdx, scrollOffset: _scroll.offset));
  }

  Future<void> _updatePrefs(ReaderPrefs p) async {
    setState(() => _prefs = p);
    await ref.read(settingsRepoProvider).saveReaderPrefs(p);
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final c in _l4Controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = _bgColors[_prefs.theme]!;
    final fg = _textColors[_prefs.theme]!;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: fg,
        titleTextStyle: Theme.of(context)
            .textTheme
            .titleLarge!
            .copyWith(color: fg),
        iconTheme: IconThemeData(color: fg.withValues(alpha: 0.75)),
        actionsIconTheme: IconThemeData(color: fg.withValues(alpha: 0.75)),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          _chapters.isEmpty
              ? '阅读器'
              : (_chapters[_chapterIdx].title ?? '第${_chapterIdx + 1}部分'),
        ),
        leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer()),
        actions: [
          IconButton(
              icon: const Icon(Icons.groups),
              tooltip: '本书人物',
              onPressed: _showCastSheet),
          IconButton(
              icon: const Icon(Icons.text_fields),
              tooltip: '阅读设置',
              onPressed: _showPrefsSheet),
        ],
      ),
      drawer: _buildChapterDrawer(fg, bg),
      body: _loading
          ? const LoadingView()
          : _chapters.isEmpty
              ? EmptyState(
                  icon: Icons.menu_book_outlined,
                  title: '本书没有章节',
                  message: '重新导入这本小说可能可以修复；已有批注与卡片不受影响。',
                )
              : NotificationListener<ScrollEndNotification>(
                  onNotification: (_) {
                    _persistProgress();
                    return false;
                  },
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(
                        Space.xl, Space.m, Space.xl, Space.xxl + Space.xl),
                    itemCount: _paragraphs.length,
                    itemBuilder: (_, i) => _paragraphItem(_paragraphs[i], fg),
                  ),
                ),
    );
  }

  Widget _buildChapterDrawer(Color fg, Color bg) {
    return Drawer(
      backgroundColor: bg,
      child: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(
              horizontal: Space.s, vertical: Space.m),
          itemCount: _chapters.length,
          itemBuilder: (_, i) {
            final ch = _chapters[i];
            final selected = i == _chapterIdx;
            final isLastRead = i == _lastReadingChapterIdx;
            return ListTile(
              selected: selected,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
              title: Text(
                ch.title ?? '第${i + 1}部分',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: selected ? null : fg),
              ),
              trailing: isLastRead && !selected
                  ? Text('上次读到',
                      style: TextStyle(
                          fontSize: 11,
                          color: fg.withValues(alpha: 0.55)))
                  : null,
              onTap: () {
                Navigator.pop(context); // 关抽屉
                _openChapter(i);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _paragraphItem(Paragraph para, Color fg) {
    final anns = _anns[para.id] ?? const <Annotation>[];
    final bubbles = [
      for (final a in anns)
        if (a.type != 'L4') _bubble(a),
    ];
    final l4 = anns.where((a) => a.type == 'L4').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          para.content,
          style: TextStyle(
              fontSize: _prefs.fontSize,
              height: _prefs.lineHeight,
              color: fg),
        ),
        if (bubbles.isNotEmpty) ...[
          const SizedBox(height: Space.xs),
          Wrap(spacing: Space.s, runSpacing: Space.xs, children: bubbles),
        ],
        for (final a in l4) ...[
          const SizedBox(height: Space.m),
          _l4Card(a, fg),
        ],
        const SizedBox(height: Space.l),
      ],
    );
  }

  // L1-L4 层级色：柔和版（书页亮暗两态都可读），与全局语义色分离
  Color _annColor(String type) => switch (type) {
        'L1' => const Color(0xFF5A8FC2), // 蓝 潜台词
        'L2' => const Color(0xFF9B7DC0), // 紫 心理
        'L3' => const Color(0xFF6FA470), // 绿 知识
        'L4' => const Color(0xFFC98A4B), // 琥珀 思考题
        _ => const Color(0xFF8B9083),
      };

  String _annLabel(String type) => switch (type) {
        'L1' => 'L1 潜台词',
        'L2' => 'L2 心理',
        'L3' => 'L3 知识',
        'L4' => 'L4 思考题',
        _ => type,
      };

  Widget _bubble(Annotation a) {
    return GestureDetector(
      key: ValueKey('bubble-${a.id}'),
      onTap: () => _showAnnotationSheet(a),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: 2),
        decoration: BoxDecoration(
            color: _annColor(a.type),
            borderRadius: BorderRadius.circular(999)),
        child: Text(a.type,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _showAnnotationSheet(Annotation a) {
    final color = _annColor(a.type);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => SheetScaffold(
        title: _annLabel(a.type),
        actions: [
          Icon(Icons.label_important, size: 18, color: color),
          const SizedBox(width: Space.xs),
          TextButton(
              onPressed: () => Navigator.pop(sheetCtx),
              child: const Text('关闭')),
        ],
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              Space.xl, Space.m, Space.xl, Space.xl),
          child: _annotationBody(a),
        ),
      ),
    );
  }

  Widget _annotationBody(Annotation a) {
    final tt = Theme.of(context).textTheme;
    switch (a.type) {
      case 'L1':
      case 'L2':
        final text = decodeL1L2(a.contentJson) ?? '（批注内容为空）';
        return Text(text, style: tt.bodyLarge!.copyWith(height: 1.7));
      case 'L3':
        final c = decodeL3(a.contentJson);
        if (c == null) return const Text('（批注内容为空）');
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.term, style: tt.titleLarge),
          const SizedBox(height: Space.xs),
          Text(c.text, style: tt.bodyLarge!.copyWith(height: 1.7)),
          if (c.uncertain) ...[
            const SizedBox(height: Space.m),
            const AppBadge('不确定，仅供参考', tone: BadgeTone.warning),
          ],
        ]);
      default:
        return const Text('（批注内容为空）');
    }
  }

  Widget _l4Card(Annotation a, Color fg) {
    final c = decodeL4(a.contentJson);
    if (c == null) return const SizedBox.shrink();
    final answered = _l4Answered.containsKey(a.id);
    final controller = _l4Controllers.putIfAbsent(a.id, TextEditingController.new);
    final l4Color = _annColor('L4');
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(Space.l),
      decoration: BoxDecoration(
        color: l4Color.withValues(alpha: 0.10),
        borderRadius: AppRadius.rMd,
        border: Border.all(color: l4Color.withValues(alpha: 0.38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.psychology_outlined, size: 16, color: l4Color),
            const SizedBox(width: Space.xs),
            Text('L4 思考题',
                style: tt.labelLarge!.copyWith(color: l4Color)),
          ]),
          const SizedBox(height: Space.s),
          Text(c.question,
              style: TextStyle(
                  fontSize: _prefs.fontSize,
                  fontWeight: FontWeight.w600,
                  height: _prefs.lineHeight * 0.9,
                  color: fg)),
          const SizedBox(height: Space.m),
          if (!answered) ...[
            TextField(
              controller: controller,
              minLines: 2,
              maxLines: 4,
              decoration:
                  const InputDecoration(hintText: '写下你的想法…（可留空跳过）'),
            ),
            const SizedBox(height: Space.s),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                  onPressed: () => _submitAnswer(a, c.perspectives, null),
                  child: const Text('跳过本题')),
              const SizedBox(width: Space.s),
              FilledButton(
                  onPressed: () => _submitAnswer(
                      a, c.perspectives, controller.text.trim()),
                  child: const Text('提交回答')),
            ]),
          ] else ...[
            if (_l4Answered[a.id] == '')
              Text('已跳过',
                  style: tt.bodySmall!
                      .copyWith(color: fg.withValues(alpha: 0.6)))
            else
              Text('我的回答：${_l4Answered[a.id]}',
                  style: tt.bodyMedium!.copyWith(color: fg)),
            const SizedBox(height: Space.m),
            Text('参考视角',
                style: tt.labelLarge!.copyWith(color: l4Color)),
            const SizedBox(height: Space.xs),
            for (final p in c.perspectives)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('• $p',
                    style: TextStyle(
                        fontSize: _prefs.fontSize - 1,
                        height: 1.6,
                        color: fg)),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _submitAnswer(
      Annotation a, List<String> perspectives, String? answer) async {
    final skipped = answer == null || answer.isEmpty;
    await _repo.recordAnswer(
        projectId: widget.projectId,
        question: decodeL4(a.contentJson)?.question ?? '',
        perspectives: perspectives,
        answer: answer,
        skipped: skipped);
    if (!mounted) return;
    setState(() => _l4Answered[a.id] = skipped ? '' : answer);
  }

  void _showPrefsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(builder: (ctx, setSheet) {
        return SheetScaffold(
          title: '阅读设置',
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('完成')),
          ],
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                Space.xl, Space.m, Space.xl, Space.xl),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sliderRow('字号', _prefs.fontSize, 14, 24, 10,
                  _prefs.fontSize.round().toString(), (v) {
                setSheet(() {});
                _updatePrefs(ReaderPrefs(
                    fontSize: v,
                    lineHeight: _prefs.lineHeight,
                    theme: _prefs.theme));
              }),
              _sliderRow('行距', _prefs.lineHeight, 1.2, 2.2, 10,
                  _prefs.lineHeight.toStringAsFixed(1), (v) {
                setSheet(() {});
                _updatePrefs(ReaderPrefs(
                    fontSize: _prefs.fontSize,
                    lineHeight: v,
                    theme: _prefs.theme));
              }),
              const SizedBox(height: Space.s),
              SegmentedButton<ReaderTheme>(
                segments: const [
                  ButtonSegment(
                      value: ReaderTheme.paper, label: Text('纸白')),
                  ButtonSegment(
                      value: ReaderTheme.sepia, label: Text('米黄')),
                  ButtonSegment(
                      value: ReaderTheme.night, label: Text('夜间')),
                ],
                selected: {_prefs.theme},
                onSelectionChanged: (s) {
                  setSheet(() {});
                  _updatePrefs(ReaderPrefs(
                      fontSize: _prefs.fontSize,
                      lineHeight: _prefs.lineHeight,
                      theme: s.first));
                },
              ),
            ]),
          ),
        );
      }),
    );
  }

  Widget _sliderRow(String label, double value, double min, double max,
      int divisions, String labelValue, ValueChanged<double> onChanged) {
    final tt = Theme.of(context).textTheme;
    return Row(children: [
      SizedBox(
          width: 32,
          child: Text(label, style: tt.bodyMedium)),
      Expanded(
        child: Slider(
          min: min,
          max: max,
          divisions: divisions,
          label: labelValue,
          value: value,
          onChanged: onChanged,
        ),
      ),
    ]);
  }

  void _showCastSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => SheetScaffold(
        title: '本书人物',
        child: _cast.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(Space.xl),
                child: Text('暂无人物信息',
                    style: Theme.of(sheetCtx).textTheme.bodySmall))
            : ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                    Space.m, Space.s, Space.m, Space.xl),
                children: [
                  for (final c in _cast)
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
                      leading: CircleAvatar(
                        radius: 15,
                        backgroundColor: _characterColor(c.color),
                        foregroundColor: Colors.white,
                        child: Text(c.name.isEmpty ? '?' : c.name[0],
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                      title: Text(c.name),
                      subtitle: Text(
                        c.aliasesJson.isEmpty ||
                                c.aliasesJson == '[]'
                            ? '（暂无人设）'
                            : c.aliasesJson,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  /// 角色色为校准页写库的 hex（存量数据），缺省回主色
  Color _characterColor(String? hex) {
    final raw = (hex ?? '').replaceFirst('#', '');
    if (raw.length == 6 || raw.length == 8) {
      final v = int.tryParse(raw, radix: 16);
      if (v != null) return Color(raw.length == 6 ? 0xFF000000 | v : v);
    }
    return const Color(0xFF5E7F63);
  }
}
