import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nesta_core/nesta_core.dart';
import 'package:provider/provider.dart';

import '../panel_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/download.dart';
import 'patient_detail.dart';

enum PanelSection {
  overview('Genel Bakış', Icons.dashboard_outlined),
  patients('Gebeler', Icons.pregnant_woman_rounded),
  alerts('Uyarılar', Icons.notifications_outlined),
  research('Araştırma Verisi', Icons.table_chart_outlined),
  account('Hesap', Icons.badge_outlined);

  const PanelSection(this.label, this.icon);
  final String label;
  final IconData icon;
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  PanelSection _section = PanelSection.overview;

  void go(PanelSection s) => setState(() => _section = s);

  void openPatient(String id) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => PatientDetailScreen(patientId: id)),
  );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PanelState>();
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final openCount = state.openAlerts.length;

    Widget icon(PanelSection s, {bool selected = false}) {
      final i = Icon(s.icon);
      if (s == PanelSection.alerts && openCount > 0) {
        return Badge(label: Text('$openCount'), child: i);
      }
      return i;
    }

    final body = switch (_section) {
      PanelSection.overview => _Overview(onGo: go, onOpen: openPatient),
      PanelSection.patients => _PatientList(onOpen: openPatient),
      PanelSection.alerts => _Alerts(onOpen: openPatient),
      PanelSection.research => const _Research(),
      PanelSection.account => const _Account(),
    };

    return Scaffold(
      appBar: wide
          ? null
          : AppBar(
              title: Text(_section.label),
              actions: [if (state.repo.isDemo) const _DemoBadge()],
            ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              extended: MediaQuery.sizeOf(context).width >= 1200,
              backgroundColor: Colors.white,
              selectedIndex: _section.index,
              onDestinationSelected: (i) => go(PanelSection.values[i]),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      color: PanelColors.peach,
                      size: 36,
                    ),
                    const Text(
                      'Nesta',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: PanelColors.primary,
                      ),
                    ),
                    if (state.repo.isDemo) ...[
                      const SizedBox(height: 6),
                      const _DemoBadge(),
                    ],
                  ],
                ),
              ),
              destinations: [
                for (final s in PanelSection.values)
                  NavigationRailDestination(
                    icon: icon(s),
                    label: Text(s.label),
                  ),
              ],
            ),
          Expanded(
            child: SelectionArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: body,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _section.index,
              onDestinationSelected: (i) => go(PanelSection.values[i]),
              destinations: [
                for (final s in PanelSection.values)
                  NavigationDestination(icon: icon(s), label: s.label),
              ],
            ),
    );
  }
}

class _DemoBadge extends StatelessWidget {
  const _DemoBadge();

  @override
  Widget build(BuildContext context) => const Chip(
    label: Text('Demo'),
    visualDensity: VisualDensity.compact,
    avatar: Icon(Icons.science_outlined, size: 16),
  );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.onGo, required this.onOpen});
  final ValueChanged<PanelSection> onGo;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PanelState>();
    final m = state.midwife;
    final width = MediaQuery.sizeOf(context).width;
    final cols = width >= 1100
        ? 4
        : width >= 600
        ? 2
        : 1;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Merhaba${m == null ? '' : ', ${m.displayName}'}',
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        if (m != null)
          Text(
            m.institution,
            style: const TextStyle(color: PanelColors.inkSoft),
          ),
        const SizedBox(height: 20),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 104,
          ),
          children: [
            StatCard(
              label: 'Takip edilen gebe',
              value: '${state.patients.length}',
              icon: Icons.pregnant_woman_rounded,
              color: PanelColors.mintSoft,
              onTap: () => onGo(PanelSection.patients),
            ),
            StatCard(
              label: 'Onay bekleyen',
              value: '${state.pending.length}',
              icon: Icons.hourglass_top_rounded,
              color: PanelColors.sandSoft,
              onTap: () => onGo(PanelSection.patients),
            ),
            StatCard(
              label: 'Açık uyarı',
              value: '${state.openAlerts.length}',
              icon: Icons.notifications_active_outlined,
              color: state.openAlerts.any((a) => a.urgent)
                  ? PanelColors.dangerSoft
                  : PanelColors.peachSoft,
              onTap: () => onGo(PanelSection.alerts),
            ),
            StatCard(
              label: 'Bu hafta seans',
              value: '${state.sessionsThisWeek}',
              icon: Icons.fitness_center_rounded,
              color: PanelColors.lilacSoft,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (m != null) _InviteCard(code: m.inviteCode),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Onay bekleyen gebeler',
          child: state.pending.isEmpty
              ? const EmptyState(
                  'Onay bekleyen gebe yok.',
                  icon: Icons.check_circle_outline,
                )
              : Column(
                  children: [
                    for (final p in state.pending)
                      _PatientRow(patient: p, onTap: () => onOpen(p.uid)),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Son uyarılar',
          action: TextButton(
            onPressed: () => onGo(PanelSection.alerts),
            child: const Text('Tümü'),
          ),
          child: state.alerts.isEmpty
              ? const EmptyState('Henüz uyarı yok.')
              : Column(
                  children: [
                    for (final a in state.alerts.take(5))
                      AlertTile(
                        alert: a,
                        now: state.now(),
                        onOpen: () => onOpen(a.patientId),
                        onAcknowledge: () => state.acknowledge(a),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) => Card(
    color: PanelColors.mintSoft,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 20,
        runSpacing: 12,
        children: [
          const Icon(
            Icons.qr_code_2_rounded,
            size: 40,
            color: PanelColors.primary,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Davet kodunuz',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                Text(
                  'Gebeleriniz Nesta uygulamasına bu kodu girerek size bağlanır. '
                  'Bağlanan gebe, siz onay verene kadar egzersiz yapamaz.',
                ),
              ],
            ),
          ),
          SelectableText(
            code,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: 6,
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Davet kodu kopyalandı.')),
              );
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Kopyala'),
          ),
        ],
      ),
    ),
  );
}

class _PatientRow extends StatelessWidget {
  const _PatientRow({required this.patient, required this.onTap});
  final PatientRecord patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PanelState>();
    final p = patient;
    final ga = p.profile.gestationalAgeAt(state.now());
    final sessions = state.sessionsOf(p.uid);
    final last = sessions.isEmpty ? null : sessions.first.startedAt;
    final week = ActivityStats(sessions).minutesInWeek(state.now());
    final open = state.openAlerts.where((a) => a.patientId == p.uid).toList();
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: PanelColors.peachSoft,
        child: Text(
          p.profile.fullName.characters.first,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: PanelColors.peach,
          ),
        ),
      ),
      title: Text(
        p.profile.fullName,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${ga.weeks}. hafta · ${p.profile.ageAt(state.now())} yaş'
        '${p.profile.riskFactors.isEmpty ? '' : ' · ${p.profile.riskFactors.map((r) => r.label).join(', ')}'}\n'
        'Bu hafta $week dk · Son seans: ${last == null ? '–' : relativeTime(last, state.now())}',
      ),
      isThreeLine: true,
      trailing: Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (open.isNotEmpty)
            Badge(
              backgroundColor: open.any((a) => a.urgent)
                  ? PanelColors.danger
                  : PanelColors.warning,
              label: Text('${open.length}'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ClearanceChip(p.clearance.status),
        ],
      ),
    );
  }
}

class _PatientList extends StatefulWidget {
  const _PatientList({required this.onOpen});
  final ValueChanged<String> onOpen;

  @override
  State<_PatientList> createState() => _PatientListState();
}

class _PatientListState extends State<_PatientList> {
  String _query = '';
  ClearanceStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PanelState>();
    final q = _query.toLowerCase();
    final list = state.patients
        .where((p) => _filter == null || p.clearance.status == _filter)
        .where((p) => q.isEmpty || p.profile.fullName.toLowerCase().contains(q))
        .toList();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Gebe ara',
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            ChoiceChip(
              label: const Text('Tümü'),
              selected: _filter == null,
              onSelected: (_) => setState(() => _filter = null),
            ),
            for (final s in [
              ClearanceStatus.pending,
              ClearanceStatus.approved,
              ClearanceStatus.rejected,
            ])
              ChoiceChip(
                label: Text(s.label),
                selected: _filter == s,
                onSelected: (_) => setState(() => _filter = s),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: list.isEmpty
                ? const EmptyState(
                    'Bu ölçütlere uyan gebe yok. Gebeleriniz davet '
                    'kodunuzla bağlandığında burada listelenir.',
                  )
                : Column(
                    children: [
                      for (var i = 0; i < list.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _PatientRow(
                          patient: list[i],
                          onTap: () => widget.onOpen(list[i].uid),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _Alerts extends StatelessWidget {
  const _Alerts({required this.onOpen});
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PanelState>();
    final open = state.openAlerts
      ..sort((a, b) {
        if (a.urgent != b.urgent) return a.urgent ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
    final done = state.alerts.where((a) => a.isAcknowledged).toList();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SectionCard(
          title: 'Açık uyarılar (${open.length})',
          child: open.isEmpty
              ? const EmptyState(
                  'Açık uyarı yok.',
                  icon: Icons.check_circle_outline,
                )
              : Column(
                  children: [
                    for (final a in open)
                      AlertTile(
                        alert: a,
                        now: state.now(),
                        onOpen: () => onOpen(a.patientId),
                        onAcknowledge: () => state.acknowledge(a),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Görülenler',
          child: done.isEmpty
              ? const EmptyState('Görülen uyarı yok.')
              : Column(
                  children: [
                    for (final a in done.take(50))
                      AlertTile(
                        alert: a,
                        now: state.now(),
                        onOpen: () => onOpen(a.patientId),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Research extends StatelessWidget {
  const _Research();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PanelState>();
    final consenting = state.patients
        .where((p) => p.consent?.researchParticipation ?? false)
        .toList();
    final sessions = consenting.fold<int>(
      0,
      (a, p) => a + state.sessionsOf(p.uid).length,
    );
    final stamp = state.now().toIso8601String().substring(0, 10);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SectionCard(
          title: 'Araştırma verisi',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Yalnızca araştırmaya katılım için açık rıza veren '
                '${consenting.length} gebenin verisi dışa aktarılır '
                '(toplam ${state.patients.length} gebe, $sessions seans). '
                'Ad, telefon ve e-posta gibi kimlik bilgileri çıkarılır; her '
                'katılımcıya K001, K002… biçiminde kod verilir.',
                style: const TextStyle(height: 1.45),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: consenting.isEmpty
                        ? null
                        : () => downloadText(
                            'nesta_seanslar_$stamp.csv',
                            state.researchCsv(),
                          ),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Seans verisi (CSV)'),
                  ),
                  OutlinedButton.icon(
                    onPressed: consenting.isEmpty
                        ? null
                        : () => downloadText(
                            'nesta_katilimcilar_$stamp.csv',
                            state.participantsCsv(),
                          ),
                    icon: const Icon(Icons.people_outline_rounded),
                    label: const Text('Katılımcı özeti (CSV)'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Dosyalar SPSS, R veya Excel ile açılabilir. Sütun açıklamaları '
                'proje deposundaki docs/VERI_SOZLUGU.md dosyasındadır.',
                style: TextStyle(color: PanelColors.inkSoft, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Account extends StatelessWidget {
  const _Account();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PanelState>();
    final m = state.midwife;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SectionCard(
          title: 'Hesap',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (m != null) ...[
                Text(
                  m.displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(m.institution),
                const SizedBox(height: 4),
                Text('Davet kodu: ${m.inviteCode}'),
              ],
              Text(
                state.repo.currentEmail ?? '',
                style: const TextStyle(color: PanelColors.inkSoft),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: state.repo.signOut,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Çıkış yap'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionCard(
          title: 'Klinik sorumluluk',
          child: Text(
            'Nesta bir karar destek ve izlem aracıdır; tanı koymaz. Egzersiz onayı '
            've bireysel kısıtlamalar ebe/hekimin klinik değerlendirmesine dayanır. '
            'Acil uyarılarda gebeyle telefonla iletişime geçin.',
            style: TextStyle(height: 1.45),
          ),
        ),
      ],
    );
  }
}
