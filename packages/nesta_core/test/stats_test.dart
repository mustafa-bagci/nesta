import 'package:nesta_core/nesta_core.dart';
import 'package:test/test.dart';

ExerciseSession _s(String id, DateTime start, int minutes,
        {int? form,
        Map<String, int> v = const {},
        SessionEndReason end = SessionEndReason.completed}) =>
    ExerciseSession(
      id: id,
      patientId: 'u1',
      exerciseId: 'kedi_inek',
      startedAt: start,
      endedAt: start.add(Duration(minutes: minutes)),
      endReason: end,
      gestationalWeek: 22,
      formScore: form,
      violationCounts: v,
    );

void main() {
  final now = DateTime(2026, 10, 7, 18); // Çarşamba
  final sessions = [
    _s('a', DateTime(2026, 10, 7, 9), 10, form: 90),
    _s('b', DateTime(2026, 10, 6, 9), 15, form: 70, v: {'x': 2}),
    _s('c', DateTime(2026, 10, 5, 9), 5, end: SessionEndReason.heartRate),
    _s('d', DateTime(2026, 9, 30, 9), 20),
  ];
  final stats = ActivityStats(sessions);

  test('haftanın başlangıcı pazartesidir', () {
    expect(startOfWeek(now), DateTime(2026, 10, 5));
  });

  test('haftalık dakikalar', () {
    expect(stats.minutesInWeek(now), 30);
    expect(stats.weeklyMinutes(now, count: 2), [20, 30]);
  });

  test('ardışık gün serisi', () {
    expect(stats.streak(now), 3);
    expect(stats.streak(DateTime(2026, 10, 8, 8)), 3, reason: 'dün biten seri');
    expect(stats.streak(DateTime(2026, 10, 10)), 0);
  });

  test('ortalama form, uyarı ve güvenlik durdurmaları', () {
    expect(stats.averageFormScore, 80);
    expect(stats.totalWarnings, 2);
    expect(stats.safetyStops, 1);
  });

  test('CSV başlık, satır sayısı ve kaçış', () {
    final csv = sessionsToCsv([..._withNote()], anonymousId: (id) => 'P-001');
    final lines = csv.split('\n');
    expect(lines.first, startsWith('katilimci,seans_id'));
    expect(lines.length, 2);
    expect(lines[1], startsWith('P-001,S00001,kedi_inek,Kedi-İnek Gevşeme'));
  });

  test('CSV özel karakterleri tırnaklar', () {
    final csv = sessionsToCsv([
      ExerciseSession(
        id: 'q"1,2',
        patientId: 'u',
        exerciseId: 'yok',
        startedAt: DateTime.utc(2026),
        endedAt: DateTime.utc(2026),
        endReason: SessionEndReason.completed,
        gestationalWeek: 1,
      )
    ]);
    expect(csv.split('\n')[1], contains('"q""1,2"'));
  });
}

List<ExerciseSession> _withNote() =>
    [_s('n1', DateTime.utc(2026, 10, 7, 9), 3)];
