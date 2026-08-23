import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/features/player/commentary_card.dart';
import 'package:peixi/features/player/quiz_engine.dart';
import 'package:peixi/features/player/quiz_overlay.dart';
import 'package:peixi/features/player/scene_progress_bar.dart';
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
    final commentaries = await db.select(db.commentaries).get();
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
    _posSub = _player.stream.position.listen(_onPosition);
    _playingSub = _player.stream.playing.listen((playing) {
      if (!mounted) return;
      setState(() => _paused = !playing);
    });
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final quiz = _quizEngine;
    final scene = (_currentSceneIdx >= 0 && _currentSceneIdx < _scenes.length)
        ? _scenes[_currentSceneIdx]
        : null;
    final cards = scene == null
        ? const <KnowledgeCard>[]
        : _cards.where((c) => c.firstSceneIdx == scene.idx).toList();

    final videoArea = Column(mainAxisSize: MainAxisSize.min, children: [
      AspectRatio(
        aspectRatio: 16 / 9,
        child: Video(controller: _videoController),
      ),
      SceneProgressBar(
        positionMs: _positionMs,
        durationMs: _durationMs,
        boundariesMs: quiz?.boundaryPoints() ?? const <int>[],
        quizMarkerMs: [for (final m in quiz?.markerPoints() ?? const []) m.posMs],
        onSeek: (ms) => _player.seek(Duration(milliseconds: ms)),
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
    if (MediaQuery.of(context).size.width >= 900) {
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
          if (MediaQuery.of(context).size.width >= 900)
            IconButton(
              icon: const Icon(Icons.view_sidebar_outlined),
              tooltip: _panelCollapsed ? '展开解说栏' : '收起解说栏',
              onPressed: () => setState(() => _panelCollapsed = !_panelCollapsed),
            ),
        ],
      ),
      body: Stack(children: [
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
    );
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
