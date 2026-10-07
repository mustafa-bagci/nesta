import 'dart:async';
import 'dart:math';

import 'package:nesta_core/nesta_core.dart';

import 'panel_repository.dart';

/// Firebase kurulmadan paneli tanıtmak için örnek verili demo.
///
/// Örnek gebeler, seanslar ve uyarılar deterministik olarak üretilir;
/// yapılan değişiklikler yalnızca sayfa açık kaldığı sürece bellekte tutulur.
class DemoPanelRepository implements PanelRepository {
  DemoPanelRepository({DateTime? now}) : _now = now ?? DateTime.now() {
    _seed();
  }

  static const midwifeId = 'demo-midwife';
  final DateTime _now;
  String? _uid;
  final _auth = StreamController<String?>.broadcast();
  final _changes = StreamController<void>.broadcast();

  MidwifeRecord _midwife = const MidwifeRecord(
    uid: midwifeId,
    fullName: 'Zeynep Demir',
    title: 'Uzm. Ebe',
    institution: 'Nesta Demo Kliniği',
    inviteCode: 'NESTA1',
  );
  final Map<String, PatientRecord> _patients = {};
  final Map<String, List<ExerciseSession>> _sessions = {};
  final List<AlertRecord> _alerts = [];

  @override
  bool get isDemo => true;

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    yield* _changes.stream.map((_) => read());
  }

  void _changed() => _changes.add(null);

  @override
  Stream<String?> authStateChanges() async* {
    yield _uid;
    yield* _auth.stream;
  }

  @override
  String? get currentEmail => _uid == null ? null : 'ebe@nesta-demo.com';

  @override
  Future<void> signIn(String email, String password) async {
    _uid = midwifeId;
    _auth.add(_uid);
  }

  @override
  Future<void> signOut() async {
    _uid = null;
    _auth.add(null);
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> registerMidwife({
    required String email,
    required String password,
    required String fullName,
    required String title,
    required String institution,
  }) async {
    _midwife = MidwifeRecord(
      uid: midwifeId,
      fullName: fullName,
      title: title,
      institution: institution,
      inviteCode: _midwife.inviteCode,
    );
    await signIn(email, password);
  }

  @override
  Future<UserRole?> getRole(String uid) async => UserRole.midwife;

  @override
  Stream<MidwifeRecord?> watchMidwife(String uid) => _watch(() => _midwife);

  @override
  Stream<List<PatientRecord>> watchPatients(String midwifeId) =>
      _watch(() => _patients.values.toList());

  @override
  Stream<List<ExerciseSession>> watchSessions(String patientId) => _watch(
    () =>
        [...?_sessions[patientId]]
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt)),
  );

  @override
  Stream<List<AlertRecord>> watchAlerts(String midwifeId) => _watch(
    () => [..._alerts]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );

  @override
  Future<void> updateClearance(String patientId, Clearance clearance) async {
    final p = _patients[patientId]!;
    _patients[patientId] = p.copyWith(
      clearance: clearance,
      updatedAt: DateTime.now().toUtc(),
    );
    _changed();
  }

  @override
  Future<void> acknowledgeAlert(String alertId) async {
    final i = _alerts.indexWhere((a) => a.id == alertId);
    if (i < 0) return;
    final a = _alerts[i];
    _alerts[i] = AlertRecord(
      id: a.id,
      patientId: a.patientId,
      patientName: a.patientName,
      midwifeId: a.midwifeId,
      type: a.type,
      message: a.message,
      createdAt: a.createdAt,
      urgent: a.urgent,
      acknowledgedAt: DateTime.now().toUtc(),
      sessionId: a.sessionId,
    );
    _changed();
  }

  // -------------------------------------------------------------------------
  // Örnek veri
  // -------------------------------------------------------------------------

  void _seed() {
    final rnd = Random(42);
    final today = DateTime.utc(_now.year, _now.month, _now.day);
    Map<String, bool> answers([Set<String> yes = const {}]) => {
      for (final q in allScreeningQuestions) q.id: yes.contains(q.id),
    };

    void add(
      String id,
      String name,
      int age,
      int weeks,
      Set<RiskFactor> risks, {
      Set<String> yes = const {},
      ClearanceStatus status = ClearanceStatus.approved,
      double? height,
      double? weight,
      bool betaBlocker = false,
      bool research = true,
      String? note,
    }) {
      final t = today.subtract(Duration(days: 30 + rnd.nextInt(20)));
      _patients[id] = PatientRecord(
        uid: id,
        profile: PregnancyProfile(
          fullName: name,
          birthDate: DateTime.utc(
            _now.year - age,
            1 + rnd.nextInt(12),
            1 + rnd.nextInt(27),
          ),
          lastMenstrualPeriod: today.subtract(
            Duration(days: weeks * 7 + rnd.nextInt(7)),
          ),
          heightCm: height ?? 155 + rnd.nextInt(20).toDouble(),
          prePregnancyWeightKg: weight ?? 55 + rnd.nextInt(25).toDouble(),
          riskFactors: risks,
          takesBetaBlocker: betaBlocker,
          phone:
              '0555 ${100 + rnd.nextInt(899)} ${10 + rnd.nextInt(89)} ${10 + rnd.nextInt(89)}',
        ),
        screening: ScreeningResult(answers: answers(yes), completedAt: t),
        consent: ConsentRecord(
          version: consentVersion,
          acceptedAt: t,
          healthDataProcessing: true,
          researchParticipation: research,
        ),
        midwifeId: midwifeId,
        clearance: Clearance(
          status: status,
          decidedAt: status == ClearanceStatus.pending
              ? null
              : t.add(const Duration(days: 1)),
          decidedBy: status == ClearanceStatus.pending ? null : midwifeId,
          note: note,
          disabledExercises: status == ClearanceStatus.approved && weeks >= 30
              ? {'kus_kopek'}
              : {},
        ),
        createdAt: t,
        updatedAt: t,
      );
      if (status == ClearanceStatus.approved) {
        _seedSessions(id, weeks, age, rnd, today);
      }
    }

    add('p1', 'Ayşe Yılmaz', 31, 26, {
      RiskFactor.gestationalDiabetes,
    }, note: 'Haftada en az 4 gün, yemekten sonra egzersiz yapın.');
    add(
      'p2',
      'Elif Kaya',
      37,
      31,
      {RiskFactor.advancedMaternalAge, RiskFactor.chronicHypertension},
      betaBlocker: true,
      note: 'Tansiyonunuzu egzersiz öncesi ölçün.',
    );
    add(
      'p3',
      'Merve Demir',
      28,
      19,
      {RiskFactor.obesity},
      height: 162,
      weight: 86,
      research: false,
    );
    add('p4', 'Fatma Şahin', 34, 23, {
      RiskFactor.pelvicGirdlePain,
      RiskFactor.previousCesarean,
    });
    add('p5', 'Zehra Arslan', 26, 16, {
      RiskFactor.thyroidDisease,
    }, status: ClearanceStatus.pending);
    add(
      'p6',
      'Seda Koç',
      33,
      27,
      {RiskFactor.gestationalDiabetes},
      yes: {'anemia', 'sedentary'},
      status: ClearanceStatus.pending,
    );
    add(
      'p7',
      'Hatice Öztürk',
      30,
      29,
      {RiskFactor.ivfPregnancy},
      yes: {'placenta_previa'},
      status: ClearanceStatus.rejected,
      note: 'Plasenta previa nedeniyle şu an egzersiz önerilmiyor.',
    );

    var n = 0;
    void alert(
      String pid,
      AlertType type,
      String msg,
      int hoursAgo, {
      bool urgent = false,
      bool ack = false,
    }) {
      final p = _patients[pid]!;
      final at = _now.toUtc().subtract(Duration(hours: hoursAgo));
      _alerts.add(
        AlertRecord(
          id: 'a${n++}',
          patientId: pid,
          patientName: p.profile.fullName,
          midwifeId: midwifeId,
          type: type,
          message: msg,
          createdAt: at,
          urgent: urgent,
          acknowledgedAt: ack ? at.add(const Duration(hours: 1)) : null,
        ),
      );
    }

    alert(
      'p1',
      AlertType.heartRateLimit,
      'Nabız 163 atım/dk\'ya ulaştı; "Destekli Plié Squat" seansı durduruldu.',
      3,
      urgent: true,
    );
    alert(
      'p4',
      AlertType.symptomBeforeSession,
      'Seans öncesi tehlike belirtisi (Kedi-İnek Gevşeme): Baş ağrısı',
      20,
    );
    alert(
      'p6',
      AlertType.screeningUpdated,
      'Tarama formu güncellendi: Değerlendirme gerekli. Egzersiz onayının yeniden '
          'değerlendirilmesi gerekiyor.',
      30,
    );
    alert(
      'p2',
      AlertType.symptomAfterSession,
      'Seans sonrası tehlike belirtisi (Ayakta Yana Esneme): Baş dönmesi veya '
          'bayılacak gibi olma',
      74,
      ack: true,
    );
  }

  void _seedSessions(
    String pid,
    int weeks,
    int age,
    Random rnd,
    DateTime today,
  ) {
    final trimester = Trimester.fromWeeks(weeks);
    final list = <ExerciseSession>[];
    final zone = HeartRateZone.forProfile(age: age);
    var i = 0;
    for (var d = 27; d >= 0; d--) {
      if (rnd.nextDouble() > 0.62) continue;
      final day = today.subtract(Duration(days: d));
      final program = dailyProgram(day, trimester);
      final count = 2 + rnd.nextInt(program.length - 1);
      var t = day.add(
        Duration(hours: 9 + rnd.nextInt(10), minutes: rnd.nextInt(60)),
      );
      for (final e in program.take(count)) {
        final dur = e.estimatedMinutes * 60 - 20 + rnd.nextInt(60);
        final camera = e.usesCamera;
        final violations = <String, int>{};
        if (camera) {
          for (final r in e.rules) {
            if (rnd.nextDouble() < 0.35) violations[r.id] = 1 + rnd.nextInt(3);
          }
        }
        final avg = zone.low - 8 + rnd.nextInt(22);
        final hrStop = rnd.nextDouble() < 0.02;
        list.add(
          ExerciseSession(
            id: '$pid-s${i++}',
            patientId: pid,
            exerciseId: e.id,
            startedAt: t,
            endedAt: t.add(Duration(seconds: dur)),
            endReason: hrStop
                ? SessionEndReason.heartRate
                : SessionEndReason.completed,
            gestationalWeek: weeks - d ~/ 7,
            reps: e.mode == ExerciseMode.guided
                ? e.guidedRepeats * e.sets
                : (e.targetReps ?? 0) * e.sets,
            formScore: camera ? 68 + rnd.nextInt(31) : null,
            violationCounts: violations,
            heartRate: HeartRateSummary(
              min: avg - 25,
              avg: avg,
              max: hrStop ? zone.stopThreshold + 3 : avg + 6 + rnd.nextInt(10),
              sampleCount: dur ~/ 5,
              secondsAboveZone: hrStop ? 40 : rnd.nextInt(10),
              zoneLow: zone.low,
              zoneHigh: zone.high,
            ),
            rpe: 10 + rnd.nextInt(6),
            preCheck: SymptomCheck(present: const {}, checkedAt: t),
            postCheck: SymptomCheck(present: const {}, checkedAt: t),
          ),
        );
        t = t.add(Duration(seconds: dur + 60));
      }
    }
    _sessions[pid] = list;
  }
}
