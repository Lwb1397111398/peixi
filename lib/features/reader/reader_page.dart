import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/settings/app_prefs.dart';
import 'package:peixi/core/theme/tokens.dart';
import 'package:peixi/features/reader/reader.dart';
import 'package:peixi/ui/widgets/app_badge.dart';
import 'package:peixi/ui/widgets/empty_state.dart';
import 'package:peixi/ui/widgets/loading_view.dart';
import 'package:peixi/ui/widgets/sheet_scaffold.dart';
import 'package:peixi/providers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// 小说阅读器（设计稿 8.4）：
/// 正文纵向滚动（字号/行距/边距/背景可调含夜间）；段落尾部 L1-L4 彩色气泡角标，
/// 点击弹底部卡片；L4 为段间展开卡片（作答/跳过写 qa_records）；
/// 顶部章节抽屉（按卷分组）；右上本书人物列表（点击看人设）。
/// 书页三主题（paper/sepia/night）是用户可配置项，色值为既有持久化数据，
/// 不随全局主题变化；页头与抽屉随书页色调适配（"暗壳亮页"反之亦然）。
/// v6 阅读体验升级：点正文中央沉浸（顶/底栏收起）；章尾「下一章」接续；
/// 底部本章/全书进度；屏幕常亮；目录当前章滚到可见 + 上次读到快跳。
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

  // v6 进度：本章/全书 0~1（ValueNotifier 局部刷新，滚动不重建整页）
  final _chapterPct = ValueNotifier<double>(0);
  final _bookPct = ValueNotifier<double>(0);
  int _totalParas = 0;

  // v6 沉浸模式：点正文中央切换顶/底栏收起（微信读书式）
  bool _immersive = false;

  // 目录抽屉：当前章 ListTile 的锚点（打开抽屉时滚到可见）
  final _drawerCurrentKey = GlobalKey();

  // L4 段间卡片状态（paraId 键）
  final _l4Controllers = <int, TextEditingController>{};
  final _l4Answered = <int, String?>{}; // null=未作答，''=跳过

  // 批注随到随显（设计文档 §9）：管线事件防抖重载当前章批注。
  // 防抖 800ms + maxWait 2s 兜底：事件间隔持续小于防抖窗口时刷新会被
  // 无限推迟（饥饿），从首个未处理事件起 2s 的硬期限定时器强制刷一次
  //（不随后续事件重置；每次刷新后重新起算）。
  static const _reloadDebounceDelay = Duration(milliseconds: 800);
  static const _reloadMaxWait = Duration(seconds: 2);
  Timer? _reloadDebounce;
  Timer? _reloadDeadline;

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
    // 阅读时屏幕常亮（微信读书同款体验；退出阅读页恢复系统设置）
    WakelockPlus.enable();
    _init();
  }

  Future<void> _init() async {
    _prefs = await ref.read(settingsRepoProvider).loadReaderPrefs();
    _chapters = await _repo.chapters(widget.projectId);
    _cast = await _repo.cast(widget.projectId);
    // 全书段落数 = 末章 endPara+1（导入时 startPara/endPara 是全书全局序号）
    _totalParas = _chapters.isEmpty ? 0 : _chapters.last.endPara + 1;
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
      _updateProgress();
      _persistProgress();
    });
  }

  /// 滚动中更新本章/全书进度（ValueNotifier，不 setState）
  void _updateProgress() {
    if (!_scroll.hasClients || _chapters.isEmpty) return;
    final max = _scroll.position.maxScrollExtent;
    final cPct = max <= 0 ? 1.0 : (_scroll.offset / max).clamp(0.0, 1.0);
    _chapterPct.value = cPct;
    final ch = _chapters[_chapterIdx];
    final span = ch.endPara - ch.startPara + 1;
    _bookPct.value = _totalParas <= 0
        ? 0
        : ((ch.startPara + cPct * span) / _totalParas).clamp(0.0, 1.0);
  }

  void _persistProgress() {
    if (!_scroll.hasClients) return;
    unawaited(_repo.saveReadingProgress(widget.projectId,
        chapterIdx: _chapterIdx,
        scrollOffset: _scroll.offset,
        progressPercent: _bookPct.value));
  }

  /// 点正文中央切换沉浸（微信读书式：顶/底栏收起，再点恢复）
  void _toggleImmersive() {
    setState(() => _immersive = !_immersive);
    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setEnabledSystemUIMode(
          _immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
    }
  }

  /// 批注随到随显：防抖后重查章级断点与当前章批注并 setState
  /// （复用现有批注加载，不重复查正文；章行一并刷新供"生成中"提示判定）。
  ///
  /// 切章竞态守卫：查询前记录当前章标识（首段 paraId），await 返回后用户
  /// 已切到别的章（_openChapter 换掉了 _paragraphs）则整体丢弃写回——否则
  /// 旧章的批注/章行快照会在新章渲染后覆盖进来，把新章刚落库的批注冲掉。
  Future<void> _reloadAnnotations() async {
    if (_chapters.isEmpty || _paragraphs.isEmpty) return;
    final chapterToken = _paragraphs.first.id;
    final rows = await _repo.chapters(widget.projectId);
    if (rows.isEmpty) return;
    final anns =
        await _repo.annotationsByParaId([for (final p in _paragraphs) p.id]);
    if (!mounted) return;
    if (_paragraphs.isEmpty || _paragraphs.first.id != chapterToken) return;
    setState(() {
      _chapters = rows;
      _chapterIdx = _chapterIdx.clamp(0, rows.length - 1);
      _anns = anns;
    });
  }

  /// 防抖 800ms，maxWait 2s：每个事件把刷新推迟 800ms；首个未处理事件
  /// 同时起一个 2s 硬期限定时器（不随事件重置），保证高频事件流下批注
  /// 最迟 2s 可见。任一定时器到点即刷新并清掉另一个。
  void _scheduleAnnotationReload() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(_reloadDebounceDelay, _flushAnnotationReload);
    _reloadDeadline ??= Timer(_reloadMaxWait, _flushAnnotationReload);
  }

  void _flushAnnotationReload() {
    _reloadDebounce?.cancel();
    _reloadDeadline?.cancel();
    _reloadDeadline = null;
    if (mounted) _reloadAnnotations();
  }

  Future<void> _updatePrefs(ReaderPrefs p) async {
    setState(() => _prefs = p);
    await ref.read(settingsRepoProvider).saveReaderPrefs(p);
  }

  @override
  void dispose() {
    _reloadDebounce?.cancel();
    _reloadDeadline?.cancel();
    _scroll.dispose();
    _chapterPct.dispose();
    _bookPct.dispose();
    WakelockPlus.disable();
    for (final c in _l4Controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 批注随到随显：该项目管线状态变化（批注进度/重批/里程碑事件）→
    // 防抖 800ms（maxWait 2s 兜底）重载当前章批注。只读 busy 做提示判定，
    // 不展示事件文案（novelEvents 的 progress/degraded/burst 事件 status 恒为
    // imported，milestone 才携带真实状态，故这里绝不读 status 做显示）。
    ref.listen(pipelineControllerProvider, (prev, next) {
      final s = next[widget.projectId];
      if (s == null) return;
      if (prev?[widget.projectId] == s) return;
      _scheduleAnnotationReload();
    });
    final pipelineBusy =
        ref.watch(pipelineControllerProvider)[widget.projectId]?.busy ?? false;
    final chapterAnnotDone =
        _chapters.isNotEmpty && _chapterIdx < _chapters.length
            ? _chapters[_chapterIdx].annotDone
            : true;
    // 生成中提示：当前章批注尚未落库 + 引擎正在推进
    final showHint =
        !_loading && _chapters.isNotEmpty && !chapterAnnotDone && pipelineBusy;
    final bg = _bgColors[_prefs.theme]!;
    final fg = _textColors[_prefs.theme]!;
    // 浅色书页用深色状态栏图标，深色反之（沉浸收起后由系统全屏模式接管）
    final overlay = _prefs.theme == ReaderTheme.paper
        ? SystemUiOverlayStyle.dark
        : SystemUiOverlayStyle.light;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: bg,
        drawer: _buildChapterDrawer(fg, bg),
        body: _loading
            ? const LoadingView()
            : _chapters.isEmpty
                ? EmptyState(
                    icon: Icons.menu_book_outlined,
                    title: '本书没有章节',
                    message: '重新导入这本小说可能可以修复；已有批注与卡片不受影响。',
                  )
                : Column(children: [
                    _topBar(bg, fg),
                    if (showHint)
                      Material(
                        color: bg,
                        child: SizedBox(
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Center(
                                child: Text('本章批注生成中…',
                                    style: TextStyle(
                                        fontSize: 12, color: fg))),
                          ),
                        ),
                      ),
                    Expanded(
                      child: GestureDetector(
                        // 点正文区域切换沉浸；气泡/L4 卡片的点击在子级
                        // 先命中，不会误触发
                        behavior: HitTestBehavior.opaque,
                        onTap: _toggleImmersive,
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            if (n is ScrollUpdateNotification ||
                                n is ScrollEndNotification) {
                              _updateProgress();
                            }
                            if (n is ScrollEndNotification) {
                              _persistProgress();
                            }
                            return false;
                          },
                          child: ListView.builder(
                            controller: _scroll,
                            padding: EdgeInsets.fromLTRB(
                                readerMarginValue(_prefs.margin),
                                Space.m,
                                readerMarginValue(_prefs.margin),
                                Space.xxl + readerMarginValue(_prefs.margin)),
                            // +1：章尾「下一章」接续卡
                            itemCount: _paragraphs.length + 1,
                            itemBuilder: (_, i) => i < _paragraphs.length
                                ? _paragraphItem(_paragraphs[i], fg)
                                : _nextChapterCard(fg),
                          ),
                        ),
                      ),
                    ),
                    _bottomBar(bg, fg),
                  ]),
      ),
    );
  }

  /// 顶栏（沉浸收起）：返回 + 章名 + 目录/人物/设置。自绘而非 AppBar，
  /// 是为了沉浸切换时高度可动画（AnimatedContainer 0↔kToolbarHeight）。
  Widget _topBar(Color bg, Color fg) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: _immersive ? 0 : kToolbarHeight,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: bg),
      child: Visibility(
        // 沉浸时不构建内容（Visibility 不留 element，命中与 finder 都干净）
        visible: !_immersive,
        // OverflowBox 恒定内容高度：沉浸还原动画的过渡帧里容器被压缩，
        // 无恒定约束的话内容会触发布局溢出（此处溢出本就该被 Clip 裁掉）
        child: OverflowBox(
          minHeight: kToolbarHeight,
          maxHeight: kToolbarHeight,
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: kToolbarHeight,
            child: SafeArea(
              bottom: false,
            child: Row(children: [
              IconButton(
                  icon:
                      Icon(Icons.arrow_back, color: fg.withValues(alpha: .75)),
                  tooltip: '返回',
                  onPressed: () => Navigator.maybePop(context)),
              Expanded(
                child: Text(
                  _chapters.isEmpty
                      ? '阅读器'
                      : (_chapters[_chapterIdx].title ??
                          '第${_chapterIdx + 1}部分'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge!
                      .copyWith(color: fg),
                ),
              ),
              IconButton(
                  icon: Icon(Icons.menu, color: fg.withValues(alpha: .75)),
                  tooltip: '目录',
                  onPressed: _openDrawer),
              IconButton(
                  icon: Icon(Icons.groups, color: fg.withValues(alpha: .75)),
                  tooltip: '本书人物',
                  onPressed: _showCastSheet),
              IconButton(
                  icon:
                      Icon(Icons.text_fields, color: fg.withValues(alpha: .75)),
                  tooltip: '阅读设置',
                  onPressed: _showPrefsSheet),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  /// 底部信息条（沉浸收起）：本章细进度条 + 「本章 x% · 全书 x%」。
  /// 全书%按全书段落序号折算（章起点 + 章内滚动插值），非按章数粗估。
  Widget _bottomBar(Color bg, Color fg) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: _immersive ? 0 : 34,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: bg),
      child: Visibility(
        visible: !_immersive,
        child: OverflowBox(
          minHeight: 34,
          maxHeight: 34,
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: 34,
            child: SafeArea(
              top: false,
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 硬约束高度：LinearProgressIndicator 在有界纵向约束下会扩展占满
                ValueListenableBuilder<double>(
                  valueListenable: _chapterPct,
                  builder: (_, pct, _) => SizedBox(
                    height: 2,
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 2,
                      color: fg.withValues(alpha: .45),
                      backgroundColor: fg.withValues(alpha: .10),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: ValueListenableBuilder<double>(
                  valueListenable: _bookPct,
                  builder: (_, bPct, _) => Text(
                    '本章 ${(_chapterPct.value * 100).round()}% · '
                    '全书 ${(bPct * 100).round()}%',
                    style: TextStyle(
                        fontSize: 11, color: fg.withValues(alpha: .60)),
                  ),
                ),
              ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  /// 章尾接续卡：读完本章一键进下一章（无下一章给收尾文案）
  Widget _nextChapterCard(Color fg) {
    final hasNext = _chapterIdx + 1 < _chapters.length;
    if (!hasNext) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xl),
        child: Center(
          child: Text('已是最后一章',
              style:
                  TextStyle(fontSize: 13, color: fg.withValues(alpha: .45))),
        ),
      );
    }
    final next = _chapters[_chapterIdx + 1];
    final title = next.title ?? '第${_chapterIdx + 2}部分';
    return Padding(
      padding: const EdgeInsets.only(top: Space.xl),
      child: Center(
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: fg,
            side: BorderSide(color: fg.withValues(alpha: .35)),
            padding: const EdgeInsets.symmetric(
                horizontal: Space.xl, vertical: Space.m),
          ),
          onPressed: () => _openChapter(_chapterIdx + 1),
          icon: const Icon(Icons.arrow_downward, size: 18),
          label: Text('下一章 · $title',
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
    // 抽屉 build 后把当前章滚到可见（偏上 1/3 处，前后章名留上下文）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _drawerCurrentKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, alignment: 0.3, duration: const Duration(milliseconds: 250));
      }
    });
  }

  /// 目录抽屉行模型：卷头（header 非空）或章条目（chapterIdx 非空）
  Widget _buildChapterDrawer(Color fg, Color bg) {
    final rows = <({String? header, int? chapterIdx})>[];
    String? lastVolume;
    var seenVolume = false;
    for (var i = 0; i < _chapters.length; i++) {
      final v = _chapters[i].volume;
      if (v != lastVolume && v != null) {
        rows.add((header: v, chapterIdx: null));
      }
      if (v != lastVolume) {
        lastVolume = v;
        seenVolume = v != null;
      }
      rows.add((header: null, chapterIdx: i));
    }
    final hasVolumes = seenVolume;
    return Drawer(
      backgroundColor: bg,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.l, Space.l, Space.l, Space.s),
            child: Text('目录',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge!
                    .copyWith(color: fg)),
          ),
          if (_lastReadingChapterIdx >= 0 &&
              _lastReadingChapterIdx != _chapterIdx)
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.l, 0, Space.l, Space.s),
              child: ActionChip(
                avatar: Icon(Icons.history, size: 15, color: fg),
                label: Text('上次读到 ${_chapterLabel(_lastReadingChapterIdx)}',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                onPressed: () {
                  Navigator.pop(context);
                  _openChapter(_lastReadingChapterIdx);
                },
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                  horizontal: Space.s, vertical: Space.m),
              itemCount: rows.length,
              itemBuilder: (_, r) {
                final row = rows[r];
                if (row.header != null) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Space.m, Space.m, Space.m, Space.xs),
                    child: Text(row.header!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge!
                            .copyWith(color: fg.withValues(alpha: .65))),
                  );
                }
                final i = row.chapterIdx!;
                final selected = i == _chapterIdx;
                final isLastRead = i == _lastReadingChapterIdx;
                return ListTile(
                  key: selected && hasVolumes ? _drawerCurrentKey : null,
                  dense: hasVolumes,
                  selected: selected,
                  shape:
                      RoundedRectangleBorder(borderRadius: AppRadius.rMd),
                  title: Text(
                    _chapterLabel(i),
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
        ]),
      ),
    );
  }

  String _chapterLabel(int i) =>
      _chapters[i].title ?? '第${i + 1}部分';

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
                _updatePrefs(_prefs.copyWith(fontSize: v));
              }),
              _sliderRow('行距', _prefs.lineHeight, 1.2, 2.2, 10,
                  _prefs.lineHeight.toStringAsFixed(1), (v) {
                setSheet(() {});
                _updatePrefs(_prefs.copyWith(lineHeight: v));
              }),
              const SizedBox(height: Space.s),
              Text('页边距', style: Theme.of(ctx).textTheme.bodyMedium),
              SegmentedButton<ReaderMargin>(
                segments: const [
                  ButtonSegment(
                      value: ReaderMargin.compact, label: Text('紧凑')),
                  ButtonSegment(
                      value: ReaderMargin.standard, label: Text('标准')),
                  ButtonSegment(
                      value: ReaderMargin.wide, label: Text('宽松')),
                ],
                selected: {_prefs.margin},
                onSelectionChanged: (s) {
                  setSheet(() {});
                  _updatePrefs(_prefs.copyWith(margin: s.first));
                },
              ),
              const SizedBox(height: Space.m),
              Text('背景', style: Theme.of(ctx).textTheme.bodyMedium),
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
                  _updatePrefs(_prefs.copyWith(theme: s.first));
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
