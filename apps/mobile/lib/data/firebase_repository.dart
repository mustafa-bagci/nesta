import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nesta_core/nesta_core.dart';

import 'repository.dart';

/// Firebase Authentication + Cloud Firestore uygulaması.
///
/// Koleksiyon yapısı ve erişim kuralları `firebase/firestore.rules`
/// dosyasında tanımlıdır.
class FirebaseRepository implements NestaRepository {
  FirebaseRepository({FirebaseAuth? auth, FirebaseFirestore? db})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _patients =>
      _db.collection('patients');
  CollectionReference<Map<String, dynamic>> get _midwives =>
      _db.collection('midwives');
  CollectionReference<Map<String, dynamic>> get _inviteCodes =>
      _db.collection('inviteCodes');
  CollectionReference<Map<String, dynamic>> get _alerts =>
      _db.collection('alerts');
  CollectionReference<Map<String, dynamic>> _sessions(String uid) =>
      _patients.doc(uid).collection('sessions');

  @override
  bool get isDemo => false;

  @override
  Stream<String?> authStateChanges() =>
      _auth.authStateChanges().map((u) => u?.uid);

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  String? get currentEmail => _auth.currentUser?.email;

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on FirebaseAuthException catch (e) {
      throw RepositoryException(_authMessage(e.code));
    } on FirebaseException catch (e) {
      throw RepositoryException(
        e.code == 'permission-denied'
            ? 'Bu işlem için yetkiniz yok.'
            : e.code == 'unavailable'
            ? 'Sunucuya ulaşılamıyor. İnternet bağlantınızı kontrol edin.'
            : 'Beklenmeyen bir hata oluştu (${e.code}).',
      );
    }
  }

  static String _authMessage(String code) => switch (code) {
    'invalid-email' => 'E-posta adresi geçersiz.',
    'user-disabled' => 'Bu hesap devre dışı bırakılmış.',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => 'E-posta veya şifre hatalı.',
    'email-already-in-use' => 'Bu e-posta adresiyle zaten bir hesap var.',
    'weak-password' => 'Şifre en az 6 karakter olmalıdır.',
    'too-many-requests' =>
      'Çok fazla deneme yapıldı. Lütfen biraz sonra tekrar deneyin.',
    'network-request-failed' => 'İnternet bağlantınızı kontrol edin.',
    'requires-recent-login' => 'Güvenliğiniz için lütfen tekrar giriş yapın.',
    _ => 'Giriş yapılamadı ($code).',
  };

  @override
  Future<void> signIn(String email, String password) => _guard(
    () => _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ),
  );

  @override
  Future<void> register(String email, String password) => _guard(
    () => _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ),
  );

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteAccount(String password) => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: user.email!, password: password),
    );
    final uid = user.uid;
    final sessions = await _sessions(uid).get();
    final batch = _db.batch();
    for (final d in sessions.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_patients.doc(uid));
    batch.delete(_users.doc(uid));
    await batch.commit();
    await user.delete();
  });

  @override
  Future<UserRole?> getRole(String uid) => _guard(() async {
    final snap = await _users.doc(uid).get();
    return UserRole.byId(snap.data()?['role']);
  });

  @override
  Future<void> setRole(String uid, UserRole role) => _guard(
    () => _users.doc(uid).set({
      'role': role.id,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    }),
  );

  @override
  Stream<PatientRecord?> watchPatient(String uid) => _patients
      .doc(uid)
      .snapshots()
      .map((s) => s.exists ? PatientRecord.fromMap(s.data()!) : null);

  @override
  Future<void> savePatient(PatientRecord patient) =>
      _guard(() => _patients.doc(patient.uid).set(patient.toMap()));

  @override
  Future<MidwifeRecord?> findMidwifeByInviteCode(String code) =>
      _guard(() async {
        final normalized = code.trim().toUpperCase();
        if (normalized.isEmpty) return null;
        final invite = await _inviteCodes.doc(normalized).get();
        final midwifeId = invite.data()?['midwifeId'] as String?;
        if (midwifeId == null) return null;
        return getMidwife(midwifeId);
      });

  @override
  Future<MidwifeRecord?> getMidwife(String uid) => _guard(() async {
    final snap = await _midwives.doc(uid).get();
    return snap.exists ? MidwifeRecord.fromMap(snap.data()!) : null;
  });

  @override
  Stream<List<ExerciseSession>> watchSessions(String uid) => _sessions(uid)
      .orderBy('startedAt', descending: true)
      .limit(500)
      .snapshots()
      .map(
        (q) => q.docs.map((d) => ExerciseSession.fromMap(d.data())).toList(),
      );

  @override
  Future<void> saveSession(ExerciseSession session) => _guard(
    () => _sessions(session.patientId).doc(session.id).set(session.toMap()),
  );

  @override
  Future<void> createAlert(AlertRecord alert) =>
      _guard(() => _alerts.doc(alert.id).set(alert.toMap()));

  @override
  String newId() => _db.collection('_').doc().id;
}
