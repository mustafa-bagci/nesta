/// KVKK aydınlatma metni ve açık rıza metinleri.
///
/// Bu metinler taslaktır; yayına almadan önce kurumun KVKK birimi veya
/// hukuk danışmanı tarafından gözden geçirilmelidir. Metin değiştiğinde
/// [consentVersion] artırılmalıdır; uygulama yeni sürüm için tekrar onay ister.
library;

const consentVersion = '2026-10-v1';

const privacyNoticeTitle = 'Kişisel Verilerin Korunması Aydınlatma Metni';

const privacyNotice = <String>[
  '6698 sayılı Kişisel Verilerin Korunması Kanunu ("KVKK") kapsamında, Nesta '
      'uygulamasını kullanmanız sırasında işlenen kişisel verileriniz '
      'hakkında sizi bilgilendirmek isteriz.',
  'İşlenen veriler: Ad-soyad, doğum tarihi, iletişim bilgisi; gebelik haftası, '
      'boy-kilo, risk faktörleri ve kontrendikasyon tarama yanıtları; egzersiz '
      'seansı kayıtları (süre, tekrar sayısı, postür uyarıları), akıllı saatten '
      'okunan nabız değerleri, algılanan zorlanma puanı ve bildirdiğiniz '
      'belirtiler. Bu verilerin bir kısmı KVKK\'nın 6. maddesi uyarınca özel '
      'nitelikli kişisel veri (sağlık verisi) niteliğindedir.',
  'Kamera görüntüsü: Egzersiz sırasında kamera görüntünüz yalnızca '
      'telefonunuzda, anlık olarak işlenir. Görüntü kaydedilmez, saklanmaz ve '
      'hiçbir sunucuya gönderilmez. Yalnızca hesaplanan eklem açıları ve uyarı '
      'sayıları kaydedilir.',
  'İşleme amacı: Size güvenli ve kişiselleştirilmiş bir egzersiz programı '
      'sunulması, egzersiz sırasında güvenlik uyarılarının verilmesi ve '
      'bağlı olduğunuz ebe/hekimin sizi izleyebilmesi.',
  'Aktarım: Verileriniz yalnızca bağlandığınız ebe/hekim ile paylaşılır. '
      'Veriler, Google Firebase altyapısında şifreli olarak saklanır; bu '
      'hizmet sağlayıcının sunucuları yurt dışında bulunabilir. Bu nedenle '
      'yurt dışına aktarım için ayrıca açık rızanız alınmaktadır.',
  'Haklarınız: KVKK\'nın 11. maddesi uyarınca verilerinizin işlenip '
      'işlenmediğini öğrenme, düzeltilmesini veya silinmesini isteme ve '
      'açık rızanızı geri alma haklarına sahipsiniz. Uygulama içindeki '
      '"Verilerimi indir" ve "Hesabımı sil" seçeneklerini kullanabilir veya '
      'proje ekibiyle iletişime geçebilirsiniz.',
];

const healthDataConsentText =
    'Sağlık verilerimin, egzersiz programımın yürütülmesi ve bağlı olduğum '
    'ebe/hekim tarafından izlenmesi amacıyla işlenmesine ve bu amaçla yurt '
    'dışındaki sunucularda saklanmasına açık rıza veriyorum. (Zorunlu)';

const researchConsentText =
    'Kimliğimi açığa çıkarmayacak şekilde anonimleştirilmiş verilerimin '
    'bilimsel araştırmada kullanılmasına açık rıza veriyorum. (İsteğe bağlı)';

const medicalDisclaimer =
    'Nesta tanı koymaz ve ebe/hekim kontrolünün yerine geçmez. Egzersiz '
    'programına yalnızca ebenizin veya hekiminizin onayıyla başlayın. Acil '
    'durumlarda 112\'yi arayın.';
