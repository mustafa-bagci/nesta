import 'package:nesta_core/nesta_core.dart';

/// Kimlik doğrulama ve veri işlemleri için ortak arayüz.
///
/// [FirebaseRepository] gerçek bulut altyapısını, [DemoRepository] ise
/// internet ve hesap gerektirmeyen yerel demo modunu sağlar.
abstract class NestaRepository {
  bool get isDemo;

  /// Oturum açmış kullanıcının kimliği (yoksa null).
  Stream<String?> authStateChanges();
  String? get currentUid;
  String? get currentEmail;

  Future<void> signIn(String email, String password);
  Future<void> register(String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();

  /// Hesabı ve tüm verileri siler. Güvenlik gereği [password] ile yeniden
  /// kimlik doğrulaması yapılır.
  Future<void> deleteAccount(String password);

  Future<UserRole?> getRole(String uid);
  Future<void> setRole(String uid, UserRole role);

  Stream<PatientRecord?> watchPatient(String uid);
  Future<void> savePatient(PatientRecord patient);

  Future<MidwifeRecord?> findMidwifeByInviteCode(String code);
  Future<MidwifeRecord?> getMidwife(String uid);

  Stream<List<ExerciseSession>> watchSessions(String uid);
  Future<void> saveSession(ExerciseSession session);

  Future<void> createAlert(AlertRecord alert);

  String newId();
}

/// Kullanıcıya gösterilecek Türkçe hata.
class RepositoryException implements Exception {
  const RepositoryException(this.message);
  final String message;

  @override
  String toString() => message;
}
