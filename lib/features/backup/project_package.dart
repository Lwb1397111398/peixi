import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/features/pipeline/project_meta.dart';

/// 项目包导出/导入（设计稿 8.6：zip = SQLite 行 JSON + 元信息）。
/// 包内结构：
///   manifest.json  {version, exportedAt, projectTitle, type}
///   db.json        十一表全行（含旧 id，导入时重映射）
///   `audio/<旧项目id>.<ext>`  临时音频（存在才打包）
/// 视频项目不含视频本体；导入后 meta.mediaMissing=true（换设备只能看解说/问答）。
class ProjectPackage {
  ProjectPackage(this.db);
  final AppDatabase db;

  /// v2：knowledge_cards 行含 SRS 调度列（v1 包导入时自动补默认值）。
  static const version = 2;

  /// 构建包字节（UI 用 FilePicker.saveFile 自选位置）
  Future<({String fileName, List<int> bytes})> buildPackage(
      int projectId,
      {required String audioDir}) async {
    final project = await (db.select(db.projects)
          ..where((t) => t.id.equals(projectId)))
        .getSingle();

    final characters = await (db.select(db.characters)
          ..where((t) => t.projectId.equals(projectId)))
        .get();
    final segments = await (db.select(db.segments)
          ..where((t) => t.projectId.equals(projectId)))
        .get();
    final scenes = await (db.select(db.scenes)
          ..where((t) => t.projectId.equals(projectId)))
        .get();
    final sceneIds = {for (final s in scenes) s.id};
    final commentaries = [
      for (final c in await db.select(db.commentaries).get())
        if (sceneIds.contains(c.sceneId)) c
    ];
    final cards = await (db.select(db.knowledgeCards)
          ..where((t) => t.projectId.equals(projectId)))
        .get();
    final questions = await (db.select(db.questions)
          ..where((t) => t.projectId.equals(projectId)))
        .get();
    final questionIds = {for (final q in questions) q.id};
    final qaRecords = [
      for (final r in await db.select(db.qaRecords).get())
        if (questionIds.contains(r.questionId)) r
    ];
    final chapters = await (db.select(db.chapters)
          ..where((t) => t.projectId.equals(projectId)))
        .get();
    final paragraphs = await (db.select(db.paragraphs)
          ..where((t) => t.projectId.equals(projectId)))
        .get();
    final paraIds = {for (final p in paragraphs) p.id};
    final annotations = [
      for (final a in await db.select(db.annotations).get())
        if (paraIds.contains(a.paraId)) a
    ];

    final dbJson = jsonEncode({
      'projects': [project.toJson()],
      'characters': [for (final r in characters) r.toJson()],
      'segments': [for (final r in segments) r.toJson()],
      'scenes': [for (final r in scenes) r.toJson()],
      'commentaries': [for (final r in commentaries) r.toJson()],
      'knowledge_cards': [for (final r in cards) r.toJson()],
      'questions': [for (final r in questions) r.toJson()],
      'qa_records': [for (final r in qaRecords) r.toJson()],
      'chapters': [for (final r in chapters) r.toJson()],
      'paragraphs': [for (final r in paragraphs) r.toJson()],
      'annotations': [for (final r in annotations) r.toJson()],
    });

    final archive = Archive()
      ..addFile(ArchiveFile.string(
          'manifest.json',
          jsonEncode({
            'version': version,
            'exportedAt': DateTime.now().toIso8601String(),
            'projectTitle': project.title,
            'type': project.type,
          })))
      ..addFile(ArchiveFile.string('db.json', dbJson));

    // 临时音频（存在则打包）
    final meta = ProjectMeta.fromJson(project.metaJson);
    if (meta.audioFormat != null) {
      final f = File('$audioDir/$projectId.${meta.audioFormat}');
      if (f.existsSync()) {
        archive.addFile(ArchiveFile(
            'audio/$projectId.${meta.audioFormat}', f.lengthSync(),
            f.readAsBytesSync()));
      }
    }

    final zip = ZipEncoder().encode(archive);
    final safeTitle = project.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return (
        fileName: '${safeTitle}_$projectId.peixi.zip', bytes: zip);
  }

  /// 落盘到指定目录（测试/批量备份用）
  Future<File> exportProject(int projectId,
      {required String outputDir, required String audioDir}) async {
    final built =
        await buildPackage(projectId, audioDir: audioDir);
    final out = File('$outputDir/${built.fileName}');
    await out.writeAsBytes(built.bytes);
    return out;
  }

  Future<int> importProject(File zipFile,
      {required String audioDir}) async {
    final bytes = zipFile.readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile findFile(String name) {
      final f = archive.findFile(name);
      if (f == null) throw Exception('项目包缺少 $name，文件可能损坏');
      return f;
    }

    findFile('manifest.json'); // 校验存在
    final dbData = jsonDecode(utf8.decode(findFile('db.json').content))
        as Map<String, dynamic>;
    List<Map<String, dynamic>> rows(String table) =>
        ((dbData[table] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

    const noId = Value<int>.absent();

    return db.transaction(() async {
      // projects（视频项目标记媒体缺失；id 换新）
      final projectMap = rows('projects').single;
      final isVideo = projectMap['type'] == 'video';
      if (isVideo) {
        final meta = ProjectMeta.fromJson(projectMap['metaJson'] as String?)
          ..mediaMissing = true;
        projectMap['metaJson'] = meta.encode();
      }
      final project =
          Project.fromJson(projectMap).toCompanion(false).copyWith(id: noId);
      final newProjectId = await db.into(db.projects).insert(project);

      // 依赖序重映射插入（fromJson 保留旧 id → copyWith 换新 id/外键）
      final charIdMap = <int, int>{};
      for (final m in rows('characters')) {
        final oldId = m['id'] as int;
        final comp = Character.fromJson(m)
            .toCompanion(false)
            .copyWith(id: noId, projectId: Value(newProjectId));
        charIdMap[oldId] = await db.into(db.characters).insert(comp);
      }

      final sceneIdMap = <int, int>{};
      for (final m in rows('scenes')) {
        final oldId = m['id'] as int;
        final comp = Scene.fromJson(m)
            .toCompanion(false)
            .copyWith(id: noId, projectId: Value(newProjectId));
        sceneIdMap[oldId] = await db.into(db.scenes).insert(comp);
      }

      final chapterIdMap = <int, int>{};
      for (final m in rows('chapters')) {
        final oldId = m['id'] as int;
        final comp = Chapter.fromJson(m)
            .toCompanion(false)
            .copyWith(id: noId, projectId: Value(newProjectId));
        chapterIdMap[oldId] = await db.into(db.chapters).insert(comp);
      }

      final questionIdMap = <int, int>{};
      for (final m in rows('questions')) {
        final oldId = m['id'] as int;
        final q = Question.fromJson(m).toCompanion(false);
        final sceneId = m['sceneId'] as int?;
        final comp = q.copyWith(
            id: noId,
            projectId: Value(newProjectId),
            sceneId: sceneId == null
                ? const Value<int>.absent()
                : Value(sceneIdMap[sceneId]));
        questionIdMap[oldId] = await db.into(db.questions).insert(comp);
      }

      for (final m in rows('segments')) {
        final s = Segment.fromJson(m).toCompanion(false);
        final speaker = m['speakerCharId'] as int?;
        final comp = s.copyWith(
            id: noId,
            projectId: Value(newProjectId),
            speakerCharId: speaker == null
                ? const Value<int>.absent()
                : Value(charIdMap[speaker]));
        await db.into(db.segments).insert(comp);
      }

      for (final m in rows('commentaries')) {
        final comp = Commentary.fromJson(m).toCompanion(false).copyWith(
            id: noId, sceneId: Value(sceneIdMap[m['sceneId'] as int]!));
        await db.into(db.commentaries).insert(comp);
      }

      for (final m in rows('knowledge_cards')) {
        // v1 包没有 SRS 列；fromJson 对缺失的非空列会抛类型错误，先补默认值
        for (final e in const {
          'dueAt': null,
          'ivlDays': 0.0,
          'ease': 2.5,
          'reps': 0,
          'lapses': 0,
          'lastReviewAt': null,
        }.entries) {
          m.putIfAbsent(e.key, () => e.value);
        }
        final comp = KnowledgeCard.fromJson(m)
            .toCompanion(false)
            .copyWith(id: noId, projectId: Value(newProjectId));
        await db.into(db.knowledgeCards).insert(comp);
      }

      for (final m in rows('qa_records')) {
        final comp = QaRecord.fromJson(m).toCompanion(false).copyWith(
            id: noId,
            questionId: Value(questionIdMap[m['questionId'] as int]!));
        await db.into(db.qaRecords).insert(comp);
      }

      final paraIdMap = <int, int>{};
      for (final m in rows('paragraphs')) {
        final oldId = m['id'] as int;
        final para = Paragraph.fromJson(m).toCompanion(false);
        final chapterId = m['chapterId'] as int?;
        final comp = para.copyWith(
            id: noId,
            projectId: Value(newProjectId),
            chapterId: chapterId == null
                ? const Value<int>.absent()
                : Value(chapterIdMap[chapterId]));
        paraIdMap[oldId] = await db.into(db.paragraphs).insert(comp);
      }

      for (final m in rows('annotations')) {
        final comp = Annotation.fromJson(m).toCompanion(false).copyWith(
            id: noId, paraId: Value(paraIdMap[m['paraId'] as int]!));
        await db.into(db.annotations).insert(comp);
      }

      // 音频还原（包内旧 id 命名 → 新项目 id）
      for (final f in archive.files) {
        if (f.isFile && f.name.startsWith('audio/')) {
          final ext = f.name.split('.').last;
          await File('$audioDir/$newProjectId.$ext')
              .writeAsBytes(f.content);
        }
      }

      return newProjectId;
    });
  }
}
