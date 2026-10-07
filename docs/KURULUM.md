# Kurulum ve Yayın

Bu belge Nesta'yı demo modundan gerçek kullanıma geçirmek için gereken adımları
anlatır. Komutlar macOS, Linux veya Windows'ta (PowerShell) çalışır.

## 1. Gerekenler

| Araç | Sürüm | Not |
|---|---|---|
| Flutter | 3.47 veya üzeri (stable) | `flutter doctor` ile kontrol edin |
| Android Studio | güncel | Android SDK ve emülatör için |
| Xcode | 16 veya üzeri | Yalnızca iPhone sürümü için, **Mac gerekir** |
| Node.js | 22 | Firebase CLI ve kural testleri için |
| Java | 21 | Firestore emülatörü için |
| Firebase CLI | `npm i -g firebase-tools` | |
| FlutterFire CLI | `dart pub global activate flutterfire_cli` | |

## 2. Demo modunda deneme

Firebase kurulmadan her iki uygulama da demo modunda açılır.

```bash
cd apps/mobile
flutter pub get
flutter run            # bağlı Android telefon veya emülatör
```

- Kayıt ekranında herhangi bir e-posta ve 6+ karakterli şifre kullanın.
- Ebe davet kodu: **NESTA1**. Onay 3 saniye içinde otomatik verilir.
- Seans sırasında nabız göstergesine **uzun basarak** nabız yükselmesi
  simüle edilir. Güvenlik uyarısını jüriye göstermek için kullanılabilir.

```bash
cd apps/panel
flutter run -d chrome  # örnek verilerle ebe paneli
```

Firebase yapılandırılmış olsa bile demo modu zorlanabilir:
`flutter run --dart-define=NESTA_DEMO=true`.

## 3. Firebase projesi

1. <https://console.firebase.google.com> üzerinden yeni proje açın
   (ör. `nesta-tubitak`). Google Analytics gerekmez.
2. **Authentication → Sign-in method**: *E-posta/Şifre*yi etkinleştirin.
3. **Firestore Database → Create database**:
   - Konum olarak Avrupa bölgesi seçin (ör. `eur3` veya `europe-west3`
     Frankfurt). KVKK açısından veri konumu aydınlatma metninde belirtilmelidir.
   - *Production mode* ile başlatın. Kurallar bir sonraki adımda yüklenecek.
4. Kuralları ve indeksleri yükleyin:

   ```bash
   cd firebase
   npm ci
   npm test                      # kurallar emülatörde test edilir (26 test)
   npx firebase login
   npx firebase use --add        # projenizi seçin
   npx firebase deploy --only firestore
   ```

5. Uygulamaları projeye bağlayın. Her uygulama klasöründe çalıştırın; komut
   `lib/firebase_options.dart` dosyasını oluşturur:

   ```bash
   cd apps/mobile && flutterfire configure --platforms=android,ios
   cd ../panel   && flutterfire configure --platforms=web
   ```

   Uygulama bu dosyayı bulduğunda demo modundan çıkar ve Firebase'i kullanır.

## 4. Ebe paneli yayını

```bash
cd apps/panel
flutter build web --release --no-web-resources-cdn
cd ../../firebase
npx firebase deploy --only hosting
```

Panel `https://<proje-adı>.web.app` adresinde yayınlanır. `--no-web-resources-cdn`
seçeneği Flutter çalışma dosyalarını Google CDN'i yerine kendi sunucunuzdan
sunar.

İlk ebe hesabı panelden **Yeni hesap** ile açılır. Hesap açılınca 6 haneli
davet kodu oluşur. Gebeler bu kodla ebeye bağlanır.

## 5. Android

### Test için APK

```bash
cd apps/mobile
flutter build apk --release
# çıktı: build/app/outputs/flutter-apk/app-release.apk
```

GitHub Actions her gönderimde bu APK'yı otomatik üretir: depoda
**Actions → son çalışma → Artifacts → nesta-android-apk**.

### Yayın imzası (Google Play için)

```bash
keytool -genkey -v -keystore nesta-release.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias nesta
```

`nesta-release.jks` dosyasını `apps/mobile/android/app/` içine koyun ve
`apps/mobile/android/key.properties` dosyasını oluşturun:

```properties
storePassword=<şifre>
keyPassword=<şifre>
keyAlias=nesta
storeFile=nesta-release.jks
```

Bu dosyalar `.gitignore` kapsamındadır; **depoya eklemeyin**. Play Store için
`flutter build appbundle --release` kullanın.

### Akıllı saat (Health Connect)

- Android 14 ve üzerinde Health Connect sistemde yerleşiktir. Daha eski
  sürümlerde Play Store'dan *Health Connect* yüklenmelidir; uygulama gerekirse
  yükleme sayfasını açar.
- Saatin uygulaması (Samsung Health, Fitbit, Google Fit vb.) nabız verisini
  Health Connect ile paylaşacak şekilde ayarlanmalıdır.
- Google Play'de sağlık izinleri için gizlilik politikası adresi gerekir:
  `--dart-define=NESTA_PRIVACY_URL=https://...` ile verilir.

## 6. iOS (Mac gerekir)

```bash
cd apps/mobile
flutter pub get
cd ios && pod install && cd ..
open ios/Runner.xcworkspace
```

Xcode'da:

1. *Runner → Signing & Capabilities*: Apple geliştirici hesabınızı (Team)
   seçin.
2. *+ Capability* ile **HealthKit**'i ekleyin. Yetki dosyası
   (`Runner.entitlements`) hazırdır.
3. Telefonu bağlayıp `flutter run --release` çalıştırın.

Asgari iOS sürümü 15.5'tir (ML Kit gereksinimi).

## 7. GitHub Actions gizli anahtarları (isteğe bağlı)

CI'da üretilen APK'nın gerçek Firebase'e bağlanması ve imzalı olması için
*Settings → Secrets and variables → Actions* altına şunları ekleyin:

| Ad | İçerik |
|---|---|
| `FIREBASE_OPTIONS_MOBILE` | `base64 -w0 apps/mobile/lib/firebase_options.dart` çıktısı |
| `FIREBASE_OPTIONS_PANEL` | `base64 -w0 apps/panel/lib/firebase_options.dart` çıktısı |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 nesta-release.jks` çıktısı |
| `ANDROID_KEY_PROPERTIES` | `key.properties` dosyasının içeriği |

Bu anahtarlar olmadan CI demo modunda, hata ayıklama anahtarıyla imzalı APK üretir.

## 8. Pilot çalışma öncesi kontrol listesi

- [ ] Etik kurul onayı ve kurum izni alındı
- [ ] Aydınlatma metni ve açık rıza metinleri (`packages/nesta_core/lib/src/content/consent.dart`)
      kurumun KVKK birimince onaylandı; veri sorumlusu ve iletişim bilgisi eklendi
- [ ] Egzersiz kataloğu ve eşikler (`docs/EGZERSIZ_KATALOGU.md`) uzman panelince onaylandı
- [ ] Teknik doğrulama (`docs/DOGRULAMA_PROTOKOLU.md`) tamamlandı
- [ ] Firestore kuralları yüklendi, panel yayında, ebe hesapları açıldı
- [ ] Katılımcı telefonlarına APK kuruldu, saat bağlantısı test edildi
