// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_service.dart';
import 'package:peixi/core/settings/settings_repository.dart';
import 'package:peixi/features/pipeline/novel_annotate_pass.dart';
import 'package:peixi/features/pipeline/novel_digest_pass.dart';
import 'package:peixi/features/pipeline/novel_importer.dart';
import 'package:peixi/features/pipeline/novel_map_pass.dart';
import 'package:peixi/features/pipeline/novel_recall.dart';
import 'package:peixi/features/pipeline/pipeline_engine.dart';
import 'package:peixi/features/pipeline/project_status.dart';

/// 调度器事件：controller 转 PipelineEvent；UI 依赖 detail 文案 + 自行复算 DB。
class NovelSchedulerEvent {
  NovelSchedulerEvent(this.kind, this.detail, {this.status});
  final String kind; // progress | burst | degraded | milestone
  final String detail;
  final ProjectStatus? status; // milestone 事件携带目标状态
}

typedef _Counts = ({int mapDone, int digestReady, int annotDone, int total});

/// 小说调度器（设计文档 §6）：①首屏冲刺（前 burst 章 map→digest→annotate，
/// 批注尽快就绪可读）②跟随模式双泳道：地图泳道保持 mapDone ≥ annotDone +
/// mapLead（领先保活）；主泳道 digest 追赶（就绪 ≥ 批注完成 + 1）+ annotate
/// 按书序推进。全部调用经 LlmService（全局信号量交错），取消/失败在批边界
/// 优雅退出；里程碑 mapped/commentaryDone/ready 只升不降。
class NovelScheduler {
  NovelScheduler({
    required AppDatabase db,
    required LlmService llm,
    required bool Function() isCancelled,
    NovelParams params = const NovelParams(),
    NovelRecallProvider? recall,
    void Function(NovelSchedulerEvent event)? onEvent,
  })  : _db = db,
        _isCancelled = isCancelled,
        _params = params,
        _recall = recall,
        _onEvent = onEvent {
    _mapPass = NovelMapPass(
        db: db,
        llm: llm,
        batchChapters: _params.mapBatchChapters,
        isCancelled: _isCancelled,
        onDegraded: (d) => _onEvent?.call(NovelSchedulerEvent('degraded', d)),
        onProgress: (done, total) => _onEvent
            ?.call(NovelSchedulerEvent('progress', '地图 $done/$total 章')));
    _digestPass = NovelDigestPass(
        db: db,
        llm: llm,
        batchChapters: _params.digestBatchChapters,
        isCancelled: _isCancelled,
        onDegraded: (d) => _onEvent?.call(NovelSchedulerEvent('degraded', d)));
    _annotatePass = NovelAnnotatePass(
        db: db,
        llm: llm,
        batchChapters: _params.annotateBatchChapters,
        recall: recall,
        isCancelled: _isCancelled,
        onDegraded: (d) => _onEvent?.call(NovelSchedulerEvent('degraded', d)),
        onProgress: (done, total) {
          _onEvent?.call(NovelSchedulerEvent('progress', '批注 $done/$total 章'));
          final pid = _currentProjectId;
          if (pid != null) unawaited(_updateBadge(pid, done));
        });
  }

  static const _pollInterval = Duration(milliseconds: 100);

  late final NovelMapPass _mapPass;
  late final NovelDigestPass _digestPass;
  late final NovelAnnotatePass _annotatePass;
  final AppDatabase _db;
  final bool Function() _isCancelled;
  final NovelParams _params;
  final NovelRecallProvider? _recall;
  final void Function(NovelSchedulerEvent event)? _onEvent;
  int? _currentProjectId;
  bool _stopped = false; // 主泳道退出后置位，地图泳道据此收尾

  Future<void> run(int projectId) async {
    _currentProjectId = projectId;
    final total = await _chapterCount(projectId);
    if (total == 0) {
      await _finish(projectId);
      return;
    }
    final burstEnd = math.min(_params.initialBurstChapters, total);
    // ① 首屏冲刺
    await _advanceTo(projectId, 'map', _mapPass.step, burstEnd);
    await _recall?.ensureIndexed(projectId); // 摘要就绪即向量化（可选层）
    await _advanceTo(projectId, 'digest', _digestPass.step, burstEnd);
    await _advanceTo(projectId, 'annotate', _annotatePass.step, burstEnd);
    _onEvent?.call(
        NovelSchedulerEvent('burst', '前 $burstEnd 章批注已就绪，可以开始阅读'));
    // ② 跟随模式：地图泳道 + 主泳道并发（LLM 调用经全局信号量交错）
    final mapLaneError = <Object>[];
    final mapLane = _mapLane(projectId, total)
        .catchError((Object e) => mapLaneError.add(e));
    try {
      await _followLane(projectId, total, mapLaneError);
    } catch (_) {
      _stopped = true; // 主泳道失败/取消 → 停掉地图泳道，别让它继续消耗调用
      // 等地图泳道收尾再抛：在途的地图 LLM 调用（可达数十秒）结束后引擎才
      // 落 FAILED/unbusy，否则用户立刻 retry/重批会与存活的旧泳道并发
      // （重复调用 + characters 查改写竞态重复行 + FAILED 后继续刷事件）。
      await mapLane;
      rethrow;
    }
    await mapLane;
    if (mapLaneError.isNotEmpty) throw mapLaneError.first; // 末尾竞态取消不吞掉
    await _finish(projectId);
  }

  Future<void> _advanceTo(int projectId, String stage,
      Future<int> Function(int) step, int target) async {
    try {
      var zeroStreak = 0;
      while (true) {
        if (_isCancelled()) throw const PipelineCancelled();
        if (await _targetDone(projectId, stage, target)) return;
        final n = await step(projectId);
        if (n == 0) {
          // 冲刺阶段上游已就绪，0 只能是持续无进展（如模型恒漏同一章）→ 熔断
          zeroStreak++;
          if (zeroStreak >= 10) {
            throw PipelineStageException(stage, '连续 10 批无法推进');
          }
          await Future.delayed(_pollInterval);
          continue;
        }
        zeroStreak = 0;
      }
    } on PipelineCancelled {
      rethrow;
    } on PipelineStageException {
      rethrow;
    } catch (e) {
      throw PipelineStageException(stage, e); // LlmException 等按当前阶段落盘
    }
  }

  /// 目标判定用"第 target-1 章的完成标志"而非计数——计数会被批超界/模型
  /// 漏章形成的"洞"骗过（count 够但窗口内有洞 → 假就绪）。
  ///
  /// digest 目标与快照趟选批口径对齐（`digestBefore != null || annotDone`）：
  /// 老项目回填态（0..k-1 章 annotDone=1 而 digest_before=null）若只认
  /// digest_before，目标章永远无法满足 → 冲刺 digest 每轮白烧 burst 范围外的
  /// 全书快照后熔断。新项目零影响：被批注章必有快照。
  Future<bool> _targetDone(int projectId, String stage, int target) async {
    final ch = await (_db.select(_db.chapters)
          ..where((t) => t.projectId.equals(projectId) &
              t.idx.equals(target - 1)))
        .getSingleOrNull();
    if (ch == null) return true; // 书比 target 短
    return switch (stage) {
      'map' => ch.mapDone,
      'digest' => ch.digestBefore != null || ch.annotDone,
      _ => ch.annotDone,
    };
  }

  Future<void> _mapLane(int projectId, int total) async {
    try {
      while (true) {
        if (_isCancelled() || _stopped) {
          throw const PipelineCancelled();
        }
        final firstUnmapped =
            await _firstIdx(projectId, (c) => c.mapDone.not());
        if (firstUnmapped == null) break; // 全书地图完成
        final c = await _counts(projectId);
        if (firstUnmapped >=
            math.min(c.annotDone + _params.mapLeadChapters, total)) {
          await Future.delayed(_pollInterval); // 领先足够，让路给批注
          continue;
        }
        final n = await _mapPass.step(projectId);
        if (n == 0) {
          throw PipelineStageException('map', '地图趟推进返回 0（全书未完成）');
        }
        await _recall?.ensureIndexed(projectId); // 新摘要随到随向量化
      }
      await _setMilestone(
          projectId, ProjectStatus.mapped, detail: '地图趟全书完成');
    } on PipelineCancelled {
      rethrow;
    } on PipelineStageException {
      rethrow;
    } catch (e) {
      throw PipelineStageException('map', e);
    }
  }

  Future<void> _followLane(
      int projectId, int total, List<Object> mapLaneError) async {
    try {
      var zeroStreak = 0;
      var lastUpstream = (mapDone: 0, digestReady: 0);
      while (true) {
        if (mapLaneError.isNotEmpty) throw mapLaneError.first;
        if (_isCancelled()) throw const PipelineCancelled();
        final c = await _counts(projectId);
        if (c.annotDone >= total) return;
        if (c.digestReady < c.annotDone + 1) {
          int n;
          try {
            n = await _digestPass.step(projectId); // 快照追赶（就绪 ≥ 批注完成 + 1）
          } on PipelineCancelled {
            rethrow;
          } on PipelineStageException {
            rethrow;
          } catch (e) {
            throw PipelineStageException('digest', e);
          }
          // 上游地图未跟上（批为空）返回 0：让路等待。不能裸 continue——
          // drift 内存库查询经微任务完成，纯微任务循环会饿死事件循环定时器，
          // 地图泳道的 poll 等待永远无法醒来（热循环 100% CPU）。
          // 此分支不加熔断：n==0 只会持续到地图前沿跟上；地图泳道若彻底
          // 卡死（n==0 即抛 PipelineStageException(map) / 取消），mapLaneError
          // 在本循环开头传导终结调度器，digest 无限等待被其失败路径兜住，
          // 不会静默挂死。
          if (n == 0) await Future.delayed(_pollInterval);
          continue;
        }
        final n = await _annotatePass.step(projectId);
        if (n == 0) {
          // 上游（地图泳道）有进展时不计零进度——批注只是在等洞被补上
          if (c.mapDone == lastUpstream.mapDone &&
              c.digestReady == lastUpstream.digestReady) {
            zeroStreak++;
            if (zeroStreak >= 3) {
              throw PipelineStageException('annotate', '连续 3 批未能产出批注且上游停滞');
            }
          } else {
            zeroStreak = 0;
          }
          lastUpstream = (mapDone: c.mapDone, digestReady: c.digestReady);
          await Future.delayed(_pollInterval);
          continue;
        }
        zeroStreak = 0;
      }
    } on PipelineCancelled {
      rethrow;
    } on PipelineStageException {
      rethrow;
    } catch (e) {
      throw PipelineStageException('annotate', e);
    }
  }

  /// 首个满足谓词的章号（null = 无）。谓词下沉到 SQL + LIMIT 1：
  /// 地图泳道每批都调用，禁止全表拉回内存逐行过滤。
  Future<int?> _firstIdx(
      int projectId, Expression<bool> Function($ChaptersTable) predicate) async {
    final row = await (_db.select(_db.chapters)
          ..where((t) => t.projectId.equals(projectId) & predicate(t))
          ..orderBy([(c) => OrderingTerm.asc(c.idx)])
          ..limit(1))
        .getSingleOrNull();
    return row?.idx;
  }

  Future<void> _finish(int projectId) async {
    await _setMilestone(projectId, ProjectStatus.commentaryDone,
        detail: '批注全部完成');
    await _setMilestone(projectId, ProjectStatus.ready, detail: '全书就绪');
  }

  /// 里程碑只升不降；FAILED 视为重跑恢复，允许直接写目标状态。
  Future<void> _setMilestone(int projectId, ProjectStatus target,
      {String? detail}) async {
    final p = await (_db.select(_db.projects)
          ..where((t) => t.id.equals(projectId)))
        .getSingleOrNull();
    if (p == null) return;
    final cur = ProjectStatus.fromDb(p.status);
    const order = [
      ProjectStatus.imported,
      ProjectStatus.mapped,
      ProjectStatus.commentaryDone,
      ProjectStatus.ready,
    ];
    final upgrade = cur == ProjectStatus.failed ||
        order.indexOf(cur) < order.indexOf(target);
    if (!upgrade) return;
    await (_db.update(_db.projects)..where((t) => t.id.equals(projectId)))
        .write(ProjectsCompanion(
            status: Value(target.db),
            failedStage: const Value(null),
            updatedAt: Value(DateTime.now())));
    _onEvent?.call(
        NovelSchedulerEvent('milestone', detail ?? target.db, status: target));
  }

  /// 库页徽章计数（denormalized 到 meta，避免列表页逐卡查库）。
  /// 读改写必须包事务：digest 趟对 meta.digest 的写在 LLM 调用后的事务里，
  /// badge 的读→写若裸奔且穿插其间，旧快照写回会覆盖刚写入的 meta.digest
  /// → 滚动摘要链断裂（drift 事务相互串行，包事务即互斥）。
  Future<void> _updateBadge(int projectId, int annotatedChapters) async {
    try {
      await _db.transaction(() async {
        final p = await (_db.select(_db.projects)
              ..where((t) => t.id.equals(projectId)))
            .getSingleOrNull();
        if (p == null) return;
        final meta = NovelMeta.fromJson(p.metaJson);
        if (meta.annotatedChapters == annotatedChapters) return;
        meta.annotatedChapters = annotatedChapters;
        await (_db.update(_db.projects)..where((t) => t.id.equals(projectId)))
            .write(ProjectsCompanion(metaJson: Value(meta.encode())));
      });
    } catch (_) {
      // 徽章计数失败不影响主线
    }
  }

  Future<int> _chapterCount(int projectId) async =>
      (await _counts(projectId)).total;

  /// 计数（热路径：主泳道/地图泳道每轮都调用）→ selectOnly 条件聚合单查询，
  /// 禁止全表拉回内存逐行过滤。SUM 借 CASE WHEN 归一 0/1，不用 FILTER 子句
  /// （老安卓系统 sqlite < 3.30 不支持）。digestReady 用"快照已满足"口径
  /// （digestBefore != null || annotDone）：与快照趟选批条件（!annotDone 才补
  /// 快照）对齐——回填老项目里已批注无快照的章不算"未就绪"，否则主泳道
  /// digest 闸门永远不满足：k 小 → 卡死空转（后续章永不批注），k 大 → 冲刺
  /// 目标永不满足、白烧全书快照后熔断。新项目零影响：被批注章必有快照。
  Future<_Counts> _counts(int projectId) async {
    final ch = _db.chapters;
    Expression<int> flag(Expression<bool> cond) => CaseWhenExpression(
        cases: [CaseWhen(cond, then: const Constant(1))],
        orElse: const Constant(0));
    final totalExp = countAll();
    final mapExp = flag(ch.mapDone).sum();
    final digestExp = flag(ch.digestBefore.isNotNull() | ch.annotDone).sum();
    final annotExp = flag(ch.annotDone).sum();
    final row = await (_db.selectOnly(ch)
          ..where(ch.projectId.equals(projectId))
          ..addColumns([totalExp, mapExp, digestExp, annotExp]))
        .getSingle();
    return (
      total: row.read(totalExp) ?? 0,
      mapDone: row.read(mapExp) ?? 0,
      digestReady: row.read(digestExp) ?? 0,
      annotDone: row.read(annotExp) ?? 0,
    );
  }
}
