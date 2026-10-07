import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nesta_core/nesta_core.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'safety_screen.dart';
import 'symptom_checklist.dart';

/// Seans sonu: özet, algılanan zorlanma (Borg) ve belirti sorgusu.
class SessionSummaryScreen extends StatefulWidget {
  const SessionSummaryScreen({super.key, required this.session});
  final ExerciseSession session;

  @override
  State<SessionSummaryScreen> createState() => _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends State<SessionSummaryScreen> {
  int? _rpe;
  Set<String> _symptoms = {};
  bool _hasSymptoms = false;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final check = SymptomCheck(
      present: _symptoms,
      checkedAt: state.now().toUtc(),
    );
    final s = widget.session.copyWith(
      rpe: _rpe,
      postCheck: check,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    await state.saveSession(s);
    final exercise = exerciseById(s.exerciseId);
    if (!check.isClear) {
      await state.reportSymptoms(
        check,
        AlertType.symptomAfterSession,
        exerciseName: exercise?.name,
        sessionId: s.id,
      );
      router.go(
        '/safety',
        extra: SafetyArgs(reason: SafetyReason.symptom, check: check),
      );
      return;
    }
    messenger.showSnackBar(const SnackBar(content: Text('Seans kaydedildi.')));
    router.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final e = exerciseById(s.exerciseId);
    final hr = s.heartRate;
    final completed = s.endReason == SessionEndReason.completed;
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SEANS ÖZETİ'),
          automaticallyImplyLeading: false,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Icon(
              completed
                  ? Icons.emoji_events_rounded
                  : Icons.check_circle_outline,
              size: 64,
              color: completed ? NestaColors.sand : NestaColors.mint,
            ),
            const SizedBox(height: 8),
            Text(
              completed ? 'Tebrikler!' : 'Seans kaydedilecek',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              e?.name ?? s.exerciseId,
              textAlign: TextAlign.center,
              style: const TextStyle(color: NestaColors.inkSoft),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.7,
              children: [
                _stat(
                  'Süre',
                  formatDuration(s.durationSeconds),
                  Icons.timer_outlined,
                  NestaColors.mintSoft,
                ),
                _stat(
                  'Tekrar',
                  '${s.reps}',
                  Icons.repeat_rounded,
                  NestaColors.peachSoft,
                ),
                _stat(
                  'Form puanı',
                  s.formScore == null ? '–' : '%${s.formScore}',
                  Icons.accessibility_new_rounded,
                  NestaColors.lilacSoft,
                ),
                _stat(
                  'Nabız (ort/maks)',
                  hr == null ? '–' : '${hr.avg}/${hr.max}',
                  Icons.favorite_border_rounded,
                  NestaColors.skySoft,
                ),
              ],
            ),
            if (s.violationCounts.isNotEmpty) ...[
              const SizedBox(height: 16),
              const SectionTitle('Postür uyarıları'),
              for (final v in s.violationCounts.entries)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.record_voice_over_outlined,
                    color: NestaColors.peach,
                  ),
                  title: Text(e?.ruleLabel(v.key) ?? v.key),
                  trailing: Text(
                    '${v.value} kez',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            const SectionTitle('Ne kadar zorlandınız?'),
            const Text(
              'Borg algılanan zorlanma ölçeği (6–20). Gebelikte hedef '
              '12–14 arasıdır: "biraz zor".',
              style: TextStyle(color: NestaColors.inkSoft, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in borgScale.entries)
                  ChoiceChip(
                    label: Text('${entry.key}'),
                    selected: _rpe == entry.key,
                    selectedColor: isModerateRpe(entry.key)
                        ? NestaColors.mint
                        : entry.key > 14
                        ? NestaColors.peach
                        : NestaColors.skySoft,
                    onSelected: (_) => setState(() => _rpe = entry.key),
                  ),
              ],
            ),
            if (_rpe != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  borgScale[_rpe]!,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            if (_rpe != null && _rpe! > 14)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: InfoBanner(
                  text:
                      'Zorlanmanız hedefin üzerinde. Bir sonraki seansta '
                      'tempoyu düşürün veya daha az tekrar yapın.',
                ),
              ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _hasSymptoms,
              onChanged: (v) => setState(() {
                _hasSymptoms = v;
                if (!v) _symptoms = {};
              }),
              title: const Text('Egzersizden sonra rahatsızlık hissettim'),
            ),
            if (_hasSymptoms)
              SymptomChecklist(
                selected: _symptoms,
                onChanged: (v) => setState(() => _symptoms = v),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Not (isteğe bağlı)',
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomAction(
          child: BusyButton(label: 'KAYDET', onPressed: _save),
        ),
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color bg) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(icon, color: NestaColors.ink),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: NestaColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
