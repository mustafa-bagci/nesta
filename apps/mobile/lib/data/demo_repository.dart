import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:nesta_core/nesta_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'repository.dart';

/// Hesap ve internet gerektirmeyen demo modu.
///
/// Veriler cihazda saklanır. "NESTA1" davet kodlu örnek bir ebe vardır ve
/// bağlantı isteği birkaç saniye sonra otomatik onaylanır. Jüri sunumları ve
/// Firebase kurulmadan önce uygulamayı denemek için kullanılır.
class DemoRepository implements NestaRepository {
  DemoRepository(
    this._prefs, {
    this.autoApproveDelay = const Duration(seconds: 3),
  }) {
    _load();
  }

  static const demoInviteCode = 'NESTA1';
  static const demoMidwife = MidwifeRecord(
    uid: 'demo-midwife',
    fullName: 'Zeynep Demir',
    title: 'Uzm. Ebe',
    institution: 'Nesta Demo Kliniği',
    inviteCode: demoInviteCode,
  );
  static const _key = 'nesta_demo_store_v1';

  final SharedPreferences _prefs;
  final Duration autoApproveDelay;
  final _random = Random();

  String? _uid;
  String? _email;
  final Map<String, String> _passwords = {};
  final Map<String, String> _uidByEmail = {};
  final Map<String, UserRole> _roles = {};
  final Map<String, PatientRecord> _patients = {};
  final Map<String, List<ExerciseSession>> _sessions = {};
  final List<AlertRecord> _alerts = [];

  final _authController = StreamController<String?>.broadcast();
  final _patientController = StreamController<String>.broadcast();
  final _sessionController = StreamController<String>.broadcast();

  List<AlertRecord> get alerts => List.unmodifiable(_alerts);

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      _uid = m['uid'] as String?;
      _email = m['email'] as String?;
      _passwords.addAll(Map<String, String>.from(m['passwords'] as Map));
      _uidByEmail.addAll(Map<String, String>.from(m['uidByEmail'] as Map));
      (m['roles'] as Map).forEach((k, v) {
        final r = UserRole.byId(v);
        if (r != null) _roles[k as String] = r;
      });
      (m['patients'] as Map).forEach(
        (k, v) => _patients[k as String] = PatientRecord.fromMap(
          Map<String, Object?>.from(v as Map),
        ),
      );
      (m['sessions'] as Map).forEach(
        (k, v) => _sessions[k as String] = [
          for (final s in v as List)
            ExerciseSession.fromMap(Map<String, Object?>.from(s as Map)),
        ],
      );
      for (final a in (m['alerts'] as List? ?? const [])) {
        _alerts.add(AlertRecord.fromMap(Map<String, Object?>.from(a as Map)));
      }
    } catch (_) {
      // Bozuk demo verisi: temiz başla.
      _prefs.remove(_key);
    }
  }

  Future<void> _persist() => _prefs.setString(
    _key,
    jsonEncode({
      'uid': _uid,
      'email': _email,
      'passwords': _passwords,
      'uidByEmail': _uidByEmail,
      'roles': _roles.map((k, v) => MapEntry(k, v.id)),
      'patients': _patients.map((k, v) => MapEntry(k, v.toMap())),
      'sessions': _sessions.map(
        (k, v) => MapEntry(k, v.map((s) => s.toMap()).toList()),
      ),
      'alerts': _alerts.map((a) => a.toMap()).toList(),
    }),
  );

  @override
  bool get isDemo => true;

  @override
  Stream<String?> authStateChanges() async* {
    yield _uid;
    yield* _authController.stream;
  }

  @override
  String? get currentUid => _uid;

  @override
  String? get currentEmail => _email;

  String _norm(String email) => email.trim().toLowerCase();

  @override
  Future<void> signIn(String email, String password) async {
    final e = _norm(email);
    final uid = _uidByEmail[e];
    if (uid == null || _passwords[e] != password) {
      throw const RepositoryException('E-posta veya şifre hatalı.');
    }
    _uid = uid;
    _email = e;
    await _persist();
    _authController.add(_uid);
  }

  @override
  Future<void> register(String email, String password) async {
    final e = _norm(email);
    if (!e.contains('@'))
      throw const RepositoryException('E-posta adresi geçersiz.');
    if (password.length < 6) {
      throw const RepositoryException('Şifre en az 6 karakter olmalıdır.');
    }
    if (_uidByEmail.containsKey(e)) {
      throw const RepositoryException(
        'Bu e-posta adresiyle zaten bir hesap var.',
      );
    }
    final uid = 'demo-${newId()}';
    _uidByEmail[e] = uid;
    _passwords[e] = password;
    _uid = uid;
    _email = e;
    await _persist();
    _authController.add(_uid);
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {
    _uid = null;
    _email = null;
    await _persist();
    _authController.add(null);
  }

  @override
  Future<void> deleteAccount(String password) async {
    final uid = _uid, email = _email;
    if (uid == null || email == null) return;
    if (_passwords[email] != password) {
      throw const RepositoryException('Şifre hatalı.');
    }
    _patients.remove(uid);
    _sessions.remove(uid);
    _roles.remove(uid);
    _alerts.removeWhere((a) => a.patientId == uid);
    _uidByEmail.remove(email);
    _passwords.remove(email);
    _patientController.add(uid);
    _sessionController.add(uid);
    await signOut();
  }

  @override
  Future<UserRole?> getRole(String uid) async => _roles[uid];

  @override
  Future<void> setRole(String uid, UserRole role) async {
    _roles[uid] = role;
    await _persist();
  }

  @override
  Stream<PatientRecord?> watchPatient(String uid) async* {
    yield _patients[uid];
    yield* _patientController.stream
        .where((id) => id == uid)
        .map((_) => _patients[uid]);
  }

  @override
  Future<void> savePatient(PatientRecord patient) async {
    _patients[patient.uid] = patient;
    await _persist();
    _patientController.add(patient.uid);
    if (patient.midwifeId == demoMidwife.uid &&
        patient.clearance.status == ClearanceStatus.pending) {
      _scheduleAutoApproval(patient.uid);
    }
  }

  void _scheduleAutoApproval(String uid) {
    Timer(autoApproveDelay, () async {
      final p = _patients[uid];
      if (p == null || p.clearance.status != ClearanceStatus.pending) return;
      final ineligible = p.screening?.outcome == ScreeningOutcome.ineligible;
      _patients[uid] = p.copyWith(
        clearance: Clearance(
          status: ineligible
              ? ClearanceStatus.rejected
              : ClearanceStatus.approved,
          decidedAt: DateTime.now().toUtc(),
          decidedBy: demoMidwife.uid,
          note: ineligible
              ? 'Tarama sonucunuza göre şu an egzersiz önerilmemektedir.'
              : 'Demo modunda onay otomatik verilmiştir. Gerçek kullanımda '
                    'ebeniz tarama yanıtlarınızı değerlendirerek onay verir.',
        ),
        updatedAt: DateTime.now().toUtc(),
      );
      await _persist();
      _patientController.add(uid);
    });
  }

  @override
  Future<MidwifeRecord?> findMidwifeByInviteCode(String code) async =>
      code.trim().toUpperCase() == demoInviteCode ? demoMidwife : null;

  @override
  Future<MidwifeRecord?> getMidwife(String uid) async =>
      uid == demoMidwife.uid ? demoMidwife : null;

  @override
  Stream<List<ExerciseSession>> watchSessions(String uid) async* {
    List<ExerciseSession> current() =>
        [...?_sessions[uid]]
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    yield current();
    yield* _sessionController.stream
        .where((id) => id == uid)
        .map((_) => current());
  }

  @override
  Future<void> saveSession(ExerciseSession session) async {
    final list = _sessions.putIfAbsent(session.patientId, () => []);
    list.removeWhere((s) => s.id == session.id);
    list.add(session);
    await _persist();
    _sessionController.add(session.patientId);
  }

  @override
  Future<void> createAlert(AlertRecord alert) async {
    _alerts.add(alert);
    await _persist();
  }

  @override
  String newId() => List.generate(
    20,
    (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[_random.nextInt(36)],
  ).join();
}
