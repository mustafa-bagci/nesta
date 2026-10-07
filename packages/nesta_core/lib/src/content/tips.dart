/// İpuçları sayfasının içeriği.
library;

class Tip {
  const Tip({
    required this.id,
    required this.title,
    required this.summary,
    required this.body,
    required this.icon,
  });

  final String id;
  final String title;
  final String summary;
  final List<String> body;

  /// Arayüzde kullanılan simge anahtarı.
  final String icon;
}

const tips = <Tip>[
  Tip(
    id: 'beslenme',
    title: 'Dengeli Beslenme',
    summary: 'Gebelikte öğünlerinizi düzenli ve çeşitli tutun.',
    icon: 'nutrition',
    body: [
      'Günde 3 ana ve 2–3 ara öğün tüketmek kan şekerinizi dengede tutar.',
      'Sebze, meyve, tam tahıl, süt ürünleri ve iyi pişmiş protein kaynaklarına yer verin.',
      'Gestasyonel diyabetiniz varsa ebenizin ve diyetisyeninizin önerdiği plana uyun; egzersizden önce hafif bir ara öğün alın.',
    ],
  ),
  Tip(
    id: 'su',
    title: 'Bol Su İçin',
    summary: 'Egzersiz öncesinde, sırasında ve sonrasında su için.',
    icon: 'water',
    body: [
      'Gün boyunca düzenli aralıklarla su için; idrar renginizin açık olması yeterli sıvı aldığınızı gösterir.',
      'Egzersize başlamadan önce ve egzersiz sırasında küçük yudumlarla su için.',
      'Sıcak ve nemli ortamlarda egzersiz yapmaktan kaçının.',
    ],
  ),
  Tip(
    id: 'stres',
    title: 'Stres Kontrolü',
    summary: 'Nefes egzersizleri ve dinlenme ile stresi azaltın.',
    icon: 'mind',
    body: [
      'Diyafram nefesi gibi yavaş nefes egzersizleri kalp hızını ve kaygıyı azaltır.',
      'Gün içinde kısa molalar verin ve kendinize dinlenme zamanı ayırın.',
      'Uzun süren kaygı veya mutsuzluk hissini ebenizle paylaşın.',
    ],
  ),
  Tip(
    id: 'pelvik_taban',
    title: 'Pelvik Taban Sağlığı',
    summary: 'Düzenli Kegel egzersizi idrar kaçırmayı önler.',
    icon: 'pelvic',
    body: [
      'Pelvik taban kasları rahmi, mesaneyi ve bağırsakları destekler.',
      'Günde en az bir set pelvik taban egzersizi yapmanız önerilir.',
      'Kasılma sırasında nefesinizi tutmayın; karın ve kalça kaslarınızı gevşek bırakın.',
    ],
  ),
  Tip(
    id: 'hafif_egzersiz',
    title: 'Hafif Egzersizler',
    summary: 'Haftada en az 150 dakika orta şiddette hareket hedefleyin.',
    icon: 'activity',
    body: [
      'Komplikasyonsuz gebeliklerde haftada en az 150 dakika orta şiddetli aktivite önerilir; riskli gebelikte süre ve şiddeti ebeniz belirler.',
      'Orta şiddet, konuşabildiğiniz ama şarkı söyleyemediğiniz tempodur.',
      'Düşme riski olan sporlardan ve temas sporlarından kaçının.',
    ],
  ),
  Tip(
    id: 'tehlike_belirtileri',
    title: 'Tehlike Belirtileri',
    summary: 'Bu belirtilerden biri olursa egzersizi hemen bırakın.',
    icon: 'warning',
    body: [
      'Vajinal kanama, düzenli ağrılı kasılmalar, vajinadan sıvı gelmesi, göğüs ağrısı veya bebek hareketlerinde azalma olursa egzersizi bırakın ve hemen sağlık kuruluşuna başvurun.',
      'Baş dönmesi, baş ağrısı, nefes darlığı, baldırda ağrı/şişlik veya kas güçsüzlüğü olursa egzersizi bırakın ve ebenize danışın.',
      'Acil durumlarda 112\'yi arayın.',
    ],
  ),
  Tip(
    id: 'uyku',
    title: 'Uyku ve Dinlenme',
    summary: 'İlerleyen haftalarda yan yatarak dinlenin.',
    icon: 'sleep',
    body: [
      'Gebeliğin ilerleyen dönemlerinde uzun süre sırtüstü yatmak yerine yan yatmak önerilir.',
      'Dizlerinizin arasına ve karnınızın altına yastık koymak rahatlatır.',
      'Egzersiz sonrası kısa bir dinlenme süresi ayırın.',
    ],
  ),
];
