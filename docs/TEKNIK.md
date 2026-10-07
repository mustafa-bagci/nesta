# Nesta Teknik Belge

## 1. Mimari

```
┌──────────────────────────┐        ┌──────────────────────────┐
│  Gebe uygulaması          │        │  Ebe paneli (web)         │
│  Flutter · Android / iOS  │        │  Flutter web              │
│                           │        │                           │
│  Kamera ─► ML Kit poz ─┐  │        │  Onay · uyarılar · grafik │
│  (cihaz üzerinde)      ▼  │        │  anonim CSV               │
│  nesta_core postür motoru │        └────────────┬─────────────┘
│  Sesli koç (TTS, tr-TR)   │                     │
│  Health Connect/HealthKit │                     │
└────────────┬─────────────┘                     │
             │  yalnızca sayısal sonuçlar         │
             ▼                                    ▼
      ┌──────────────────────────────────────────────┐
      │ Firebase Authentication + Cloud Firestore     │
      │ (güvenlik kuralları: firebase/firestore.rules) │
      └──────────────────────────────────────────────┘
```

- **nesta_core**: Flutter'dan bağımsız saf Dart paketi. Egzersiz kütüphanesi,
  postür kuralları, tekrar sayacı, nabız eşikleri, tarama soruları, veri
  modelleri ve CSV dışa aktarımı burada bulunur. Mobil uygulama ve panel aynı
  kodu kullanır. Paketin kendi birim testleri vardır.
- **Kamera görüntüsü telefondan çıkmaz.** Her kare cihaz üzerindeki ML Kit poz
  modeline verilir ve 33 eklem noktası alınır. Görüntü bellekten hemen atılır.
  Buluta yalnızca seans özeti (süre, tekrar, form puanı, uyarı sayıları, nabız
  özeti) yazılır.
- **Çevrimdışı çalışma**: Firestore'un yerel önbelleği sayesinde seanslar
  internet yokken kaydedilir ve bağlantı gelince eşitlenir.

## 2. Postür analizi algoritması

1. **Poz tahmini**: Google ML Kit Pose Detection (BlazePose tabanlı, 33 nokta,
   akış modu). Her nokta için görünürlük olasılığı (0–1) üretilir. 0,5 altındaki
   noktalar "görünmüyor" sayılır.
2. **Görünürlük denetimi**: Her egzersiz için gerekli eklemler tanımlıdır.
   Yandan çekimde kameraya dönük taraf, görünürlük olasılıkları karşılaştırılarak
   otomatik seçilir. Vücut 1,5 sn görünmezse konumlanma uyarısı verilir.
3. **Ölçümler**: Üç nokta arasındaki eklem açısı (ör. kalça–diz–ayak bileği),
   bir doğrunun düşey veya yatayla açısı, yükseklik açısı ve iki eklem çifti
   arasındaki genişlik oranı.
4. **Yumuşatma**: Titremeyi azaltmak için üstel hareketli ortalama (α = 0,4).
5. **Kural değerlendirmesi**:
   - Ölçüm güvenli aralığın dışına çıkar ve **800 ms** sürerse ihlal başlar.
   - İhlalin bitmesi için ölçümün aralığın **4° (oranlarda 5 puan) içine**
     dönmesi gerekir (histerezis). Böylece sınırda titreşen değer art arda
     uyarı üretmez.
   - Aynı kural için iki sesli uyarı arasında en az **6 sn**, herhangi iki
     uyarı arasında en az **2,5 sn** bırakılır.
6. **Tekrar sayımı**: Her egzersizde bir ölçüm için iki eşik vardır
   (ör. diz açısı 140° altına inip 155° üstüne çıkınca bir tekrar sayılır).
7. **Form puanı**: Vücudun göründüğü sürenin, hiçbir kuralın ihlal edilmediği
   kısmının yüzdesi.

Kurallar egzersiz demo animasyonlarıyla birlikte tanımlanır. Testler, her
egzersizin doğru hareketinin hiç uyarı üretmediğini ve tipik hatalı
hareketlerin yakalandığını doğrular (`packages/nesta_core/test`).

Tüm eşikler [EGZERSIZ_KATALOGU.md](EGZERSIZ_KATALOGU.md) dosyasında listelenir.
Eşikler **başlangıç değerleridir**; uzman paneli ve teknik doğrulama sonuçlarına
göre güncellenmelidir.

## 3. Güvenlik katmanı

| Katman | Kaynak | Davranış |
|---|---|---|
| Kontrendikasyon taraması | ACOG (2020), 10 mutlak + 13 göreceli soru | Mutlak varsa program açılmaz; göreceli olanlar ebe ekranında vurgulanır |
| Ebe onayı | — | Onay olmadan program açılmaz; gebe kendini onaylayamaz (sunucu kuralı) |
| Ebe kısıtlaması | — | Ebe her gebe için tek tek egzersiz kapatabilir ve not yazabilir |
| Trimester filtresi | Klinik pilates ilkeleri | Sırtüstü egzersiz yok; Kuş-Köpek 3. trimesterde kapalı |
| Seans öncesi belirti sorgusu | ACOG (2020) bırakma belirtileri | Belirti varsa seans başlamaz, ebeye uyarı gider; acil belirtide 112 yönlendirmesi |
| Seans sırasında belirti | — | "Kendimi iyi hissetmiyorum" ile anında durdurma ve ebeye acil uyarı |
| Nabız | Kanada (2019) kılavuzu, yaş ve BKİ'ye göre hedef aralık | Hedef üstü 15 sn: uyarı. Hedef + 15 atım/dk'da 10 sn veya hedef üstünde 90 sn: seans durur, ebeye acil uyarı |
| Nabzı etkileyen ilaç | — | Nabız eşiği yerine 3 dakikada bir konuşma testi ve Borg RPE |
| Tarama değişikliği | — | Onaylı gebe taramayı değiştirirse onay yeniden "bekliyor"a döner ve ebeye bildirim gider |

## 4. Veri güvenliği ve KVKK

- **Erişim kuralları** (`firebase/firestore.rules`), 26 otomatik testle
  doğrulanır:
  - Gebe yalnızca kendi kaydını ve seanslarını görür.
  - Ebe yalnızca kendisine bağlı gebeleri görür ve yalnızca onay alanını
    değiştirebilir.
  - Davet kodları listelenemez.
  - Uyarıları yalnızca ilgili ebe görür ve yalnızca "görüldü" olarak
    işaretleyebilir.
- **Katmanlı açık rıza**: Sağlık verisinin işlenmesi zorunludur, araştırmada
  kullanılması isteğe bağlıdır. Rıza metninin sürümü kaydedilir; metin
  değişirse yeniden onay istenir.
- **Veri taşınabilirliği ve silme**: Gebe verilerini CSV/JSON olarak indirebilir
  ve hesabını tüm verileriyle silebilir.
- **Anonim araştırma verisi**: Dışa aktarımda kimlik bilgileri ve sistem
  kimlikleri çıkarılır.
- **Ağ**: Panel, Flutter çalışma dosyalarını ve yazı tipini kendi sunucusundan
  sunar; üçüncü taraf CDN'e istek yapmaz.

## 5. Teknoloji ve sürümler

| Bileşen | Teknoloji |
|---|---|
| Uygulama çatısı | Flutter 3.47 / Dart 3.13 |
| Poz tahmini | google_mlkit_pose_detection (cihaz üzerinde) |
| Kamera | camera (Android CameraX, iOS AVFoundation) |
| Sesli koç | flutter_tts (Türkçe) |
| Nabız | health (Android Health Connect, iOS HealthKit) |
| Kimlik doğrulama ve veri | Firebase Auth, Cloud Firestore |
| Durum yönetimi ve yönlendirme | provider, go_router |
| Yazı tipi | Inter (SIL OFL 1.1, uygulamaya gömülü) |
| CI | GitHub Actions (test, APK, web derlemesi, kural testleri) |

## 6. Bilinen sınırlamalar

- Tek kamerayla iki boyutlu analiz yapılır. Kamera açısı, ışık ve yerde yapılan
  egzersizlerde vücudun bir kısmının görünmemesi doğruluğu etkiler.
- Poz modeli gebe vücut oranları için ayrıca eğitilmemiştir. Doğruluk teknik
  doğrulama ile ölçülmelidir.
- Akıllı saatler nabzı Health Connect/Apple Sağlık'a gecikmeli yazabilir
  (birkaç saniye ile birkaç dakika). Bu nedenle nabız uyarıları saatin aktarım
  sıklığına bağlıdır.
- Pelvik taban kas fonksiyonu kamerayla ölçülemez. Bu egzersiz sesli rehberle
  yürütülür.
- Uygulama tanı koymaz. Yaygın kullanım öncesinde tıbbi cihaz yazılımı
  mevzuatı kapsamında değerlendirilmelidir.

## 7. Geliştirme yol haritası

1. Uzman paneliyle eşiklerin kesinleştirilmesi (kapsam geçerlik indeksi)
2. Gebe gönüllülerle etiketli eklem noktası veri seti; kural tabanlı
   denetimin, doğru/hatalı hareketi ayırt eden zamansal bir sınıflandırıcıyla
   (LSTM / 1D-CNN) karşılaştırılması
3. Bluetooth (BLE) nabız bandı desteğiyle saniye düzeyinde nabız
4. Doğum sonu modülü
5. Hastane bilgi sistemleriyle (HL7 FHIR) entegrasyon
