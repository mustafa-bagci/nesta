import 'package:nesta_core/nesta_core.dart';
import 'package:test/test.dart';

Map<String, bool> _allNo() =>
    {for (final q in allScreeningQuestions) q.id: false};

void main() {
  final now = DateTime.utc(2026, 10, 7);

  test('soru kimlikleri benzersizdir', () {
    final ids = allScreeningQuestions.map((q) => q.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('tüm yanıtlar hayır ise uygun', () {
    final r = ScreeningResult(answers: _allNo(), completedAt: now);
    expect(r.isComplete, isTrue);
    expect(r.outcome, ScreeningOutcome.eligible);
  });

  test('göreceli kontrendikasyon değerlendirme gerektirir', () {
    final r =
        ScreeningResult(answers: _allNo()..['anemia'] = true, completedAt: now);
    expect(r.outcome, ScreeningOutcome.needsReview);
    expect(r.positiveRelative.single.id, 'anemia');
  });

  test('mutlak kontrendikasyon programı kapatır', () {
    final r = ScreeningResult(
        answers: _allNo()
          ..['anemia'] = true
          ..['preeclampsia'] = true,
        completedAt: now);
    expect(r.outcome, ScreeningOutcome.ineligible);
  });

  test('eksik yanıt tamamlanmamış sayılır', () {
    final r = ScreeningResult(
        answers: _allNo()..remove('preeclampsia'), completedAt: now);
    expect(r.isComplete, isFalse);
  });

  test('serileştirme geri dönüşümlüdür', () {
    final r = ScreeningResult(
        answers: _allNo()..['heavy_smoker'] = true, completedAt: now);
    final back = ScreeningResult.fromMap(r.toMap());
    expect(back.answers, r.answers);
    expect(back.completedAt, now);
    expect(back.outcome, ScreeningOutcome.needsReview);
  });

  group('SymptomCheck', () {
    test('acil belirti işaretlenir', () {
      final c = SymptomCheck(present: {'headache'}, checkedAt: now);
      expect(c.isClear, isFalse);
      expect(c.hasUrgent, isFalse);
      final u = SymptomCheck(present: {'vaginal_bleeding'}, checkedAt: now);
      expect(u.hasUrgent, isTrue);
    });

    test('boş kontrol temizdir', () {
      expect(SymptomCheck(present: {}, checkedAt: now).isClear, isTrue);
    });
  });
}
