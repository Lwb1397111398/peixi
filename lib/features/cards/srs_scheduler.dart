import 'dart:math';

/// 复习评分（Anki 四键）。
enum SrsGrade { again, hard, good, easy }

/// 单张卡片的调度状态（对应 knowledge_cards 的 SRS 列）。
class SrsState {
  const SrsState({
    this.ivlDays = 0,
    this.ease = 2.5,
    this.reps = 0,
    this.lapses = 0,
  });
  final double ivlDays;
  final double ease;
  final int reps;
  final int lapses;
}

/// 调度结果：新状态 + 下次到期时间。
class SrsSchedule {
  const SrsSchedule({
    required this.ivlDays,
    required this.ease,
    required this.reps,
    required this.lapses,
    required this.dueAt,
  });
  final double ivlDays;
  final double ease;
  final int reps;
  final int lapses;
  final DateTime dueAt;
}

/// SM-2 简化版（Anki 默认参数）。
/// - again：记错了。进度清零，10 分钟后重新进队列，ease 下调。
/// - hard：想起来了但费劲。间隔小步延长，ease 下调。
/// - good：常规回忆成功。新卡 1 天 → 二次 6 天 → 其后 ×ease。
/// - easy：毫不费力。跳跃式延长，ease 上调。
/// 间隔上限 1 年；ease 下限 1.3（与 Anki 一致）。
SrsSchedule scheduleCard(
  SrsState s,
  SrsGrade grade, {
  DateTime? now,
}) {
  now ??= DateTime.now();
  switch (grade) {
    case SrsGrade.again:
      return SrsSchedule(
        ivlDays: 0,
        ease: max(1.3, s.ease - 0.2),
        reps: 0,
        lapses: s.lapses + 1,
        dueAt: now.add(const Duration(minutes: 10)),
      );
    case SrsGrade.hard:
      final ivl = s.reps == 0 ? 0.5 : _cap(s.ivlDays * 1.2);
      return SrsSchedule(
        ivlDays: ivl,
        ease: max(1.3, s.ease - 0.15),
        reps: s.reps + 1,
        lapses: s.lapses,
        dueAt: now.add(_ivlToDuration(ivl)),
      );
    case SrsGrade.good:
      final ivl = s.reps == 0
          ? 1.0
          : s.reps == 1
              ? 6.0
              : _cap(s.ivlDays * s.ease);
      return SrsSchedule(
        ivlDays: ivl,
        ease: s.ease,
        reps: s.reps + 1,
        lapses: s.lapses,
        dueAt: now.add(_ivlToDuration(ivl)),
      );
    case SrsGrade.easy:
      final ivl = s.reps == 0 ? 3.0 : _cap(s.ivlDays * s.ease * 1.3);
      return SrsSchedule(
        ivlDays: ivl,
        ease: s.ease + 0.15,
        reps: s.reps + 1,
        lapses: s.lapses,
        dueAt: now.add(_ivlToDuration(ivl)),
      );
  }
}

double _cap(double days) => min(days, 365.0);

Duration _ivlToDuration(double days) =>
    Duration(minutes: (days * 24 * 60).round());

/// 到期判断：dueAt 为 null 表示新卡（永远可进复习队列）。
bool isDue(DateTime? dueAt, DateTime now) =>
    dueAt == null || !dueAt.isAfter(now);
