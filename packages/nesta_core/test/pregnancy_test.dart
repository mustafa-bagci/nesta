import 'package:nesta_core/nesta_core.dart';
import 'package:test/test.dart';

void main() {
  group('GestationalAge', () {
    test('son adet tarihinden hafta ve gün hesaplanır', () {
      final ga = GestationalAge.fromLastMenstrualPeriod(
          DateTime(2026, 1, 1), DateTime(2026, 3, 1));
      expect(ga.totalDays, 59);
      expect(ga.weeks, 8);
      expect(ga.days, 3);
      expect(ga.label, '8 hafta 3 gün');
    });

    test('tahmini doğum tarihinden hesaplanır', () {
      final now = DateTime(2026, 10, 7);
      final ga =
          GestationalAge.fromDueDate(now.add(const Duration(days: 140)), now);
      expect(ga.weeks, 20);
      expect(ga.days, 0);
    });

    test('trimester sınırları ACOG tanımına uyar', () {
      expect(const GestationalAge(13 * 7 + 6).trimester, Trimester.first);
      expect(const GestationalAge(14 * 7).trimester, Trimester.second);
      expect(const GestationalAge(27 * 7 + 6).trimester, Trimester.second);
      expect(const GestationalAge(28 * 7).trimester, Trimester.third);
    });

    test('mantıksız tarih işaretlenir', () {
      expect(const GestationalAge(-3).isPlausible, isFalse);
      expect(const GestationalAge(45 * 7).isPlausible, isFalse);
      expect(const GestationalAge(30 * 7).isPlausible, isTrue);
    });
  });

  group('PregnancyProfile', () {
    final profile = PregnancyProfile(
      fullName: 'Ayşe Yılmaz',
      birthDate: DateTime.utc(1994, 6, 15),
      lastMenstrualPeriod: DateTime.utc(2026, 4, 1),
      heightCm: 165,
      prePregnancyWeightKg: 70,
      riskFactors: {RiskFactor.gestationalDiabetes, RiskFactor.obesity},
      takesBetaBlocker: true,
    );

    test('yaş doğum gününe göre hesaplanır', () {
      expect(profile.ageAt(DateTime(2026, 6, 14)), 31);
      expect(profile.ageAt(DateTime(2026, 6, 15)), 32);
    });

    test('BKİ hesaplanır', () {
      expect(profile.prePregnancyBmi, closeTo(25.7, 0.05));
    });

    test('tahmini doğum tarihi SAT + 280 gündür', () {
      expect(profile.estimatedDueDate, DateTime.utc(2027, 1, 6));
    });

    test('serileştirme geri dönüşümlüdür', () {
      final back = PregnancyProfile.fromMap(profile.toMap());
      expect(back.fullName, profile.fullName);
      expect(back.birthDate, profile.birthDate);
      expect(back.lastMenstrualPeriod, profile.lastMenstrualPeriod);
      expect(back.riskFactors, profile.riskFactors);
      expect(back.takesBetaBlocker, isTrue);
      expect(back.prePregnancyBmi, profile.prePregnancyBmi);
    });
  });
}
