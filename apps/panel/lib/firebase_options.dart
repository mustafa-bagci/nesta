// Bu dosya `flutterfire configure` komutu ile kendi Firebase projenizin
// ayarlarıyla değiştirilmelidir (bkz. docs/KURULUM.md). Değiştirilene kadar
// panel örnek verili demo modunda çalışır.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
    'Firebase henüz yapılandırılmadı. `flutterfire configure` çalıştırın.',
  );
}
