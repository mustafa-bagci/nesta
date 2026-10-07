import 'package:nesta_core/nesta_core.dart';

/// Ebe paneli veri işlemleri.
abstract class PanelRepository {
  bool get isDemo;

  Stream<String?> authStateChanges();
  String? get currentEmail;

  Future<void> signIn(String email, String password);
  Future<void> signOut();
  Future<void> sendPasswordReset(String email);

  /// Yeni ebe hesabı açar ve benzersiz bir davet kodu üretir.
  Future<void> registerMidwife({
    required String email,
    required String password,
    required String fullName,
    required String title,
    required String institution,
  });

  Future<UserRole?> getRole(String uid);
  Stream<MidwifeRecord?> watchMidwife(String uid);

  /// Ebeye bağlı gebeler.
  Stream<List<PatientRecord>> watchPatients(String midwifeId);
  Stream<List<ExerciseSession>> watchSessions(String patientId);
  Stream<List<AlertRecord>> watchAlerts(String midwifeId);

  Future<void> updateClearance(String patientId, Clearance clearance);
  Future<void> acknowledgeAlert(String alertId);
}

class PanelException implements Exception {
  const PanelException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Karışıklığa yol açan karakterler (0/O, 1/I) çıkarılmış davet kodu alfabesi.
const inviteAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
