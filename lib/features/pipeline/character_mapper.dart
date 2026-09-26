import 'package:drift/drift.dart' show Value;
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_routing.dart';
import 'package:peixi/core/llm/llm_service.dart';
import 'package:peixi/core/llm/prompts.dart';
import 'package:peixi/features/pipeline/project_meta.dart';

/// S6 角色自动映射：全量对白 + 文件名 → Prompt A → characters 表 +
/// 回填 segments.speaker_char_id。超长时均匀抽样防上下文溢出。
class CharacterMapper {
  CharacterMapper({required this.db, required this.llm});
  final AppDatabase db;
  final LlmService llm;

  static const _maxLines = 1500;

  Future<void> map(int projectId) async {
    final p = await (db.select(db.projects)
          ..where((t) => t.id.equals(projectId)))
        .getSingle();
    final meta = ProjectMeta.fromJson(p.metaJson);
    final sentences =
        ((meta.asrNormalized?['sentences'] as List?) ?? []).cast<Map>();

    var lines = <Map>[];
    if (sentences.length <= _maxLines) {
      lines = sentences;
    } else {
      // 均匀抽样保序
      final step = sentences.length / _maxLines;
      lines = [for (var i = 0; i < _maxLines; i++) sentences[(i * step).floor()]];
    }
    final dialogue = lines
        .map((s) =>
            '[${s['speaker_id']}][${formatTimestamp(s['begin_ms'] as int)}]${s['text']}')
        .join('\n');

    // chatJson 内部已注入 jsonSystemPrefix 并启用 json_object
    final result = await llm.chatJson(
      [
        {
          'role': 'user',
          'content': Prompts.characterMapping(
              filename: meta.sourceFilename ?? p.title, dialogueLines: dialogue),
        },
      ],
      slot: LlmSlot.summary,
      purpose: 'map',
      projectId: projectId,
    );

    final chars = (result['characters'] as List? ?? []).cast<Map>();
    if (chars.isEmpty) {
      throw Exception('角色映射返回空结果');
    }

    // 幂等：重跑先清旧
    await (db.update(db.segments)..where((t) => t.projectId.equals(projectId)))
        .write(const SegmentsCompanion(speakerCharId: Value(null)));
    await (db.delete(db.characters)
          ..where((t) => t.projectId.equals(projectId)))
        .go();

    final speakerToCharId = <String, int>{};
    for (final c in chars) {
      final speaker = (c['speaker_id'] ?? '').toString();
      final name = (c['name'] ?? '').toString().trim();
      if (speaker.isEmpty || name.isEmpty) continue;
      final id = await db.into(db.characters).insert(CharactersCompanion.insert(
            projectId: projectId,
            name: name,
            speakerKey: Value(speaker),
            confidence: Value((c['confidence'] as num?)?.toDouble()),
          ));
      speakerToCharId[speaker] = id;
    }
    if (speakerToCharId.isEmpty) {
      throw Exception('角色映射无有效条目');
    }

    // segments 与 sentences 同序写入（S5 保证），按 idx 对齐回填
    final segs = await (db.select(db.segments)
          ..where((t) => t.projectId.equals(projectId)))
        .get();
    for (final seg in segs) {
      if (seg.idx >= sentences.length) break;
      final speaker = sentences[seg.idx]['speaker_id'] as String?;
      final charId = speaker == null ? null : speakerToCharId[speaker];
      if (charId != null) {
        await (db.update(db.segments)..where((t) => t.id.equals(seg.id)))
            .write(SegmentsCompanion(speakerCharId: Value(charId)));
      }
    }
  }
}
