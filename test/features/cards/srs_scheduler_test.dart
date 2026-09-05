import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/features/cards/srs_scheduler.dart';

void main() {
  final now = DateTime(2026, 9, 5, 12);

  test('新卡（reps=0）good：间隔 1 天，ease 不变', () {
    final s = scheduleCard(const SrsState(), SrsGrade.good, now: now);
    expect(s.ivlDays, 1.0);
    expect(s.ease, 2.5);
    expect(s.reps, 1);
    expect(s.dueAt, now.add(const Duration(days: 1)));
  });

  test('新卡 easy：间隔 3 天，ease 上调', () {
    final s = scheduleCard(const SrsState(), SrsGrade.easy, now: now);
    expect(s.ivlDays, 3.0);
    expect(s.ease, 2.65);
    expect(s.dueAt, now.add(const Duration(days: 3)));
  });

  test('新卡 hard：间隔半天，ease 下调', () {
    final s = scheduleCard(const SrsState(), SrsGrade.hard, now: now);
    expect(s.ivlDays, 0.5);
    expect(s.ease, 2.35);
    expect(s.dueAt, now.add(const Duration(hours: 12)));
  });

  test('二次 good：6 天；其后按 ease 倍增', () {
    final second = scheduleCard(
        const SrsState(ivlDays: 1, ease: 2.5, reps: 1), SrsGrade.good,
        now: now);
    expect(second.ivlDays, 6.0);
    final third = scheduleCard(
        SrsState(ivlDays: second.ivlDays, ease: 2.5, reps: 2), SrsGrade.good,
        now: now);
    expect(third.ivlDays, closeTo(15.0, 0.001)); // 6 × 2.5
  });

  test('again：进度清零、lapses+1、10 分钟后重现、ease 下调但不低于 1.3', () {
    final s = scheduleCard(
        const SrsState(ivlDays: 21, ease: 2.5, reps: 5), SrsGrade.again,
        now: now);
    expect(s.ivlDays, 0);
    expect(s.reps, 0);
    expect(s.lapses, 1);
    expect(s.ease, 2.3);
    expect(s.dueAt, now.add(const Duration(minutes: 10)));

    final floor = scheduleCard(
        const SrsState(ivlDays: 21, ease: 1.35, reps: 5), SrsGrade.again,
        now: now);
    expect(floor.ease, 1.3, reason: 'ease 下限 1.3');
  });

  test('成熟卡 hard：×1.2；easy：×ease×1.3 且 ease 上调', () {
    final h = scheduleCard(
        const SrsState(ivlDays: 10, ease: 2.5, reps: 4), SrsGrade.hard,
        now: now);
    expect(h.ivlDays, closeTo(12.0, 0.001));
    expect(h.ease, 2.35);

    final e = scheduleCard(
        const SrsState(ivlDays: 10, ease: 2.5, reps: 4), SrsGrade.easy,
        now: now);
    expect(e.ivlDays, closeTo(32.5, 0.001));
    expect(e.ease, 2.65);
  });

  test('间隔上限 1 年', () {
    final s = scheduleCard(
        const SrsState(ivlDays: 400, ease: 3.0, reps: 30), SrsGrade.easy,
        now: now);
    expect(s.ivlDays, 365.0);
  });

  test('isDue：null 视为新卡永远到期；未来时间未到期', () {
    expect(isDue(null, now), isTrue);
    expect(isDue(now.add(const Duration(days: 1)), now), isFalse);
    expect(isDue(now.subtract(const Duration(minutes: 1)), now), isTrue);
  });
}
