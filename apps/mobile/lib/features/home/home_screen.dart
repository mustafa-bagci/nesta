import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nesta_core/nesta_core.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../exercises/exercise_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = state.patient!;
    final ga = state.gestationalAge!;
    final program = state.todaysProgram;
    final done = state.completedToday();
    final firstName = p.profile.fullName.split(' ').first;
    final minutes = program.fold<int>(0, (a, e) => a + e.estimatedMinutes);
    final note = p.clearance.note;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Merhaba, $firstName',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('d MMMM EEEE', 'tr').format(state.now()),
                        style: const TextStyle(color: NestaColors.inkSoft),
                      ),
                    ],
                  ),
                ),
                const NestaLogo(size: 40, showName: false),
              ],
            ),
            if (state.repo.isDemo) ...[
              const SizedBox(height: 10),
              const Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  avatar: Icon(Icons.science_outlined, size: 18),
                  label: Text('Demo modu'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _WeekStrip(now: state.now(), activeDays: state.stats.activeDays),
            const SizedBox(height: 16),
            _PregnancyCard(ga: ga, dueDate: p.profile.estimatedDueDate),
            if (note != null && note.isNotEmpty) ...[
              const SizedBox(height: 12),
              InfoBanner(
                title: '${state.midwife?.displayName ?? 'Ebenizin'} notu',
                text: note,
                icon: Icons.chat_bubble_outline_rounded,
                color: NestaColors.primary,
                background: NestaColors.mintSoft,
              ),
            ],
            const SizedBox(height: 20),
            SectionTitle(
              'Bugünün Programı',
              trailing: Text(
                '${done.length}/${program.length} · ~$minutes dk',
                style: const TextStyle(color: NestaColors.inkSoft),
              ),
            ),
            for (final e in program)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ExerciseCard(
                  exercise: e,
                  completed: done.contains(e.id),
                  onTap: () => context.push('/exercise/${e.id}'),
                ),
              ),
            const SizedBox(height: 8),
            const InfoBanner.warning(
              title: 'Güvenliğiniz için',
              text:
                  'Kanama, düzenli ağrılı kasılma, sıvı gelmesi, göğüs ağrısı '
                  'veya bebek hareketlerinde azalma olursa egzersizi bırakın ve '
                  '${AppConfig.emergencyNumber}\'yi arayın.',
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.now, required this.activeDays});
  final DateTime now;
  final Set<DateTime> activeDays;

  static const _letters = ['P', 'S', 'Ç', 'P', 'C', 'C', 'P'];

  @override
  Widget build(BuildContext context) {
    final start = startOfWeek(now);
    final today = DateTime(now.year, now.month, now.day);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 7; i++)
          Builder(
            builder: (context) {
              final d = start.add(Duration(days: i));
              final isToday = d == today;
              final active = activeDays.contains(d);
              return Column(
                children: [
                  Text(
                    _letters[i],
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: NestaColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isToday
                          ? NestaColors.peach
                          : active
                          ? NestaColors.mint
                          : NestaColors.mintSoft,
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
                  const SizedBox(height: 4),
                  Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: active ? NestaColors.primary : Colors.transparent,
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _PregnancyCard extends StatelessWidget {
  const _PregnancyCard({required this.ga, required this.dueDate});
  final GestationalAge ga;
  final DateTime dueDate;

  @override
  Widget build(BuildContext context) {
    final progress = (ga.totalDays / 280).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [NestaColors.mint, Color(0xFFB8E3D6)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 7,
                  color: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.35),
                ),
                Text(
                  '${ga.weeks}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${ga.weeks}. hafta ${ga.days}. gün',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ga.trimester.label,
                  style: const TextStyle(color: Colors.white),
                ),
                Text(
                  'Tahmini doğum: ${DateFormat('d MMMM y', 'tr').format(dueDate.toLocal())}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
