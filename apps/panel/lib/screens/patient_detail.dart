import 'package:flutter/material.dart';
import 'package:nesta_core/nesta_core.dart';
import 'package:provider/provider.dart';

import '../panel_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Gebe ayrıntısı: profil, tarama, egzersiz onayı, seanslar ve uyarılar.
class PatientDetailScreen extends StatelessWidget {
  const PatientDetailScreen({super.key, required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PanelState>();
    final p = state.patient(patientId);
    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState('Gebe bulunamadı veya artık size bağlı değil.'),
      );
    }
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final left = [
      _ProfileCard(patient: p),
      const SizedBox(height: 16),
      _ClearanceCard(patient: p),
      const SizedBox(height: 16),
      _ScreeningCard(patient: p),
    ];
    final right = [
      _ActivityCard(patient: p),
      const SizedBox(height: 16),
      _PatientAlerts(patient: p),
      const SizedBox(height: 16),
      _SessionsCard(patient: p),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(p.profile.fullName)),
      body: SelectionArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1300),
            child: wide
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: Column(children: left)),
                        const SizedBox(width: 16),
                        Expanded(flex: 3, child: Column(children: right)),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [...left, const SizedBox(height: 16), ...right],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.patient});
  final PatientRecord patient;

  @override
  Widget build(BuildContext context) {
    final now = context.read<PanelState>().now();
    final pr = patient.profile;
    final ga = pr.gestationalAgeAt(now);
    final bmi = pr.prePregnancyBmi;
    final zone = pr.takesBetaBlocker
        ? null
        : HeartRateZone.forProfile(age: pr.ageAt(now), bmi: bmi);
    Widget row(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(k, style: const TextStyle(color: PanelColors.inkSoft)),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return SectionCard(
      title: 'Gebe bilgileri',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row('Yaş', '${pr.ageAt(now)}'),
          row('Gebelik haftası', '${ga.label} (${ga.trimester.label})'),
          row('Tahmini doğum', dateFmt.format(pr.estimatedDueDate)),
          if (bmi != null) row('Gebelik öncesi BKİ', bmi.toStringAsFixed(1)),
          row('Telefon', pr.phone ?? '–'),
          row(
            'Nabız takibi',
            zone == null
                ? 'Konuşma testi (nabzı etkileyen ilaç)'
                : 'Hedef $zone',
          ),
          row(
            'Araştırma onamı',
            (patient.consent?.researchParticipation ?? false)
                ? 'Var'
                : 'Yok (veri dışa aktarılmaz)',
          ),
          const SizedBox(height: 10),
          const Text(
            'Risk faktörleri',
            style: TextStyle(color: PanelColors.inkSoft),
          ),
          const SizedBox(height: 6),
          pr.riskFactors.isEmpty
              ? const Text('Belirtilmedi')
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final r in pr.riskFactors)
                      Chip(
                        label: Text(r.label),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
          if (pr.otherRiskNote != null) ...[
            const SizedBox(height: 6),
            Text('Not: ${pr.otherRiskNote}'),
          ],
        ],
      ),
    );
  }
}

class _ClearanceCard extends StatefulWidget {
  const _ClearanceCard({required this.patient});
  final PatientRecord patient;

  @override
  State<_ClearanceCard> createState() => _ClearanceCardState();
}

class _ClearanceCardState extends State<_ClearanceCard> {
  late final TextEditingController _note = TextEditingController(
    text: widget.patient.clearance.note ?? '',
  );
  late Set<String> _disabled = {...widget.patient.clearance.disabledExercises};
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _decide(bool approve) async {
    final state = context.read<PanelState>();
    final messenger = ScaffoldMessenger.of(context);
    if (approve &&
        widget.patient.screening?.outcome == ScreeningOutcome.ineligible) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Mutlak kontrendikasyon'),
          content: const Text(
            'Tarama formunda mutlak kontrendikasyon işaretlenmiş. '
            'Uygulama bu durumda egzersiz programını açmaz. Gebe taramayı '
            'güncellemedikçe onayınız uygulanmayacaktır.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yine de kaydet'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _busy = true);
    try {
      await state.decide(
        widget.patient,
        approve: approve,
        note: _note.text,
        disabled: _disabled,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            approve ? 'Egzersiz programı onaylandı.' : 'Karar kaydedildi.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: PanelColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    final t = p.profile
        .gestationalAgeAt(context.read<PanelState>().now())
        .trimester;
    return SectionCard(
      title: 'Egzersiz onayı',
      action: ClearanceChip(p.clearance.status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.clearance.decidedAt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Son karar: ${dateTimeFmt.format(p.clearance.decidedAt!.toLocal())}',
                style: const TextStyle(color: PanelColors.inkSoft),
              ),
            ),
          TextField(
            controller: _note,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Gebeye not',
              hintText: 'Ör. Haftada 3 gün, seans başına 20 dakikayı geçmeyin.',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Bu gebe için kapatılacak egzersizler',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          for (final e in exerciseLibrary)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _disabled.contains(e.id),
              onChanged: (v) => setState(() {
                _disabled = {..._disabled};
                v == true ? _disabled.add(e.id) : _disabled.remove(e.id);
              }),
              title: Text(e.name),
              subtitle: e.allowedIn(t)
                  ? null
                  : Text(
                      '${t.label} için zaten önerilmez',
                      style: const TextStyle(fontSize: 12),
                    ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : () => _decide(true),
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  p.clearance.isApproved ? 'Onayı güncelle' : 'Onayla',
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: PanelColors.danger,
                ),
                onPressed: _busy ? null : () => _decide(false),
                icon: const Icon(Icons.block_rounded),
                label: const Text('Egzersiz önerme'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScreeningCard extends StatelessWidget {
  const _ScreeningCard({required this.patient});
  final PatientRecord patient;

  @override
  Widget build(BuildContext context) {
    final s = patient.screening;
    if (s == null) {
      return const SectionCard(
        title: 'Kontrendikasyon taraması',
        child: Text('Gebe taramayı henüz doldurmadı.'),
      );
    }
    final positives = [...s.positiveAbsolute, ...s.positiveRelative];
    return SectionCard(
      title: 'Kontrendikasyon taraması',
      action: ScreeningChip(s.outcome),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dolduruldu: ${dateTimeFmt.format(s.completedAt.toLocal())}',
            style: const TextStyle(color: PanelColors.inkSoft),
          ),
          const SizedBox(height: 8),
          if (positives.isEmpty)
            const Text('Tüm sorulara "Hayır" yanıtı verildi.')
          else
            for (final q in positives)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.error_outline_rounded,
                  color: q.level == ContraindicationLevel.absolute
                      ? PanelColors.danger
                      : PanelColors.warning,
                ),
                title: Text(q.text),
                subtitle: Text(
                  q.level == ContraindicationLevel.absolute
                      ? 'Mutlak kontrendikasyon'
                      : 'Göreceli kontrendikasyon',
                ),
              ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Tüm yanıtlar'),
            children: [
              for (final q in allScreeningQuestions)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(q.text),
                  trailing: Text(
                    s.answers[q.id] == true ? 'Evet' : 'Hayır',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: s.answers[q.id] == true
                          ? PanelColors.danger
                          : PanelColors.inkSoft,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.patient});
  final PatientRecord patient;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PanelState>();
    final sessions = state.sessionsOf(patient.uid);
    final stats = ActivityStats(sessions);
    final now = state.now();
    final weekly = stats.weeklyMinutes(now, count: 6);
    final rpes = sessions.map((s) => s.rpe).whereType<int>().toList();
    final hrs = sessions.map((s) => s.heartRate?.avg).whereType<int>().toList();
    String avg(List<int> l) => l.isEmpty
        ? '–'
        : (l.reduce((a, b) => a + b) / l.length).toStringAsFixed(1);
    Widget metric(String label, String value) => Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PanelColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: const TextStyle(color: PanelColors.inkSoft, fontSize: 12),
          ),
        ],
      ),
    );
    return SectionCard(
      title: 'Aktivite',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              metric('Toplam seans', '${sessions.length}'),
              metric('Bu hafta (dk)', '${stats.minutesInWeek(now)}'),
              metric(
                'Ort. form puanı',
                stats.averageFormScore == null
                    ? '–'
                    : '%${stats.averageFormScore}',
              ),
              metric('Ort. zorlanma (RPE)', avg(rpes)),
              metric('Ort. nabız', avg(hrs)),
              metric('Güvenlik durdurma', '${stats.safetyStops}'),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Haftalık dakika (son 6 hafta)',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          BarChart(
            values: weekly,
            labels: [
              for (var i = 5; i >= 0; i--) i == 0 ? 'Bu hafta' : '$i hf önce',
            ],
            goal: 150,
          ),
        ],
      ),
    );
  }
}

class _PatientAlerts extends StatelessWidget {
  const _PatientAlerts({required this.patient});
  final PatientRecord patient;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PanelState>();
    final alerts = state.alerts
        .where((a) => a.patientId == patient.uid)
        .toList();
    return SectionCard(
      title: 'Uyarılar',
      child: alerts.isEmpty
          ? const EmptyState(
              'Bu gebe için uyarı yok.',
              icon: Icons.check_circle_outline,
            )
          : Column(
              children: [
                for (final a in alerts)
                  AlertTile(
                    alert: a,
                    now: state.now(),
                    onAcknowledge: () => state.acknowledge(a),
                  ),
              ],
            ),
    );
  }
}

class _SessionsCard extends StatelessWidget {
  const _SessionsCard({required this.patient});
  final PatientRecord patient;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PanelState>();
    final sessions = state.sessionsOf(patient.uid);
    if (sessions.isEmpty) {
      return const SectionCard(
        title: 'Seanslar',
        child: EmptyState('Henüz kayıtlı seans yok.'),
      );
    }
    return SectionCard(
      title: 'Seanslar (${sessions.length})',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 18,
          headingTextStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            color: PanelColors.ink,
          ),
          columns: const [
            DataColumn(label: Text('Tarih')),
            DataColumn(label: Text('Egzersiz')),
            DataColumn(label: Text('Süre'), numeric: true),
            DataColumn(label: Text('Tekrar'), numeric: true),
            DataColumn(label: Text('Form'), numeric: true),
            DataColumn(label: Text('Uyarı'), numeric: true),
            DataColumn(label: Text('Nabız ort/maks')),
            DataColumn(label: Text('RPE'), numeric: true),
            DataColumn(label: Text('Sonuç')),
          ],
          rows: [
            for (final s in sessions.take(100))
              DataRow(
                color: WidgetStatePropertyAll(
                  s.endReason == SessionEndReason.heartRate ||
                          s.endReason == SessionEndReason.symptom
                      ? PanelColors.dangerSoft
                      : null,
                ),
                cells: [
                  DataCell(Text(dateTimeFmt.format(s.startedAt.toLocal()))),
                  DataCell(
                    Text(exerciseById(s.exerciseId)?.name ?? s.exerciseId),
                  ),
                  DataCell(
                    Text(
                      '${s.durationSeconds ~/ 60}:${(s.durationSeconds % 60).toString().padLeft(2, '0')}',
                    ),
                  ),
                  DataCell(Text(s.reps == 0 ? '–' : '${s.reps}')),
                  DataCell(Text(s.formScore == null ? '–' : '%${s.formScore}')),
                  DataCell(
                    Tooltip(
                      message: s.violationCounts.entries
                          .map(
                            (e) =>
                                '${exerciseById(s.exerciseId)?.ruleLabel(e.key) ?? e.key}: ${e.value}',
                          )
                          .join('\n'),
                      child: Text('${s.totalWarnings}'),
                    ),
                  ),
                  DataCell(
                    Text(
                      s.heartRate == null
                          ? '–'
                          : '${s.heartRate!.avg}/${s.heartRate!.max}',
                    ),
                  ),
                  DataCell(Text(s.rpe?.toString() ?? '–')),
                  DataCell(Text(s.endReason.label)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
