/// Takip ekranı ve ebe paneli için seans istatistikleri.
library;

import '../exercises/library.dart';
import '../models/records.dart';

DateTime _day(DateTime d) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// Haftanın pazartesi gününü döndürür (yerel saat).
DateTime startOfWeek(DateTime d) {
  final day = _day(d);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

class ActivityStats {
  ActivityStats(List<ExerciseSession> sessions)
      : sessions = List.unmodifiable(
            [...sessions]..sort((a, b) => a.startedAt.compareTo(b.startedAt)));

  final List<ExerciseSession> sessions;

  /// Gün → o gün egzersizde geçirilen dakika.
  Map<DateTime, int> get minutesByDay {
    final m = <DateTime, int>{};
    for (final s in sessions) {
      final d = _day(s.startedAt);
      m[d] = (m[d] ?? 0) + s.durationSeconds;
    }
    return m.map((k, v) => MapEntry(k, (v / 60).round()));
  }

  Set<DateTime> get activeDays =>
      sessions.map((s) => _day(s.startedAt)).toSet();

  /// [weekStart] haftasındaki toplam dakika.
  int minutesInWeek(DateTime weekStart) {
    final start = startOfWeek(weekStart);
    final end = start.add(const Duration(days: 7));
    var sec = 0;
    for (final s in sessions) {
      final d = s.startedAt.toLocal();
      if (!d.isBefore(start) && d.isBefore(end)) sec += s.durationSeconds;
    }
    return (sec / 60).round();
  }

  /// Bugünden geriye son [count] haftanın dakikaları (eskiden yeniye).
  List<int> weeklyMinutes(DateTime now, {int count = 4}) => [
        for (var i = count - 1; i >= 0; i--)
          minutesInWeek(startOfWeek(now).subtract(Duration(days: 7 * i))),
      ];

  /// Bugün (veya dün) biten ardışık aktif gün sayısı.
  int streak(DateTime now) {
    final days = activeDays;
    var d = _day(now);
    if (!days.contains(d)) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (days.contains(d)) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// Kamera ile takip edilen seansların ortalama form puanı.
  int? get averageFormScore {
    final scores = sessions.map((s) => s.formScore).whereType<int>().toList();
    if (scores.isEmpty) return null;
    return (scores.reduce((a, b) => a + b) / scores.length).round();
  }

  int get totalWarnings => sessions.fold(0, (a, s) => a + s.totalWarnings);

  int get safetyStops => sessions
      .where((s) =>
          s.endReason == SessionEndReason.symptom ||
          s.endReason == SessionEndReason.heartRate)
      .length;
}

String _csvCell(Object? v) {
  if (v == null) return '';
  final s = v.toString();
  if (s.contains(RegExp(r'[",;\n]'))) return '"${s.replaceAll('"', '""')}"';
  return s;
}

/// Seansları araştırma analizi için CSV'ye dönüştürür.
///
/// [anonymousId] verilirse gebenin kimliği yerine bu değer yazılır.
String sessionsToCsv(List<ExerciseSession> sessions,
    {String Function(String patientId)? anonymousId}) {
  const header = [
    'katilimci',
    'seans_id',
    'egzersiz_id',
    'egzersiz',
    'baslangic',
    'bitis',
    'sure_sn',
    'gebelik_haftasi',
    'bitis_nedeni',
    'tekrar',
    'form_puani',
    'postur_uyari_sayisi',
    'uyari_detay',
    'nabiz_min',
    'nabiz_ort',
    'nabiz_maks',
    'hedef_ustu_sn',
    'rpe',
    'oncesi_belirti',
    'sonrasi_belirti',
  ];
  final rows = <List<Object?>>[header];
  for (final s in sessions) {
    final hr = s.heartRate;
    rows.add([
      anonymousId?.call(s.patientId) ?? s.patientId,
      s.id,
      s.exerciseId,
      exerciseById(s.exerciseId)?.name ?? '',
      s.startedAt.toUtc().toIso8601String(),
      s.endedAt.toUtc().toIso8601String(),
      s.durationSeconds,
      s.gestationalWeek,
      s.endReason.id,
      s.reps,
      s.formScore,
      s.totalWarnings,
      (s.violationCounts.entries.map((e) => '${e.key}:${e.value}').toList()
            ..sort())
          .join('|'),
      hr?.min,
      hr?.avg,
      hr?.max,
      hr?.secondsAboveZone,
      s.rpe,
      s.preCheck?.present.join('|'),
      s.postCheck?.present.join('|'),
    ]);
  }
  return rows.map((r) => r.map(_csvCell).join(',')).join('\n');
}
