# Araştırma Verisi Sözlüğü

Ebe panelindeki **Araştırma Verisi** bölümü iki CSV dosyası üretir. Dosyalar
UTF-8 (BOM'lu) kodlanır ve Excel, SPSS ve R ile doğrudan açılır.

**Yalnızca araştırmaya katılım için açık rıza veren gebelerin verisi** dışa
aktarılır. Ad, telefon, e-posta, doğum tarihi ve sistem kimlikleri çıkarılır.
Katılımcılara kayıt sırasına göre `K001`, `K002`… kodu, seanslara `S00001`…
sıra numarası verilir.

## nesta_seanslar_YYYY-AA-GG.csv (seans düzeyi)

| Sütun | Açıklama | Birim / değerler |
|---|---|---|
| `katilimci` | Katılımcı kodu | K001… |
| `seans_id` | Seans sıra numarası | S00001… |
| `egzersiz_id` | Egzersiz kimliği | bkz. EGZERSIZ_KATALOGU.md |
| `egzersiz` | Egzersiz adı | metin |
| `baslangic`, `bitis` | Seans başlangıç ve bitişi | ISO 8601, UTC |
| `sure_sn` | Seans süresi | saniye |
| `gebelik_haftasi` | Seans günündeki gebelik haftası | hafta |
| `bitis_nedeni` | Seansın nasıl bittiği | `completed` tamamlandı, `user_stopped` kullanıcı bitirdi, `symptom` tehlike belirtisi, `heart_rate` nabız sınırı |
| `tekrar` | Sayılan tekrar (rehberli egzersizde tamamlanan döngü) | adet |
| `form_puani` | Vücudun göründüğü sürenin doğru postürde geçen yüzdesi; kamerasız seanslarda boş | 0–100 |
| `postur_uyari_sayisi` | Verilen toplam postür uyarısı | adet |
| `uyari_detay` | Kural bazında uyarı sayıları | `kural:adet\|kural:adet` |
| `nabiz_min`, `nabiz_ort`, `nabiz_maks` | Seans boyunca nabız | atım/dk |
| `hedef_ustu_sn` | Hedef aralığın üzerinde geçen süre | saniye |
| `rpe` | Borg algılanan zorlanma | 6–20 |
| `oncesi_belirti` | Seans öncesi bildirilen belirtiler | belirti kimlikleri, `\|` ile ayrılmış |
| `sonrasi_belirti` | Seans sırası/sonrası bildirilen belirtiler | belirti kimlikleri |

Belirti kimlikleri: `vaginal_bleeding` vajinal kanama, `contractions` düzenli
ağrılı kasılma, `fluid_leakage` sıvı gelmesi, `chest_pain` göğüs ağrısı,
`reduced_fetal_movement` bebek hareketlerinde azalma, `dyspnea` nefes darlığı,
`dizziness` baş dönmesi, `headache` baş ağrısı, `muscle_weakness` kas
güçsüzlüğü, `calf_pain` baldır ağrısı/şişlik.

## nesta_katilimcilar_YYYY-AA-GG.csv (katılımcı düzeyi)

| Sütun | Açıklama |
|---|---|
| `katilimci` | Katılımcı kodu |
| `yas` | Dışa aktarma günündeki yaş |
| `gebelik_haftasi`, `trimester` | Dışa aktarma günündeki gebelik haftası ve trimester |
| `bki` | Gebelik öncesi beden kitle indeksi |
| `risk_faktorleri` | `\|` ile ayrılmış risk faktörü kimlikleri (ör. `gestational_diabetes`) |
| `tarama_sonucu` | `eligible` uygun, `needs_review` değerlendirme gerekli, `ineligible` egzersiz önerilmez |
| `onay_durumu` | `approved`, `pending`, `rejected`, `not_requested` |
| `seans_sayisi` | Toplam seans |
| `toplam_dakika` | Toplam egzersiz süresi |
| `ort_form_puani` | Kamera ile izlenen seansların ortalama form puanı |
| `guvenlik_durdurma` | Belirti veya nabız nedeniyle durdurulan seans sayısı |

## Uygulanabilirlik ölçütlerinin hesaplanması

| Ölçüt | Hesap |
|---|---|
| Tamamlama oranı | 8. haftada aktif katılımcı / başlayan katılımcı |
| Seans uyumu | Gerçekleşen seans günü / planlanan seans günü (haftada 3 × 8 hafta) |
| Güvenlik | `bitis_nedeni` = `symptom` veya `heart_rate` olan seans sayısı ve oranı |
| Uyarı yanıtı | Uyarı sonrası postür düzeltme: `form_puani` ile birlikte değerlendirilir |
