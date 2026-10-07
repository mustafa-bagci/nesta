# Teknik Doğrulama Protokolü

Amaç: Nesta'nın ölçtüğü eklem açılarının ve verdiği postür uyarılarının
doğruluğunu referans yöntemlerle karşılaştırmak. Bu aşama gebe katılımcılı
pilot çalışmadan önce, etik kurul onayını beklerken **gebe olmayan
gönüllülerle** başlatılabilir; ardından az sayıda gebeyle tekrarlanır.

## 1. Katılımcılar

- Aşama A: 10–15 sağlıklı, gebe olmayan gönüllü kadın
- Aşama B (etik onaydan sonra): ikinci veya üçüncü trimesterde, egzersize engel
  durumu olmayan 10 gebe

## 2. Düzenek

- Telefon, yerden 40–60 cm yükseklikte sabit bir sehpada, katılımcıdan
  yaklaşık 2 m uzakta. Kamera ekseni hareket düzlemine dik olmalıdır.
- Aynı anda ikinci bir kamera (referans video, 30 fps) aynı açıdan kayıt yapar.
- Işık: gün ışığı veya eşit tavan aydınlatması; arkadan ışık olmamalı.
- Eklem merkezlerine (büyük trokanter, lateral femoral epikondil, lateral
  malleol, akromiyon, lateral epikondil, ulnar stiloid) cilt üstü işaretleyici.

## 3. Referans ölçüm

- **Kinovea** (ücretsiz, açık kaynak 2B hareket analizi) ile referans videoda
  işaretleyicilerden açı ölçümü
- Statik pozisyonlarda ek olarak **gonyometre**
- Postür hatası etiketleri: iki uzman (ebe ve fizyoterapist) referans videoyu
  birbirinden bağımsız izleyerek her tekrarı "doğru / hatalı (hangi kural)"
  olarak etiketler. Uzmanlar arası uyum Cohen κ ile raporlanır.

## 4. Görevler

Her katılımcı kameralı her egzersizi (Kedi-İnek, Destekli Plié Squat, Ayakta
Yana Esneme, Oturarak Kol Kaldırma, Yan Yatarak Bacak Kaldırma, Kuş-Köpek,
Duvarda Pelvik Tilt) şu sırayla yapar:

1. Doğru biçimde 5 tekrar (veya 20 sn)
2. Her kural için yönlendirilmiş hatalı biçimde 3 tekrar (ör. dizleri içe
   kaçırma, gövdeyi öne eğme)

## 5. Kayıt

Uygulamada **Profil → Araştırma modu (kare kaydı)** açılır. Kameralı her
seansta her karenin zaman damgası, 13 eklemin koordinatı ve görünürlük
olasılığı, kural ölçümleri (açı/oran), aktif ihlaller ve tekrar sayısı
telefonda bir CSV dosyasına yazılır. Görüntü kaydedilmez. Dosyalar **Kare
kayıtlarını paylaş** ile bilgisayara aktarılır. Referans video, ilk karedeki
ortak bir işaretle (ör. el çırpma) eşzamanlanır.

Aynı kayıtlar, uzman etiketleriyle birleştirildiğinde doğru/hatalı hareket
sınıflandırıcısı için eğitim veri setini oluşturur (bkz. TEKNIK.md, yol
haritası).

## 6. Analiz

| Soru | Yöntem | Kabul ölçütü (önceden belirlenmiş) |
|---|---|---|
| Açı ölçümleri referansla uyumlu mu? | ICC(2,1), mutlak uyum; ortalama mutlak hata (°); Bland–Altman uyum sınırları | ICC ≥ 0,75 (Koo ve Li, 2016); MAE ≤ 10° |
| Hatalı postür doğru yakalanıyor mu? | Kural bazında duyarlılık, özgüllük, F1 (uzman etiketi referans) | Duyarlılık ≥ %80, özgüllük ≥ %80 |
| Tekrarlar doğru sayılıyor mu? | Sayılan / gerçek tekrar | Hata ≤ 1 tekrar / set |
| Uyarı ne kadar sürede geliyor? | Hatanın başlangıcı ile sesli uyarı arasındaki süre | ≤ 2 sn |
| Nabız uyarısı ne kadar sürede geliyor? | Saatteki eşik aşımı ile uygulamadaki uyarı arası süre (saat modeline göre ayrı) | Raporlanır |

Kabul ölçütünü karşılamayan kurallar için eşikler güncellenir veya kural
kaldırılır. Güncel değerler `docs/EGZERSIZ_KATALOGU.md` dosyasına yansır.

## 7. Raporlama

Sonuçlar proje raporunun **Bulgular** bölümünde tablo halinde verilir:
egzersiz ve kural bazında ICC (%95 GA), MAE, duyarlılık ve özgüllük, ayrıca
Bland–Altman grafikleri.
