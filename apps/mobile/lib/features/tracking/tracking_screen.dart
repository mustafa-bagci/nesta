import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nesta_core/nesta_core.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Takip ekranı: aylık takvim, haftalık aktivite ve seans geçmişi.
class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final n = context.read<AppState>().now();
    _month = DateTime(n.year, n.month);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final stats = state.stats;
    final now = state.now();
    final weekly = stats.weeklyMinutes(now);
    return Scaffold(
      appBar: AppBar(title: const Text('TAKİP')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Row(
            children: [
              _tile(
                'Bu hafta',
                '${stats.minutesInWeek(now)} dk',
                Icons.calendar_view_week_rounded,
                NestaColors.mintSoft,
              ),
              const SizedBox(width: 10),
              _tile(
                'Seri',
                '${stats.streak(now)} gün',
                Icons.local_fire_department_outlined,
                NestaColors.peachSoft,
              ),
              const SizedBox(width: 10),
              _tile(
                'Form',
                stats.averageFormScore == null
                    ? '–'
                    : '%${stats.averageFormScore}',
                Icons.accessibility_new_rounded,
                NestaColors.lilacSoft,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: _MonthCalendar(
                month: _month,
                today: now,
                minutesByDay: stats.minutesByDay,
                onChange: (m) => setState(() => _month = m),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Haftalık Aktivite',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const Text(
                    'Son 4 hafta, toplam dakika',
                    style: TextStyle(color: NestaColors.inkSoft, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(height: 160, child: _WeeklyBars(minutes: weekly)),
                  const SizedBox(height: 8),
                  const Text(
                    'Genel öneri haftada 150 dakikadır; riskli gebelikte hedefinizi '
                    'ebeniz belirler.',
                    style: TextStyle(color: NestaColors.inkSoft, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SectionTitle(
            'Seans Geçmişi',
            trailing: Text(
              '${state.sessions.length} seans',
              style: const TextStyle(color: NestaColors.inkSoft),
            ),
          ),
          if (state.sessions.isEmpty)
            const InfoBanner(
              text:
                  'Henüz kayıtlı seansınız yok. İlk egzersizinizi '
                  'ana sayfadaki programdan başlatabilirsiniz.',
            ),
          for (final s in state.sessions.take(50)) _SessionTile(session: s),
        ],
      ),
    );
  }

  Widget _tile(String label, String value, IconData icon, Color bg) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: NestaColors.inkSoft),
          ),
        ],
      ),
    ),
  );
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.today,
    required this.minutesByDay,
    required this.onChange,
  });

  final DateTime month;
  final DateTime today;
  final Map<DateTime, int> minutesByDay;
  final ValueChanged<DateTime> onChange;

  static const _days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final offset = first.weekday - 1;
    final t = DateTime(today.year, today.month, today.day);
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Önceki ay',
              onPressed: () => onChange(DateTime(month.year, month.month - 1)),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                DateFormat('MMMM y', 'tr').format(month).toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Sonraki ay',
              onPressed: () => onChange(DateTime(month.year, month.month + 1)),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        Row(
          children: [
            for (final d in _days)
              Expanded(
                child: Text(
                  d,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: NestaColors.inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: offset + daysInMonth,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.8,
          ),
          itemBuilder: (context, i) {
            if (i < offset) return const SizedBox();
            final d = DateTime(month.year, month.month, i - offset + 1);
            final mins = minutesByDay[d];
            final isToday = d == t;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isToday ? NestaColors.peach : null,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${d.day}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isToday ? Colors.white : NestaColors.ink,
                    ),
                  ),
                ),
                Icon(
                  Icons.check_rounded,
                  size: 12,
                  color: mins != null
                      ? NestaColors.primary
                      : Colors.transparent,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _WeeklyBars extends StatelessWidget {
  const _WeeklyBars({required this.minutes});
  final List<int> minutes;

  @override
  Widget build(BuildContext context) {
    final maxV = [...minutes, 150].reduce((a, b) => a > b ? a : b).toDouble();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < minutes.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${minutes[i]} dk',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: FractionallySizedBox(
                      heightFactor: (minutes[i] / maxV).clamp(0.03, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [NestaColors.peach, NestaColors.mint],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    i == minutes.length - 1 ? 'Bu hafta' : 'Hafta ${i + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: NestaColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});
  final ExerciseSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final e = exerciseById(s.exerciseId);
    final colors = NestaColors.forKey(e?.colorKey ?? 'mint');
    final safety =
        s.endReason == SessionEndReason.symptom ||
        s.endReason == SessionEndReason.heartRate;
    final details = [
      formatDuration(s.durationSeconds),
      if (s.reps > 0) '${s.reps} tekrar',
      if (s.formScore != null) 'form %${s.formScore}',
      if (s.heartRate != null) 'nabız ort. ${s.heartRate!.avg}',
      if (s.rpe != null) 'zorlanma ${s.rpe}',
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: safety ? NestaColors.dangerSoft : colors.$2,
          child: Icon(
            safety ? Icons.warning_amber_rounded : Icons.check_rounded,
            color: safety ? NestaColors.danger : colors.$1,
          ),
        ),
        title: Text(
          e?.name ?? s.exerciseId,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${DateFormat('d MMM, HH:mm', 'tr').format(s.startedAt.toLocal())}\n$details'
          '${safety ? '\n${s.endReason.label}' : ''}',
        ),
        isThreeLine: true,
      ),
    );
  }
}
