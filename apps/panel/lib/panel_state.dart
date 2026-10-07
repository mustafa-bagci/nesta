import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nesta_core/nesta_core.dart';

import 'data/panel_repository.dart';

/// Ebe panelinin ortak durumu: oturum, gebeler, seanslar ve uyarılar.
class PanelState extends ChangeNotifier {
  PanelState(this.repo, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _authSub = repo.authStateChanges().listen(_onAuth);
  }

  final PanelRepository repo;
  final DateTime Function() _clock;

  bool authResolved = false;
  String? uid;
  UserRole? role;
  MidwifeRecord? midwife;
  List<PatientRecord> patients = const [];
  List<AlertRecord> alerts = const [];
  final Map<String, List<ExerciseSession>> sessions = {};

  StreamSubscription<String?>? _authSub;
  final List<StreamSubscription<Object?>> _subs = [];
  final Map<String, StreamSubscription<List<ExerciseSession>>> _sessionSubs =
      {};

  DateTime now() => _clock();

  Future<void> _onAuth(String? newUid) async {
    for (final s in [..._subs, ..._sessionSubs.values]) {
      await s.cancel();
    }
    _subs.clear();
    _sessionSubs.clear();
    sessions.clear();
    uid = newUid;
    role = null;
    midwife = null;
    patients = const [];
    alerts = const [];
    authResolved = newUid == null;
    notifyListeners();
    if (newUid == null) return;

    try {
      role = await repo.getRole(newUid);
    } on PanelException {
      role = null;
    }
    authResolved = true;
    notifyListeners();
    if (role != UserRole.midwife) return;

    _subs.add(
      repo.watchMidwife(newUid).listen((m) {
        midwife = m;
        notifyListeners();
      }),
    );
    _subs.add(
      repo.watchPatients(newUid).listen((list) {
        patients = [...list]
          ..sort((a, b) => a.profile.fullName.compareTo(b.profile.fullName));
        for (final p in list) {
          _sessionSubs.putIfAbsent(
            p.uid,
            () => repo.watchSessions(p.uid).listen((s) {
              sessions[p.uid] = s;
              notifyListeners();
            }),
          );
        }
        notifyListeners();
      }),
    );
    _subs.add(
      repo.watchAlerts(newUid).listen((a) {
        alerts = a;
        notifyListeners();
      }),
    );
  }

  PatientRecord? patient(String id) {
    for (final p in patients) {
      if (p.uid == id) return p;
    }
    return null;
  }

  List<ExerciseSession> sessionsOf(String id) => sessions[id] ?? const [];

  List<PatientRecord> get pending => patients
      .where((p) => p.clearance.status == ClearanceStatus.pending)
      .toList();

  List<PatientRecord> get approved =>
      patients.where((p) => p.clearance.isApproved).toList();

  List<AlertRecord> get openAlerts =>
      alerts.where((a) => !a.isAcknowledged).toList();

  int get sessionsThisWeek {
    final start = startOfWeek(now());
    return sessions.values
        .expand((l) => l)
        .where((s) => !s.startedAt.toLocal().isBefore(start))
        .length;
  }

  Future<void> decide(
    PatientRecord p, {
    required bool approve,
    String? note,
    Set<String> disabled = const {},
  }) => repo.updateClearance(
    p.uid,
    Clearance(
      status: approve ? ClearanceStatus.approved : ClearanceStatus.rejected,
      decidedAt: now().toUtc(),
      decidedBy: uid,
      note: note == null || note.trim().isEmpty ? null : note.trim(),
      disabledExercises: disabled,
    ),
  );

  Future<void> acknowledge(AlertRecord a) => repo.acknowledgeAlert(a.id);

  /// Araştırma onamı veren gebelerin anonimleştirilmiş seansları.
  String researchCsv() {
    final consenting =
        patients
            .where((p) => p.consent?.researchParticipation ?? false)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final ids = {
      for (var i = 0; i < consenting.length; i++)
        consenting[i].uid: 'K${(i + 1).toString().padLeft(3, '0')}',
    };
    final all = [for (final p in consenting) ...sessionsOf(p.uid)]
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return sessionsToCsv(all, anonymousId: (id) => ids[id] ?? 'K???');
  }

  /// Katılımcı düzeyinde özet tablo (demografik ve uyum verisi).
  String participantsCsv() {
    final consenting =
        patients
            .where((p) => p.consent?.researchParticipation ?? false)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final rows = <String>[
      'katilimci,yas,gebelik_haftasi,trimester,bki,risk_faktorleri,'
          'tarama_sonucu,onay_durumu,seans_sayisi,toplam_dakika,ort_form_puani,'
          'guvenlik_durdurma',
    ];
    for (var i = 0; i < consenting.length; i++) {
      final p = consenting[i];
      final ga = p.profile.gestationalAgeAt(now());
      final st = ActivityStats(sessionsOf(p.uid));
      final minutes = st.minutesByDay.values.fold<int>(0, (a, b) => a + b);
      rows.add(
        [
          'K${(i + 1).toString().padLeft(3, '0')}',
          p.profile.ageAt(now()),
          ga.weeks,
          ga.trimester.number,
          p.profile.prePregnancyBmi?.toStringAsFixed(1) ?? '',
          p.profile.riskFactors.map((r) => r.id).join('|'),
          p.screening?.outcome.id ?? '',
          p.clearance.status.id,
          st.sessions.length,
          minutes,
          st.averageFormScore ?? '',
          st.safetyStops,
        ].join(','),
      );
    }
    return rows.join('\n');
  }

  @override
  void dispose() {
    _authSub?.cancel();
    for (final s in [..._subs, ..._sessionSubs.values]) {
      s.cancel();
    }
    super.dispose();
  }
}
