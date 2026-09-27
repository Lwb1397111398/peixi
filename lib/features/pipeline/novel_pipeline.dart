// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:drift/drift.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/features/pipeline/pipeline_engine.dart';
import 'package:peixi/features/pipeline/project_status.dart';

/// 小说处理引擎外壳（两遍式架构，设计文档 §6）：
/// 推进逻辑全部在 NovelScheduler（attachRun 注入）——三趟推进、里程碑、
/// 进度事件、取消检查都在调度器内；引擎只负责语义外壳：
/// ①事件广播与防并发；②[PipelineCancelled] 优雅退出（进度已落库，状态不变）；
/// ③[PipelineStageException] 按 stage 落 FAILED+failed_stage；
/// ④未知异常兜底到 'map' 阶段失败（调度器已尽量包装，此处防御）。
class NovelPipelineEngine {
  NovelPipelineEngine({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  final StreamController<PipelineEvent> _events =
      StreamController<PipelineEvent>.broadcast();
  Stream<PipelineEvent> get events => _events.stream;
  final Set<int> _busy = {};
  final Set<int> _cancelRequested = {};

  /// 项目是否正在调度器中运行（单章重批按钮据此禁用/拒绝）。
  bool isBusy(int projectId) => _busy.contains(projectId);

  /// 请求取消（仅当项目正在运行时登记）。协作式：调度器在批边界检查标记后抛
  /// [PipelineCancelled]，已完成的批/章已落库，续跑可无损恢复。
  void requestCancel(int projectId) {
    if (_busy.contains(projectId)) _cancelRequested.add(projectId);
  }

  bool isCancelled(int projectId) => _cancelRequested.contains(projectId);

  Future<void> Function(int projectId)? _runFn;

  /// 调度器注入点（推进/里程碑/取消检查都在调度器内；引擎只管语义外壳）
  void attachRun(Future<void> Function(int projectId) run) => _runFn = run;

  void _emit(int projectId, String stage, ProjectStatus status,
      {String? detail, bool cancelled = false}) {
    _events.add(PipelineEvent(
        projectId: projectId,
        stage: stage,
        status: status,
        detail: detail,
        cancelled: cancelled));
  }

  Future<Project> _project(int id) async {
    final p = await (_db.select(_db.projects)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (p == null) throw PipelineException('项目不存在: $id');
    return p;
  }

  Future<void> _setStatus(int id, ProjectStatus s, {String? failedStage}) async {
    await (_db.update(_db.projects)..where((t) => t.id.equals(id))).write(
        ProjectsCompanion(
            status: Value(s.db),
            failedStage: Value(failedStage),
            updatedAt: Value(DateTime.now())));
  }

  Future<void> run(int projectId) async {
    if (!_busy.add(projectId)) return; // 同项目防并发
    _cancelRequested.remove(projectId); // 上轮取消标记不带入新一轮
    try {
      final p = await _project(projectId);
      final st = ProjectStatus.fromDb(p.status);
      _emit(projectId, 'novel',
          st == ProjectStatus.failed ? ProjectStatus.imported : st);
      await _runFn?.call(projectId);
    } on PipelineCancelled {
      final p = await _project(projectId);
      _emit(projectId, 'novel', ProjectStatus.fromDb(p.status),
          detail: '已取消（进度已保存，可继续）', cancelled: true);
    } on PipelineStageException catch (e) {
      await _setStatus(projectId, ProjectStatus.failed, failedStage: e.stage);
      _emit(projectId, 'novel', ProjectStatus.failed, detail: '$e');
    } catch (e) {
      await _setStatus(projectId, ProjectStatus.failed, failedStage: 'map');
      _emit(projectId, 'novel', ProjectStatus.failed, detail: '$e');
    } finally {
      _busy.remove(projectId);
    }
  }

  Future<void> retry(int projectId) => run(projectId);
}
