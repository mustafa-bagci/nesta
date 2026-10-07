import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nesta_core/nesta_core.dart';

import 'panel_repository.dart';

class FirebasePanelRepository implements PanelRepository {
  FirebasePanelRepository({FirebaseAuth? auth, FirebaseFirestore? db})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final _random = Random.secure();

  @override
  bool get isDemo => false;

  @override
  Stream<String?> authStateChanges() =>
      _auth.authStateChanges().map((u) => u?.uid);

  @override
  String? get currentEmail => _auth.currentUser?.email;

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on FirebaseAuthException catch (e) {
      throw PanelException(switch (e.code) {
        'invalid-email' => 'E-posta adresi geçersiz.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' => 'E-posta veya şifre hatalı.',
        'email-already-in-use' => 'Bu e-posta adresiyle zaten bir hesap var.',
        'weak-password' => 'Şifre en az 6 karakter olmalıdır.',
        'too-many-requests' =>
          'Çok fazla deneme yapıldı. Biraz sonra tekrar deneyin.',
        _ => 'Giriş yapılamadı (${e.code}).',
      });
    } on FirebaseException catch (e) {
      throw PanelException(
        e.code == 'permission-denied'
            ? 'Bu işlem için yetkiniz yok.'
            : 'Beklenmeyen bir hata oluştu (${e.code}).',
      );
    }
  }

  @override
  Future<void> signIn(String email, String password) => _guard(
    () => _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ),
  );

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  String _code() => List.generate(
    6,
    (_) => inviteAlphabet[_random.nextInt(inviteAlphabet.length)],
  ).join();

  @override
  Future<void> registerMidwife({
    required String email,
    required String password,
    required String fullName,
    required String title,
    required String institution,
  }) => _guard(() async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = cred.user!.uid;
    await _db.collection('users').doc(uid).set({
      'role': UserRole.midwife.id,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    // Benzersiz davet kodu: çakışma olursa yeniden üret.
    late String code;
    for (var attempt = 0; attempt < 10; attempt++) {
      code = _code();
      final ref = _db.collection('inviteCodes').doc(code);
      final created = await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (snap.exists) return false;
        tx.set(ref, {'midwifeId': uid});
        return true;
      });
      if (created) break;
    }
    await _db
        .collection('midwives')
        .doc(uid)
        .set(
          MidwifeRecord(
            uid: uid,
            fullName: fullName.trim(),
            title: title.trim(),
            institution: institution.trim(),
            inviteCode: code,
          ).toMap(),
        );
  });

  @override
  Future<UserRole?> getRole(String uid) => _guard(() async {
    final s = await _db.collection('users').doc(uid).get();
    return UserRole.byId(s.data()?['role']);
  });

  @override
  Stream<MidwifeRecord?> watchMidwife(String uid) => _db
      .collection('midwives')
      .doc(uid)
      .snapshots()
      .map((s) => s.exists ? MidwifeRecord.fromMap(s.data()!) : null);

  @override
  Stream<List<PatientRecord>> watchPatients(String midwifeId) => _db
      .collection('patients')
      .where('midwifeId', isEqualTo: midwifeId)
      .snapshots()
      .map((q) => q.docs.map((d) => PatientRecord.fromMap(d.data())).toList());

  @override
  Stream<List<ExerciseSession>> watchSessions(String patientId) => _db
      .collection('patients')
      .doc(patientId)
      .collection('sessions')
      .orderBy('startedAt', descending: true)
      .limit(500)
      .snapshots()
      .map(
        (q) => q.docs.map((d) => ExerciseSession.fromMap(d.data())).toList(),
      );

  @override
  Stream<List<AlertRecord>> watchAlerts(String midwifeId) => _db
      .collection('alerts')
      .where('midwifeId', isEqualTo: midwifeId)
      .orderBy('createdAt', descending: true)
      .limit(300)
      .snapshots()
      .map((q) => q.docs.map((d) => AlertRecord.fromMap(d.data())).toList());

  @override
  Future<void> updateClearance(String patientId, Clearance clearance) => _guard(
    () => _db.collection('patients').doc(patientId).update({
      'clearance': clearance.toMap(),
      'updatedAt': DateTime.now().toUtc().millisecondsSinceEpoch,
    }),
  );

  @override
  Future<void> acknowledgeAlert(String alertId) => _guard(
    () => _db.collection('alerts').doc(alertId).update({
      'acknowledgedAt': DateTime.now().toUtc().millisecondsSinceEpoch,
    }),
  );
}
