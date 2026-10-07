/// Egzersiz öncesi kontrendikasyon taraması.
///
/// Sorular ACOG Committee Opinion 804 (2020) "absolute" ve "relative"
/// kontrendikasyon listelerinden uyarlanmıştır. Klinik ekip tarafından
/// gözden geçirilmeden metinler değiştirilmemelidir.
library;

import '../util/codec.dart';

enum ContraindicationLevel { absolute, relative }

class ScreeningQuestion {
  const ScreeningQuestion(this.id, this.text, this.level, {this.hint});

  final String id;
  final String text;
  final ContraindicationLevel level;
  final String? hint;
}

/// ACOG (2020) mutlak kontrendikasyonları — biri bile "evet" ise
/// uygulama egzersiz programını açmaz.
const absoluteContraindications = <ScreeningQuestion>[
  ScreeningQuestion(
      'heart_disease',
      'Hekiminizin önemli olduğunu söylediği bir kalp hastalığınız var mı?',
      ContraindicationLevel.absolute),
  ScreeningQuestion(
      'restrictive_lung',
      'Kısıtlayıcı (restriktif) bir akciğer hastalığınız var mı?',
      ContraindicationLevel.absolute),
  ScreeningQuestion(
      'cervical_insufficiency',
      'Rahim ağzı yetmezliği tanınız var mı veya rahim ağzınıza dikiş (serklaj) atıldı mı?',
      ContraindicationLevel.absolute),
  ScreeningQuestion(
      'multiple_preterm_risk',
      'Erken doğum riski taşıyan çoğul (ikiz, üçüz) gebeliğiniz var mı?',
      ContraindicationLevel.absolute),
  ScreeningQuestion(
      'persistent_bleeding',
      'Gebeliğin 2. veya 3. trimesterinde süregelen vajinal kanamanız var mı?',
      ContraindicationLevel.absolute),
  ScreeningQuestion(
      'placenta_previa',
      '26. gebelik haftasından sonra plasenta previa (önde yerleşimli plasenta) tanınız var mı?',
      ContraindicationLevel.absolute),
  ScreeningQuestion(
      'preterm_labor',
      'Bu gebelikte erken doğum eylemi (erken sancı) geçirdiniz mi?',
      ContraindicationLevel.absolute),
  ScreeningQuestion(
      'ruptured_membranes',
      'Su keseniz açıldı mı (amniyon sıvısı geliyor mu)?',
      ContraindicationLevel.absolute),
  ScreeningQuestion(
      'preeclampsia',
      'Preeklampsi veya gebeliğe bağlı yüksek tansiyon tanınız var mı?',
      ContraindicationLevel.absolute),
  ScreeningQuestion(
      'severe_anemia',
      'Hekiminizin ağır olarak nitelendirdiği bir kansızlığınız (anemi) var mı?',
      ContraindicationLevel.absolute),
];

/// ACOG (2020) göreceli kontrendikasyonları — "evet" yanıtı programı
/// kapatmaz, ancak ebe/hekim onayında özellikle değerlendirilir.
const relativeContraindications = <ScreeningQuestion>[
  ScreeningQuestion('anemia', 'Kansızlığınız (anemi) var mı?',
      ContraindicationLevel.relative),
  ScreeningQuestion(
      'arrhythmia',
      'Değerlendirilmemiş bir kalp ritim bozukluğunuz var mı?',
      ContraindicationLevel.relative),
  ScreeningQuestion('chronic_bronchitis', 'Kronik bronşitiniz var mı?',
      ContraindicationLevel.relative),
  ScreeningQuestion('uncontrolled_t1dm', 'Kontrolsüz tip 1 diyabetiniz var mı?',
      ContraindicationLevel.relative),
  ScreeningQuestion(
      'extreme_obesity',
      'Hekiminiz aşırı (morbid) obezite tanısı koydu mu?',
      ContraindicationLevel.relative),
  ScreeningQuestion(
      'extreme_underweight',
      'Hekiminiz aşırı düşük kilolu olduğunuzu söyledi mi?',
      ContraindicationLevel.relative),
  ScreeningQuestion(
      'sedentary',
      'Gebelikten önce neredeyse hiç fiziksel aktivite yapmıyor muydunuz?',
      ContraindicationLevel.relative),
  ScreeningQuestion(
      'fetal_growth_restriction',
      'Bu gebelikte bebeğinizde gelişme geriliği saptandı mı?',
      ContraindicationLevel.relative),
  ScreeningQuestion(
      'uncontrolled_hypertension',
      'Kontrol altında olmayan yüksek tansiyonunuz var mı?',
      ContraindicationLevel.relative),
  ScreeningQuestion(
      'orthopedic',
      'Hareketinizi kısıtlayan ortopedik bir sorununuz var mı?',
      ContraindicationLevel.relative),
  ScreeningQuestion(
      'seizure',
      'Kontrol altında olmayan epilepsi/nöbet hastalığınız var mı?',
      ContraindicationLevel.relative),
  ScreeningQuestion(
      'hyperthyroidism',
      'Kontrol altında olmayan hipertiroidiniz var mı?',
      ContraindicationLevel.relative),
  ScreeningQuestion(
      'heavy_smoker',
      'Günde 20 veya daha fazla sigara içiyor musunuz?',
      ContraindicationLevel.relative),
];

const allScreeningQuestions = [
  ...absoluteContraindications,
  ...relativeContraindications,
];

enum ScreeningOutcome {
  /// Mutlak kontrendikasyon yok, göreceli de yok.
  eligible('eligible', 'Uygun'),

  /// Göreceli kontrendikasyon var — ebe/hekim ayrıca değerlendirmeli.
  needsReview('needs_review', 'Değerlendirme gerekli'),

  /// Mutlak kontrendikasyon var — program açılmaz.
  ineligible('ineligible', 'Egzersiz önerilmez');

  const ScreeningOutcome(this.id, this.label);
  final String id;
  final String label;
}

/// Tarama formuna verilen yanıtlar.
class ScreeningResult {
  ScreeningResult(
      {required Map<String, bool> answers, required this.completedAt})
      : answers = Map.unmodifiable(answers);

  /// Soru kimliği → "evet" mi?
  final Map<String, bool> answers;
  final DateTime completedAt;

  bool get isComplete =>
      allScreeningQuestions.every((q) => answers.containsKey(q.id));

  List<ScreeningQuestion> get positiveAbsolute =>
      absoluteContraindications.where((q) => answers[q.id] == true).toList();

  List<ScreeningQuestion> get positiveRelative =>
      relativeContraindications.where((q) => answers[q.id] == true).toList();

  ScreeningOutcome get outcome {
    if (positiveAbsolute.isNotEmpty) return ScreeningOutcome.ineligible;
    if (positiveRelative.isNotEmpty) return ScreeningOutcome.needsReview;
    return ScreeningOutcome.eligible;
  }

  Map<String, Object?> toMap() => {
        'answers': answers,
        'completedAt': millis(completedAt),
        'outcome': outcome.id,
      };

  factory ScreeningResult.fromMap(Map<String, Object?> m) => ScreeningResult(
        answers: mapFrom(m['answers']).map((k, v) => MapEntry(k, v == true)),
        completedAt: dateFrom(m['completedAt'])!,
      );
}

/// ACOG (2020) "egzersizi bırakma" belirtileri; her seans öncesinde ve
/// sırasında sorulur. Herhangi biri varsa egzersiz yapılmaz.
class WarningSign {
  const WarningSign(this.id, this.text, {this.urgent = false});
  final String id;
  final String text;

  /// Acil başvuru gerektiren belirti.
  final bool urgent;
}

const warningSigns = <WarningSign>[
  WarningSign('vaginal_bleeding', 'Vajinal kanama', urgent: true),
  WarningSign('contractions', 'Düzenli ve ağrılı rahim kasılmaları',
      urgent: true),
  WarningSign('fluid_leakage', 'Vajinadan sıvı gelmesi', urgent: true),
  WarningSign('chest_pain', 'Göğüs ağrısı', urgent: true),
  WarningSign('reduced_fetal_movement', 'Bebek hareketlerinde azalma',
      urgent: true),
  WarningSign('dyspnea', 'Hareket etmeden önce nefes darlığı'),
  WarningSign('dizziness', 'Baş dönmesi veya bayılacak gibi olma'),
  WarningSign('headache', 'Baş ağrısı'),
  WarningSign('muscle_weakness', 'Dengenizi etkileyen kas güçsüzlüğü'),
  WarningSign('calf_pain', 'Baldırda ağrı veya şişlik'),
];

WarningSign? warningSignById(String id) {
  for (final w in warningSigns) {
    if (w.id == id) return w;
  }
  return null;
}

/// Seans öncesi veya sonrası belirti sorgusu sonucu.
class SymptomCheck {
  SymptomCheck({required Set<String> present, required this.checkedAt})
      : present = Set.unmodifiable(present);

  final Set<String> present;
  final DateTime checkedAt;

  bool get isClear => present.isEmpty;
  bool get hasUrgent =>
      present.any((id) => warningSignById(id)?.urgent ?? false);

  List<WarningSign> get signs =>
      present.map(warningSignById).whereType<WarningSign>().toList();

  Map<String, Object?> toMap() => {
        'present': present.toList()..sort(),
        'checkedAt': millis(checkedAt),
      };

  factory SymptomCheck.fromMap(Map<String, Object?> m) => SymptomCheck(
        present: ((m['present'] as List?) ?? const []).cast<String>().toSet(),
        checkedAt: dateFrom(m['checkedAt'])!,
      );
}
