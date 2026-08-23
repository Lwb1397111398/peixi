import 'dart:async';

import 'package:drift/drift.dart' show Expression, Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/features/pipeline/project_meta.dart';
import 'package:peixi/providers.dart';

/// 校准页（设计稿 8.3，S7 人工闸门）：
/// 按台词量降序列出声音簇；色块 + 最长 3 句代表台词 + ▶试听 +
/// 建议名胶囊（低置信度高亮）+ 自定义输入；顶部〔全部采纳建议〕。
class CalibrationPage extends ConsumerStatefulWidget {
  const CalibrationPage({
    super.key,
    required this.projectId,
    required this.audioPath,
    required this.onConfirm,
  });
  final int projectId;
  final String audioPath;
  final Future<void> Function(Map<int, String> names) onConfirm;

  @override
  ConsumerState<CalibrationPage> createState() => _CalibrationPageState();
}

class _SpeakerCluster {
  _SpeakerCluster(this.character, this.lineCount, this.lines);
  final Character character;
  final int lineCount;
  final List<Segment> lines; // 最长 3 句
}

const _palette = [
  Color(0xFFE57373), Color(0xFF64B5F6), Color(0xFF81C784),
  Color(0xFFFFD54F), Color(0xFFBA68C8), Color(0xFF4DB6AC),
  Color(0xFFFF8A65), Color(0xFF9575CD),
];

class _CalibrationPageState extends ConsumerState<CalibrationPage> {
  final _controllers = <int, TextEditingController>{};
  List<_SpeakerCluster> _clusters = [];
  bool _loading = true;
  bool _submitting = false;

  Player? _player;
  StreamSubscription<Duration>? _posSub;
  int? _playingSegStart;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final chars = await (db.select(db.characters)
          ..where((t) => Expression.and([
                t.projectId.equals(widget.projectId),
                t.speakerKey.isNotNull(),
                t.speakerKey.isNotIn(['']),
              ])))
        .get();
    final segs = await (db.select(db.segments)
          ..where((t) => t.projectId.equals(widget.projectId)))
        .get();

    final clusters = <_SpeakerCluster>[];
    for (final c in chars) {
      final mine = segs.where((s) => s.speakerCharId == c.id).toList();
      if (mine.isEmpty) continue;
      mine.sort((a, b) => b.content.length.compareTo(a.content.length));
      clusters.add(_SpeakerCluster(c, mine.length, mine.take(3).toList()));
    }
    clusters.sort((a, b) => b.lineCount.compareTo(a.lineCount));

    // 色块持久化（播放器解说按角色着色复用）
    for (var i = 0; i < clusters.length; i++) {
      final color = _palette[i % _palette.length].toARGB32();
      if (clusters[i].character.color == null) {
        await (db.update(db.characters)
              ..where((t) => t.id.equals(clusters[i].character.id)))
            .write(CharactersCompanion(color: Value('#${color.toRadixString(16).padLeft(8, '0')}')));
        clusters[i] = _SpeakerCluster(
            clusters[i].character.copyWith(
                color: Value('#${color.toRadixString(16).padLeft(8, '0')}')),
            clusters[i].lineCount,
            clusters[i].lines);
      }
      _controllers[clusters[i].character.id] =
          TextEditingController(text: clusters[i].character.name);
    }
    if (!mounted) return;
    setState(() {
      _clusters = clusters;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _stopPreview();
    _player?.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _preview(Segment seg) async {
    _stopPreview();
    final player = _player ??= Player();
    try {
      await player.open(Media(widget.audioPath));
      await player.seek(Duration(milliseconds: seg.startMs));
      unawaited(player.play());
      setState(() => _playingSegStart = seg.id);
      _posSub = player.stream.position.listen((pos) {
        if (pos.inMilliseconds >= seg.endMs) {
          _stopPreview();
        }
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('试听失败：临时音频不存在或格式不支持')));
      }
    }
  }

  void _stopPreview() {
    _posSub?.cancel();
    _posSub = null;
    _player?.pause();
    if (_playingSegStart != null && mounted) {
      setState(() => _playingSegStart = null);
    }
  }

  void _adoptAll() {
    for (final cl in _clusters) {
      _controllers[cl.character.id]?.text = cl.character.name;
    }
  }

  Future<void> _confirm() async {
    setState(() => _submitting = true);
    final names = {
      for (final e in _controllers.entries)
        if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
    };
    await widget.onConfirm(names);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('校准说话人'),
        actions: [
          TextButton.icon(
            onPressed: _adoptAll,
            icon: const Icon(Icons.done_all, size: 18),
            label: const Text('全部采纳建议'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _clusters.isEmpty
              ? const Center(child: Text('没有可校准的说话人簇'))
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      '确认每个声音对应的角色名。低置信度建议已高亮，改完点右下角确认，'
                      '之后将自动完成场景切分与解说生成。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _clusters.length,
                      itemBuilder: (context, i) => _clusterTile(_clusters[i]),
                    ),
                  ),
                ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _submitting ? null : _confirm,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: const Text('确认，继续生成'),
          ),
        ),
      ),
    );
  }

  Widget _clusterTile(_SpeakerCluster cl) {
    final lowConf = (cl.character.confidence ?? 1.0) < 0.6;
    final color = Color(
        int.parse(cl.character.color?.replaceFirst('#', '') ??
                _palette[_clusters.indexOf(cl) % _palette.length]
                    .toARGB32()
                    .toRadixString(16)
                    .padLeft(8, '0'),
            radix: 16));
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: lowConf
                    ? Colors.orange.withValues(alpha: 0.18)
                    : Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${cl.character.name}（${(cl.character.confidence ?? 0).toStringAsFixed(2)}）'
                '${lowConf ? ' · 待确认' : ''}',
                style: TextStyle(
                    fontSize: 12,
                    color: lowConf ? Colors.orange : Colors.green),
              ),
            ),
            const Spacer(),
            Text('${cl.lineCount} 句',
                style: Theme.of(context).textTheme.bodySmall),
          ]),
          const SizedBox(height: 8),
          for (final seg in cl.lines)
            Row(children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 20,
                icon: Icon(_playingSegStart == seg.id
                    ? Icons.stop_circle
                    : Icons.play_circle_outline),
                onPressed: () => _playingSegStart == seg.id
                    ? _stopPreview()
                    : _preview(seg),
              ),
              Expanded(
                child: Text(
                  seg.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ]),
          const SizedBox(height: 4),
          TextField(
            controller: _controllers[cl.character.id],
            decoration: const InputDecoration(
              isDense: true,
              labelText: '角色名',
              border: OutlineInputBorder(),
            ),
          ),
        ]),
      ),
    );
  }
}

/// 供导航层构造校准页（注入音频路径与确认回调）。
Future<CalibrationPage> buildCalibrationPage({
  required int projectId,
  required WidgetRef ref,
  required Future<void> Function(Map<int, String>) onConfirm,
}) async {
  final db = ref.read(databaseProvider);
  final p = await (db.select(db.projects)
        ..where((t) => t.id.equals(projectId)))
      .getSingle();
  final meta = ProjectMeta.fromJson(p.metaJson);
  final controller = ref.read(pipelineControllerProvider.notifier);
  final dir = await controller.audioDir();
  return CalibrationPage(
    projectId: projectId,
    audioPath: meta.audioPath(dir.path, projectId),
    onConfirm: onConfirm,
  );
}
