/// 全局并发/频控闸门：所有 LLM 调用共用，防止压垮限速中转站。
class LlmGate {
  int maxConcurrent = 2;
  Duration minInterval = Duration.zero;
  DateTime _cooldownUntil = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastDispatch = DateTime.fromMillisecondsSinceEpoch(0);
  int _inFlight = 0;

  /// 429 触发的冷却时长策略（attempt 从 0 计）。测试可注入缩短。
  Duration Function(int attempt) cooldownFor =
      (attempt) => Duration(seconds: 5 + attempt * 5);

  /// 当前剩余冷却时长（未在冷却中为 Duration.zero）。
  Duration get cooldownRemaining {
    final now = DateTime.now();
    return _cooldownUntil.isAfter(now)
        ? _cooldownUntil.difference(now)
        : Duration.zero;
  }

  void updateLimits({int? maxConcurrent, Duration? minInterval}) {
    if (maxConcurrent != null && maxConcurrent >= 1) {
      this.maxConcurrent = maxConcurrent;
    }
    if (minInterval != null) this.minInterval = minInterval;
  }

  /// 429 等限流信号：全局冷却（在途请求不受影响，新请求延后）。
  void cooldown(Duration d) {
    final until = DateTime.now().add(d);
    if (until.isAfter(_cooldownUntil)) _cooldownUntil = until;
  }

  Future<void> acquire() async {
    while (true) {
      final now = DateTime.now();
      if (_inFlight < maxConcurrent && !now.isBefore(_cooldownUntil)) {
        final earliest = _lastDispatch.add(minInterval);
        if (now.isBefore(earliest)) {
          await Future.delayed(earliest.difference(now));
          continue;
        }
        _inFlight++;
        _lastDispatch = DateTime.now();
        return;
      }
      await Future.delayed(const Duration(milliseconds: 20));
    }
  }

  void release() {
    assert(_inFlight > 0, 'release 与 acquire 必须配对');
    _inFlight--;
  }
}
