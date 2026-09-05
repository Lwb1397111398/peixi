import 'dart:async';

/// 串行任务队列：同一时刻只推进一个项目的管线。
///
/// 批量导入整季会一口气入队 N 个项目；若无节流，多个 ffmpeg 会话、
/// 本地 ASR isolate 与 LLM 请求会同时压满资源，且 FFmpegKit.cancel()
/// 是全局中止、一次取消会误杀所有正在抽取的会话。串行化后这些假设
/// 重新成立（引擎自身仍保留 per-project 防并发作为第二道保险）。
class PipelineQueue {
  final _items = <_Item>[];
  final _skipped = <int>{};
  bool _draining = false;
  Future<void> _tail = Future.value();

  /// 入队一个管线任务。任务应在内部把失败落盘（引擎约定），
  /// 此处兜底捕获以保证后续任务不受影响。
  void add(int projectId, Future<void> Function() task) {
    _items.add(_Item(projectId, task));
    unawaited(_drain());
  }

  /// 取消尚未开始的排队任务；正在运行的项目交给引擎协作式取消。
  void cancelPending(int projectId) {
    _skipped.add(projectId);
    _items.removeWhere((i) => i.projectId == projectId);
  }

  bool get isIdle => !_draining && _items.isEmpty;

  int get pendingCount => _items.length;

  /// 等当前已入队任务全部执行完（测试用：确保落盘完成再关闭数据库）。
  Future<void> waitIdle() => _tail;

  Future<void> _drain() {
    if (_draining) return _tail;
    _draining = true;
    _tail = Future<void>(() async {
      try {
        while (_items.isNotEmpty) {
          final item = _items.removeAt(0);
          if (_skipped.remove(item.projectId)) continue;
          try {
            await item.task();
          } catch (_) {
            // 引擎内部已把失败写入 projects.status；这里只保证队列不断流
          }
        }
      } finally {
        _draining = false;
      }
    });
    return _tail;
  }
}

class _Item {
  const _Item(this.projectId, this.task);
  final int projectId;
  final Future<void> Function() task;
}
