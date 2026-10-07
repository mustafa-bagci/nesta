import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nesta_core/nesta_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repository.dart';

/// Uygulamanın hangi adımda olduğunu belirleyen ve tüm ekranların paylaştığı
/// durum. Yönlendirme ([buildRouter]) bu durumdaki değişiklikleri dinler.
class AppState extends ChangeNotifier {
  AppState(this.repo, this.prefs, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    welcomeSeen = prefs.getBool(_welcomeKey) ?? false;
    settings = VoiceSettings.load(prefs);
    _authSub = repo.authStateChanges().listen(_onAuth);
  }

  static const _welcomeKey = 'welcome_seen';
  static const _pendingConsentKey = 'pending_consent';

  final NestaRepository repo;
  final SharedPreferences prefs;
  final DateTime Function() _clock;

  late bool welcomeSeen;
  late VoiceSettings settings;

  bool authResolved = false;
  String? uid;
  UserRole? role;
  bool patientLoaded = false;
  PatientRecord? patient;
  List<ExerciseSession> sessions = const [];
  MidwifeRecord? midwife;

  StreamSubscription<String?>? _authSub;
  StreamSubscription<PatientRecord?>? _patientSub;
  StreamSubscription<List<ExerciseSession>>? _sessionSub;

  DateTime now() => _clock();

  // -------------------------------------------------------------------------
  // Oturum
  // -------------------------------------------------------------------------

  Future<void> _onAuth(String? newUid) async {
    if (authResolved && newUid == uid) return;
    await _patientSub?.cancel();
    await _sessionSub?.cancel();
    uid = newUid;
    role = null;
    patient = null;
    patientLoaded = false;
    sessions = const [];
    midwife = null;
    authResolved = true;
    notifyListeners();
    if (newUid == null) return;

    try {
      role = await repo.getRole(newUid);
      if (role == null) {
        // Mobil uygulamadan açılan hesaplar gebe hesabıdır; ebe hesapları
        // web panelinden oluşturulur.
        await repo.setRole(newUid, UserRole.pregnant);
        role = UserRole.pregnant;
      }
    } on RepositoryException {
      role = UserRole.pregnant;
    }
    if (uid != newUid) return;
    notifyListeners();
    if (role != UserRole.pregnant) return;

    _patientSub = repo.watchPatient(newUid).listen((p) async {
      patient = p;
      patientLoaded = true;
      if (p?.midwifeId != null && midwife?.uid != p!.midwifeId) {
        try {
          midwife = await repo.getMidwife(p.midwifeId!);
        } on RepositoryException {
          midwife = null;
        }
      }
      notifyListeners();
    });
    _sessionSub = repo.watchSessions(newUid).listen((s) {
      sessions = s;
      notifyListeners();
    });
  }

  Future<void> markWelcomeSeen() async {
    welcomeSeen = true;
    await prefs.setBool(_welcomeKey, true);
    notifyListeners();
  }

  Future<void> signOut() => repo.signOut();

  Future<void> deleteAccount(String password) async {
    await repo.deleteAccount(password);
    await prefs.remove(_pendingConsentKey);
  }

  // -------------------------------------------------------------------------
  // Onay, profil, tarama, ebe bağlantısı
  // -------------------------------------------------------------------------

  ConsentRecord? get _pendingConsent {
    final raw = prefs.getStringList(_pendingConsentKey);
    if (raw == null || raw.length != 3) return null;
    return ConsentRecord(
      version: raw[0],
      acceptedAt: DateTime.fromMillisecondsSinceEpoch(
        int.parse(raw[1]),
        isUtc: true,
      ),
      healthDataProcessing: true,
      researchParticipation: raw[2] == '1',
    );
  }

  bool get needsConsent {
    final c = patient?.consent ?? _pendingConsent;
    return c == null || c.version != consentVersion || !c.healthDataProcessing;
  }

  Future<void> acceptConsent({required bool research}) async {
    final consent = ConsentRecord(
      version: consentVersion,
      acceptedAt: now().toUtc(),
      healthDataProcessing: true,
      researchParticipation: research,
    );
    final p = patient;
    if (p != null) {
      await repo.savePatient(
        p.copyWith(consent: consent, updatedAt: now().toUtc()),
      );
    } else {
      await prefs.setStringList(_pendingConsentKey, [
        consent.version,
        '${consent.acceptedAt.millisecondsSinceEpoch}',
        research ? '1' : '0',
      ]);
      notifyListeners();
    }
  }

  Future<void> saveProfile(PregnancyProfile profile) async {
    final t = now().toUtc();
    final p = patient;
    if (p == null) {
      await repo.savePatient(
        PatientRecord(
          uid: uid!,
          profile: profile,
          consent: _pendingConsent,
          createdAt: t,
          updatedAt: t,
        ),
      );
      await prefs.remove(_pendingConsentKey);
    } else {
      await repo.savePatient(p.copyWith(profile: profile, updatedAt: t));
    }
  }

  /// Tarama formunu kaydeder. Önceden onaylanmış bir gebe formu değiştirirse
  /// onay yeniden ebeye düşer ve ebeye bildirim gider.
  Future<void> saveScreening(ScreeningResult result) async {
    final p = patient!;
    final t = now().toUtc();
    final changed =
        p.screening != null && !mapEquals(p.screening!.answers, result.answers);
    var clearance = p.clearance;
    if (changed &&
        p.midwifeId != null &&
        clearance.status != ClearanceStatus.notRequested) {
      clearance = Clearance(
        status: ClearanceStatus.pending,
        disabledExercises: clearance.disabledExercises,
      );
    }
    await repo.savePatient(
      p.copyWith(screening: result, clearance: clearance, updatedAt: t),
    );
    if (changed && p.midwifeId != null) {
      await _alert(
        AlertType.screeningUpdated,
        'Tarama formu güncellendi: ${result.outcome.label}. '
        'Egzersiz onayının yeniden değerlendirilmesi gerekiyor.',
        urgent: result.outcome == ScreeningOutcome.ineligible,
      );
    }
  }

  Future<MidwifeRecord?> linkMidwife(String code) async {
    final m = await repo.findMidwifeByInviteCode(code);
    if (m == null) return null;
    final p = patient!;
    midwife = m;
    await repo.savePatient(
      p.copyWith(
        midwifeId: m.uid,
        clearance: const Clearance(status: ClearanceStatus.pending),
        updatedAt: now().toUtc(),
      ),
    );
    return m;
  }

  // -------------------------------------------------------------------------
  // Seanslar ve uyarılar
  // -------------------------------------------------------------------------

  Future<void> saveSession(ExerciseSession s) => repo.saveSession(s);

  Future<void> _alert(
    AlertType type,
    String message, {
    bool urgent = false,
    String? sessionId,
  }) async {
    final p = patient;
    if (p?.midwifeId == null) return;
    await repo.createAlert(
      AlertRecord(
        id: repo.newId(),
        patientId: p!.uid,
        patientName: p.profile.fullName,
        midwifeId: p.midwifeId!,
        type: type,
        message: message,
        createdAt: now().toUtc(),
        urgent: urgent,
        sessionId: sessionId,
      ),
    );
  }

  /// Bildirilen tehlike belirtilerini ebeye iletir.
  Future<void> reportSymptoms(
    SymptomCheck check,
    AlertType type, {
    String? exerciseName,
    String? sessionId,
  }) {
    final names = check.signs.map((s) => s.text).join(', ');
    final where = exerciseName == null ? '' : ' ($exerciseName)';
    return _alert(
      type,
      '${type.label}$where: $names',
      urgent: check.hasUrgent,
      sessionId: sessionId,
    );
  }

  Future<void> reportHeartRateStop(
    int bpm,
    String exerciseName,
    String sessionId,
  ) => _alert(
    AlertType.heartRateLimit,
    'Nabız $bpm atım/dk\'ya ulaştı; "$exerciseName" seansı durduruldu.',
    urgent: true,
    sessionId: sessionId,
  );

  // -------------------------------------------------------------------------
  // Türetilmiş değerler
  // -------------------------------------------------------------------------

  GestationalAge? get gestationalAge =>
      patient?.profile.gestationalAgeAt(now());

  Trimester get trimester => gestationalAge?.trimester ?? Trimester.second;

  Set<String> get disabledExercises =>
      patient?.clearance.disabledExercises ?? const {};

  List<Exercise> get todaysProgram =>
      dailyProgram(now(), trimester, disabled: disabledExercises);

  List<Exercise> get availableExerciseList =>
      availableExercises(trimester, disabled: disabledExercises);

  HeartRateZone? get heartRateZone {
    final p = patient?.profile;
    if (p == null || p.takesBetaBlocker) return null;
    return HeartRateZone.forProfile(
      age: p.ageAt(now()),
      bmi: p.prePregnancyBmi,
    );
  }

  ActivityStats get stats => ActivityStats(sessions);

  Set<String> completedToday() {
    final n = now();
    return sessions
        .where((s) {
          final d = s.startedAt.toLocal();
          return d.year == n.year &&
              d.month == n.month &&
              d.day == n.day &&
              s.endReason == SessionEndReason.completed;
        })
        .map((s) => s.exerciseId)
        .toSet();
  }

  Future<void> updateSettings(VoiceSettings s) async {
    settings = s;
    await s.save(prefs);
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _patientSub?.cancel();
    _sessionSub?.cancel();
    super.dispose();
  }
}

/// Sesli koç ve kamera tercihleri.
@immutable
class VoiceSettings {
  const VoiceSettings({
    this.voiceEnabled = true,
    this.speechRate = 0.5,
    this.useFrontCamera = true,
    this.showSkeleton = true,
  });

  final bool voiceEnabled;
  final double speechRate;
  final bool useFrontCamera;
  final bool showSkeleton;

  static VoiceSettings load(SharedPreferences p) => VoiceSettings(
    voiceEnabled: p.getBool('voice_enabled') ?? true,
    speechRate: p.getDouble('speech_rate') ?? 0.5,
    useFrontCamera: p.getBool('front_camera') ?? true,
    showSkeleton: p.getBool('show_skeleton') ?? true,
  );

  Future<void> save(SharedPreferences p) async {
    await p.setBool('voice_enabled', voiceEnabled);
    await p.setDouble('speech_rate', speechRate);
    await p.setBool('front_camera', useFrontCamera);
    await p.setBool('show_skeleton', showSkeleton);
  }

  VoiceSettings copyWith({
    bool? voiceEnabled,
    double? speechRate,
    bool? useFrontCamera,
    bool? showSkeleton,
  }) => VoiceSettings(
    voiceEnabled: voiceEnabled ?? this.voiceEnabled,
    speechRate: speechRate ?? this.speechRate,
    useFrontCamera: useFrontCamera ?? this.useFrontCamera,
    showSkeleton: showSkeleton ?? this.showSkeleton,
  );
}
