import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/logging/crash_log.dart';
import 'package:peixi/core/theme/tokens.dart';
import 'package:peixi/features/player/commentary_card.dart';
import 'package:peixi/features/player/player_shortcuts.dart';
import 'package:peixi/features/player/quiz_engine.dart';
import 'package:peixi/features/player/quiz_overlay.dart';
import 'package:peixi/features/player/scene_progress_bar.dart';
import 'package:peixi/ui/widgets/loading_view.dart';
import 'package:peixi/providers.dart';

/// 视频播放器页（设计稿 8.2）：桌面左视频右解说栏；手机竖屏上视频下解说卡。
/// 场景切换动画 250ms；手动暂停自动展开全部层级；L4 到点自动暂停弹题。
class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key, required this.projectId});
  final int projectId;

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  late final Player _player = Player();
  late final VideoController _videoController = VideoController(_player);

  Project? _project;
  List<Scene> _scenes = [];
  final Map<int, Commentary> _commentaryByScene = {};
  final Map<int, Question> _questionByScene = {};
  List<KnowledgeCard> _cards = [];
  final Map<String, Color> _colorByName = {};

  QuizEngine? _quizEngine;
  int _currentSceneIdx = -1;
  int _positionMs = 0;
  int _durationMs = 1;
  bool _paused = false;
  bool _panelCollapsed = false;
  final Set<int> _seenCardIds = {};
  double _playbackRate = 1.0;
  String? _subtitleUri; // S2 提取的 .srt（存在才有字幕开关）
  bool _subtitlesOn = false;

  Question? _activeQuiz;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<bool>? _playingSub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final p = await (db.select(db.projects)
          ..where((t) => t.id.equals(widget.projectId)))
        .getSingle();
    final scenes = await (db.select(db.scenes)
          ..where((t) => t.projectId.equals(widget.projectId))
          ..orderBy([(t) => OrderingTerm.asc(t.idx)]))
        .get();
    // 只取本项目场景的解说（scene_id 有唯一索引，全表加载会随项目数变慢）
    final commentaries = scenes.isEmpty
        ? const <Commentary>[]
        : await (db.select(db.commentaries)
              ..where((t) => t.sceneId
                  .isIn([for (final s in scenes) s.id])))
            .get();
    final questions = await (db.select(db.questions)
          ..where((t) => t.projectId.equals(widget.projectId)))
        .get();
    final cards = await (db.select(db.knowledgeCards)
          ..where((t) => t.projectId.equals(widget.projectId)))
        .get();
    final chars = await (db.select(db.characters)
          ..where((t) => t.projectId.equals(widget.projectId)))
        .get();

    final prefs = await ref.read(settingsRepoProvider).loadPlayPrefs();
    final quizScenes = [
      for (final s in scenes)
        QuizScene(
          sceneId: s.id,
          idx: s.idx,
          startMs: s.startMs,
          endMs: s.endMs,
          importance: s.importance,
          hasQuestion: questions.any(
              (q) => q.sceneId == s.id && q.question.trim().isNotEmpty),
        ),
    ];

    if (!mounted) return;
    setState(() {
      _project = p;
      _scenes = scenes;
      _playbackRate = prefs.playbackRate;
      for (final c in commentaries) {
        _commentaryByScene[c.sceneId] = c;
      }
      for (final q in questions) {
        if (q.sceneId != null) _questionByScene[q.sceneId!] = q;
      }
      _cards = cards;
      for (final c in chars) {
        _colorByName[c.name] = Color(int.parse(
            (c.color ?? 'FFFFFFFF').replaceFirst('#', ''),
            radix: 16));
      }
      _quizEngine = QuizEngine(prefs: prefs, scenes: quizScenes);
      _durationMs = scenes.isEmpty ? 1 : scenes.last.endMs + 1000;
    });

    await _player.open(Media(p.sourcePath), play: false);
    await _player.setRate(_playbackRate);
    await _loadSubtitleTrack();
    _posSub = _player.stream.position.listen(_onPosition);
    _playingSub = _player.stream.playing.listen((playing) {
      if (!mounted) return;
      setState(() => _paused = !playing);
    });
  }

  /// S2 提取的内嵌字幕轨（有则默认开启，AppBar 可切换）。
  Future<void> _loadSubtitleTrack() async {
    try {
      final audioDir =
          await ref.read(pipelineControllerProvider.notifier).audioDir();
      final srt = File('${audioDir.path}/${widget.projectId}.srt');
      if (!srt.existsSync()) return;
      _subtitleUri = Uri.file(srt.path).toString();
      await _player.setSubtitleTrack(SubtitleTrack.uri(_subtitleUri!));
      if (mounted) setState(() => _subtitlesOn = true);
    } catch (e, st) {
      // 字幕轨加载失败不影响播放，但留痕便于排查"为何没有字幕"
      CrashLog.write('subtitle-track', e, st);
    }
  }

  void _onPosition(Duration pos) {
    if (!mounted || _activeQuiz != null) return;
    final ms = pos.inMilliseconds;
    final engine = _quizEngine;
    if (engine != null) {
      final trigger = engine.shouldTrigger(ms);
      if (trigger != null) {
        final q = _questionByScene[trigger.scene.sceneId];
        if (q != null) {
          _player.pause();
          setState(() => _activeQuiz = q);
          return;
        }
      }
    }
    final idx = sceneAt(engine?.scenes ?? const [], ms);
    if (idx != _currentSceneIdx || ms != _positionMs) {
      setState(() {
        _currentSceneIdx = idx;
        _positionMs = ms;
      });
    }
  }

  Future<void> _recordAnswer(Question q, String answer, bool skipped) async {
    final db = ref.read(databaseProvider);
    await db.into(db.qaRecords).insert(QaRecordsCompanion.insert(
          questionId: q.id,
          userAnswer: answer,
          skipped: Value(skipped),
        ));
  }

  Future<void> _saveRate(double r) async {
    final repo = ref.read(settingsRepoProvider);
    final prefs = await repo.loadPlayPrefs();
    await repo.savePlayPrefs(prefs.copyWith(playbackRate: r));
  }

  List<String> _perspectivesOf(Question q) {
    if (q.perspectivesJson.isEmpty) return const [];
    try {
      final v = jsonDecode(q.perspectivesJson);
      if (v is List) return v.map((e) => e.toString()).toList();
    } catch (_) {}
    return const [];
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _playingSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_project == null) {
      return const Scaffold(body: LoadingView());
    }
    final quiz = _quizEngine;
    final scene = (_currentSceneIdx >= 0 && _currentSceneIdx < _scenes.length)
        ? _scenes[_currentSceneIdx]
        : null;
    final cards = scene == null
        ? const <KnowledgeCard>[]
        : _cards.where((c) => c.firstSceneIdx == scene.idx).toList();

    final videoArea = Column(mainAxisSize: MainAxisSize.min, children: [
      // 视频区恒定黑底（letterbox），不随主题变化
      Container(
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Video(controller: _videoController),
        ),
      ),
      SceneProgressBar(
        positionMs: _positionMs,
        durationMs: _durationMs,
        boundariesMs: quiz?.boundaryPoints() ?? const <int>[],
        quizMarkerMs: [for (final m in quiz?.markerPoints() ?? const []) m.posMs],
        onSeek: (ms) {
          _quizEngine?.notifySeek(ms);
          _player.seek(Duration(milliseconds: ms));
        },
      ),
    ]);

    final commentaryArea = _CommentaryPanel(
      scene: scene,
      commentary: scene == null ? null : _commentaryByScene[scene.id],
      cards: cards,
      colorByName: _colorByName,
      forceExpand: _paused,
      seenCardIds: _seenCardIds,
      sceneCount: _scenes.length,
    );

    Widget body;
    if (MediaQuery.sizeOf(context).width >= kTwoPaneBreakpoint) {
      body = Row(children: [
        Expanded(child: videoArea),
        if (!_panelCollapsed) SizedBox(width: 380, child: commentaryArea),
      ]);
    } else {
      body = Column(children: [
        videoArea,
        Expanded(child: commentaryArea),
      ]);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${_project!.title} · 观看'),
        actions: [
          if (_subtitleUri != null)
            IconButton(
              icon: Icon(_subtitlesOn
                  ? Icons.closed_caption
                  : Icons.closed_caption_off),
              tooltip: _subtitlesOn ? '关闭字幕' : '显示字幕',
              onPressed: () async {
                final on = !_subtitlesOn;
                await _player.setSubtitleTrack(on
                    ? SubtitleTrack.uri(_subtitleUri!)
                    : SubtitleTrack.no());
                if (mounted) setState(() => _subtitlesOn = on);
              },
            ),
          PopupMenuButton<double>(
            tooltip: '播放倍速',
            icon: const Icon(Icons.speed_outlined),
            initialValue: _playbackRate,
            onSelected: (r) {
              setState(() => _playbackRate = r);
              _player.setRate(r);
              _saveRate(r);
            },
            itemBuilder: (_) => [
              for (final r in [0.75, 1.0, 1.25, 1.5, 2.0])
                PopupMenuItem(value: r, child: Text('${r}x')),
            ],
          ),
          if (MediaQuery.sizeOf(context).width >= kTwoPaneBreakpoint)
            IconButton(
              icon: const Icon(Icons.view_sidebar_outlined),
              tooltip: _panelCollapsed ? '展开解说栏' : '收起解说栏',
              onPressed: () => setState(() => _panelCollapsed = !_panelCollapsed),
            ),
        ],
      ),
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(children: [
          body,
          if (_activeQuiz != null)
            Positioned.fill(
              child: QuizOverlay(
                question: _activeQuiz!.question,
                perspectives: _perspectivesOf(_activeQuiz!),
                onSubmit: (answer) => _recordAnswer(_activeQuiz!, answer, false),
                onSkip: () => _recordAnswer(_activeQuiz!, '', true),
                onResume: () {
                  setState(() => _activeQuiz = null);
                  _player.play();
                },
              ),
            ),
        ]),
      ),
    );
  }

  /// 键盘控制：空格暂停/继续、←/→ 快退快进 10s、↑/↓ 音量。
  /// 答题输入框等编辑框聚焦时全部让位。
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final editing =
        FocusManager.instance.primaryFocus?.context?.widget is EditableText;
    switch (resolvePlayerKey(event.logicalKey, editing: editing)) {
      case PlayerKeyAction.toggle:
        _player.state.playing ? _player.pause() : _player.play();
      case PlayerKeyAction.seekBack:
        _seekBy(-10000);
      case PlayerKeyAction.seekForward:
        _seekBy(10000);
      case PlayerKeyAction.volumeUp:
        _volumeBy(10);
      case PlayerKeyAction.volumeDown:
        _volumeBy(-10);
      case PlayerKeyAction.none:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _seekBy(int deltaMs) {
    final ms = clampSeekMs(_positionMs, deltaMs, maxMs: _durationMs);
    _quizEngine?.notifySeek(ms);
    _player.seek(Duration(milliseconds: ms));
  }

  Future<void> _volumeBy(int delta) async {
    final v = (_player.state.volume + delta).clamp(0.0, 100.0);
    await _player.setVolume(v);
  }
}

/// 解说面板：场景切换时旧卡下滑淡出、新卡上滑淡入（250ms）。
class _CommentaryPanel extends StatelessWidget {
  const _CommentaryPanel({
    required this.scene,
    required this.commentary,
    required this.cards,
    required this.colorByName,
    required this.forceExpand,
    required this.seenCardIds,
    required this.sceneCount,
  });

  final Scene? scene;
  final Commentary? commentary;
  final List<KnowledgeCard> cards;
  final Map<String, Color> colorByName;
  final bool forceExpand;
  final Set<int> seenCardIds;
  final int sceneCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: scene == null
          ? Center(
              child: Text('开始播放后，解说将随场景切换',
                  style: Theme.of(context).textTheme.bodyMedium))
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) {
                final inAnim = child.key == ValueKey(scene!.id);
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: inAnim ? const Offset(0, 0.15) : Offset.zero,
                    end: inAnim ? Offset.zero : const Offset(0, -0.15),
                  ).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                );
              },
              child: SingleChildScrollView(
                key: ValueKey(scene!.id),
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                        '场景 ${scene!.idx + 1}/$sceneCount',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: Theme.of(context).colorScheme.outline)),
                  ),
                  CommentaryCard(
                    scene: scene!,
                    commentary: commentary,
                    cards: cards,
                    colorByName: colorByName,
                    forceExpand: forceExpand,
                    seenCardIds: seenCardIds,
                  ),
                ]),
              ),
            ),
    );
  }
}
