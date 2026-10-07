/// Gebelik profili ve gebelik haftası hesapları.
library;

import '../util/codec.dart';

/// Gebeliğin hangi trimesterde olduğu.
///
/// ACOG tanımı: 1. trimester 0–13+6 hafta, 2. trimester 14+0–27+6 hafta,
/// 3. trimester 28+0 hafta ve sonrası.
enum Trimester {
  first(1, '1. Trimester'),
  second(2, '2. Trimester'),
  third(3, '3. Trimester');

  const Trimester(this.number, this.label);
  final int number;
  final String label;

  static Trimester fromWeeks(int weeks) {
    if (weeks < 14) return Trimester.first;
    if (weeks < 28) return Trimester.second;
    return Trimester.third;
  }

  static Trimester fromNumber(int n) =>
      Trimester.values.firstWhere((t) => t.number == n);
}

/// Gebelik haftası (hafta + gün).
class GestationalAge implements Comparable<GestationalAge> {
  const GestationalAge(this.totalDays);

  /// Son adet tarihinden hesaplanır.
  factory GestationalAge.fromLastMenstrualPeriod(DateTime lmp, DateTime now) =>
      GestationalAge(_dateOnly(now).difference(_dateOnly(lmp)).inDays);

  /// Tahmini doğum tarihinden hesaplanır (gebelik 280 gün kabul edilir).
  factory GestationalAge.fromDueDate(DateTime dueDate, DateTime now) =>
      GestationalAge(
          280 - _dateOnly(dueDate).difference(_dateOnly(now)).inDays);

  final int totalDays;

  int get weeks => totalDays ~/ 7;
  int get days => totalDays % 7;
  Trimester get trimester => Trimester.fromWeeks(weeks);

  /// 0–42 hafta dışındaki değerler büyük olasılıkla hatalı tarih girişidir.
  bool get isPlausible => totalDays >= 0 && totalDays <= 42 * 7;

  String get label => '$weeks hafta $days gün';

  @override
  int compareTo(GestationalAge other) => totalDays.compareTo(other.totalDays);

  @override
  bool operator ==(Object other) =>
      other is GestationalAge && other.totalDays == totalDays;

  @override
  int get hashCode => totalDays.hashCode;

  @override
  String toString() => label;
}

DateTime _dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// Riskli gebelik kapsamında değerlendirilen ve egzersize engel olmayan
/// (ama programın bireyselleştirilmesini gerektiren) risk faktörleri.
enum RiskFactor {
  gestationalDiabetes('gestational_diabetes', 'Gestasyonel diyabet'),
  pregestationalDiabetes('pregestational_diabetes', 'Gebelik öncesi diyabet'),
  chronicHypertension('chronic_hypertension', 'Kontrollü kronik hipertansiyon'),
  obesity('obesity', 'Gebelik öncesi obezite (BKİ ≥ 30)'),
  advancedMaternalAge(
      'advanced_maternal_age', 'İleri anne yaşı (35 yaş ve üzeri)'),
  thyroidDisease('thyroid_disease', 'Tiroid hastalığı'),
  previousPretermBirth(
      'previous_preterm_birth', 'Önceki gebelikte erken doğum'),
  previousCesarean('previous_cesarean', 'Önceki sezaryen'),
  ivfPregnancy('ivf_pregnancy', 'Yardımla üreme (tüp bebek) gebeliği'),
  pelvicGirdlePain('pelvic_girdle_pain', 'Pelvik kuşak / bel ağrısı'),
  other('other', 'Diğer');

  const RiskFactor(this.id, this.label);
  final String id;
  final String label;

  static RiskFactor? byId(String id) {
    for (final r in RiskFactor.values) {
      if (r.id == id) return r;
    }
    return null;
  }
}

/// Gebenin kendisinin girdiği temel bilgiler.
class PregnancyProfile {
  const PregnancyProfile({
    required this.fullName,
    required this.birthDate,
    this.lastMenstrualPeriod,
    this.dueDate,
    this.heightCm,
    this.prePregnancyWeightKg,
    this.riskFactors = const {},
    this.otherRiskNote,
    this.takesBetaBlocker = false,
    this.phone,
  }) : assert(lastMenstrualPeriod != null || dueDate != null);

  final String fullName;
  final DateTime birthDate;
  final DateTime? lastMenstrualPeriod;
  final DateTime? dueDate;
  final double? heightCm;
  final double? prePregnancyWeightKg;
  final Set<RiskFactor> riskFactors;
  final String? otherRiskNote;

  /// Nabız yanıtını baskılayan ilaç kullanımı; bu durumda nabız eşikleri
  /// yerine algılanan zorlanma ve konuşma testi kullanılır.
  final bool takesBetaBlocker;
  final String? phone;

  int ageAt(DateTime now) {
    var age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  /// Gebelik öncesi beden kitle indeksi.
  double? get prePregnancyBmi {
    final h = heightCm, w = prePregnancyWeightKg;
    if (h == null || w == null || h <= 0) return null;
    final m = h / 100;
    return w / (m * m);
  }

  GestationalAge gestationalAgeAt(DateTime now) {
    if (lastMenstrualPeriod != null) {
      return GestationalAge.fromLastMenstrualPeriod(lastMenstrualPeriod!, now);
    }
    return GestationalAge.fromDueDate(dueDate!, now);
  }

  /// Tahmini doğum tarihi (verilmediyse son adet tarihi + 280 gün).
  DateTime get estimatedDueDate =>
      dueDate ?? lastMenstrualPeriod!.add(const Duration(days: 280));

  PregnancyProfile copyWith({
    String? fullName,
    DateTime? birthDate,
    DateTime? lastMenstrualPeriod,
    DateTime? dueDate,
    double? heightCm,
    double? prePregnancyWeightKg,
    Set<RiskFactor>? riskFactors,
    String? otherRiskNote,
    bool? takesBetaBlocker,
    String? phone,
  }) =>
      PregnancyProfile(
        fullName: fullName ?? this.fullName,
        birthDate: birthDate ?? this.birthDate,
        lastMenstrualPeriod: lastMenstrualPeriod ?? this.lastMenstrualPeriod,
        dueDate: dueDate ?? this.dueDate,
        heightCm: heightCm ?? this.heightCm,
        prePregnancyWeightKg: prePregnancyWeightKg ?? this.prePregnancyWeightKg,
        riskFactors: riskFactors ?? this.riskFactors,
        otherRiskNote: otherRiskNote ?? this.otherRiskNote,
        takesBetaBlocker: takesBetaBlocker ?? this.takesBetaBlocker,
        phone: phone ?? this.phone,
      );

  Map<String, Object?> toMap() => {
        'fullName': fullName,
        'birthDate': birthDate.millisecondsSinceEpoch,
        'lastMenstrualPeriod': lastMenstrualPeriod?.millisecondsSinceEpoch,
        'dueDate': dueDate?.millisecondsSinceEpoch,
        'heightCm': heightCm,
        'prePregnancyWeightKg': prePregnancyWeightKg,
        'riskFactors': riskFactors.map((r) => r.id).toList(),
        'otherRiskNote': otherRiskNote,
        'takesBetaBlocker': takesBetaBlocker,
        'phone': phone,
      };

  factory PregnancyProfile.fromMap(Map<String, Object?> m) => PregnancyProfile(
        fullName: m['fullName'] as String,
        birthDate: dateFrom(m['birthDate'])!,
        lastMenstrualPeriod: dateFrom(m['lastMenstrualPeriod']),
        dueDate: dateFrom(m['dueDate']),
        heightCm: (m['heightCm'] as num?)?.toDouble(),
        prePregnancyWeightKg: (m['prePregnancyWeightKg'] as num?)?.toDouble(),
        riskFactors: ((m['riskFactors'] as List?) ?? const [])
            .map((e) => RiskFactor.byId(e as String))
            .whereType<RiskFactor>()
            .toSet(),
        otherRiskNote: m['otherRiskNote'] as String?,
        takesBetaBlocker: (m['takesBetaBlocker'] as bool?) ?? false,
        phone: m['phone'] as String?,
      );
}
